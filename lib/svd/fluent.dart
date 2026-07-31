import 'dart:io';

import '../token.dart';
import 'emit.dart';
import 'model.dart';
import 'parse.dart';

/// Result of `$peripherals_from_svd(...)`: header on disk + device for rewrite.
final class SvdPeripheralsExpansion {
  final String cincludeSnippet;
  final SvdDevice device;

  const SvdPeripheralsExpansion({
    required this.cincludeSnippet,
    required this.device,
  });
}

/// Resolves SVD, writes `{stem}_regs.h` (and `.kl`) next to the Klin source,
/// returns `@[cinclude(...)]` text plus the parsed device for fluent rewrite.
SvdPeripheralsExpansion expandPeripheralsFromSvd({
  required String svdArg,
  String? peripheralsArg,
  required String sourcePath,
  required SourcePos callPos,
}) {
  final sourceFile = File(sourcePath).absolute;
  final sourceDir = sourceFile.parent;
  final svdFile = File(
    svdArg.startsWith('/') || _isWindowsDrive(svdArg)
        ? svdArg
        : '${sourceDir.path}${Platform.pathSeparator}$svdArg',
  ).absolute;
  if (!svdFile.existsSync()) {
    throw PreprocessError(
      'SVD file not found `${svdFile.path}`',
      callPos,
      path: sourcePath,
    );
  }

  final Set<String>? peripherals;
  if (peripheralsArg == null || peripheralsArg == 'ALL') {
    peripherals = null;
  } else {
    peripherals = peripheralsArg
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    if (peripherals.isEmpty) {
      throw PreprocessError(
        'empty peripherals list in `\$peripherals_from_svd`',
        callPos,
        path: sourcePath,
      );
    }
  }

  final stem = _fileStem(svdFile.path);
  final includeName = '${stem}_regs.h';
  final headerPath = '${sourceDir.path}${Platform.pathSeparator}$includeName';
  final klinPath =
      '${sourceDir.path}${Platform.pathSeparator}${stem}_regs.kl';

  final device = parseSvd(
    svdFile.readAsStringSync(),
    peripherals: peripherals,
  );
  final guard = includeName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
  final generated = emitSvd(
    device,
    headerGuard: '${guard}_INCLUDED',
    includeName: includeName,
  );
  File(headerPath).writeAsStringSync(generated.header);
  File(klinPath).writeAsStringSync(generated.klin);

  return SvdPeripheralsExpansion(
    cincludeSnippet: '@[cinclude("$includeName")]\n',
    device: device,
  );
}

/// Rewrites `PERIPH.REG.FIELD.set/write/toggle(...)` to snake_case accessors.
///
/// `.EnumName` as the sole argument becomes the integer from SVD.
String rewriteSvdFluent(
  String source,
  SvdDevice device, {
  required String path,
}) {
  final fields = _indexFields(device);
  final out = StringBuffer();
  var i = 0;
  var line = 1;
  var col = 1;

  void writeChar(String c) {
    out.write(c);
    if (c == '\n') {
      line++;
      col = 1;
    } else {
      col++;
    }
    i++;
  }

  while (i < source.length) {
    final c = source[i];
    if (c == '"') {
      out.write(c);
      i++;
      col++;
      while (i < source.length && source[i] != '"') {
        if (source[i] == '\\' && i + 1 < source.length) {
          out.write(source[i]);
          out.write(source[i + 1]);
          i += 2;
          col += 2;
        } else {
          writeChar(source[i]);
        }
      }
      if (i < source.length) writeChar(source[i]);
      continue;
    }
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        writeChar(source[i]);
      }
      continue;
    }

    if (_isIdentStart(c)) {
      final start = i;
      final startPos = SourcePos(line, col);
      final ident = _readIdentAt(source, i);
      final afterIdent = start + ident.length;
      if (_looksLikeFluent(source, afterIdent)) {
        final match = _tryParseFluentCall(source, start);
        if (match != null) {
          final key = '${match.periph}.${match.reg}.${match.field}';
          final info = fields[key];
          if (info == null) {
            throw PreprocessError(
              'unknown SVD field `$key`',
              startPos,
              path: path,
            );
          }
          if (match.method == 'toggle' && !info.hasToggle) {
            throw PreprocessError(
              'field `$key` has no `toggle` accessor',
              startPos,
              path: path,
            );
          }
          if (match.method == 'toggle' && match.argsRaw.trim().isNotEmpty) {
            throw PreprocessError(
              '`toggle` takes no arguments',
              startPos,
              path: path,
            );
          }
          final args = _rewriteArgs(
            match.argsRaw,
            info,
            callPos: startPos,
            path: path,
          );
          final replacement = '${info.prefix}_${match.method}($args)';
          out.write(replacement);
          // Advance scanner past the original call.
          for (var k = start; k < match.end; k++) {
            if (source[k] == '\n') {
              line++;
              col = 1;
            } else {
              col++;
            }
          }
          i = match.end;
          continue;
        }
      }
      out.write(ident);
      i = afterIdent;
      col += ident.length;
      continue;
    }

    writeChar(c);
  }

  return out.toString();
}

