import 'package:klin/analyze.dart';
import 'package:test/test.dart';

void main() {
  group('hover + definition', () {
    test('hover and goto local variable', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
    let y: i32 = x
}
''';
      final result = analyzeSource(
        path: 'nav.kl',
        source: source,
        requireMain: true,
      );
      expect(result.diagnostics, isEmpty);
      expect(result.program, isNotNull);

      // `x` on the `let y` line — use site.
      final useLine = 3;
      final useCol = source.split('\n')[useLine - 1].indexOf('x') + 1;
      final hover = hoverAt(result, useLine, useCol);
      expect(hover, contains('x:'));
      expect(hover, contains('i32'));

      final def = definitionAt(result, useLine, useCol);
      expect(def, isNotNull);
      expect(def!.pos.line, 2); // `let x`
    });

    test('hover and goto function call', () {
      const source = '''
fn add(a: i32, b: i32): i32 {
    return a + b
}
fn main(): void {
    let z: i32 = add(1, 2)
}
''';
      final result = analyzeSource(
        path: 'nav_fn.kl',
        source: source,
        requireMain: true,
      );
      expect(result.diagnostics, isEmpty);

      final callLine = 5;
      final callCol = source.split('\n')[callLine - 1].indexOf('add') + 1;
      final hover = hoverAt(result, callLine, callCol);
      expect(hover, contains('add'));
      expect(hover, contains('i32'));

      final def = definitionAt(result, callLine, callCol);
      expect(def, isNotNull);
      expect(def!.pos.line, 1);
    });

    test('hover field access', () {
      const source = '''
struct Point {
    x: i32
    y: i32
}
fn main(): void {
    let p: Point = Point { x: 1, y: 2 }
    let a: i32 = p.x
}
''';
      final result = analyzeSource(
        path: 'nav_field.kl',
        source: source,
        requireMain: true,
      );
      expect(result.diagnostics, isEmpty);

      final line = 7;
      final col = source.split('\n')[line - 1].indexOf('.x') + 2; // on `x`
      final hover = hoverAt(result, line, col);
      expect(hover, contains('x:'));
      expect(hover, contains('i32'));

      final def = definitionAt(result, line, col);
      expect(def, isNotNull);
      expect(def!.pos.line, 2);
    });

    test('nav disabled when positions skewed by macros', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let v: Vec2i = Vec2i { x: 1, y: 2 }
  let a: i32 = v.x
}
''';
      final result = analyzeSource(path: 'skew_nav.kl', source: source);
      expect(result.positionsSkewed, isTrue);
      // Even if analysis succeeded, hover/def stay off when skewed.
      if (result.program != null) {
        expect(hoverAt(result, 7, 3), isNull);
        expect(definitionAt(result, 7, 3), isNull);
      }
    });
  });
}
