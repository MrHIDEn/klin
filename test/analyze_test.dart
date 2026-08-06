import 'package:klin/analyze.dart';
import 'package:klin/fmt.dart';
import 'package:klin/token.dart';
import 'package:test/test.dart';

void main() {
  group('analyzeSource', () {
    test('clean library file has no diagnostics when requireMain is false', () {
      const source = '''
fn foo(): void {
}
''';
      final result = analyzeSource(
        path: 'lib_foo.kl',
        source: source,
        requireMain: false,
      );
      expect(result.diagnostics, isEmpty);
      expect(result.program, isNotNull);
    });

    test('parse error yields one diagnostic with line/col', () {
      const source = '''
fn foo(): void {
''';
      final result = analyzeSource(path: 'bad.kl', source: source);
      expect(result.diagnostics, hasLength(1));
      final d = result.diagnostics.single;
      expect(d.path, 'bad.kl');
      expect(d.message, isNotEmpty);
      expect(d.pos.line, greaterThanOrEqualTo(1));
      expect(d.pos.col, greaterThanOrEqualTo(1));
      expect(result.program, isNull);
    });

    test('check error yields one diagnostic', () {
      const source = '''
fn main(): void {
    let x: NoSuchType = 1
}
''';
      final result = analyzeSource(
        path: 'check.kl',
        source: source,
        requireMain: true,
      );
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.message, contains('NoSuchType'));
      expect(result.program, isNull);
    });

    test('requireMain true reports missing main', () {
      const source = '''
fn foo(): void {
}
''';
      final withMain = analyzeSource(
        path: 'lib.kl',
        source: source,
        requireMain: true,
      );
      expect(withMain.diagnostics, hasLength(1));
      expect(withMain.diagnostics.single.message, contains('main'));

      final without = analyzeSource(
        path: 'lib.kl',
        source: source,
        requireMain: false,
      );
      expect(without.diagnostics, isEmpty);
    });

    test('check error after macro expand remaps pos (no wrong squiggle)', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let bad: NoSuch = 1
}
''';
      final result = analyzeSource(path: 'skew.kl', source: source);
      expect(result.diagnostics, hasLength(1));
      expect(result.positionsSkewed, isTrue);
      final d = result.diagnostics.single;
      expect(d.pos.line, 1);
      expect(d.pos.col, 1);
      expect(d.message, contains('after preprocess'));
      expect(d.message, contains('NoSuch'));
    });

    test('diagnosticForOpenDocument rewrites foreign paths', () {
      const foreign = KlinDiagnostic(
        message: 'boom',
        pos: SourcePos(3, 4),
        path: '/other/macros.kl',
      );
      final attributed = diagnosticForOpenDocument(foreign, '/app/main.kl');
      expect(attributed.path, '/app/main.kl');
      expect(attributed.pos.line, 1);
      expect(attributed.pos.col, 1);
      expect(attributed.message, contains('/other/macros.kl'));
      expect(attributed.message, contains('boom'));
    });
  });

  group('formatDocument helper', () {
    test('formatSource is idempotent on a small snippet', () {
      const ugly = 'fn foo():void{let x:i32=1}';
      final once = formatSource(ugly);
      final twice = formatSource(once);
      expect(twice, once);
      expect(once, contains('fn foo'));
    });

    test('formatSource throws on invalid input (LSP returns empty edits)', () {
      expect(() => formatSource('fn {'), throwsA(anything));
    });
  });
}
