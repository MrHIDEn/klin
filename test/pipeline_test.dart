import 'dart:io';

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
    final c = emitC(program, 'test/hello.kl');

    expect(c, contains('#include <stdio.h>'));
    expect(c, contains('int main(void) {'));
    expect(c, contains('puts("hello");'));
    expect(c, contains('puts("z Klina");'));
    expect(c, contains('return 0;'));
    expect(c, contains('#line '));
    expect(c, contains('test/hello.kl'));
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
}

Future<({int exitCode, String stdout, String stderr})> _compileAndRun(
  String klPath,
  Directory tmp,
) async {
  final source = await File(klPath).readAsString();
  final program = Parser(Lexer(source).tokenize()).parse();
  final cPath = '${tmp.path}/hello.c';
  final binPath = '${tmp.path}/hello';
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
