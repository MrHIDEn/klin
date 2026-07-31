import 'svd/fluent.dart';
import 'svd/model.dart';
import 'token.dart';

export 'token.dart' show PreprocessError;

/// Compile-time `$fn` macros (decision D3) and built-in `$peripherals_from_svd`.
/// Runs before lex/parse of Klin.
///
/// ```
/// $fn point(name: name, T: type) {
///   struct $name { x: $T  y: $T }
///   fn (p: $name) len_sq(): $T { return p.x * p.x + p.y * p.y }
/// }
/// $point(Vec2i, i32)
/// ```

final class _MacroParam {
  final String name;
  final String kind; // `type` | `name` | `str`

  const _MacroParam(this.name, this.kind);
}

final class _MacroDef {
  final String name;
  final List<_MacroParam> params;
  final String body;
  final SourcePos pos;

  const _MacroDef({
    required this.name,
    required this.params,
    required this.body,
    required this.pos,
  });
}

/// Expands `$fn` definitions and `$name(...)` invocations in [source].
String preprocess(String source, {String path = '<input>'}) {
  final scanner = _PpScanner(source, path);
  return scanner.expand();
}

final class _PpScanner {
  final String source;
  final String path;
  int _i = 0;
  int _line = 1;
  int _col = 1;

  _PpScanner(this.source, this.path);

  Never _err(String message, [SourcePos? pos]) =>
      throw PreprocessError(message, pos ?? _pos, path: path);

  String expand() {
    final macros = <String, _MacroDef>{};
    final out = StringBuffer();
    SvdDevice? svdDevice;

    while (!_atEnd) {
      if (_startsWithFn()) {
        final def = _parseFnDef();
        if (macros.containsKey(def.name)) {
          _err('redefinition of macro `\$${def.name}`', def.pos);
        }
        macros[def.name] = def;
        continue;
      }

      if (_peek == r'$' &&
          _i + 1 < source.length &&
          _isIdentStart(source[_i + 1])) {
        final start = _pos;
        _advance(); // $
        final name = _readIdent();
        _skipSpace();
        if (!_atEnd && _peek == '(') {
          if (name == 'peripherals_from_svd') {
            if (svdDevice != null) {
              _err('duplicate `\$peripherals_from_svd`', start);
            }
            final args = _parseArgList();
            if (args.isEmpty || args.length > 2) {
              _err(
                '`\$peripherals_from_svd` expects 1 or 2 arguments '
                '(svd path[, peripherals])',
                start,
              );
            }
            final expansion = expandPeripheralsFromSvd(
              svdArg: args[0],
              peripheralsArg: args.length > 1 ? args[1] : null,
              sourcePath: path,
              callPos: start,
            );
            svdDevice = expansion.device;
            out.write(expansion.klinSnippet);
            continue;
          }
          final def = macros[name];
          if (def == null) {
            _err('unknown macro `\$$name`', start);
          }
          final args = _parseArgList();
          out.write(_expandCall(def, args, start));
          continue;
        }
        _err('expected `(` after macro `\$$name`', start);
      }

      // Skip strings / comments so `$` inside them is left alone.
      if (_peek == '"') {
        out.write(_readStringLiteral());
        continue;
      }
      if (_peek == '/' && _i + 1 < source.length && source[_i + 1] == '/') {
        out.write(_readLineComment());
        continue;
      }

      out.write(_advance());
    }

    final text = out.toString();
    if (svdDevice == null) return text;
    return rewriteSvdFluent(text, svdDevice, path: path);
  }

  bool _startsWithFn() {
    if (!_startsWith(r'$fn')) return false;
    final after = _i + 3;
    if (after >= source.length) return true;
    return !_isIdentContinue(source[after]);
  }

  _MacroDef _parseFnDef() {
    final start = _pos;
    _expectPrefix(r'$fn');
    _skipSpace();
    final name = _readIdent();
    if (name.isEmpty) {
      _err('expected macro name after `\$fn`');
    }
    _skipSpace();
    if (_atEnd || _peek != '(') {
      _err('expected `(` after macro name');
    }
    _advance();
    final params = <_MacroParam>[];
    _skipSpace();
    if (!_atEnd && _peek != ')') {
      while (true) {
        _skipSpace();
        final pname = _readIdent();
        if (pname.isEmpty) {
          _err('expected parameter name');
        }
        _skipSpace();
        if (_atEnd || _peek != ':') {
          _err('expected `:` after parameter `$pname`');
        }
        _advance();
        _skipSpace();
        final kind = _readIdent();
        if (kind != 'type' && kind != 'name' && kind != 'str') {
          _err('macro parameter kind must be `type`, `name`, or `str`');
        }
        params.add(_MacroParam(pname, kind));
        _skipSpace();
        if (!_atEnd && _peek == ',') {
          _advance();
          continue;
        }
        break;
      }
    }
    _skipSpace();
    if (_atEnd || _peek != ')') {
      _err('expected `)` after macro parameters');
    }
    _advance();
    _skipSpace();
    if (_atEnd || _peek != '{') {
      _err('expected `{` to start macro body');
    }
    final body = _readBalanced('{', '}');
    return _MacroDef(name: name, params: params, body: body, pos: start);
  }

