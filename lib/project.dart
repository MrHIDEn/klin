import 'dart:io';

import 'ast.dart';
import 'lexer.dart';
import 'parser.dart';
import 'token.dart';

/// Ładuje plik wejściowy oraz wszystkie jego przechodnie importy.
Program loadProject(String entryPath) {
  final structs = <StructDecl>[];
  final funcs = <FuncDecl>[];
  final imports = <String, Set<String>>{};
  final loading = <String>{};
  final loaded = <String>{};
  SourcePos? firstPos;

  void load(String path) {
    final file = File(path).absolute;
    final normalized = file.path;
    if (loaded.contains(normalized)) return;
    if (!loading.add(normalized)) {
      throw ParseError('cykliczny import `$normalized`', const SourcePos(1, 1));
    }
    if (!file.existsSync()) {
      throw FileSystemException(
          'nie znaleziono importowanego pliku', normalized);
    }
    final unit = Parser(Lexer(file.readAsStringSync()).tokenize()).parseUnit();
    final moduleName = unit.declaredName ?? _fileStem(file.path);
    firstPos ??= unit.pos;
    imports[moduleName] = unit.imports.toSet();
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
    for (final importName in unit.imports) {
      load('${file.parent.path}${Platform.pathSeparator}$importName.kl');
    }
    loading.remove(normalized);
    loaded.add(normalized);
  }

  load(entryPath);
  return Program(structs, funcs, firstPos ?? const SourcePos(1, 1),
      imports: imports);
}

String _fileStem(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  return dot == -1 ? name : name.substring(0, dot);
}
