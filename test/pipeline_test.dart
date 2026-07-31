import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
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

  test(r'golden: $fn macro expands to a specialized struct (issue 026)',
      () async {
    final result = await _compileAndRun('test/macro_point.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/macro_point.out').readAsString());

    final raw = File('test/macro_point.kl').readAsStringSync();
    final expanded = preprocess(raw, path: 'test/macro_point.kl');
    expect(expanded, contains('struct Vec2i'));
    expect(expanded, contains('fn (p: Vec2i) len_sq(): i32'));
    expect(expanded, isNot(contains(r'$fn')));
    expect(expanded, isNot(contains(r'$point')));

    final program = loadProject('test/macro_point.kl');
    Checker().check(program);
    final c = emitC(program, 'test/macro_point.kl');
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

  test('--emit-pp writes expanded Klin source', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-pp', 'test/macro_point.kl'],
    );
    final pp = File('out/macro_point.pp.kl');
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

  test('klin run compiles and executes a program', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'run', 'test/hello.kl'],
    );
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, await File('test/hello.out').readAsString());
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
    expect(objdump.stdout.toString(), contains('<SysTick_Handler>'));
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

  final compile = await Process.run('gcc', [cPath, '-o', binPath]);
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
