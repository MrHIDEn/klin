import 'dart:io';

import 'ast.dart';

/// One `@[link("…")]` occurrence with the declaring file's directory.
final class LinkAttrRef {
  final String raw;
  final String sourceDir;

  const LinkAttrRef(this.raw, this.sourceDir);
}

/// Collects `@[link]` args with per-declaration source directories.
List<LinkAttrRef> collectLinkAttrRefs(Program program, String fallbackDir) {
  final out = <LinkAttrRef>[];
  for (final decl in [...program.structs, ...program.funcs]) {
    final attrs = switch (decl) {
      StructDecl(:final attrs) => attrs,
      FuncDecl(:final attrs) => attrs,
      _ => const <Attr>[],
    };
    final path = switch (decl) {
      StructDecl(:final sourcePath) => sourcePath,
      FuncDecl(:final sourcePath) => sourcePath,
      _ => null,
    };
    final dir = path != null
        ? File(path).absolute.parent.path
        : fallbackDir;
    for (final attr in attrs) {
      if (attr.name == 'link' && attr.arg != null) {
        out.add(LinkAttrRef(attr.arg!, dir));
      }
    }
  }
  return out;
}

/// Builds `cc` argv: `[cPath, objects…, (-g)?, -L…, -l…, -o, binPath]`.
///
/// `@[link]` strings that start with `-L` / `-l` / other `-` are linker flags.
/// Otherwise they are object/archive/assembly paths (`.a` / `.o` / `.so` /
/// `.s` / `.S`) resolved relative to the declaring `.kl` file's directory.
/// CLI `-L` dirs are emitted before any `-l` flags.
/// When [debug] is true, passes host `-g` (debug symbols; no Klin runtime).
List<String> buildCcArgs({
  required String cPath,
  required String binPath,
  required Program program,
  required String sourceDir,
  List<String> cliLibs = const [],
  List<String> cliLibDirs = const [],
  bool debug = false,
}) {
  final objects = <String>[];
  final dashL = <String>[for (final d in cliLibDirs) '-L$d'];
  final dashOther = <String>[];

  for (final ref in collectLinkAttrRefs(program, sourceDir)) {
    final raw = ref.raw;
    if (!raw.startsWith('-')) {
      objects.add(_resolveLinkPath(raw, ref.sourceDir));
    } else if (raw.startsWith('-L')) {
      dashL.add(raw);
    } else {
      dashOther.add(raw);
    }
  }
  for (final lib in cliLibs) {
    dashOther.add('-l$lib');
  }

  return [
    cPath,
    ...objects,
    if (debug) '-g',
    ...dashL,
    ...dashOther,
    '-o',
    binPath,
  ];
}

/// Raw `@[link]` strings (for `out/*.link` dump). Prefer [collectLinkAttrRefs]
/// when resolving paths.
List<String> collectLinkAttrs(Program program) => [
      for (final ref in collectLinkAttrRefs(program, '.')) ref.raw,
    ];

String _resolveLinkPath(String raw, String sourceDir) {
  final asIs = File(raw);
  if (asIs.isAbsolute) return asIs.path;
  final fromSource = File('$sourceDir${Platform.pathSeparator}$raw');
  if (fromSource.existsSync()) return fromSource.absolute.path;
  final fromCwd = File(raw);
  if (fromCwd.existsSync()) return fromCwd.absolute.path;
  return fromSource.absolute.path;
}
