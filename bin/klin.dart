import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';

/// CLI: argv → czytaj → lex → parse → check → emit → cc → run
///
/// Użycie: dart run bin/klin.dart [--cc gcc|clang|tcc] <plik.kl>
Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  if (opts == null) {
    stderr.writeln('użycie: klin [--cc gcc|clang|tcc] <plik.kl>');
    exit(2);
  }

  final sourcePath = opts.sourcePath;
  final file = File(sourcePath);
  if (!await file.exists()) {
    stderr.writeln('klin: nie znaleziono pliku `$sourcePath`');
    exit(1);
  }

  final source = await file.readAsString();
  final Program program;
  try {
    final tokens = Lexer(source).tokenize();
    program = Parser(tokens).parse();
    Checker().check(program);
  } on LexError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  } on ParseError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  } on CheckError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  }

  final base = _basenameWithoutExt(sourcePath);
  final outDir = Directory('out');
  await outDir.create(recursive: true);
  final cPath = 'out/$base.c';
  final binPath = 'out/$base';

  final cSource = emitC(program, sourcePath);
  await File(cPath).writeAsString(cSource);

  final compile = await Process.run(opts.cc, [cPath, '-o', binPath]);
  if (compile.exitCode != 0) {
    // Z3: gcc nie powinien krzyczeć — jeśli krzyczy, to bug frontendu.
    stderr.writeln('klin: błąd kompilatora C (${opts.cc}):');
    stderr.write(compile.stderr);
    stderr.write(compile.stdout);
    exit(1);
  }

  final run = await Process.run(binPath, []);
  stdout.write(run.stdout);
  stderr.write(run.stderr);
  exit(run.exitCode);
}

final class _Opts {
  final String sourcePath;
  final String cc;

  const _Opts(this.sourcePath, this.cc);
}

_Opts? _parseArgs(List<String> args) {
  String cc = 'gcc';
  String? source;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--cc') {
      if (i + 1 >= args.length) return null;
      cc = args[++i];
    } else if (a.startsWith('-')) {
      return null;
    } else if (source == null) {
      source = a;
    } else {
      return null;
    }
  }
  if (source == null) return null;
  return _Opts(source, cc);
}

String _basenameWithoutExt(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}
