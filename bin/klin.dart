import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/project.dart';

/// CLI: argv → preprocess → lex → parse → check → emit → optionally cc → run
///
/// Usage:
///   klin run [--cc gcc|clang|tcc] <file.kl>
///   klin [--cc gcc|clang|tcc] [--emit-c|--emit-pp] <file.kl>
Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  if (opts == null) {
    stderr.writeln(
      'usage: klin run [--cc gcc|clang|tcc] <file.kl>\n'
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
