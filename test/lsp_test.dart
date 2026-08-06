import 'package:klin/lsp/server.dart';
import 'package:klin/token.dart';
import 'package:test/test.dart';

void main() {
  group('LSP helpers', () {
    test('diagnosticRange maps 1-based SourcePos to 0-based LSP', () {
      final range = diagnosticRange(const SourcePos(2, 5));
      expect(range.start.line, 1);
      expect(range.start.character, 4);
      expect(range.end.line, 1);
      expect(range.end.character, 5);
    });

    test('formatDocumentEdits returns a full-document replace', () {
      const ugly = 'fn foo():void{let x:i32=1}';
      final edits = formatDocumentEdits(ugly);
      expect(edits, hasLength(1));
      expect(edits.single.newText, contains('fn foo'));
      expect(edits.single.range.start.line, 0);
      expect(edits.single.range.start.character, 0);
    });

    test('formatDocumentEdits returns empty on parse error', () {
      expect(formatDocumentEdits('fn {'), isEmpty);
    });

    test('uriToPath unwraps file URIs', () {
      final path = uriToPath(Uri.file('/tmp/hello.kl'));
      expect(path, contains('hello.kl'));
    });
  });
}
