import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/fmt.dart';
import 'package:klin/lexer.dart';
import 'package:klin/link_args.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/project.dart';
import 'package:klin/token.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('golden: hello.kl prints expected output', () async {
    final result = await _compileAndRun('test/hello.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/hello.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: !T propagates errors and or handles them', () async {
    final result = await _compileAndRun('test/result_chain.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/result_chain.out').readAsString());

    final source = File('test/result_chain.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/result_chain.kl');
    expect(c, contains('} klin_res_i32;'));
    expect(c, contains('.is_err = true'));
    expect(c, contains('.u.ok ='));
  });

  test('golden: struct destructuring `let { }` (issue 056)', () async {
    final result = await _compileAndRun('test/destruct_struct.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/destruct_struct.out').readAsString());

    final source = File('test/destruct_struct.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/destruct_struct.kl');
    // A plain-name source lowers to direct field reads, no temp copy.
    expect(c, contains('int32_t x = p.x;'));
    expect(c, contains('int32_t y = p.y;'));
    // A call source is evaluated once into a temp, then read per field.
    expect(c, contains('klin_val_0 = make();'));
    expect(c, contains('int32_t x = klin_val_0.x;'));
  });

  test('error: destructuring a non-struct value (issue 056)', () {
    const source = '''
fn main() {
  let n = 5
  let { x } = n
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('requires a struct')),
      ),
    );
  });

  test('error: destructuring an unknown field (issue 056)', () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  let { z } = p
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
            (e) => e is CheckError && e.toString().contains('has no field `z`')),
      ),
    );
  });

  test('error: destructuring a fixed-array field is rejected (issue 056)', () {
    const source = '''
struct Box { data: [3]i32
 n: i32 }
fn main() {
  let b = Box{ data: [1, 2, 3], n: 3 }
  let { data, n } = b
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('cannot destructure array field')),
      ),
    );
  });

  test('error: duplicate name in destructuring pattern (issue 056)', () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  let { x, x } = p
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) => e is ParseError && e.toString().contains('duplicate')),
      ),
    );
  });

  test('error: destructuring `let` requires `=` (issue 056)', () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  let { x } p
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(isA<ParseError>()),
    );
  });

  test('golden: fixed-array destructuring `let [ ]` (issue 056)', () async {
    final result = await _compileAndRun('test/destruct_array.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/destruct_array.out').readAsString());

    final source = File('test/destruct_array.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/destruct_array.kl');
    // A named array source (no shadow) is indexed in place.
    expect(c, contains('int32_t a = xs[0];'));
    expect(c, contains('int32_t c = xs[2];'));
    // A binding that shadows the source name captures it via a pointer first.
    expect(c, contains('int32_t *'));
    expect(c, contains('int32_t xs = '));
  });

  test('error: array destructuring length mismatch (issue 056)', () {
    const source = '''
fn main() {
  let xs: [3]i32 = [1, 2, 3]
  let [a, b] = xs
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('but the pattern binds')),
      ),
    );
  });

  test('error: array destructuring rejects a slice (issue 056)', () {
    const source = '''
fn main() {
  let buf: [3]i32 = [1, 2, 3]
  let s = buf[:]
  let [a, b, c] = s
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('requires a fixed-length array')),
      ),
    );
  });

  test('error: array destructuring rejects a non-array source (issue 056)', () {
    const source = '''
fn make(): i32 { return 1 }
fn main() {
  let [a, b] = make()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('array variable or literal')),
      ),
    );
  });

  test('golden: destructuring rename and `_` skip (issue 056 phase D)',
      () async {
    final result = await _compileAndRun('test/destruct_phase_d.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/destruct_phase_d.out').readAsString());

    final source = File('test/destruct_phase_d.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/destruct_phase_d.kl');
    // Rename binds the local name from the named field.
    expect(c, contains('int32_t px = p.x;'));
    expect(c, contains('int32_t py = p.y;'));
    // `_` skips positions but keeps the original indices.
    expect(c, contains('int32_t b = xs[1];'));
    expect(c, contains('int32_t d = xs[3];'));
    expect(c, contains('int32_t last = xs[3];'));
  });

  test('error: duplicate renamed binding in struct pattern (issue 056)', () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  let { x: a, y: a } = p
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) =>
            e is ParseError && e.toString().contains('duplicate name `a`')),
      ),
    );
  });

  test('error: array pattern that binds nothing (all `_`) (issue 056)', () {
    const source = '''
fn main() {
  let xs: [2]i32 = [1, 2]
  let [_, _] = xs
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) => e is ParseError && e.toString().contains('binds nothing')),
      ),
    );
  });

  test('error: unhandled !T result', () {
    const source = '''
fn fallible(): !i32 { return error(1) }
fn main() {
  fallible()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('must be handled'),
        ),
      ),
    );
  });

  test('propagation runs defer before returning an error', () async {
    const source = '''
fn fail(): !i32 { return error(7) }
fn wrap(): !i32 {
  defer puts("cleanup")
  return fail()!
}
fn main() {
  let value = wrap() or { err }
  printf("%d\\n", value)
}
''';
    final file = File('${tmp.path}/defer_propagate.kl');
    await file.writeAsString(source);
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'cleanup\n7\n');
  });

  test('or and propagate work as call arguments', () async {
    const source = '''
fn fail(): !i32 { return error(3) }
fn ok(): !i32 { return 8 }
fn main() {
  printf("%d\\n", ok() or { 0 })
  printf("%d\\n", fail() or { err })
}
''';
    final file = File('${tmp.path}/result_nested.kl');
    await file.writeAsString(source);
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '8\n3\n');
  });

  test('different !*T types emit separate result typedefs', () {
    const source = '''
fn a(): !*i32 { return error(1) }
fn b(): !*f64 { return error(2) }
fn main() {
  let x = a() or { cast(*i32, 0) }
  let y = b() or { cast(*f64, 0) }
  printf("%p %p\\n", x, y)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'ptr_results.kl');
    expect(c, contains('} klin_res_ptr_i32;'));
    expect(c, contains('} klin_res_ptr_f64;'));
    expect(c, isNot(contains('} klin_res_ptr;')));
  });

  test('golden: emitted C is readable and contains #line', () {
    final source = File('test/hello.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/hello.kl');

    expect(c, contains('#include <stdio.h>'));
    expect(c, contains('int main(void) {'));
    expect(c, contains('puts("hello");'));
    expect(c, contains('puts("z Klina");'));
    expect(c, contains('return 0;'));
    expect(c, contains('#line '));
    expect(c, contains('test/hello.kl'));
  });

  test('golden: vars.kl — arithmetic, mut, range', () async {
    final result = await _compileAndRun('test/vars.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/vars.out').readAsString();
    expect(result.stdout, expected);

    final source = File('test/vars.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/vars.kl');
    expect(c, contains('int32_t x = (2 + 3);'));
    expect(c, contains('int32_t y = (x * 2);'));
    expect(c, contains('y = (y + 1);'));
  });

  test('golden: short_decl.kl — := sugar for let mut (issue 055)', () async {
    final result = await _compileAndRun('test/short_decl.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/short_decl.out').readAsString());

    final source = File('test/short_decl.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/short_decl.kl');
    expect(c, contains('int32_t x = (2 + 3);'));
    expect(c, contains('int32_t i = 0;'));
    expect(c, isNot(contains('mut')));

    final tokens = Lexer('x := 1').tokenize();
    expect(tokens[1].kind, TokenKind.colonEqual);
    expect(tokens[1].lexeme, ':=');
  });

  test('klin fmt: preserves := short decl (issue 055)', () {
    final ugly = File('test/fmt_short_decl.kl').readAsStringSync();
    final expected = File('test/fmt_short_decl.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('error: := without initializer', () {
    expect(
      () => Parser(Lexer('fn main() { x := }').tokenize()).parse(),
      throwsA(isA<ParseError>()),
    );
  });

  test('golden: match statement lowers to if/else chains (issue 014)',
      () async {
    final result = await _compileAndRun('test/match_stmt.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/match_stmt.out').readAsString());

    final source = File('test/match_stmt.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/match_stmt.kl');
    // No switch/case/break: `match` is an if/else chain, so arms never fall
    // through and `break` inside an arm still belongs to the enclosing loop.
    expect(c, isNot(contains('switch (')));
    expect(c, isNot(contains('case ')));
    // The subject is evaluated once into a temp, then compared.
    expect(c, matches(RegExp(r'if \(\w+ == 1 \|\| \w+ == 2 \|\| \w+ == 3\)')));
    expect(c, matches(RegExp(r'else if \(\(\w+ >= 4 && \w+ <= 10\)\)')));

    final tokens = Lexer('match x { 1..=2 { } }').tokenize();
    expect(tokens[0].kind, TokenKind.match_);
    expect(tokens[4].kind, TokenKind.dotDotEqual);
    expect(tokens[4].lexeme, '..=');
  });

  test('golden: match expression assigns from each arm (issue 014)', () async {
    final result = await _compileAndRun('test/match_expr.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/match_expr.out').readAsString());

    final source = File('test/match_expr.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/match_expr.kl');
    expect(c, isNot(contains('switch (')));
    // The result is a plain declaration assigned inside the branches.
    expect(c, contains('int32_t a;'));
    expect(c, contains('double c;'));
  });

  test('match statement calling only puts still includes <stdio.h>', () {
    const source = '''
fn main() {
  match 1 {
    1 { puts("one") }
    else { puts("other") }
  }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'match_stdio.kl');
    expect(c, contains('#include <stdio.h>'));
  });

  test('klin fmt: formats match arms (issue 014)', () {
    final ugly = File('test/fmt_match.kl').readAsStringSync();
    final expected = File('test/fmt_match.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('error: match else arm must come last', () {
    final source = File('test/match_else_order.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('3:') &&
              msg.contains('else') &&
              msg.contains('last arm');
        }),
      ),
    );
  });

  test('error: match requires an integer subject', () {
    const source = 'fn main() { match 1.5 { 1 { puts("a") } } }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError && e.toString().contains('integer subject'),
        ),
      ),
    );
  });

  test('error: match expression requires an else arm', () {
    const source = 'fn main() { let a = match 1 { 1 { 2 } } }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('requires an `else`'),
        ),
      ),
    );
  });

  test('error: match expression only in let/assign position', () {
    const source =
        'fn main() { printf("%d\\n", match 1 { 1 { 2 } else { 3 } }) }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('only allowed as a `let` initializer'),
        ),
      ),
    );
  });

  test('error: match expression cannot nest under let arithmetic', () {
    const source = 'fn main() { let a = 1 + match 1 { else { 2 } } }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('only allowed as a `let` initializer'),
        ),
      ),
    );
  });

  test('error: match expression cannot nest in let call argument', () {
    const source =
        'fn main() { let a = printf("%d\\n", match 1 { 1 { 2 } else { 3 } }) }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('only allowed as a `let` initializer'),
        ),
      ),
    );
  });

  test('grouped match expression is allowed as a let initializer', () async {
    const source = '''
fn main() {
  let a = (match 1 { 1 { 2 } else { 3 } })
  printf("%d\\n", a)
}
''';
    final file = File('${tmp.path}/grouped_match.kl');
    await file.writeAsString(source);
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '2\n');
  });

  test('error: match requires at least one arm', () {
    expect(
      () => Parser(Lexer('fn main() { match 1 { } }').tokenize()).parse(),
      throwsA(isA<ParseError>()),
    );
  });

  test('assignment from or-block resolves the target type', () async {
    const source = '''
fn fallible(): !i32 { return error(1) }
fn main() {
  let mut b = 0
  b = fallible() or { 42 }
  printf("%d\\n", b)
}
''';
    final file = File('${tmp.path}/assign_or.kl');
    await file.writeAsString(source);
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '42\n');
  });

  test('golden: int/float aliases emit fixed-width C types', () async {
    final result = await _compileAndRun('test/int_float_aliases.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/int_float_aliases.out').readAsString(),
    );

    final source = File('test/int_float_aliases.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/int_float_aliases.kl');
    expect(c, contains('int32_t add(int32_t a, int32_t b)'));
    expect(c, contains('int32_t x = 40;'));
    expect(c, contains('double y = 1.5;'));
    expect(c, isNot(contains(' int ')));
    expect(c, isNot(contains(' float ')));
  });

  test('error: C keyword cannot be a variable name', () {
    const source = '''
fn main() {
  let int = 1
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate(
          (e) =>
              e is ParseError &&
              e.toString().contains('a C keyword') &&
              e.toString().contains('variable name'),
        ),
      ),
    );
  });

  test('golden: stdlib io.print / io.println', () async {
    final result = await _compileAndRun('test/io_println.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/io_println.out').readAsString());

    final program = loadProject('test/io_println.kl');
    Checker().check(program);
    final c = emitC(program, 'test/io_println.kl');
    expect(c, contains('#include <stdio.h>'));
    expect(c, contains('int32_t puts(const char* msg);'));
    expect(c, contains('puts(" from io");'));
    expect(c, contains('io_print("hello");'));
    expect(c, contains('printf("%s", msg);'));
    expect(c, isNot(contains('io_println(')));
  });

  test('golden: string interpolation → printf (issue 016)', () async {
    final result = await _compileAndRun('test/interp.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/interp.out').readAsString());

    final program = loadProject('test/interp.kl');
    Checker().check(program);
    final c = emitC(program, 'test/interp.kl');
    expect(c, contains('printf('));
    expect(c, contains('klin_fmt_trim_frac'));
    expect(c, isNot(contains('malloc')));
    expect(c, contains('%.8s'));
  });

  test('golden: stdlib time Instant/Duration/format (issue 037)', () async {
    final result = await _compileAndRun('test/time_basic.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/time_basic.out').readAsString());

    final program = loadProject('test/time_basic.kl');
    Checker().check(program);
    final c = emitC(program, 'test/time_basic.kl');
    expect(c, contains('klin_time_format'));
    expect(c, contains('klin_time_wall_ns'));
    expect(c, contains('klin_time_mono_ns'));
    expect(c, contains('clock_gettime'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: time calendar add_days/months/years (issue 039)', () async {
    final result = await _compileAndRun('test/time_calendar.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/time_calendar.out').readAsString());

    final program = loadProject('test/time_calendar.kl');
    Checker().check(program);
    final c = emitC(program, 'test/time_calendar.kl');
    expect(c, contains('klin_time_add_date'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: function pointers without capture (issue 017 phase 2)', () async {
    final result = await _compileAndRun('test/fn_ptr.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/fn_ptr.out').readAsString());

    final program = loadProject('test/fn_ptr.kl');
    Checker().check(program);
    final c = emitC(program, 'test/fn_ptr.kl');
    expect(c, contains('(*'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: stdlib mem Allocator heap alloc/free (issue 057)', () async {
    final result = await _compileAndRun('test/mem_alloc.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/mem_alloc.out').readAsString());

    final program = loadProject('test/mem_alloc.kl');
    Checker().check(program);
    final c = emitC(program, 'test/mem_alloc.kl');
    expect(c, contains('klin_mem_alloc_u8'));
    expect(c, contains('klin_mem_free_u8'));
    expect(c, contains('klin_mem_alloc_i32'));
    expect(c, contains('malloc'));
    expect(c, contains('free('));
    expect(c, contains('#include <stdlib.h>'));

    final hello = loadProject('test/hello.kl');
    Checker().check(hello);
    final helloC = emitC(hello, 'test/hello.kl');
    expect(helloC, isNot(contains('malloc')));
    expect(helloC, isNot(contains('klin_mem_')));
    expect(helloC, isNot(contains('#include <stdlib.h>')));
  });

  test('golden: stdlib slice ops layer 0+1 (issue 017 phase 3)', () async {
    final result = await _compileAndRun('test/slice_ops.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/slice_ops.out').readAsString());

    final program = loadProject('test/slice_ops.kl');
    Checker().check(program);
    final c = emitC(program, 'test/slice_ops.kl');
    expect(c, contains('slice_map_into_i32'));
    expect(c, isNot(contains('malloc')));
    expect(c, isNot(contains('klin_mem_')));
  });

  test('golden: stdlib slice_alloc map/filter (issue 017 phase 4)', () async {
    final result = await _compileAndRun('test/slice_alloc_ops.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/slice_alloc_ops.out').readAsString(),
    );

    final program = loadProject('test/slice_alloc_ops.kl');
    Checker().check(program);
    final c = emitC(program, 'test/slice_alloc_ops.kl');
    expect(c, contains('slice_alloc_map_alloc_i32'));
    expect(c, contains('slice_alloc_filter_alloc_i32'));
    expect(c, contains('klin_mem_alloc_i32'));
    expect(c, contains('malloc'));
    expect(c, contains('#include <stdlib.h>'));
  });

  test('nested fn types emit typedefs leaves-first', () {
    final file = File('${Directory.systemTemp.path}/klin_nested_fn.kl');
    file.writeAsStringSync(r'''
fn id(x: i32): i32 {
    return x
}

fn pick(): fn(i32): i32 {
    return id
}

fn main() {
    let f = pick()
    printf("%d\n", f(7))
}
''');
    final program = loadProject(file.path);
    Checker().check(program);
    final c = emitC(program, file.path);
    final outer = c.indexOf('typedef');
    // Inner fn(i32):i32 typedef must appear before any that mention it as return.
    final innerName = 'klin_fn_i32__i32';
    final outerRet = c.indexOf('(*klin_fn_void_');
    expect(c.indexOf(innerName), lessThan(outerRet == -1 ? c.length : outerRet));
    expect(c, contains(innerName));
  });

  test('time.parse_iso failure uses or branch', () async {
    final file = File('${tmp.path}/time_bad_parse.kl');
    await file.writeAsString(r'''
import time

fn main() {
    let t = time.parse_iso("not-a-date") or {
        printf("bad=%d\n", err)
        time.unix(0)
    }
    printf("ok=%lld\n", t.unix_ns)
}
''');
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, contains('bad='));
    expect(result.stdout, contains('ok=0'));
  });

  test('time.parse_iso rejects truncated datetime and trailing junk', () async {
    final file = File('${tmp.path}/time_trunc_iso.kl');
    await file.writeAsString(r'''
import time

fn main() {
    let a = time.parse_iso("2024-01-01T12:00:00") or {
        printf("trunc=1\n")
        time.unix(0)
    }
    let b = time.parse_iso("2024-01-01junk") or {
        printf("junk=1\n")
        time.unix(0)
    }
    let c = time.parse_iso("1969-12-31T23:59:59Z") or {
        printf("epoch_m1_fail=1\n")
        time.unix(0)
    }
    printf("a=%lld b=%lld c=%lld\n", a.unix_ns, b.unix_ns, c.unix_ns)
}
''');
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, contains('trunc=1'));
    expect(result.stdout, contains('junk=1'));
    expect(result.stdout, isNot(contains('epoch_m1_fail=1')));
    expect(result.stdout, contains('c=-1000000000'));
  });

  test('time.format returns -1 for too-small buffer', () async {
    final file = File('${tmp.path}/time_tiny_buf.kl');
    await file.writeAsString(r'''
import time

fn main() {
    let t = time.unix(1704067200)
    let mut buf: [1]u8
    let n = time.format(buf[:], "%Y-%m-%d", t)
    printf("n=%d\n", n)
}
''');
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, contains('n=-1'));
  });

  test('error: interpolated string in let is print-only', () {
    final source = r'''
fn main() {
    let b: str = "x"
    let s = "a $b"
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError && e.toString().contains('print-only'),
        ),
      ),
    );
  });

  test('error: interpolated printf rejects extra args', () {
    final source = r'''
fn main() {
    let n = 1
    printf("${n:%d}", n)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError && e.toString().contains('sole argument'),
        ),
      ),
    );
  });

  test('error: unknown interpolation mask n3', () {
    final source = r'''
fn main() {
    let n = 1
    puts("${n:n3}")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError && e.toString().contains('unknown format'),
        ),
      ),
    );
  });

  test('error: sN format requires str', () {
    final source = r'''
fn main() {
    let n = 1
    puts("${n:s8}")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('requires `str`'),
        ),
      ),
    );
  });

  test('error: fraction mask requires numeric type', () {
    final source = r'''
fn main() {
    let s: str = "x"
    puts("${s:0.00}")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('requires a numeric type'),
        ),
      ),
    );
  });

  test('fmt preserves interpolation syntax', () {
    final source = r'''
fn main() {
puts("hi $name ${n:%d} ${x:0.00} ${t:s8}")
}
''';
    final formatted = formatSource(source);
    expect(formatted, contains(r'$name'));
    expect(formatted, contains(r'${n:%d}'));
    expect(formatted, contains(r'${x:0.00}'));
    expect(formatted, contains(r'${t:s8}'));
  });

  test(r'golden: $fn macro expands to a specialized struct (issue 026)',
      () async {
    final result = await _compileAndRun('test/point_macro.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/point_macro.out').readAsString());

    final raw = File('test/point_macro.kl').readAsStringSync();
    final expanded = preprocess(raw, path: 'test/point_macro.kl');
    expect(expanded, contains('struct Vec2i'));
    expect(expanded, contains('fn (p: Vec2i) len_sq(): i32'));
    expect(expanded, isNot(contains(r'$fn')));
    expect(expanded, isNot(contains(r'$point')));

    final program = loadProject('test/point_macro.kl');
    Checker().check(program);
    final c = emitC(program, 'test/point_macro.kl');
    expect(c, contains('typedef struct'));
    expect(c, contains('Vec2i'));
    expect(c, contains('len_sq'));
  });

  test('error: unknown macro reports call site and file path', () {
    expect(
      () => preprocess(r'$missing(i32)', path: 'mod/t.kl'),
      throwsA(
        predicate(
          (e) =>
              e is PreprocessError &&
              e.toString().contains('mod/t.kl:') &&
              e.toString().contains('unknown macro') &&
              e.toString().contains(r'$missing'),
        ),
      ),
    );
  });

  test('klin fmt: ugly source matches golden and is idempotent (issue 033)',
      () async {
    final ugly = await File('test/fmt_ugly.kl').readAsString();
    final expected = await File('test/fmt_ugly.fmt.kl').readAsString();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);

    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'fmt', 'test/fmt_ugly.kl'],
    );
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, expected);

    for (final path in [
      'examples/hello.kl',
      'examples/vec2.kl',
      'examples/point.kl',
      'examples/slice_sum.kl',
      'examples/modules/app.kl',
    ]) {
      final src = File(path).readAsStringSync();
      final formatted = formatSource(src);
      expect(formatSource(formatted), formatted, reason: path);
    }
    expect(
      formatSource(File('examples/slice_sum.kl').readAsStringSync()),
      contains('[10, 20, 30, 40]'),
    );
  });

  test(r'$ in macro strings/comments is not an unsubstituted slot', () {
    final expanded = preprocess(r'''
$fn note(T: type) {
fn f(): $T {
  // keep $hint
  puts("$USD")
  return 0
}
}
$note(i32)
''', path: 't.kl');
    expect(expanded, contains(r'// keep $hint'));
    expect(expanded, contains(r'puts("$USD")'));
    expect(expanded, contains('fn f(): i32'));
  });

  test(r'$peripherals_from_svd rewrites fluent MMIO (issue 027)', () {
    final dir = Directory('${tmp.path}/svd_fluent')..createSync();
    File('${dir.path}/tiny.svd').writeAsStringSync('''
<device><peripherals>
  <peripheral><name>RCC</name><baseAddress>0x40023800</baseAddress><registers>
    <register><name>AHB1ENR</name><addressOffset>0x30</addressOffset><fields>
      <field><name>GPIOAEN</name><bitOffset>0</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
  <peripheral><name>GPIOA</name><baseAddress>0x40020000</baseAddress><registers>
    <register><name>MODER</name><addressOffset>0</addressOffset><fields>
      <field><name>MODER5</name><bitOffset>10</bitOffset><bitWidth>2</bitWidth>
        <enumeratedValues><enumeratedValue><name>Output</name><value>1</value></enumeratedValue></enumeratedValues>
      </field>
    </fields></register>
    <register><name>ODR</name><addressOffset>0x14</addressOffset><fields>
      <field><name>ODR5</name><bitOffset>5</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>
''');
    final klPath = '${dir.path}/blinky.kl';
    File(klPath).writeAsStringSync(r'''
$peripherals_from_svd("tiny.svd", "RCC,GPIOA")
fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
  GPIOA.MODER.MODER5.write(.Output)
  GPIOA.ODR.ODR5.toggle()
}
''');
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
    );
    expect(expanded, contains('@[cinclude("tiny_regs.h")]'));
    expect(
      expanded,
      contains('@[cimport, cheader, codename("GPIOA_ODR_ODR5_toggle")]'),
    );
    expect(expanded, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));
    expect(expanded, contains('GPIOA_MODER_MODER5_write(1)'));
    expect(expanded, contains('GPIOA_ODR_ODR5_toggle()'));
    expect(expanded, isNot(contains('RCC.AHB1ENR')));
    expect(File('${dir.path}/tiny_regs.h').existsSync(), isTrue);

    expect(
      () => preprocess(
        r'''
$peripherals_from_svd("tiny.svd", "RCC,GPIOA")
fn main() { GPIOA.ODR.ODR5.toggle(1) }
''',
        path: klPath,
      ),
      throwsA(
        predicate(
          (e) =>
              e is PreprocessError && e.toString().contains('takes no arguments'),
        ),
      ),
    );
  });

  test('--emit-pp writes expanded Klin source', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-pp', 'test/point_macro.kl'],
    );
    final pp = File('out/point_macro.pp.kl');
    addTearDown(() async {
      if (await pp.exists()) await pp.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await pp.exists(), isTrue);
    final text = await pp.readAsString();
    expect(text, contains('struct Vec2i'));
    expect(text, isNot(contains(r'$point')));
  });

  test('syntax error: message includes line number', () async {
    final source = await File('test/bad_syntax.kl').readAsString();
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) {
          final msg = e.toString();
          // `42` is on line 3, where the lexer reports the position.
          return msg.contains('3:') && (e is LexError || e is ParseError);
        }),
      ),
    );
  });

  test('syntax error through CLI: nonzero exit and line number on stderr',
      () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/bad_syntax.kl'],
    );
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('3:'));
  });

  test('error: frontend catches a C keyword call, not gcc', () {
    final source = File('test/c_keyword_call.kl').readAsStringSync();
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) {
          if (e is! ParseError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('a C keyword') &&
              msg.contains('typedef');
        }),
      ),
    );
  });

  test('type error: mismatch includes position', () {
    final source = File('test/type_mismatch.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('type mismatch') &&
              msg.contains('i32') &&
              msg.contains('bool');
        }),
      ),
    );
  });

  test('type error through CLI: nonzero exit and message', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/type_mismatch.kl'],
    );
    expect(proc.exitCode, isNot(0));
    final err = proc.stderr.toString();
    expect(err, contains('2:'));
    expect(err, contains('type mismatch'));
  });

  test('error: mutating let without mut', () {
    final source = File('test/immutable_assign.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('3:') &&
              msg.contains('immutable variable') &&
              msg.contains('x');
        }),
      ),
    );
  });

  test('mutation error through CLI: nonzero exit and message', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/immutable_assign.kl'],
    );
    expect(proc.exitCode, isNot(0));
    final err = proc.stderr.toString();
    expect(err, contains('3:'));
    expect(err, contains('immutable variable'));
  });

  test('golden: fizzbuzz.kl', () async {
    final result = await _compileAndRun('test/fizzbuzz.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fizzbuzz.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: break_continue.kl — while + C-style for', () async {
    final result = await _compileAndRun('test/break_continue.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/break_continue.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: defer — LIFO order', () async {
    final result = await _compileAndRun('test/defer_order.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_order.out').readAsString());
  });

  test('golden: defer before break is block-scoped', () async {
    final result = await _compileAndRun('test/defer_break.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_break.out').readAsString());
  });

  test('golden: defer before continue is block-scoped', () async {
    final result = await _compileAndRun('test/defer_continue.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_continue.out').readAsString());
  });

  test('golden: defer before return preserves value', () async {
    final result = await _compileAndRun('test/defer_return.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_return.out').readAsString());
  });

  test('error: defer inside defer', () {
    const source = '''
fn main() {
  defer defer puts("nested")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('inside `defer`'),
        ),
      ),
    );
  });

  test('early return does not run a later defer', () async {
    const source = '''
fn main() {
  defer puts("a")
  puts("body")
  return
  defer puts("b")
}
''';
    final dir = await Directory.systemTemp.createTemp('klin_defer_early_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final kl = File('${dir.path}/early.kl');
    await kl.writeAsString(source);
    final result = await _compileAndRun(kl.path, dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'body\na\n');
  });

  test('golden: function called before definition', () async {
    final result = await _compileAndRun('test/call_before_def.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/call_before_def.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: recursive fib', () async {
    final result = await _compileAndRun('test/fib.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fib.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: Vec2 — structs, fields, and methods', () async {
    final result = await _compileAndRun('test/vec2.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/vec2.out').readAsString());

    final program = loadProject('test/vec2.kl');
    Checker().check(program);
    final c = emitC(program, 'test/vec2.kl');
    expect(c, contains('vec2_Vec2_translate(vec2_Vec2 *v'));
    expect(c, isNot(contains('mut')));
  });

  test('golden: project with modules', () async {
    final result = await _compileAndRun('test/modules/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/modules/app.out').readAsString());

    final program = loadProject('test/modules/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/modules/app.kl');
    expect(c, contains('typedef struct {'));
    expect(c, contains('} geom_Vec2;'));
    expect(c, contains('static void geom_helper(void);'));
    expect(c, contains('geom_Vec2_len_sq(geom_Vec2 v)'));
    expect(c, contains('util_add(2, 3)'));
  });

  test('error: private symbol from imported module', () {
    final program = loadProject('test/modules/private_app.kl');
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('is private'),
        ),
      ),
    );
  });

  test('error: unqualified call to another module function is not FFI', () {
    final dir = Directory.systemTemp.createTempSync('klin_mod_bare_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/lib.kl').writeAsStringSync('''
module lib
fn secret(): i32 { return 1 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import lib
fn main() {
  secret()
}
''');
    final program = loadProject('${dir.path}/app.kl');
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('is in module') &&
              e.toString().contains('lib.secret'),
        ),
      ),
    );
  });

  test('import alias maps to the file module declaration', () {
    final dir = Directory.systemTemp.createTempSync('klin_mod_alias_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/file_a.kl').writeAsStringSync('''
module real
pub fn answer(): i32 { return 42 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import file_a
fn main() {
  printf("%d\\n", file_a.answer())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('real_answer'));
    expect(c, isNot(contains('file_a_answer')));
  });

  test('import resolves from lib/ next to the importer (issue 020)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_lib_dir_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/lib').createSync();
    File('${dir.path}/lib/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return a + b }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import mathx
fn main() {
  printf("%d\\n", mathx.add(2, 3))
}
''');
    final result = await _compileAndRun('${dir.path}/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('import -I / KLIN_PATH; sibling wins over lib/ (issue 020)', () async {
    final root = Directory.systemTemp.createTempSync('klin_lib_path_');
    addTearDown(() => root.deleteSync(recursive: true));
    final vendor = Directory('${root.path}/vendor')..createSync();
    File('${vendor.path}/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return a + b }
''');
    final appDir = Directory('${root.path}/app')..createSync();
    Directory('${appDir.path}/lib').createSync();
    File('${appDir.path}/lib/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return 99 }
''');
    File('${appDir.path}/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return 7 }
''');
    File('${appDir.path}/app.kl').writeAsStringSync('''
module app
import mathx
fn main() {
  printf("%d\\n", mathx.add(2, 3))
}
''');

    // Sibling wins over lib/.
    final sibling = await _compileAndRun('${appDir.path}/app.kl', tmp);
    expect(sibling.exitCode, 0, reason: sibling.stderr);
    expect(sibling.stdout, '7\n');

    File('${appDir.path}/mathx.kl').deleteSync();
    Directory('${appDir.path}/lib').deleteSync(recursive: true);

    // -I finds vendor.
    final viaI = await Process.run(
      'dart',
      [
        'run',
        'bin/klin.dart',
        'run',
        '-I',
        vendor.path,
        '${appDir.path}/app.kl',
      ],
    );
    expect(viaI.exitCode, 0, reason: '${viaI.stderr}${viaI.stdout}');
    expect(viaI.stdout, '5\n');

    // $KLIN_PATH finds vendor.
    final viaEnv = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'run', '${appDir.path}/app.kl'],
      environment: {
        ...Platform.environment,
        'KLIN_PATH': vendor.path,
      },
    );
    expect(viaEnv.exitCode, 0, reason: '${viaEnv.stderr}${viaEnv.stdout}');
    expect(viaEnv.stdout, '5\n');
  });

  test('directory package is one module; private shared across files (issue 047)',
      () async {
    final result = await _compileAndRun('examples/pkg_geom/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '25\n');

    final program = loadProject('examples/pkg_geom/app.kl');
    Checker().check(program);
    final c = emitC(program, 'examples/pkg_geom/app.kl');
    expect(c, contains('static int32_t geom_sq('));
    expect(c, contains('geom_Vec2_len_sq('));
  });

  test('entry loads same-module sibling files (issue 047)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_entry_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/helper.kl').writeAsStringSync('''
module app
fn answer(): i32 { return 7 }
''');
    File('${dir.path}/main.kl').writeAsStringSync('''
module app
fn main() {
  printf("%d\\n", answer())
}
''');
    final result = await _compileAndRun('${dir.path}/main.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '7\n');
  });

  test('*_test.kl is skipped when loading a package directory (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_skip_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/vec.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 1 }
''');
    File('${dir.path}/geom/geom_test.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 99 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.n())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    // Duplicate `n` would fail if *_test.kl were loaded.
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('klin_ret_0 = 1'));
    expect(c, isNot(contains('99')));
  });

  test('ambiguous name.kl and name/ directory is an error (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_ambig_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/geom.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 1 }
''');
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 2 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {}
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(
        predicate(
          (e) =>
              e is FileSystemException &&
              e.message.contains('ambiguous import'),
        ),
      ),
    );
  });

  test('package directory rejects mismatched module name (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_mismatch_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module wrong
pub fn n(): i32 { return 1 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.n())
}
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(
        predicate(
          (e) =>
              e is ParseError &&
              e.toString().contains('does not match package'),
        ),
      ),
    );
  });

  test('re-import of a file already in a loaded package is a no-op (issue 047)',
      () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_reimport_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module geom
import b
pub fn one(): i32 { return b.two() }
''');
    File('${dir.path}/geom/b.kl').writeAsStringSync('''
module geom
pub fn two(): i32 { return 2 }
''');
    // Mistaken same-package import by file name would resolve to b.kl;
    // must not duplicate geom_two.
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.one())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program); // would fail on duplicate `two` if re-parsed
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('geom_one'));
    expect(c, contains('geom_two'));
  });

  test('broken same-module sibling fails loudly (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_bad_sib_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
fn main() {}
''');
    File('${dir.path}/other.kl').writeAsStringSync('''
module app
fn broken( {
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(isA<ParseError>()),
    );
  });

  test('error: mutating method on immutable variable', () {
    final source = File('test/bad_mut_method.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('mutating method'),
        ),
      ),
    );
  });

  test('shadowed mut receiver emits `.` rather than `->`', () {
    const source = '''
struct Vec2 {
  x: i32
}
fn (mut v: Vec2) bump() {
  let mut v = Vec2{ 1 }
  v.x = v.x + 1
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'shadow.kl');
    expect(c, contains('v.x = (v.x + 1);'));
    expect(c, isNot(contains('v->x')));
  });

  test('error: assignment to a struct literal field', () {
    const source = '''
struct Vec2 {
  x: i32
}
fn main() {
  Vec2{ 1 }.x = 2
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('field of an immutable expression'),
        ),
      ),
    );
  });

  test('error: wrong function argument count', () {
    final source = File('test/bad_arity.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('expects 2 arguments') &&
              e.toString().contains('got 1'),
        ),
      ),
    );
  });

  test('error: mismatched function argument type', () {
    final source = File('test/bad_arg_type.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('expected `i32`') &&
              e.toString().contains('got `bool`'),
        ),
      ),
    );
  });

  test('return plus a next-line call does not consume the statement', () {
    const source = '''
fn main() {
  return
  puts("after")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    final body = program.funcs.single.body!.stmts;
    expect(body.length, 2);
    expect(body[0], isA<ReturnStmt>());
    expect((body[0] as ReturnStmt).value, isNull);
    expect(body[1], isA<CallStmt>());
  });

  test('error: calling a local variable instead of a function', () {
    const source = '''
fn foo(): i32 { return 1 }
fn main() {
  let foo = 1
  foo()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('is not a function'),
        ),
      ),
    );
  });

  test('error: break outside a loop', () {
    final source = File('test/break_outside.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('break') &&
              msg.contains('a loop');
        }),
      ),
    );
  });

  test('error: if condition is not bool', () {
    final source = File('test/bad_cond.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('bool') &&
              msg.contains('untyped int');
        }),
      ),
    );
  });

  test('golden: slice, array, and mutable pointer', () async {
    final result = await _compileAndRun('test/slice_sum.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/slice_sum.out').readAsString());

    final source = File('test/slice_sum.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/slice_sum.kl');
    expect(c, contains('klin_slice_i32'));
    expect(c, contains('int32_t buf[4] = { 10, 20, 30, 40 };'));
    expect(c, contains('(klin_slice_i32){ buf, 4 }'));
    expect(c, contains('xs.ptr[i]'));
    expect(c, contains('volatile uint32_t * p'));
    expect(c, contains('(volatile uint32_t *)(uintptr_t)'));
  });

  test('implicit array-to-slice conversion emits a slice header', () {
    const source = '''
fn sum(xs: []i32): i32 { return xs.len }
fn main() {
  let buf: [2]i32 = [1, 2]
  printf("%d\\n", sum(buf))
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'coerce.kl');
    expect(c, contains('(klin_slice_i32){ buf, 2 }'));
  });

  test('error: write through immutable pointer', () {
    const source = '''
fn main() {
  let mut value: i32 = 0
  let p: *i32 = &value
  *p = 1
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('immutable pointer'),
        ),
      ),
    );
  });

  test('hexadecimal literal accepts underscores', () {
    const source = '''
fn main() {
  let address: u32 = 0x4000_1000
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    expect(emitC(program, 'hex.kl'), contains('0x40001000'));
  });

  test('codename emits a global C symbol', () {
    const source = '''
@[codename("SysTick_Handler")]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'tick.kl');
    expect(c, contains('void SysTick_Handler(void);'));
    expect(c, contains('void SysTick_Handler(void) {'));
    expect(c, isNot(contains('static void SysTick_Handler')));
  });

  test('cexport + codename emits a global C symbol (issue 045)', () {
    const source = '''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {
  printf("%d\\n", add(2, 3))
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'exp.kl');
    expect(c, contains('int32_t klin_add(int32_t a, int32_t b);'));
    expect(c, contains('int32_t klin_add(int32_t a, int32_t b) {'));
    expect(c, isNot(contains('static int32_t klin_add')));
  });

  test('cexport without codename is a checker error', () {
    const source = '''
@[cexport]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('codename'),
      )),
    );
  });

  test('cexport cannot combine with cimport', () {
    const source = '''
@[cexport, cimport, codename("x")]
fn x()
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('cimport') &&
            e.toString().contains('cexport'),
      )),
    );
  });

  test('cexport on main is a checker error', () {
    const source = '''
@[cexport, codename("not_really_main")]
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('main'),
      )),
    );
  });

  test('C caller can link against cexport symbol (issue 045)', () async {
    final kl = File('${tmp.path}/lib_add.kl');
    await kl.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    // Klin requires `main`; rename it so the C caller owns the entry point.
    var cSource = emitC(program, kl.path);
    cSource = cSource.replaceAll('int main(void)', 'static int klin_lib_main(void)');
    final cPath = '${tmp.path}/lib_add.c';
    await File(cPath).writeAsString(cSource);

    final caller = File('${tmp.path}/caller.c');
    await caller.writeAsString('''
#include <stdint.h>
#include <stdio.h>
int32_t klin_add(int32_t a, int32_t b);
int main(void) {
  printf("%d\\n", (int)klin_add(2, 3));
  return 0;
}
''');
    final bin = '${tmp.path}/cexport_bin';
    final compile = await Process.run('gcc', [
      caller.path,
      cPath,
      '-o',
      bin,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(bin, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '5\n');
  });

  test('emitH writes prototypes for cexport (issue 046)', () {
    const source = '''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final h = emitH(program, 'lib.kl');
    expect(h, contains('#ifndef KLIN_LIB_H'));
    expect(h, contains('#include <stdint.h>'));
    expect(h, contains('int32_t klin_add(int32_t a, int32_t b);'));
    expect(h, isNot(contains('main')));
    expect(h, contains('#endif /* KLIN_LIB_H */'));
  });

  test('emitH closes nested struct deps regardless of decl order (issue 046)', () {
    // Signature only mentions Outer; Inner is two levels down. One pass over
    // program.structs (decl order Inner → Mid → Outer) used to miss Inner.
    const source = '''
struct Inner {
  x: i32
}
struct Mid {
  inner: Inner
}
struct Outer {
  mid: Mid
}
@[cexport, codename("klin_take_outer")]
fn take_outer(o: Outer): i32 {
  return o.mid.inner.x
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final h = emitH(program, 'nest.kl');
    expect(h, contains('Inner'));
    expect(h, contains('Mid'));
    expect(h, contains('Outer'));
    expect(h.indexOf('Inner'), lessThan(h.indexOf('Mid')));
    expect(h.indexOf('Mid'), lessThan(h.indexOf('Outer')));
    expect(h, contains('klin_take_outer'));
  });

  test('C caller can #include emitH header (issue 046)', () async {
    final kl = File('${tmp.path}/lib_add_h.kl');
    await kl.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    var cSource = emitC(program, kl.path);
    cSource =
        cSource.replaceAll('int main(void)', 'static int klin_lib_main(void)');
    final cPath = '${tmp.path}/lib_add_h.c';
    final hPath = '${tmp.path}/lib_add_h.h';
    await File(cPath).writeAsString(cSource);
    await File(hPath).writeAsString(emitH(program, kl.path));

    final caller = File('${tmp.path}/caller_h.c');
    await caller.writeAsString('''
#include <stdio.h>
#include "lib_add_h.h"
int main(void) {
  printf("%d\\n", (int)klin_add(2, 3));
  return 0;
}
''');
    final bin = '${tmp.path}/cexport_h_bin';
    final compile = await Process.run('gcc', [
      caller.path,
      cPath,
      '-I',
      tmp.path,
      '-o',
      bin,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(bin, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '5\n');
  });

  test('cimport emits a declaration and checks its signature', () {
    const source = '''
@[cimport, codename("pin_set")]
fn set_pin(value: u32)
fn main() {
  set_pin(1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'ffi.kl');
    expect(c, contains('uint32_t value'));
    expect(c, contains('void pin_set(uint32_t value);'));
    expect(c, isNot(contains('void pin_set(uint32_t value) {')));

    const badSource = '''
@[cimport]
fn set_pin(value: u32)
fn main() {
  set_pin()
}
''';
    final bad = Parser(Lexer(badSource).tokenize()).parse();
    expect(
      () => Checker().check(bad),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('expects 1 arguments'),
      )),
    );
  });

  test(
      'cimport with a body and a bodyless non-cimport function are checker errors',
      () {
    final pos = const SourcePos(1, 1);
    final main = FuncDecl(
      name: 'main',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: Block([], pos),
      pos: pos,
    );
    final importedWithBody = FuncDecl(
      name: 'ffi',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: Block([], pos),
      attrs: [Attr('cimport', null, pos)],
      pos: pos,
    );
    expect(
      () => Checker().check(Program([], [importedWithBody, main], pos)),
      throwsA(isA<CheckError>()),
    );
    final missingBody = FuncDecl(
      name: 'missing',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: null,
      pos: pos,
    );
    expect(
      () => Checker().check(Program([], [missingBody, main], pos)),
      throwsA(isA<CheckError>()),
    );
  });

  test('asm emits asm volatile without stdio', () {
    const source = '''
fn main() {
  asm("wfi")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'asm.kl');
    expect(c, contains('asm volatile("wfi");'));
    expect(c, isNot(contains('#include <stdio.h>')));
  });

  test('klin test runs *_test.kl and reports assert failures (issue 035)',
      () async {
    final pass = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test', 'examples/add_test.kl'],
    );
    expect(pass.exitCode, 0, reason: pass.stderr.toString());
    expect(pass.stdout.toString(), contains('ok\texamples/add_test.kl'));
    expect(pass.stdout.toString(), contains('PASS'));

    final dir = Directory('${tmp.path}/klin_tests')..createSync();
    File('${dir.path}/fail_test.kl').writeAsStringSync('''
import testing
fn test_boom() {
  testing.assert_eq_i32(1, 2)
}
''');
    final fail = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test', '${dir.path}/fail_test.kl'],
      environment: {
        ...Platform.environment,
        'KLIN_STDLIB': Directory('stdlib').absolute.path,
      },
    );
    expect(fail.exitCode, isNot(0));
    expect(fail.stdout.toString(), contains('FAIL'));
    expect(
      '${fail.stdout}${fail.stderr}',
      contains('assert_eq_i32'),
    );

    // Imported `main` must not suppress the test harness.
    File('${dir.path}/lib_with_main.kl').writeAsStringSync('''
module lib_with_main
pub fn value(): i32 { return 7 }
fn main() { puts("imported-main") }
''');
    File('${dir.path}/import_main_test.kl').writeAsStringSync('''
import lib_with_main
import testing
fn test_value() {
  testing.assert_eq_i32(lib_with_main.value(), 7)
}
''');
    final imported = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test', '${dir.path}/import_main_test.kl'],
      environment: {
        ...Platform.environment,
        'KLIN_STDLIB': Directory('stdlib').absolute.path,
      },
    );
    expect(imported.exitCode, 0, reason: imported.stderr.toString());
    expect(imported.stdout.toString(), contains('ok\t'));
    expect('${imported.stdout}${imported.stderr}', isNot(contains('imported-main')));
  });

  test('klin run compiles and executes a program', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'run', 'test/hello.kl'],
    );
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, await File('test/hello.out').readAsString());
  });

  test('klin --version and -v print package version', () async {
    for (final flag in ['--version', '-v']) {
      final proc = await Process.run('dart', ['run', 'bin/klin.dart', flag]);
      expect(proc.exitCode, 0, reason: '$flag: ${proc.stderr}');
      expect(proc.stdout.toString().trim(), 'klin 0.1.0');
    }
  });

  test('klin --help and -h print usage on stdout', () async {
    for (final flag in ['--help', '-h']) {
      final proc = await Process.run('dart', ['run', 'bin/klin.dart', flag]);
      expect(proc.exitCode, 0, reason: '$flag: ${proc.stderr}');
      expect(proc.stdout.toString(), contains('usage:'));
      expect(proc.stdout.toString(), contains('--version'));
      expect(proc.stderr.toString(), isEmpty);
    }
  });

  test('klin with no args prints help on stdout', () async {
    final proc = await Process.run('dart', ['run', 'bin/klin.dart']);
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout.toString(), contains('usage:'));
    expect(proc.stderr.toString(), isEmpty);
  });

  test('klin run without a file prints usage', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'run'],
    );
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('usage:'));
    expect(proc.stderr.toString(), contains('klin run'));
  });

  test('bare file path remains an alias for run', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/hello.kl'],
    );
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, await File('test/hello.out').readAsString());
  });

  test('--emit-c writes C without compiling or running', () async {
    final source = File('${tmp.path}/emit_only.kl');
    await source.writeAsString('''
@[link("driver.a")]
fn main() {}
''');
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-c', source.path],
    );
    final cFile = File('out/emit_only.c');
    final linkFile = File('out/emit_only.link');
    addTearDown(() async {
      if (await cFile.exists()) await cFile.delete();
      if (await linkFile.exists()) await linkFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await cFile.exists(), isTrue);
    expect(await linkFile.readAsString(), 'driver.a\n');
  });

  test('--emit-h writes header without compiling or running', () async {
    final source = File('${tmp.path}/emit_h_only.kl');
    await source.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''');
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-h', source.path],
    );
    final hFile = File('out/emit_h_only.h');
    final cFile = File('out/emit_h_only.c');
    addTearDown(() async {
      if (await hFile.exists()) await hFile.delete();
      if (await cFile.exists()) await cFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await hFile.exists(), isTrue);
    expect(await cFile.exists(), isFalse);
    expect(await hFile.readAsString(), contains('int32_t klin_add'));
  });

  test('--emit-c --emit-h writes both artifacts', () async {
    final source = File('${tmp.path}/emit_both.kl');
    await source.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''');
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-c', '--emit-h', source.path],
    );
    final hFile = File('out/emit_both.h');
    final cFile = File('out/emit_both.c');
    addTearDown(() async {
      if (await hFile.exists()) await hFile.delete();
      if (await cFile.exists()) await cFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await hFile.exists(), isTrue);
    expect(await cFile.exists(), isTrue);
  });

  test('buildCcArgs resolves @[link] paths and CLI -l/-L', () {
    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
          attrs: [
            Attr('link', 'libadd.a', pos),
            Attr('link', '-lm', pos),
          ],
          sourcePath: '${tmp.path}/main.kl',
        ),
      ],
      pos,
    );
    final dir = tmp.path;
    File('$dir/libadd.a').writeAsStringSync('');
    final args = buildCcArgs(
      cPath: 'out/x.c',
      binPath: 'out/x',
      program: program,
      sourceDir: dir,
      cliLibs: const ['m'],
      cliLibDirs: const ['/opt/lib'],
    );
    expect(args.first, 'out/x.c');
    expect(args, contains('$dir/libadd.a'));
    final lOpt = args.indexOf('-L/opt/lib');
    final lm = args.indexOf('-lm');
    expect(lOpt, greaterThan(0));
    expect(lm, greaterThan(lOpt));
    expect(args.where((a) => a == '-lm').length, 2);
    expect(args.sublist(args.length - 2), ['-o', 'out/x']);
  });

  test('buildCcArgs puts CLI -L before @[link("-l…")]', () {
    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
          attrs: [Attr('link', '-lfoo', pos)],
        ),
      ],
      pos,
    );
    final args = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
      cliLibDirs: const ['/libs'],
    );
    expect(args.indexOf('-L/libs'), lessThan(args.indexOf('-lfoo')));
  });

  test('cheader cimport skips C prototype emission', () {
    const source = '''
@[cinclude("regs.h")]
@[cimport, cheader, codename("pin_toggle")]
fn pin_toggle()
fn main() {
  pin_toggle()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'hdr.kl');
    expect(c, contains('#include "regs.h"'));
    expect(c, isNot(contains('void pin_toggle(void);')));
    expect(c, contains('pin_toggle();'));
  });

  test('klin run links @[cimport] against a static archive (issue 021)', () async {
    final addC = File('${tmp.path}/add.c');
    await addC.writeAsString('''
int add(int a, int b) { return a + b; }
''');
    final obj = '${tmp.path}/add.o';
    final archive = '${tmp.path}/libadd.a';
    final ccObj = await Process.run('gcc', ['-c', addC.path, '-o', obj]);
    expect(ccObj.exitCode, 0, reason: ccObj.stderr);
    final ar = await Process.run('ar', ['rcs', archive, obj]);
    expect(ar.exitCode, 0, reason: ar.stderr);

    final kl = File('${tmp.path}/use_add.kl');
    await kl.writeAsString('''
@[link("libadd.a")]
@[cimport, codename("add")]
fn add(a: i32, b: i32): i32

fn main() {
  printf("%d\\n", add(2, 3))
}
''');
    final result = await _compileAndRun(kl.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('klin run links @[cimport] against an ASM unit (issue 022)', () async {
    final asm = File('${tmp.path}/add.S');
    await asm.writeAsString(r'''
#if defined(__APPLE__)
#  define ASM_ADD_SYM _asm_add
#else
#  define ASM_ADD_SYM asm_add
#endif
.globl ASM_ADD_SYM
ASM_ADD_SYM:
#if defined(__aarch64__) || defined(__arm64__)
        add     w0, w0, w1
        ret
#elif defined(__x86_64__)
        movl    %edi, %eax
        addl    %esi, %eax
        ret
#else
#  error unsupported arch
#endif
''');
    final kl = File('${tmp.path}/use_asm.kl');
    await kl.writeAsString('''
@[link("add.S")]
@[cimport, codename("asm_add")]
fn asm_add(a: i32, b: i32): i32

fn main() {
  printf("%d\\n", asm_add(2, 3))
}
''');
    final result = await _compileAndRun(kl.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('klin run -l/-L links a named library (issue 021)', () async {
    final addC = File('${tmp.path}/mylib.c');
    await addC.writeAsString('''
int mylib_answer(void) { return 42; }
''');
    final obj = '${tmp.path}/mylib.o';
    final archive = '${tmp.path}/libmylib.a';
    expect(
      (await Process.run('gcc', ['-c', addC.path, '-o', obj])).exitCode,
      0,
    );
    expect((await Process.run('ar', ['rcs', archive, obj])).exitCode, 0);

    final kl = File('${tmp.path}/use_mylib.kl');
    await kl.writeAsString('''
@[cimport, codename("mylib_answer")]
fn answer(): i32

fn main() {
  printf("%d\\n", answer())
}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    final cPath = '${tmp.path}/use_mylib.c';
    final binPath = '${tmp.path}/use_mylib';
    await File(cPath).writeAsString(emitC(program, kl.path));
    final args = buildCcArgs(
      cPath: cPath,
      binPath: binPath,
      program: program,
      sourceDir: tmp.path,
      cliLibs: const ['mylib'],
      cliLibDirs: [tmp.path],
    );
    final compile = await Process.run('gcc', args);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(binPath, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '42\n');
  });

  test('error: unknown C call without cimport (issue 021)', () {
    const source = '''
fn main() {
  unknown_c_fn(1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('unknown function') &&
            e.toString().contains('cimport'),
      )),
    );
  });

  test('host builtins puts/printf remain without cimport', () {
    const source = '''
fn main() {
  puts("hi")
  printf("%d\\n", 1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
  });

  test('STM32 example builds and exports SysTick_Handler', () async {
    final compiler = await Process.run(
      'sh',
      ['-c', 'command -v arm-none-eabi-gcc'],
    );
    if (compiler.exitCode != 0) return;

    const example = 'examples/stm32/blink_f411';
    addTearDown(
        () => Process.run('make', ['clean'], workingDirectory: example));
    final registers = await Process.run(
      'dart',
      [
        'run',
        'bin/svd2klin.dart',
        '--svd',
        'third_party/svd/stm32f411.svd',
        '--out-h',
        '$example/stm32f411_regs.h',
        '--out-kl',
        '$example/stm32f411_regs.kl',
        '--peripherals',
        'RCC,GPIOA,STK',
      ],
    );
    expect(registers.exitCode, 0, reason: registers.stderr.toString());
    final build = await Process.run('make', [], workingDirectory: example);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');

    final nm = await Process.run(
      'arm-none-eabi-nm',
      ['blink.elf'],
      workingDirectory: example,
    );
    expect(nm.exitCode, 0, reason: nm.stderr.toString());
    expect(nm.stdout.toString(), contains('SysTick_Handler'));

    final objdump = await Process.run(
      'arm-none-eabi-objdump',
      ['-d', 'blink.elf'],
      workingDirectory: example,
    );
    expect(objdump.exitCode, 0, reason: objdump.stderr.toString());
    final disasm = objdump.stdout.toString();
    expect(disasm, contains('<SysTick_Handler>'));
    // Fluent API must lower to static inline MMIO — no bl to accessors (027).
    final accessorBl = RegExp(
      r'bl\s+[0-9a-f]+\s+<(?:RCC_|GPIOA_|STK_)[^>]+>',
    );
    expect(accessorBl.hasMatch(disasm), isFalse, reason: disasm);
  });
}

Future<({int exitCode, String stdout, String stderr})> _compileAndRun(
  String klPath,
  Directory tmp,
) async {
  final program = loadProject(klPath);
  Checker().check(program);
  final base = klPath.split('/').last.replaceAll('.kl', '');
  final cPath = '${tmp.path}/$base.c';
  final binPath = '${tmp.path}/$base';
  await File(cPath).writeAsString(emitC(program, klPath));

  final sourceDir = File(klPath).absolute.parent.path;
  final ccArgs = buildCcArgs(
    cPath: cPath,
    binPath: binPath,
    program: program,
    sourceDir: sourceDir,
  );
  final compile = await Process.run('gcc', ccArgs);
  if (compile.exitCode != 0) {
    return (
      exitCode: compile.exitCode,
      stdout: compile.stdout.toString(),
      stderr: 'gcc: ${compile.stderr}',
    );
  }

  final run = await Process.run(binPath, []);
  return (
    exitCode: run.exitCode,
    stdout: run.stdout.toString(),
    stderr: run.stderr.toString(),
  );
}
