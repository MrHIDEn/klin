import 'ast.dart';
import 'checker.dart';
import 'lexer.dart';
import 'navigate.dart';
import 'parser.dart';
import 'preprocess.dart';
import 'token.dart';

export 'source_map.dart' show SourceMap;

/// Severity for editor diagnostics (issue 086). Matches LSP Error for MVP.
enum KlinDiagnosticSeverity { error }

/// One frontend error mapped for the Language Server / editors.
final class KlinDiagnostic {
  final String message;
  final SourcePos pos;
  final String path;
  final KlinDiagnosticSeverity severity;

  const KlinDiagnostic({
    required this.message,
    required this.pos,
    required this.path,
    this.severity = KlinDiagnosticSeverity.error,
  });
}

/// Result of analyzing one Klin source buffer.
final class AnalysisResult {
  final List<KlinDiagnostic> diagnostics;
  final Program? program;

  /// True when preprocess rewrote the buffer and no usable [sourceMap] exists
  /// (e.g. after SVD fluent rewrite). Nav / completion stay disabled then.
  final bool positionsSkewed;

  /// Editor ↔ expanded position map when preprocess tracking succeeded.
  final SourceMap? sourceMap;

  const AnalysisResult({
    required this.diagnostics,
    this.program,
    this.positionsSkewed = false,
    this.sourceMap,
  });
}

/// Preprocess → lex → parse → check for a single buffer.
///
/// Check-phase errors are collected per function (`collectErrors: true`) so the
/// LSP can show more than one diagnostic. Lex/parse stay fail-fast.
///
/// [requireMain] defaults to `false` (library-friendly). CLI compile paths keep
/// calling [Checker.check] with the default `true`.
///
/// When preprocess rewrites the source, [SourceMap] remaps diagnostics and
/// navigation positions back to the editor buffer. If mapping is unavailable,
/// [positionsSkewed] is set and nav/completion are disabled.
AnalysisResult analyzeSource({
  required String path,
  required String source,
  bool requireMain = false,
}) {
  late final PreprocessResult pp;
  try {
    pp = preprocessWithMap(source, path: path);
  } on PreprocessError catch (e) {
    return AnalysisResult(
      diagnostics: [
        KlinDiagnostic(
          message: e.message,
          pos: e.pos,
          path: e.path.isNotEmpty ? e.path : path,
        ),
      ],
    );
  }

  final expanded = pp.text;
  final map = pp.map;
  final skewed = expanded != source && map == null;

  try {
    final program = Parser(Lexer(expanded).tokenize()).parse();
    try {
      Checker().check(
        program,
        requireMain: requireMain,
        collectErrors: true,
      );
      return AnalysisResult(
        diagnostics: const [],
        program: program,
        positionsSkewed: skewed,
        sourceMap: map,
      );
    } on CheckErrors catch (e) {
      return AnalysisResult(
        diagnostics: [
          for (final err in e.errors)
            _mappedDiagnostic(path, err.message, err.pos, map, skewed),
        ],
        program: program,
        positionsSkewed: skewed,
        sourceMap: map,
      );
    } on CheckError catch (e) {
      return AnalysisResult(
        diagnostics: [
          _mappedDiagnostic(path, e.message, e.pos, map, skewed),
        ],
        // Registration failures — AST may be only partially typed.
        program: program,
        positionsSkewed: skewed,
        sourceMap: map,
      );
    }
  } on LexError catch (e) {
    return AnalysisResult(
      diagnostics: [
        _mappedDiagnostic(path, e.message, e.pos, map, skewed),
      ],
      positionsSkewed: skewed,
      sourceMap: map,
    );
  } on ParseError catch (e) {
    return AnalysisResult(
      diagnostics: [
        _mappedDiagnostic(path, e.message, e.pos, map, skewed),
      ],
      positionsSkewed: skewed,
      sourceMap: map,
    );
  }
}

KlinDiagnostic _mappedDiagnostic(
  String path,
  String message,
  SourcePos pos,
  SourceMap? map,
  bool skewed,
) {
  if (map != null) {
    return KlinDiagnostic(
      message: message,
      pos: map.toOriginal(pos),
      path: path,
    );
  }
  if (!skewed) {
    return KlinDiagnostic(message: message, pos: pos, path: path);
  }
  return KlinDiagnostic(
    message: '$message (after preprocess)',
    pos: const SourcePos(1, 1),
    path: path,
  );
}

/// True when [a] and [b] name the same file (path or basename).
bool sameDiagnosticPath(String a, String b) {
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;
  final na = a.replaceAll('\\', '/');
  final nb = b.replaceAll('\\', '/');
  if (na == nb) return true;
  final ba = na.split('/').last;
  final bb = nb.split('/').last;
  return ba == bb && ba.isNotEmpty;
}

/// Attribute a diagnostic to [openPath] for publishDiagnostics on that URI.
///
/// Errors that originated in another file (e.g. preprocess of an import) keep
/// their message but are pinned to the start of the open buffer so the editor
/// still surfaces them.
KlinDiagnostic diagnosticForOpenDocument(
  KlinDiagnostic d,
  String openPath,
) {
  if (sameDiagnosticPath(d.path, openPath)) {
    return KlinDiagnostic(
      message: d.message,
      pos: d.pos,
      path: openPath,
      severity: d.severity,
    );
  }
  return KlinDiagnostic(
    message: '${d.path}:${d.pos.line}:${d.pos.col}: ${d.message}',
    pos: const SourcePos(1, 1),
    path: openPath,
    severity: d.severity,
  );
}

SourcePos _queryPos(AnalysisResult result, int line, int col) {
  final map = result.sourceMap;
  if (map == null) return SourcePos(line, col);
  return map.toExpanded(SourcePos(line, col));
}

/// Hover text at 1-based editor [line]/[col], or null.
String? hoverAt(AnalysisResult result, int line, int col) {
  if (result.positionsSkewed || result.program == null) return null;
  final q = _queryPos(result, line, col);
  final target = findNavTarget(result.program!, q.line, q.col);
  if (target == null) return null;
  return hoverText(target);
}

/// Go-to-definition at 1-based editor [line]/[col], or null.
///
/// Definition positions are remapped to the editor buffer when a [SourceMap]
/// is present.
ResolvedDef? definitionAt(AnalysisResult result, int line, int col) {
  if (result.positionsSkewed || result.program == null) return null;
  final q = _queryPos(result, line, col);
  final target = findNavTarget(result.program!, q.line, q.col);
  final def = target?.def;
  if (def == null) return null;
  final map = result.sourceMap;
  if (map == null) return def;
  return ResolvedDef(map.toOriginal(def.pos), def.path);
}
