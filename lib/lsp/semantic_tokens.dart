import 'package:klin/analyze.dart';
import 'package:klin/navigate.dart';
import 'package:klin/token.dart';
import 'package:lsp_server/lsp_server.dart';

/// Legend advertised by `klin lsp` (issue 094). Indices must match
/// [_typeForNav] / modifier bits below.
final SemanticTokensLegend klinSemanticTokensLegend = SemanticTokensLegend(
  tokenTypes: const [
    'function',
    'method',
    'parameter',
    'variable',
    'property',
    'struct',
    'enum',
    'enumMember',
    'type',
  ],
  tokenModifiers: const [
    'declaration',
    'readonly',
    'defaultLibrary',
  ],
);

const _typeFunction = 0;
const _typeMethod = 1;
const _typeParameter = 2;
const _typeVariable = 3;
const _typeProperty = 4;
const _typeStruct = 5;
const _typeEnum = 6;
const _typeEnumMember = 7;
// Legend index 8 (`type`) reserved for future type-annotation sites.

const _modDeclaration = 1 << 0;
const _modReadonly = 1 << 1;
const _modDefaultLibrary = 1 << 2;

/// Builds LSP semantic tokens for the open buffer (full document).
///
/// Empty when analysis has no program or positions are skewed (same policy as
/// hover / completion).
SemanticTokens buildSemanticTokens(
  AnalysisResult result, {
  required String openPath,
}) {
  final program = result.program;
  if (program == null || result.positionsSkewed) {
    return SemanticTokens(data: const []);
  }

  final raw = <_Tok>[];

  for (final t in allNavTargets(program)) {
    final path = t.occurrencePath ?? openPath;
    if (!sameDiagnosticPath(path, openPath)) continue;
    final pos = _toEditorPos(t.pos, path, result.sourceMap, openPath);
    var mods = 0;
    if (semanticNavIsDeclaration(t)) mods |= _modDeclaration;
    if (semanticNavIsReadonly(t)) mods |= _modReadonly;
    if (semanticNavIsCimport(t)) mods |= _modDefaultLibrary;
    raw.add(_Tok(pos, t.nameLength, _typeForNav(semanticNavKind(t)), mods));
  }

  for (final s in program.structs) {
    final path = s.sourcePath ?? openPath;
    if (!sameDiagnosticPath(path, openPath)) continue;
    final pos = _toEditorPos(s.namePos, path, result.sourceMap, openPath);
    raw.add(_Tok(pos, s.name.length, _typeStruct, _modDeclaration));
    for (final f in s.fields) {
      final fp = _toEditorPos(f.pos, path, result.sourceMap, openPath);
      raw.add(_Tok(fp, f.name.length, _typeProperty, _modDeclaration));
    }
  }

  for (final e in program.enums) {
    final path = e.sourcePath ?? openPath;
    if (!sameDiagnosticPath(path, openPath)) continue;
    final pos = _toEditorPos(e.namePos, path, result.sourceMap, openPath);
    raw.add(_Tok(pos, e.name.length, _typeEnum, _modDeclaration));
    for (final v in e.variants) {
      final vp = _toEditorPos(v.pos, path, result.sourceMap, openPath);
      raw.add(_Tok(vp, v.name.length, _typeEnumMember, _modDeclaration));
    }
  }

  raw.sort((a, b) {
    if (a.pos.line != b.pos.line) return a.pos.line.compareTo(b.pos.line);
    return a.pos.col.compareTo(b.pos.col);
  });

  return SemanticTokens(data: _encodeRelative(raw));
}

int _typeForNav(SemanticNavKind k) => switch (k) {
      SemanticNavKind.function || SemanticNavKind.call => _typeFunction,
      SemanticNavKind.method => _typeMethod,
      SemanticNavKind.parameter => _typeParameter,
      SemanticNavKind.variable => _typeVariable,
      SemanticNavKind.property => _typeProperty,
      SemanticNavKind.enumMember => _typeEnumMember,
    };

SourcePos _toEditorPos(
  SourcePos expandedPos,
  String occurrencePath,
  SourceMap? map,
  String openPath,
) {
  if (map == null) return expandedPos;
  if (!sameDiagnosticPath(occurrencePath, openPath)) return expandedPos;
  return map.toOriginal(expandedPos);
}

List<int> _encodeRelative(List<_Tok> toks) {
  final data = <int>[];
  var prevLine = 1;
  var prevCol = 1;
  for (final t in toks) {
    if (t.length <= 0) continue;
    final line = t.pos.line;
    final col = t.pos.col;
    final deltaLine = line - prevLine;
    final deltaCol = deltaLine == 0 ? col - prevCol : col - 1;
    data.addAll([deltaLine, deltaCol, t.length, t.type, t.mods]);
    prevLine = line;
    prevCol = col;
  }
  return data;
}

final class _Tok {
  final SourcePos pos;
  final int length;
  final int type;
  final int mods;
  _Tok(this.pos, this.length, this.type, this.mods);
}
