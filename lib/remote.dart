import 'dart:io';

/// Reserved first path segments for remote imports (issue 049).
const remoteHosts = {'github', 'gitlab'};

/// Parsed `host/owner/repo` with optional `@ref`.
final class RemoteImport {
  final String host;
  final String owner;
  final String repo;
  final String? ref;

  const RemoteImport({
    required this.host,
    required this.owner,
    required this.repo,
    this.ref,
  });

  /// Import path without `@ref` (e.g. `github/mrhiden/osa`).
  String get path => '$host/$owner/$repo';

  String get gitUrl => switch (host) {
        'github' => 'https://github.com/$owner/$repo.git',
        'gitlab' => 'https://gitlab.com/$owner/$repo.git',
        _ => throw StateError('unsupported host `$host`'),
      };
}

/// True when [importKey] is a remote import (`github/…` or `gitlab/…`).
bool isRemoteImportPath(String importKey) {
  final slash = importKey.indexOf('/');
  if (slash <= 0) return false;
  return remoteHosts.contains(importKey.substring(0, slash));
}

/// Parse `github/owner/repo` or `github/owner/repo@ref`.
///
/// MVP: exactly three path segments. Throws [FormatException] on bad input.
RemoteImport parseRemoteImport(String spec) {
  var path = spec.trim();
  String? ref;
  final at = path.lastIndexOf('@');
  if (at > 0) {
    ref = path.substring(at + 1).trim();
    path = path.substring(0, at).trim();
    if (ref.isEmpty) {
      throw FormatException('empty @ref in remote import `$spec`');
    }
  }
  final parts = path.split('/');
  if (parts.length != 3 || parts.any((p) => p.isEmpty)) {
    throw FormatException(
      'remote import `$spec` must be host/owner/repo (optionally @ref)',
    );
  }
  final host = parts[0];
  if (!remoteHosts.contains(host)) {
    throw FormatException(
      'remote host `$host` is not allowed (use github or gitlab)',
    );
  }
  final owner = parts[1];
  final repo = parts[2];
  if (!_isSafePathSegment(owner) || !_isSafePathSegment(repo)) {
    throw FormatException(
      'remote import `$spec` has an invalid owner or repo segment',
    );
  }
  if (ref != null && (ref.contains('..') || ref.contains('/') || ref.contains('\\'))) {
    throw FormatException('invalid @ref in remote import `$spec`');
  }
  return RemoteImport(
    host: host,
    owner: owner,
    repo: repo,
    ref: ref,
  );
}

bool _isSafePathSegment(String s) {
  if (s == '.' || s == '..') return false;
  if (s.contains('..')) return false;
  // Allow typical GitHub names; reject path separators and NUL.
  return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(s);
}

/// Root of Klin cache (`$KLIN_CACHE` or `~/.klin`), overridable for tests.
String klinCacheRoot({String? override}) {
  if (override != null && override.isNotEmpty) return override;
  final env = Platform.environment['KLIN_CACHE'];
  if (env != null && env.isNotEmpty) return env;
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  return '$home${Platform.pathSeparator}.klin';
}

/// Directory for a cached package: `$cache/pkg/host/owner/repo`.
String packageCacheDir(RemoteImport remote, {String? cacheRoot}) {
  final root = klinCacheRoot(override: cacheRoot);
  final sep = Platform.pathSeparator;
  return '$root${sep}pkg$sep${remote.host}$sep${remote.owner}$sep${remote.repo}';
}

/// Whether the package directory looks installed (has `.kl` sources).
bool isPackageInstalled(String pkgDir) {
  final dir = Directory(pkgDir);
  if (!dir.existsSync()) return false;
  for (final entity in dir.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.isEmpty
        ? entity.path
        : entity.path.split(Platform.pathSeparator).last;
    if (name.endsWith('.kl') && !name.endsWith('_test.kl')) return true;
  }
  return false;
}

String? readPin(String pkgDir) {
  final f = File('$pkgDir${Platform.pathSeparator}.pin');
  if (!f.existsSync()) return null;
  final text = f.readAsStringSync().trim();
  return text.isEmpty ? null : text;
}

void writePin(String pkgDir, String ref) {
  Directory(pkgDir).createSync(recursive: true);
  File('$pkgDir${Platform.pathSeparator}.pin').writeAsStringSync('$ref\n');
}

// --- klin.mod ---------------------------------------------------------------

