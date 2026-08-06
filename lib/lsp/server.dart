import 'dart:async';
import 'dart:io';

import 'package:klin/analyze.dart';
import 'package:klin/fmt.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/token.dart';
import 'package:klin/version.dart';
import 'package:lsp_server/lsp_server.dart';

import 'documents.dart';

/// Maps a Klin [SourcePos] (1-based) to an LSP [Range] (0-based, one column).
Range diagnosticRange(SourcePos pos) {
  final line = (pos.line - 1).clamp(0, 1 << 30);
  final col = (pos.col - 1).clamp(0, 1 << 30);
  return Range(
    start: Position(line: line, character: col),
    end: Position(line: line, character: col + 1),
  );
}

List<Diagnostic> toLspDiagnostics(List<KlinDiagnostic> diags) {
  return [
    for (final d in diags)
      Diagnostic(
        message: d.message,
        range: diagnosticRange(d.pos),
        severity: DiagnosticSeverity.Error,
        source: 'klin',
      ),
  ];
}

/// Full-document format edits via [formatSource]. Empty on lex/parse errors.
List<TextEdit> formatDocumentEdits(String source) {
  try {
    final formatted = formatSource(source);
    if (formatted == source) return const [];
    return [
      TextEdit(
        range: _fullDocumentRange(source),
        newText: formatted,
      ),
    ];
  } on LexError {
    return const [];
  } on ParseError {
    return const [];
  }
}

Range _fullDocumentRange(String source) {
  if (source.isEmpty) {
    return Range(
      start: Position(line: 0, character: 0),
      end: Position(line: 0, character: 0),
    );
  }
  final lines = source.split('\n');
  final lastLine = lines.length - 1;
  final lastCol = lines[lastLine].length;
  return Range(
    start: Position(line: 0, character: 0),
    end: Position(line: lastLine, character: lastCol),
  );
}

String uriToPath(Uri uri) {
  if (uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return uri.path;
}

/// Applies one LSP content change to [current] (full or incremental).
String applyContentChange(
  String current,
  TextDocumentContentChangeEvent change,
) {
  return change.map(
    (incremental) {
      final start = offsetOfPosition(current, incremental.range.start);
      final end = offsetOfPosition(current, incremental.range.end);
      if (start < 0 || end < start || end > current.length) {
        // Corrupt range — fall back to replacement text only if empty doc.
        return incremental.text;
      }
      return current.replaceRange(start, end, incremental.text);
    },
    (full) => full.text,
  );
}

/// UTF-16 code unit offset for an LSP [Position] (0-based line/character).
int offsetOfPosition(String text, Position pos) {
  var offset = 0;
  var line = 0;
  while (line < pos.line && offset < text.length) {
    final next = text.indexOf('\n', offset);
    if (next < 0) {
      return text.length;
    }
    offset = next + 1;
    line++;
  }
  final lineEnd = text.indexOf('\n', offset);
  final maxCol = lineEnd < 0 ? text.length - offset : lineEnd - offset;
  final col = pos.character.clamp(0, maxCol);
  return offset + col;
}

/// Starts the Klin Language Server on stdio (issue 086).
Future<void> runKlinLsp({
  Stream<List<int>>? input,
  StreamSink<List<int>>? output,
}) async {
  final connection = Connection(input ?? stdin, output ?? stdout);
  final docs = DocumentStore();
  var exitAfterShutdown = false;

  void publishFor(Uri uri, String text) {
    final path = uriToPath(uri);
    final result = analyzeSource(path: path, source: text);
    final attributed = [
      for (final d in result.diagnostics)
        diagnosticForOpenDocument(d, path),
    ];
    connection.sendDiagnostics(
      PublishDiagnosticsParams(
        uri: uri,
        diagnostics: toLspDiagnostics(attributed),
      ),
    );
  }

  connection.onInitialize((params) async {
    return InitializeResult(
      capabilities: ServerCapabilities(
        textDocumentSync: const Either2.t1(TextDocumentSyncKind.Full),
        documentFormattingProvider: const Either2.t1(true),
      ),
      serverInfo: InitializeResultServerInfo(
        name: 'klin',
        version: klinVersion,
      ),
    );
  });

  connection.onInitialized((_) async {});

  connection.onShutdown(() async {
    exitAfterShutdown = true;
  });

  connection.onExit(() async {
    exit(exitAfterShutdown ? 0 : 1);
  });

  connection.onDidOpenTextDocument((params) async {
    final uriKey = params.textDocument.uri.toString();
    final text = params.textDocument.text;
    docs.open(uriKey, text);
    publishFor(params.textDocument.uri, text);
  });

  connection.onDidChangeTextDocument((params) async {
    final uriKey = params.textDocument.uri.toString();
    if (params.contentChanges.isEmpty) return;
    var text = docs.get(uriKey) ?? '';
    for (final change in params.contentChanges) {
      text = applyContentChange(text, change);
    }
    docs.change(uriKey, text);
    publishFor(params.textDocument.uri, text);
  });

  connection.onDidCloseTextDocument((params) async {
    final uriKey = params.textDocument.uri.toString();
    docs.close(uriKey);
    connection.sendDiagnostics(
      PublishDiagnosticsParams(
        uri: params.textDocument.uri,
        diagnostics: const [],
      ),
    );
  });

  connection.onDocumentFormatting((params) async {
    final uriKey = params.textDocument.uri.toString();
    final text = docs.get(uriKey);
    if (text == null) return const <TextEdit>[];
    return formatDocumentEdits(text);
  });

  await connection.listen();
}
