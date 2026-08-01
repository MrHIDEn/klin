import 'dart:io';

import 'ast.dart';
import 'lexer.dart';
import 'parser.dart';
import 'preprocess.dart';
import 'token.dart';

/// Loads an entry file (and same-module siblings) plus transitive imports.
///
/// [klinPathDirs] are CLI `-I` directories (searched in order, after `lib/`).
/// Environment `$KLIN_PATH` is also consulted (PATH-style separator).
///
/// `import name` resolves to `name.kl` **or** a directory `name/` of `.kl`
/// files (issue 047). Both in the same search slot → error.
Program loadProject(
  String entryPath, {
  List<String> klinPathDirs = const [],
}) {
  final structs = <StructDecl>[];
  final funcs = <FuncDecl>[];
  final importAliases = <String, Map<String, String>>{};
  final loading = <String>{};
  final loaded = <String, String>{}; // packageKey → moduleName
  final fileModule = <String, String>{}; // abs file path → moduleName
  SourcePos? firstPos;

  String loadPackageFiles(
    List<String> filePaths, {
    String? requiredModule,
  }) {
    final absFiles = [
      for (final p in filePaths) File(p).absolute.path,
    ]..sort();
    if (absFiles.isEmpty) {
      throw FileSystemException('imported package has no .kl files', '');
    }

    // Already loaded as part of a larger (or identical) package — do not
    // re-parse / re-register declarations (issue 047 / Bugbot).
    if (absFiles.every(fileModule.containsKey)) {
      final module = fileModule[absFiles.first]!;
      for (final path in absFiles) {
        if (fileModule[path] != module) {
          throw ParseError(
            'file `$path` already loaded as module `${fileModule[path]}`',
            const SourcePos(1, 1),
          );
        }
      }
      return module;
    }
    if (absFiles.any(fileModule.containsKey)) {
      final conflict = absFiles.firstWhere(fileModule.containsKey);
      throw ParseError(
        'file `$conflict` already loaded as part of another package',
        const SourcePos(1, 1),
      );
    }

    final packageKey = absFiles.join('\x1e');
    final existing = loaded[packageKey];
    if (existing != null) return existing;
    if (!loading.add(packageKey)) {
      throw ParseError('cyclic import `$packageKey`', const SourcePos(1, 1));
    }

    final units = <({String path, ModuleUnit unit, String moduleName})>[];
    for (final path in absFiles) {
      final file = File(path);
      if (!file.existsSync()) {
        throw FileSystemException('imported file not found', path);
      }
      final expanded = preprocess(file.readAsStringSync(), path: path);
      final unit = Parser(Lexer(expanded).tokenize()).parseUnit();
      final moduleName = unit.declaredName ?? _fileStem(path);
      if (requiredModule != null && moduleName != requiredModule) {
        throw ParseError(
          'module `$moduleName` in `$path` does not match package '
          '`$requiredModule`',
          unit.pos,
        );
      }
      units.add((path: path, unit: unit, moduleName: moduleName));
    }

    final moduleName = units.first.moduleName;
    for (final u in units) {
      if (u.moduleName != moduleName) {
        throw ParseError(
          'mixed module names in package (`$moduleName` vs `${u.moduleName}`)',
          u.unit.pos,
        );
      }
    }

    firstPos ??= units.first.unit.pos;
    for (final u in units) {
      for (final struct in u.unit.structs) {
        struct.moduleName = moduleName;
        struct.sourcePath = u.path;
        structs.add(struct);
      }
      for (final func in u.unit.funcs) {
        func.moduleName = moduleName;
        func.sourcePath = u.path;
        funcs.add(func);
      }
    }

    // Mark files loaded before resolving imports so same-package
    // `import otherfile` does not re-register declarations.
    for (final path in absFiles) {
      fileModule[path] = moduleName;
    }
    loaded[packageKey] = moduleName;

    final aliases = importAliases.putIfAbsent(moduleName, () => {});
    // Group imports by their source qualifier (alias or default). The same
    // qualifier bound to two different specs is a conflict.
    final byQualifier = <String, ImportSpec>{};
    for (final u in units) {
      for (final imp in u.unit.imports) {
        final existing = byQualifier[imp.qualifier];
        if (existing != null &&
            existing.resolutionKey != imp.resolutionKey) {
          throw ParseError(
            'import alias `${imp.qualifier}` is already bound to '
            '`${existing.spec}`',
            imp.pos,
          );
        }
        byQualifier[imp.qualifier] = imp;
      }
    }
    // Resolve imports relative to the package directory (parent of files).
    final fromDir = File(absFiles.first).parent.path;
    for (final qualifier in byQualifier.keys.toList()..sort()) {
      final imp = byQualifier[qualifier]!;
      final target = _resolveImportTarget(
        fromDir,
        imp.resolutionKey,
        klinPathDirs: klinPathDirs,
      );
      final childModule = switch (target) {
        _FileImport(:final path) => loadPackageFiles([path]),
        _DirImport(:final path) => loadPackageFiles(
            _packageKlFiles(path),
            requiredModule: imp.defaultQualifier,
          ),
      };
      aliases[qualifier] = childModule;
    }

    loading.remove(packageKey);
    return moduleName;
  }

  // Entry: load the entry file plus same-module siblings in its directory.
  final entryAbs = File(entryPath).absolute.path;
  final entryExpanded =
      preprocess(File(entryAbs).readAsStringSync(), path: entryAbs);
  final entryUnit = Parser(Lexer(entryExpanded).tokenize()).parseUnit();
  final entryModule = entryUnit.declaredName ?? _fileStem(entryAbs);
  final entryDir = File(entryAbs).parent.path;
  final siblingFiles = <String>[entryAbs];
  final moduleDecl = RegExp('(?:^|\\n)\\s*module\\s+$entryModule\\b');
  for (final path in _packageKlFiles(entryDir)) {
    if (path == entryAbs) continue;
    final raw = File(path).readAsStringSync();
    final looksLikeSibling = _fileStem(path) == entryModule ||
        moduleDecl.hasMatch(raw);
    try {
      final expanded = preprocess(raw, path: path);
      final unit = Parser(Lexer(expanded).tokenize()).parseUnit();
      final name = unit.declaredName ?? _fileStem(path);
      if (name == entryModule) siblingFiles.add(path);
    } on PreprocessError {
      if (looksLikeSibling) rethrow;
    } on LexError {
      if (looksLikeSibling) rethrow;
    } on ParseError {
      if (looksLikeSibling) rethrow;
    }
  }
  loadPackageFiles(siblingFiles);

  return Program(
    structs,
    funcs,
    firstPos ?? const SourcePos(1, 1),
    importAliases: importAliases,
  );
}

