import 'ast.dart';
import 'checker.dart';
import 'lexer.dart';
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

  const AnalysisResult({
    required this.diagnostics,
    this.program,
  });
}

/// Preprocess → lex → parse → check for a single buffer.
///
/// Catches the first frontend error (fail-fast pipeline). Does not exit the
/// process — suitable for Language Server and unit tests.
///
/// [requireMain] defaults to `false` (library-friendly). CLI compile paths keep
/// calling [Checker.check] with the default `true`.
AnalysisResult analyzeSource({
  required String path,
  required String source,
  bool requireMain = false,
}) {
  try {
    final expanded = preprocess(source, path: path);
    final program = Parser(Lexer(expanded).tokenize()).parse();
    Checker().check(program, requireMain: requireMain);
    return AnalysisResult(diagnostics: const [], program: program);
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
  } on LexError catch (e) {
    return AnalysisResult(
      diagnostics: [
        KlinDiagnostic(message: e.message, pos: e.pos, path: path),
      ],
    );
  } on ParseError catch (e) {
    return AnalysisResult(
      diagnostics: [
        KlinDiagnostic(message: e.message, pos: e.pos, path: path),
      ],
    );
  } on CheckError catch (e) {
    return AnalysisResult(
      diagnostics: [
        KlinDiagnostic(message: e.message, pos: e.pos, path: path),
      ],
    );
  }
}
