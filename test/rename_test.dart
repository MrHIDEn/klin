import 'package:klin/analyze.dart';
import 'package:klin/rename.dart';
import 'package:test/test.dart';

void main() {
  group('renameAt', () {
    test('renames local variable at declaration and uses', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
    let y: i32 = x
}
''';
      final result = analyzeSource(
        path: 'r.kl',
        source: source,
        requireMain: false,
      );
      expect(result.diagnostics, isEmpty);
      // Cursor on `x` in `let x`
      final xCol = source.split('\n')[1].indexOf('x') + 1;
      final edits = renameAt(
        result,
        2,
        xCol,
        'z',
        openPath: 'r.kl',
      );
      expect(edits, isNotNull);
      final texts = edits!.map((e) => '${e.pos.line}:${e.pos.col}->${e.newText}');
      expect(edits.length, greaterThanOrEqualTo(2));
      expect(edits.every((e) => e.newText == 'z'), isTrue);
      expect(texts, isNotEmpty);
    });

    test('prepareRename returns range for a local', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
}
''';
      final result = analyzeSource(
        path: 'r.kl',
        source: source,
        requireMain: false,
      );
      final xCol = source.split('\n')[1].indexOf('x') + 1;
      final prep = prepareRenameAt(result, 2, xCol, openPath: 'r.kl');
      expect(prep, isNotNull);
      expect(prep!.placeholder, 'x');
      expect(prep.length, 1);
    });

    test('rejects invalid identifier', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
}
''';
      final result = analyzeSource(
        path: 'r.kl',
        source: source,
        requireMain: false,
      );
      final xCol = source.split('\n')[1].indexOf('x') + 1;
      expect(
        renameAt(result, 2, xCol, '1bad', openPath: 'r.kl'),
        isNull,
      );
    });
  });
}