final class KlinMod {
  final int version;
  final Map<String, String> requires; // path → ref

  KlinMod({this.version = 1, Map<String, String>? requires})
      : requires = Map<String, String>.from(requires ?? {});

  static KlinMod empty() => KlinMod();
}

/// Find `klin.mod` walking up from [startDir]. Returns null if none.
File? findKlinModFile(String startDir) {
  var dir = Directory(startDir).absolute;
  for (var i = 0; i < 32; i++) {
    final candidate = File('${dir.path}${Platform.pathSeparator}klin.mod');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

KlinMod parseKlinMod(String content) {
  final requires = <String, String>{};
  var version = 1;
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) {
      continue;
    }
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length == 2 && parts[0] == 'klin') {
      version = int.tryParse(parts[1]) ?? 1;
      continue;
    }
    if (parts.length == 3 && parts[0] == 'require') {
      requires[parts[1]] = parts[2];
      continue;
    }
    throw FormatException('invalid klin.mod line: `$rawLine`');
  }
  return KlinMod(version: version, requires: requires);
}

String formatKlinMod(KlinMod mod) {
  final buf = StringBuffer('klin ${mod.version}\n');
  final keys = mod.requires.keys.toList()..sort();
  for (final path in keys) {
    buf.writeln('require $path ${mod.requires[path]}');
  }
  return buf.toString();
}

KlinMod loadKlinMod(File file) => parseKlinMod(file.readAsStringSync());

void saveKlinMod(File file, KlinMod mod) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(formatKlinMod(mod));
}

/// Resolve "latest" ref for a remote: newest `v*` semver tag, else main/master.
Future<String> resolveLatestRef(RemoteImport remote) async {
  final tags = await _gitLsRemote(remote.gitUrl, '--tags');
  final semver = <(List<int>, String)>[];
  for (final line in tags) {
    // <sha>\trefs/tags/v1.2.3 or refs/tags/v1.2.3^{}
    final tab = line.indexOf('\t');
    if (tab < 0) continue;
    var ref = line.substring(tab + 1).trim();
    if (ref.endsWith('^{}')) continue;
    const prefix = 'refs/tags/';
    if (!ref.startsWith(prefix)) continue;
    final tag = ref.substring(prefix.length);
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(tag);
    if (m == null) continue;
    semver.add((
      [
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      ],
      tag,
    ));
  }
  if (semver.isNotEmpty) {
    semver.sort((a, b) {
      for (var i = 0; i < 3; i++) {
        final c = b.$1[i].compareTo(a.$1[i]);
        if (c != 0) return c;
      }
      return 0;
    });
    return semver.first.$2;
  }

  final heads = await _gitLsRemote(remote.gitUrl, '--heads');
  for (final preferred in ['main', 'master']) {
    for (final line in heads) {
      if (line.endsWith('refs/heads/$preferred')) return preferred;
    }
  }
  throw ProcessException(
    'git',
    ['ls-remote', remote.gitUrl],
    'no tags or main/master on ${remote.gitUrl}',
  );
}

Future<List<String>> _gitLsRemote(String url, String mode) async {
  final result = await Process.run('git', ['ls-remote', mode, url]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      ['ls-remote', mode, url],
      '${result.stderr}'.trim().isEmpty
          ? 'git ls-remote failed'
          : '${result.stderr}'.trim(),
      result.exitCode,
    );
  }
  return '${result.stdout}'
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// Fetch [remote] at [ref] into the package cache. Returns package dir.
///
/// [force] replaces an existing install. Writes `.pin`.
Future<String> fetchRemote(
  RemoteImport remote, {
  required String ref,
  String? cacheRoot,
  bool force = false,
}) async {
  final pkgDir = packageCacheDir(remote, cacheRoot: cacheRoot);
  if (!force && isPackageInstalled(pkgDir)) {
    final pin = readPin(pkgDir);
    if (pin == ref) return pkgDir;
    throw StateError(
      'package `${remote.path}` is already installed at `$pin`; '
      'use `klin update ${remote.path}@$ref` to change',
    );
  }

  final tmp = Directory.systemTemp.createTempSync('klin_get_');
  final staging = Directory.systemTemp.createTempSync('klin_stage_');
  try {
    await _gitCheckoutRef(remote.gitUrl, ref, tmp.path);

    final sourceDir = _selectPackageSourceDir(tmp.path, remote.repo);
    // Stage into a fresh dir, then swap into place so a failed copy cannot
    // wipe a previously good cache install.
    for (final entity in Directory(sourceDir).listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!name.endsWith('.kl')) continue;
      if (name.endsWith('_test.kl')) continue;
      entity.copySync('${staging.path}${Platform.pathSeparator}$name');
    }
    if (!isPackageInstalled(staging.path)) {
      throw FileSystemException(
        'remote package `${remote.path}` has no .kl sources after fetch',
        sourceDir,
      );
    }
    File('${staging.path}${Platform.pathSeparator}.pin')
        .writeAsStringSync('$ref\n');

    final parent = Directory(pkgDir).parent;
    parent.createSync(recursive: true);
    if (Directory(pkgDir).existsSync()) {
      Directory(pkgDir).deleteSync(recursive: true);
    }
    staging.renameSync(pkgDir);
    return pkgDir;
  } finally {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  }
}