sealed class _ImportTarget {
  const _ImportTarget();
}

final class _FileImport extends _ImportTarget {
  final String path;
  const _FileImport(this.path);
}

final class _DirImport extends _ImportTarget {
  final String path;
  const _DirImport(this.path);
}

/// Resolves `import name` → single file or package directory.
///
/// Per search root (sibling, `lib/`, `-I`, `$KLIN_PATH`, stdlib): try
/// `name.kl` and `name/` in that slot; both present → ambiguous.
_ImportTarget _resolveImportTarget(
  String fromDir,
  String importName, {
  List<String> klinPathDirs = const [],
}) {
  final sep = Platform.pathSeparator;
  final roots = <String>[
    fromDir,
    '$fromDir${sep}lib',
    ...klinPathDirs,
    ..._klinPathEnvDirs(),
    ..._stdlibSearchDirs(),
  ];

  for (final root in roots) {
    final filePath = '$root$sep$importName.kl';
    final dirPath = '$root$sep$importName';
    final hasFile = File(filePath).existsSync();
    final dirFiles = _packageKlFilesIfDir(dirPath);
    final hasDir = dirFiles.isNotEmpty;
    if (hasFile && hasDir) {
      throw FileSystemException(
        'ambiguous import `$importName`: both `$filePath` and package '
        'directory `$dirPath` exist',
        filePath,
      );
    }
    if (hasFile) return _FileImport(File(filePath).absolute.path);
    if (hasDir) return _DirImport(Directory(dirPath).absolute.path);
  }

  throw FileSystemException(
    'imported file not found',
    '$fromDir$sep$importName.kl',
  );
}

/// `.kl` files in [dir], excluding `*_test.kl`. Empty if not a directory.
List<String> _packageKlFiles(String dir) {
  final directory = Directory(dir);
  if (!directory.existsSync()) return const [];
  final out = <String>[];
  for (final entity in directory.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (!name.endsWith('.kl')) continue;
    if (name.endsWith('_test.kl')) continue;
    out.add(entity.absolute.path);
  }
  out.sort();
  return out;
}

List<String> _packageKlFilesIfDir(String dir) => _packageKlFiles(dir);

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
