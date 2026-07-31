import 'dart:io';

import 'ast.dart';
import 'lexer.dart';
import 'parser.dart';
import 'token.dart';

/// Loads an entry file and all of its transitive imports.
Program loadProject(String entryPath) {
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
    final unit = Parser(Lexer(file.readAsStringSync()).tokenize()).parseUnit();
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
      final childModule = load(
        '${file.parent.path}${Platform.pathSeparator}$importName.kl',
      );
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

String _fileStem(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  return dot == -1 ? name : name.substring(0, dot);
}
