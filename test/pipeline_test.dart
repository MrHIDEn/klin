import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/project.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('złoty: hello.kl wypisuje oczekiwane wyjście', () async {
    final result = await _compileAndRun('test/hello.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/hello.out').readAsString();
    expect(result.stdout, expected);
  });

  test('złoty: emitowany C jest czytelny i zawiera #line', () {
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

  test('złoty: vars.kl — arytmetyka, mut, zakres', () async {
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

  test('błąd składni: komunikat z numerem linii', () async {
    final source = await File('test/bad_syntax.kl').readAsString();
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) {
          final msg = e.toString();
          // `42` w linii 3 — lekser zgłasza pozycję.
          return msg.contains('3:') && (e is LexError || e is ParseError);
        }),
      ),
    );
  });

  test('błąd składni przez CLI: exit ≠ 0 i numer linii na stderr', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/bad_syntax.kl'],
    );
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('3:'));
  });

  test('błąd: wywołanie słowa kluczowego C łapie frontend, nie gcc', () {
    final source = File('test/c_keyword_call.kl').readAsStringSync();
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) {
          if (e is! ParseError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('słowem kluczowym C') &&
              msg.contains('typedef');
        }),
      ),
    );
  });

  test('błąd typów: niezgodność z pozycją', () {
    final source = File('test/type_mismatch.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('niezgodność typów') &&
              msg.contains('i32') &&
              msg.contains('bool');
        }),
      ),
    );
  });

  test('błąd typów przez CLI: exit ≠ 0 i komunikat', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/type_mismatch.kl'],
    );
    expect(proc.exitCode, isNot(0));
    final err = proc.stderr.toString();
    expect(err, contains('2:'));
    expect(err, contains('niezgodność typów'));
  });

  test('błąd: mutacja let bez mut', () {
    final source = File('test/immutable_assign.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('3:') &&
              msg.contains('niemutowalnej zmiennej') &&
              msg.contains('x');
        }),
      ),
    );
  });

  test('błąd mutacji przez CLI: exit ≠ 0 i komunikat', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/immutable_assign.kl'],
    );
    expect(proc.exitCode, isNot(0));
    final err = proc.stderr.toString();
    expect(err, contains('3:'));
    expect(err, contains('niemutowalnej zmiennej'));
  });

  test('złoty: fizzbuzz.kl', () async {
    final result = await _compileAndRun('test/fizzbuzz.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fizzbuzz.out').readAsString();
    expect(result.stdout, expected);
  });

  test('złoty: break_continue.kl — while + for C', () async {
    final result = await _compileAndRun('test/break_continue.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/break_continue.out').readAsString();
    expect(result.stdout, expected);
  });

  test('złoty: funkcja wywołana przed definicją', () async {
    final result = await _compileAndRun('test/call_before_def.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/call_before_def.out').readAsString();
    expect(result.stdout, expected);
  });

  test('złoty: rekurencyjny fib', () async {
    final result = await _compileAndRun('test/fib.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fib.out').readAsString();
    expect(result.stdout, expected);
  });

  test('złoty: Vec2 — struktury, pola i metody', () async {
    final result = await _compileAndRun('test/vec2.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/vec2.out').readAsString());

    final program = loadProject('test/vec2.kl');
    Checker().check(program);
    final c = emitC(program, 'test/vec2.kl');
    expect(c, contains('vec2_Vec2_translate(vec2_Vec2 *v'));
    expect(c, isNot(contains('mut')));
  });

  test('złoty: projekt z modułami', () async {
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

  test('błąd: prywatny symbol importowanego modułu', () {
    final program = loadProject('test/modules/private_app.kl');
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('jest prywatna'),
        ),
      ),
    );
  });

  test('błąd: niekwalifikowane wywołanie fn z innego modułu nie jest FFI', () {
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
              e.toString().contains('jest w module') &&
              e.toString().contains('lib.secret'),
        ),
      ),
    );
  });

  test('import alias mapuje na deklarację module w pliku', () {
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

  test('błąd: metoda mutująca na niemutowalnej zmiennej', () {
    final source = File('test/bad_mut_method.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('metody mutującej'),
        ),
      ),
    );
  });

  test('zacieniony mut receiver emituje `.` nie `->`', () {
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

  test('błąd: przypisanie do pola literału struktury', () {
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
              e.toString().contains('pola niemutowalnego wyrażenia'),
        ),
      ),
    );
  });

  test('błąd: zła liczba argumentów funkcji', () {
    final source = File('test/bad_arity.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('oczekuje 2 argumentów') &&
              e.toString().contains('dostano 1'),
        ),
      ),
    );
  });

  test('błąd: niezgodny typ argumentu funkcji', () {
    final source = File('test/bad_arg_type.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('oczekiwano `i32`') &&
              e.toString().contains('dostano `bool`'),
        ),
      ),
    );
  });

  test('return + wywołanie w następnej linii nie pożera stmt', () {
    const source = '''
fn main() {
  return
  puts("after")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    final body = program.funcs.single.body.stmts;
    expect(body.length, 2);
    expect(body[0], isA<ReturnStmt>());
    expect((body[0] as ReturnStmt).value, isNull);
    expect(body[1], isA<CallStmt>());
  });

  test('błąd: wywołanie lokalnej zmiennej zamiast funkcji', () {
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
          (e) => e is CheckError && e.toString().contains('nie jest funkcją'),
        ),
      ),
    );
  });

  test('błąd: break poza pętlą', () {
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
              msg.contains('pętlą');
        }),
      ),
    );
  });

  test('błąd: warunek if nie-bool', () {
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

  test('złoty: slice, tablica i mutowalny wskaźnik', () async {
    final result = await _compileAndRun('test/slice_sum.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/slice_sum.out').readAsString());

    final source = File('test/slice_sum.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/slice_sum.kl');
    expect(c, contains('klin_slice_i32'));
    expect(c, contains('int32_t buf[4] = { 10, 20, 30, 40 };'));
    expect(c, contains('xs.ptr[i]'));
    expect(c, contains('(volatile uint32_t *)(uintptr_t)'));
  });

  test('błąd: zapis przez niemutowalny wskaźnik', () {
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
          (e) =>
              e is CheckError && e.toString().contains('niemutowalny wskaźnik'),
        ),
      ),
    );
  });

  test('literał szesnastkowy akceptuje podkreślenia', () {
    const source = '''
fn main() {
  let address: u32 = 0x4000_1000
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    expect(emitC(program, 'hex.kl'), contains('0x40001000'));
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
