import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/fmt.dart';
import 'package:klin/klin_test.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/project.dart';

/// CLI: argv → preprocess → lex → parse → check → emit → optionally cc → run
///
/// Usage:
///   klin run [--cc gcc|clang|tcc] <file.kl>
///   klin fmt [-w] <file.kl…>
///   klin test [--cc gcc|clang|tcc] [path…]
///   klin [--cc gcc|clang|tcc] [--emit-c|--emit-pp] <file.kl>
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == 'fmt') {
    await _runFmt(args.skip(1).toList());
    return;
  }
  if (args.isNotEmpty && args.first == 'test') {
    await _runTest(args.skip(1).toList());
    return;
  }

  final opts = _parseArgs(args);
  if (opts == null) {
    stderr.writeln(
      'usage: klin run [--cc gcc|clang|tcc] <file.kl>\n'
      '       klin fmt [-w] <file.kl…>\n'
      '       klin test [--cc gcc|clang|tcc] [path…]\n'
      '       klin [--cc gcc|clang|tcc] [--emit-c|--emit-pp] <file.kl>',
    );
    exit(2);
  }

  final sourcePath = opts.sourcePath;
  final file = File(sourcePath);
  if (!await file.exists()) {
    stderr.writeln('klin: file not found `$sourcePath`');
    exit(1);
  }

  final base = _basenameWithoutExt(sourcePath);
  final outDir = Directory('out');
  await outDir.create(recursive: true);

  if (opts.emitPp) {
    try {
      final expanded = preprocess(await file.readAsString(), path: sourcePath);
      await File('out/$base.pp.kl').writeAsString(expanded);
    } on PreprocessError catch (e) {
      stderr.writeln('$e');
      exit(1);
    }
    return;
  }

  final Program program;
  try {
    program = loadProject(sourcePath);
    Checker().check(program);
  } on PreprocessError catch (e) {
    stderr.writeln('$e');
    exit(1);
  } on LexError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  } on ParseError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  } on CheckError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('klin: ${e.message}: ${e.path}');
    exit(1);
  }

  final cPath = 'out/$base.c';
  final binPath = 'out/$base';

  final cSource = emitC(program, sourcePath);
  await File(cPath).writeAsString(cSource);
  if (opts.emitC) {
    final links = collectLinkAttrs(program);
    if (links.isNotEmpty) {
      await File('out/$base.link').writeAsString('${links.join('\n')}\n');
    }
    return;
  }

  final compile = await Process.run(opts.cc, [cPath, '-o', binPath]);
  if (compile.exitCode != 0) {
    // Z3: gcc should not report errors; if it does, the frontend is at fault.
    stderr.writeln('klin: C compiler error (${opts.cc}):');
    stderr.write(compile.stderr);
    stderr.write(compile.stdout);
    exit(1);
  }

  final run = await Process.run(binPath, []);
  stdout.write(run.stdout);
  stderr.write(run.stderr);
  exit(run.exitCode);
}

Future<void> _runFmt(List<String> args) async {
  var write = false;
  final paths = <String>[];
  for (final a in args) {
    if (a == '-w') {
      write = true;
    } else if (a.startsWith('-')) {
      stderr.writeln('usage: klin fmt [-w] <file.kl…>');
      exit(2);
    } else {
      paths.add(a);
    }
  }
  if (paths.isEmpty) {
    stderr.writeln('usage: klin fmt [-w] <file.kl…>');
    exit(2);
  }

  var failed = false;
  for (final path in paths) {
    final file = File(path);
    if (!await file.exists()) {
      stderr.writeln('klin: file not found `$path`');
      failed = true;
      continue;
    }
    final raw = await file.readAsString();
    try {
      final formatted = formatSource(raw);
      if (write) {
        if (formatted != raw) {
          await file.writeAsString(formatted);
        }
      } else {
        stdout.write(formatted);
        if (paths.length > 1 && !formatted.endsWith('\n')) {
          stdout.writeln();
        }
      }
    } on LexError catch (e) {
      stderr.writeln('$path:$e');
      failed = true;
    } on ParseError catch (e) {
      stderr.writeln('$path:$e');
      failed = true;
    }
  }
  if (failed) exit(1);
}

Future<void> _runTest(List<String> args) async {
  var cc = 'gcc';
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--cc') {
      if (i + 1 >= args.length) {
        stderr.writeln('usage: klin test [--cc gcc|clang|tcc] [path…]');
        exit(2);
      }
      cc = args[++i];
    } else if (a.startsWith('-')) {
      stderr.writeln('usage: klin test [--cc gcc|clang|tcc] [path…]');
      exit(2);
    } else {
      paths.add(a);
    }
  }

  final List<String> files;
  try {
    files = discoverTestFiles(paths);
  } on FileSystemException catch (e) {
    stderr.writeln('klin: ${e.message}: ${e.path}');
    exit(1);
  }
  if (files.isEmpty) {
    stderr.writeln('klin test: no *_test.kl files found');
    exit(1);
  }

  var failed = 0;
  final cwd = Directory.current.absolute.path;
  String displayPath(String path) {
    final abs = File(path).absolute.path;
    final prefix = cwd.endsWith(Platform.pathSeparator)
        ? cwd
        : '$cwd${Platform.pathSeparator}';
    return abs.startsWith(prefix) ? abs.substring(prefix.length) : abs;
  }

  for (final path in files) {
    final shown = displayPath(path);
    try {
      final result = await runKlinTestFile(path, cc: cc);
      if (result.ok) {
        stdout.writeln('ok\t$shown');
      } else {
        failed++;
        stdout.writeln('FAIL\t$shown');
        if (result.stderr.isNotEmpty) stderr.write(result.stderr);
        if (result.stdout.isNotEmpty) stdout.write(result.stdout);
      }
    } on PreprocessError catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('$e');
    } on LexError catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('$path:$e');
    } on ParseError catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('$path:$e');
    } on CheckError catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('$path:$e');
    } on FileSystemException catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('klin: ${e.message}: ${e.path}');
    }
  }

  if (failed == 0) {
    stdout.writeln('PASS');
    exit(0);
  }
  stdout.writeln('FAIL\t$failed/${files.length}');
  exit(1);
}

final class _Opts {
  final String sourcePath;
  final String cc;
  final bool emitC;
  final bool emitPp;

  const _Opts(this.sourcePath, this.cc, this.emitC, this.emitPp);
}

/// Recognized subcommands. Bare `<file.kl>` is an alias for `run`.
const _commands = {'run'};

_Opts? _parseArgs(List<String> args) {
  String cc = 'gcc';
  var emitC = false;
  var emitPp = false;
  String? command;
  String? source;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--cc') {
      if (i + 1 >= args.length) return null;
      cc = args[++i];
    } else if (a == '--emit-c') {
      emitC = true;
    } else if (a == '--emit-pp') {
      emitPp = true;
    } else if (a.startsWith('-')) {
      return null;
    } else if (command == null && source == null && _commands.contains(a)) {
      command = a;
    } else if (source == null) {
      source = a;
    } else {
      return null;
    }
  }
  if (source == null) return null;
  if (emitC && emitPp) return null;
  // `run` means compile+execute; `--emit-c` / `--emit-pp` skip execution.
  if (command != null && command != 'run') return null;
  return _Opts(source, cc, emitC, emitPp);
}

String _basenameWithoutExt(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}