final class _FieldInfo {
  final String prefix;
  final bool hasToggle;
  final Map<String, int> enums;

  const _FieldInfo({
    required this.prefix,
    required this.hasToggle,
    required this.enums,
  });
}

final class _FluentCall {
  final String periph;
  final String reg;
  final String field;
  final String method;
  final String argsRaw;
  final int end;

  const _FluentCall({
    required this.periph,
    required this.reg,
    required this.field,
    required this.method,
    required this.argsRaw,
    required this.end,
  });
}

Map<String, _FieldInfo> _indexFields(SvdDevice device) {
  final map = <String, _FieldInfo>{};
  for (final peripheral in device.peripherals) {
    for (final register in peripheral.registers) {
      for (final field in register.fields) {
        if (field.isReadOnly || register.isReadOnly) continue;
        final prefix = '${peripheral.name}_${register.name}_${field.name}';
        final writeOnly = field.isWriteOnly || register.isWriteOnly;
        final key = '${peripheral.name}.${register.name}.${field.name}';
        map[key] = _FieldInfo(
          prefix: prefix,
          hasToggle: field.bitWidth == 1 && !writeOnly,
          enums: {
            for (final value in field.enums) value.name: value.value,
          },
        );
      }
    }
  }
  return map;
}

bool _looksLikeFluent(String source, int afterFirstIdent) {
  return afterFirstIdent < source.length && source[afterFirstIdent] == '.';
}

_FluentCall? _tryParseFluentCall(String source, int start) {
  var i = start;
  final periph = _readIdentAt(source, i);
  if (periph.isEmpty) return null;
  i += periph.length;
  if (i >= source.length || source[i] != '.') return null;
  i++;
  final reg = _readIdentAt(source, i);
  if (reg.isEmpty) return null;
  i += reg.length;
  if (i >= source.length || source[i] != '.') return null;
  i++;
  final field = _readIdentAt(source, i);
  if (field.isEmpty) return null;
  i += field.length;
  if (i >= source.length || source[i] != '.') return null;
  i++;
  final method = _readIdentAt(source, i);
  if (method != 'set' && method != 'write' && method != 'toggle') {
    return null;
  }
  i += method.length;
  while (i < source.length && _isSpace(source[i])) {
    i++;
  }
  if (i >= source.length || source[i] != '(') return null;
  i++; // (
  final argsStart = i;
  var depth = 1;
  while (i < source.length && depth > 0) {
    final c = source[i];
    if (c == '"') {
      i++;
      while (i < source.length && source[i] != '"') {
        if (source[i] == '\\' && i + 1 < source.length) {
          i += 2;
        } else {
          i++;
        }
      }
      if (i < source.length) i++;
      continue;
    }
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) break;
    }
    i++;
  }
  if (depth != 0) return null;
  final argsRaw = source.substring(argsStart, i);
  i++; // )
  return _FluentCall(
    periph: periph,
    reg: reg,
    field: field,
    method: method,
    argsRaw: argsRaw,
    end: i,
  );
}

String _rewriteArgs(
  String argsRaw,
  _FieldInfo info, {
  required SourcePos callPos,
  required String path,
}) {
  final trimmed = argsRaw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length > 1 &&
      trimmed.startsWith('.') &&
      _isIdentStart(trimmed[1])) {
    final name = _readIdentAt(trimmed, 1);
    if (name.length + 1 == trimmed.length) {
      final value = info.enums[name];
      if (value == null) {
        throw PreprocessError(
          'unknown enum `.$name` for field `${info.prefix}`',
          callPos,
          path: path,
        );
      }
      return '$value';
    }
  }
  return trimmed;
}

String _readIdentAt(String source, int i) {
  if (i >= source.length || !_isIdentStart(source[i])) return '';
  final start = i;
  i++;
  while (i < source.length && _isIdentContinue(source[i])) {
    i++;
  }
  return source.substring(start, i);
}

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\r' || c == '\n';

bool _isIdentStart(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95;
}

bool _isIdentContinue(String c) =>
    _isIdentStart(c) || (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57);

bool _isWindowsDrive(String path) =>
    path.length >= 2 && path[1] == ':' && _isIdentStart(path[0]);

String _fileStem(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  return dot == -1 ? name : name.substring(0, dot);
}
