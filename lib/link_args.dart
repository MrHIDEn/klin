import 'dart:io';

import 'ast.dart';
import 'emit_c.dart';

/// Builds `cc` argv: `[cPath, …link…, -o, binPath]`.
///
/// `@[link]` strings that start with `-` are passed as-is (`-lm`, `-L/opt`).
/// Otherwise they are object/archive paths resolved relative to [sourceDir].
/// [cliLibs] become `-lNAME`; [cliLibDirs] become `-LDIR`.
List<String> buildCcArgs({
  required String cPath,
  required String binPath,
  required Program program,
  required String sourceDir,
  List<String> cliLibs = const [],
  List<String> cliLibDirs = const [],
}) {
  final args = <String>[cPath];
  for (final raw in collectLinkAttrs(program)) {
    args.add(_resolveLinkAttr(raw, sourceDir));
  }
  for (final dir in cliLibDirs) {
    args.add('-L$dir');
  }
  for (final lib in cliLibs) {
    args.add('-l$lib');
  }
  args.addAll(['-o', binPath]);
  return args;
}

String _resolveLinkAttr(String raw, String sourceDir) {
  if (raw.startsWith('-')) return raw;
  final asIs = File(raw);
  if (asIs.isAbsolute) return asIs.path;
  final fromSource = File('$sourceDir${Platform.pathSeparator}$raw');
  if (fromSource.existsSync()) return fromSource.absolute.path;
  final fromCwd = File(raw);
  if (fromCwd.existsSync()) return fromCwd.absolute.path;
  // Prefer source-relative path even if missing (cc will report the error).
  return fromSource.absolute.path;
}