Future<void> _gitCheckoutRef(String url, String ref, String dest) async {
  final isCommit = RegExp(r'^[0-9a-fA-F]{7,40}$').hasMatch(ref);
  if (!isCommit) {
    final clone = await Process.run('git', [
      'clone',
      '--depth',
      '1',
      '--branch',
      ref,
      url,
      dest,
    ]);
    if (clone.exitCode == 0) return;
  }

  if (Directory(dest).existsSync()) {
    Directory(dest).deleteSync(recursive: true);
  }
  Directory(dest).createSync(recursive: true);
  final init = await Process.run('git', ['-C', dest, 'init']);
  if (init.exitCode != 0) {
    throw ProcessException('git', ['init'], '${init.stderr}'.trim(), init.exitCode);
  }
  await Process.run('git', ['-C', dest, 'remote', 'add', 'origin', url]);
  final fetch = await Process.run('git', [
    '-C',
    dest,
    'fetch',
    '--depth',
    '1',
    'origin',
    ref,
  ]);
  if (fetch.exitCode != 0) {
    throw ProcessException(
      'git',
      ['fetch', 'origin', ref],
      '${fetch.stderr}'.trim().isEmpty
          ? 'git fetch failed for `$ref`'
          : '${fetch.stderr}'.trim(),
      fetch.exitCode,
    );
  }
  final co = await Process.run('git', [
    '-C',
    dest,
    'checkout',
    'FETCH_HEAD',
  ]);
  if (co.exitCode != 0) {
    throw ProcessException(
      'git',
      ['checkout', 'FETCH_HEAD'],
      '${co.stderr}'.trim(),
      co.exitCode,
    );
  }
}

/// Prefer `<repo>/*.kl` inside the clone; else root `*.kl`.
String _selectPackageSourceDir(String cloneRoot, String repo) {
  final nested = '$cloneRoot${Platform.pathSeparator}$repo';
  if (_hasKlSources(nested)) return nested;
  if (_hasKlSources(cloneRoot)) return cloneRoot;
  throw FileSystemException(
    'no .kl package sources in clone of `$repo`',
    cloneRoot,
  );
}

bool _hasKlSources(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return false;
  for (final entity in d.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.endsWith('.kl') && !name.endsWith('_test.kl')) return true;
  }
  return false;
}

/// Ensure [remote] is installed per [mod] / [requestedRef] policy.
///
/// Returns `(pkgDir, ref used, modWasUpdated)`.
Future<(String pkgDir, String ref, bool modUpdated)> ensureRemotePackage({
  required RemoteImport remote,
  required KlinMod mod,
  required File modFile,
  String? cacheRoot,
  bool force = false,
}) async {
  var modUpdated = false;
  String ref;
  if (remote.ref != null) {
    ref = remote.ref!;
    if (mod.requires[remote.path] != ref) {
      modUpdated = true;
    }
  } else if (mod.requires.containsKey(remote.path)) {
    ref = mod.requires[remote.path]!;
  } else {
    ref = await resolveLatestRef(remote);
    modUpdated = true;
  }

  final pkgDir = await fetchRemote(
    remote,
    ref: ref,
    cacheRoot: cacheRoot,
    force: force,
  );
  // Write klin.mod only after a successful fetch so a failed get cannot
  // leave a pin that was never installed.
  if (modUpdated || mod.requires[remote.path] != ref) {
    mod.requires[remote.path] = ref;
    saveKlinMod(modFile, mod);
    modUpdated = true;
  }
  return (pkgDir, ref, modUpdated);
}
