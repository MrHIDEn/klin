import 'ast.dart';
import 'checker.dart';
import 'lexer.dart';
import 'navigate.dart';
import 'parser.dart';
import 'preprocess.dart';
import 'token.dart';

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

  /// True when preprocess rewrote the buffer; post-expand positions then refer
  /// to expanded text, not the editor buffer (see [analyzeSource]).
  final bool positionsSkewed;

  const AnalysisResult({
    required this.diagnostics,
    this.program,
    this.positionsSkewed = false,
  });
}

/// Preprocess → lex → parse → check for a single buffer.
///
/// Catches the first frontend error (fail-fast pipeline). Does not exit the
/// process — suitable for Language Server and unit tests.
///
/// [requireMain] defaults to `false` (library-friendly). CLI compile paths keep
/// calling [Checker.check] with the default `true`.
///
/// When preprocess changes the source, lex/parse/check positions are relative
/// to the **expanded** text. Those diagnostics are remapped to line 1 / col 1
/// with an `(after preprocess)` note so the editor does not paint a squiggle on
/// the wrong line of the buffer. [PreprocessError] keeps its original position
/// (still on the pre-expand source, or on an imported path).
AnalysisResult analyzeSource({
  required String path,
  required String source,
  bool requireMain = false,
}) {
  late final String expanded;
  try {
    expanded = preprocess(source, path: path);
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

  final skewed = expanded != source;
  try {
    final program = Parser(Lexer(expanded).tokenize()).parse();
    Checker().check(program, requireMain: requireMain);
    return AnalysisResult(
      diagnostics: const [],
      program: program,
      positionsSkewed: skewed,
    );
  } on LexError catch (e) {
    return _postExpandDiagnostic(path, e.message, e.pos, skewed);
  } on ParseError catch (e) {
    return _postExpandDiagnostic(path, e.message, e.pos, skewed);
  } on CheckError catch (e) {
    return _postExpandDiagnostic(path, e.message, e.pos, skewed);
  }
}

AnalysisResult _postExpandDiagnostic(
  String path,
  String message,
  SourcePos pos,
  bool skewed,
) {
  if (!skewed) {
    return AnalysisResult(
      diagnostics: [
        KlinDiagnostic(message: message, pos: pos, path: path),
      ],
    );
  }
  return AnalysisResult(
    diagnostics: [
      KlinDiagnostic(
        message: '$message (after preprocess)',
        pos: const SourcePos(1, 1),
        path: path,
      ),
    ],
    positionsSkewed: true,
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

/// Hover text at 1-based [line]/[col], or null.
///
/// Disabled when [AnalysisResult.positionsSkewed] (macro expand without source
/// maps) or when analysis failed (`program == null`).
String? hoverAt(AnalysisResult result, int line, int col) {
  if (result.positionsSkewed || result.program == null) return null;
  final target = findNavTarget(result.program!, line, col);
  if (target == null) return null;
  return hoverText(target);
}

/// Go-to-definition at 1-based [line]/[col], or null.
ResolvedDef? definitionAt(AnalysisResult result, int line, int col) {
  if (result.positionsSkewed || result.program == null) return null;
  final target = findNavTarget(result.program!, line, col);
  return target?.def;
}
