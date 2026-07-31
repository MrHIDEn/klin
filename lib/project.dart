import 'dart:io';

import 'ast.dart';
import 'lexer.dart';
import 'parser.dart';
import 'preprocess.dart';
import 'token.dart';

/// Loads an entry file and all of its transitive imports.
///
/// [klinPathDirs] are CLI `-I` directories (searched in order, after `lib/`).
/// Environment `$KLIN_PATH` is also consulted (PATH-style separator).
Program loadProject(
  String entryPath, {
  List<String> klinPathDirs = const [],
}) {
  final structs = <StructDecl>[];
  final funcs = <FuncDecl>[];
  final importAliases = <String, Map<String, String>>{};
  final loading = <String>{};
  final loaded = <String, String>{}; // path → moduleName
  SourcePos? firstPos;

  String load(String path) {
    final file = File(path).absolute;
    final normalized = file.path;
    final existing = loaded[normalized];
    if (existing != null) return existing;
    if (!loading.add(normalized)) {
      throw ParseError('cyclic import `$normalized`', const SourcePos(1, 1));
    }
    if (!file.existsSync()) {
      throw FileSystemException('imported file not found', normalized);
    }
    final expanded = preprocess(file.readAsStringSync(), path: file.path);
    final unit = Parser(Lexer(expanded).tokenize()).parseUnit();
    final moduleName = unit.declaredName ?? _fileStem(file.path);
    firstPos ??= unit.pos;
    for (final struct in unit.structs) {
      struct.moduleName = moduleName;
      struct.sourcePath = file.path;
      structs.add(struct);
    }
    for (final func in unit.funcs) {
      func.moduleName = moduleName;
      func.sourcePath = file.path;
      funcs.add(func);
    }
    final aliases = <String, String>{};
    for (final importName in unit.imports) {
      final childPath = _resolveImportPath(
        file.parent.path,
        importName,
        klinPathDirs: klinPathDirs,
      );
      final childModule = load(childPath);
      aliases[importName] = childModule;
    }
    importAliases[moduleName] = aliases;
    loading.remove(normalized);
    loaded[normalized] = moduleName;
    return moduleName;
  }

  load(entryPath);
  return Program(
    structs,
    funcs,
    firstPos ?? const SourcePos(1, 1),
    importAliases: importAliases,
  );
}

/// Resolves `import name` → path to `name.kl`.
///
/// Order: sibling → `lib/` → `-I` dirs → `$KLIN_PATH` → `$KLIN_STDLIB` / repo
/// `stdlib/`.
String _resolveImportPath(
  String fromDir,
  String importName, {
  List<String> klinPathDirs = const [],
}) {
  final fileName = '$importName.kl';
  final sep = Platform.pathSeparator;
  final candidates = <String>[
    '$fromDir$sep$fileName',
    '$fromDir${sep}lib$sep$fileName',
    for (final dir in klinPathDirs) '$dir$sep$fileName',
    for (final dir in _klinPathEnvDirs()) '$dir$sep$fileName',
    for (final dir in _stdlibSearchDirs()) '$dir$sep$fileName',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  throw FileSystemException('imported file not found', candidates.first);
}

/// Directories from `$KLIN_PATH` (`:` on Unix, `;` on Windows).
Iterable<String> _klinPathEnvDirs() sync* {
  final env = Platform.environment['KLIN_PATH'];
  if (env == null || env.isEmpty) return;
  final sep = Platform.isWindows ? ';' : ':';
  for (final part in env.split(sep)) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) yield trimmed;
  }
}

Iterable<String> _stdlibSearchDirs() sync* {
  final env = Platform.environment['KLIN_STDLIB'];
  if (env != null && env.isNotEmpty) yield env;

  var dir = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    final std = Directory('${dir.path}${Platform.pathSeparator}stdlib');
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (std.existsSync() && pubspec.existsSync()) {
      yield std.path;
      break;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  if (Platform.script.scheme == 'file') {
    final scriptFile = File.fromUri(Platform.script);
    final rootStd = Directory(
      '${scriptFile.parent.parent.path}${Platform.pathSeparator}stdlib',
    );
    if (rootStd.existsSync()) yield rootStd.path;
  }
}

String _fileStem(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  return dot == -1 ? name : name.substring(0, dot);
}
