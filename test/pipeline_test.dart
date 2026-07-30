import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
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
          return msg.contains('3:') &&
              (e is LexError || e is ParseError);
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
}

Future<({int exitCode, String stdout, String stderr})> _compileAndRun(
  String klPath,
  Directory tmp,
) async {
  final source = await File(klPath).readAsString();
  final program = Parser(Lexer(source).tokenize()).parse();
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
