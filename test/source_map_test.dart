import 'package:klin/analyze.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/source_map.dart';
import 'package:test/test.dart';

void main() {
  group('SourceMap', () {
    test(r'toExpanded maps inside $name(…) call into the expansion', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let a: i32 = 1
}
''';
      final pp = preprocessWithMap(source, path: 't.kl');
      expect(pp.map, isNotNull);
      final map = pp.map!;
      final call = source.indexOf(r'$point');
      final v = source.indexOf('Vec2i', call);
      final exp = map.toExpanded(positionOf(source, v));
      final expOff = offsetOf(pp.text, exp);
      final mainOff = pp.text.indexOf('fn main');
      expect(mainOff, greaterThan(0));
      // Must land in the expansion (`struct Vec2i`), not on `fn main`.
      expect(expOff, lessThan(mainOff));
      expect(pp.text.substring(expOff, mainOff), contains('struct Vec2i'));
    });

    test('toOriginal remaps expanded identity text', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let a: i32 = 1
}
''';
      final pp = preprocessWithMap(source, path: 't.kl');
      final map = pp.map!;
      final aInExp = pp.text.indexOf('let a');
      final orig = map.toOriginal(positionOf(pp.text, aInExp));
      expect(source.substring(offsetOf(source, orig)), startsWith('let a'));
    });

    test(r'analyze remaps diagnostic after $fn via source map', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let bad: NoSuch = 1
}
''';
      final result = analyzeSource(path: 't.kl', source: source);
      expect(result.sourceMap, isNotNull);
      expect(result.positionsSkewed, isFalse);
      expect(result.diagnostics.single.pos.line, 6);
    });
  });
}