  List<String> _parseArgList() {
    if (_atEnd || _peek != '(') {
      _err('expected `(`');
    }
    _advance();
    final args = <String>[];
    _skipSpace();
    if (!_atEnd && _peek == ')') {
      _advance();
      return args;
    }
    while (true) {
      _skipSpace();
      final arg = _readArg();
      args.add(arg);
      _skipSpace();
      if (!_atEnd && _peek == ',') {
        _advance();
        continue;
      }
      break;
    }
    _skipSpace();
    if (_atEnd || _peek != ')') {
      _err('expected `)` after macro arguments');
    }
    _advance();
    return args;
  }

  String _readArg() {
    if (_atEnd) _err('expected macro argument');
    if (_peek == '"') {
      final lit = _readStringLiteral();
      // Strip quotes for substitution into `$name` / `$T` slots.
      return lit.substring(1, lit.length - 1);
    }
    // Bare identifier or type name (i32, *mut u8 — MVP: single ident only).
    final id = _readIdent();
    if (id.isEmpty) {
      _err('expected macro argument');
    }
    return id;
  }

  String _expandCall(_MacroDef def, List<String> args, SourcePos callPos) {
    if (args.length != def.params.length) {
      _err(
        'macro `\$${def.name}` expects ${def.params.length} arguments, '
        'got ${args.length}',
        callPos,
      );
    }
    var body = def.body;
    for (var i = 0; i < def.params.length; i++) {
      final param = def.params[i];
      final value = args[i];
      body = body.replaceAllMapped(
        RegExp('\\\$' + RegExp.escape(param.name) + r'\b'),
        (_) => value,
      );
    }
    final leftover = _firstCodeSlot(body);
    if (leftover != null) {
      _err(
        'unsubstituted `$leftover` in expansion of `\$${def.name}`',
        callPos,
      );
    }
    return body;
  }

  /// First `$ident` outside string literals and `//` comments, if any.
  static String? _firstCodeSlot(String text) {
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (c == '"') {
        i++;
        while (i < text.length && text[i] != '"') {
          if (text[i] == '\\' && i + 1 < text.length) i += 2;
          else i++;
        }
        if (i < text.length) i++;
        continue;
      }
      if (c == '/' && i + 1 < text.length && text[i + 1] == '/') {
        i += 2;
        while (i < text.length && text[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == r'$' &&
          i + 1 < text.length &&
          _isIdentStart(text[i + 1])) {
        final start = i;
        i += 2;
        while (i < text.length && _isIdentContinue(text[i])) {
          i++;
        }
        return text.substring(start, i);
      }
      i++;
    }
    return null;
  }

  String _readBalanced(String open, String close) {
    if (_atEnd || _peek != open) {
      _err('expected `$open`');
    }
    _advance(); // consume open
    final buf = StringBuffer();
    var depth = 1;
    while (!_atEnd && depth > 0) {
      if (_peek == '"') {
        buf.write(_readStringLiteral());
        continue;
      }
      if (_peek == '/' && _i + 1 < source.length && source[_i + 1] == '/') {
        buf.write(_readLineComment());
        continue;
      }
      final c = _advance();
      if (c == open) {
        depth++;
        buf.write(c);
      } else if (c == close) {
        depth--;
        if (depth > 0) buf.write(c);
      } else {
        buf.write(c);
      }
    }
    if (depth != 0) {
      _err('unclosed `$open` in macro body');
    }
    return buf.toString();
  }

  String _readStringLiteral() {
    final buf = StringBuffer();
    buf.write(_advance()); // "
    while (!_atEnd && _peek != '"') {
      if (_peek == '\\') {
        buf.write(_advance());
        if (!_atEnd) buf.write(_advance());
      } else {
        buf.write(_advance());
      }
    }
    if (_atEnd) _err('unterminated string in macro');
    buf.write(_advance()); // closing "
    return buf.toString();
  }

  String _readLineComment() {
    final buf = StringBuffer();
    while (!_atEnd && _peek != '\n') {
      buf.write(_advance());
    }
    return buf.toString();
  }

  void _expectPrefix(String prefix) {
    if (!_startsWith(prefix)) {
      _err('expected `$prefix`');
    }
    for (var k = 0; k < prefix.length; k++) {
      _advance();
    }
  }

  bool _startsWith(String s) {
    if (_i + s.length > source.length) return false;
    return source.substring(_i, _i + s.length) == s;
  }

  void _skipSpace() {
    while (!_atEnd) {
      final c = _peek;
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        _advance();
      } else if (c == '/' && _i + 1 < source.length && source[_i + 1] == '/') {
        while (!_atEnd && _peek != '\n') {
          _advance();
        }
      } else {
        break;
      }
    }
  }

  String _readIdent() {
    if (_atEnd || !_isIdentStart(_peek)) return '';
    final start = _i;
    _advance();
    while (!_atEnd && _isIdentContinue(_peek)) {
      _advance();
    }
    return source.substring(start, _i);
  }

  SourcePos get _pos => SourcePos(_line, _col);

  bool get _atEnd => _i >= source.length;

  String get _peek => source[_i];

  String _advance() {
    final c = source[_i++];
    if (c == '\n') {
      _line++;
      _col = 1;
    } else {
      _col++;
    }
    return c;
  }

  static bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95;
  }

  static bool _isIdentContinue(String c) =>
      _isIdentStart(c) || (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57);
}
