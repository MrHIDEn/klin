import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

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

String? readCommit(String pkgDir) {
  final f = File('$pkgDir${Platform.pathSeparator}.commit');
  if (!f.existsSync()) return null;
  final text = f.readAsStringSync().trim().toLowerCase();
  if (text.isEmpty || !RegExp(r'^[0-9a-f]{7,40}$').hasMatch(text)) {
    return null;
  }
  return text;
}

void writeCommit(String pkgDir, String commit) {
  Directory(pkgDir).createSync(recursive: true);
  File('$pkgDir${Platform.pathSeparator}.commit')
      .writeAsStringSync('${commit.toLowerCase()}\n');
}

/// SHA-256 of installed package `.kl` sources (sorted by basename).
///
/// Format is stable: for each file, `name\0` + bytes + `\0`.
String packageContentHash(String pkgDir) {
  final files = <File>[];
  for (final entity in Directory(pkgDir).listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (!name.endsWith('.kl') || name.endsWith('_test.kl')) continue;
    files.add(entity);
  }
  files.sort((a, b) {
    final an = a.path.split(Platform.pathSeparator).last;
    final bn = b.path.split(Platform.pathSeparator).last;
    return an.compareTo(bn);
  });
  final bytes = BytesBuilder(copy: false);
  for (final f in files) {
    final name = f.path.split(Platform.pathSeparator).last;
    bytes.add(utf8.encode(name));
    bytes.addByte(0);
    bytes.add(f.readAsBytesSync());
    bytes.addByte(0);
  }
  return sha256.convert(bytes.takeBytes()).toString();
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

// --- klin.lock (issue 065) --------------------------------------------------

/// One locked remote: mod version pin → resolved commit + content hash.
final class KlinLockEntry {
  final String version;
  final String commit;
  final String hash; // sha256 hex of package .kl sources

  const KlinLockEntry({
    required this.version,
    required this.commit,
    required this.hash,
  });
}

final class KlinLock {
  final int version;
  final Map<String, KlinLockEntry> packages; // path → entry

  KlinLock({this.version = 1, Map<String, KlinLockEntry>? packages})
      : packages = Map<String, KlinLockEntry>.from(packages ?? {});

  static KlinLock empty() => KlinLock();
}

/// `klin.lock` beside [modFile], if present.
File klinLockFileFor(File modFile) =>
    File('${modFile.parent.path}${Platform.pathSeparator}klin.lock');

KlinLock parseKlinLock(String content) {
  final packages = <String, KlinLockEntry>{};
  var version = 1;
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) {
      continue;
    }
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length == 3 && parts[0] == 'klin' && parts[1] == 'lock') {
      version = int.tryParse(parts[2]) ?? 1;
      continue;
    }
    // path version commit sha256:<hex>
    if (parts.length == 4 && parts[3].startsWith('sha256:')) {
      final commit = parts[2].toLowerCase();
      if (!RegExp(r'^[0-9a-f]{7,40}$').hasMatch(commit)) {
        throw FormatException('invalid klin.lock commit: `$rawLine`');
      }
      final hash = parts[3].substring('sha256:'.length);
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        throw FormatException('invalid klin.lock hash: `$rawLine`');
      }
      packages[parts[0]] = KlinLockEntry(
        version: parts[1],
        commit: commit,
        hash: hash,
      );
      continue;
    }
    throw FormatException('invalid klin.lock line: `$rawLine`');
  }
  return KlinLock(version: version, packages: packages);
}

String formatKlinLock(KlinLock lock) {
  final buf = StringBuffer('klin lock ${lock.version}\n');
  final keys = lock.packages.keys.toList()..sort();
  for (final path in keys) {
    final e = lock.packages[path]!;
    buf.writeln('$path ${e.version} ${e.commit} sha256:${e.hash}');
  }
  return buf.toString();
}

KlinLock loadKlinLock(File file) => parseKlinLock(file.readAsStringSync());

void saveKlinLock(File file, KlinLock lock) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(formatKlinLock(lock));
}

KlinLock loadKlinLockOrEmpty(File file) {
  if (!file.existsSync()) return KlinLock.empty();
  return loadKlinLock(file);
}

/// Parse `v1.2.3` / `1.2.3` into `[major, minor, patch]`, else null.
List<int>? parseSemverParts(String ref) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(ref.trim());
  if (m == null) return null;
  return [
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  ];
}

/// Compare two semver refs. Returns negative / zero / positive, or null if
/// either side is not strict `v?X.Y.Z`.
int? compareSemverRefs(String a, String b) {
  final pa = parseSemverParts(a);
  final pb = parseSemverParts(b);
  if (pa == null || pb == null) return null;
  for (var i = 0; i < 3; i++) {
    final c = pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return 0;
}

/// True when [candidate] should replace [current] (`klin upgrade` / outdated).
///
/// Semver pins: only when candidate is greater than current. Otherwise any
/// different latest (branch / non-semver) is treated as an upgrade candidate.
bool isUpgradeTarget(String current, String candidate) {
  if (current == candidate) return false;
  final cmp = compareSemverRefs(current, candidate);
  if (cmp != null) return cmp < 0;
  return true;
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
    final parts = parseSemverParts(tag);
    if (parts == null) continue;
    semver.add((parts, tag));
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

/// One package where [klin.mod] pin is behind remote latest (issue 066).
final class OutdatedPackage {
  final String path;
  final String current;
  final String latest;

  const OutdatedPackage({
    required this.path,
    required this.current,
    required this.latest,
  });
}

typedef LatestRefResolver = Future<String> Function(RemoteImport remote);

/// Compare `klin.mod` requires to remote latest tags/refs.
///
/// [onlyPaths] limits the scan (must already be in [mod.requires]).
Future<List<OutdatedPackage>> collectOutdated(
  KlinMod mod, {
  Iterable<String>? onlyPaths,
  LatestRefResolver resolveLatest = resolveLatestRef,
}) async {
  final paths = <String>[];
  if (onlyPaths == null || onlyPaths.isEmpty) {
    paths.addAll(mod.requires.keys);
  } else {
    for (final raw in onlyPaths) {
      final remote = parseRemoteImport(raw);
      if (remote.ref != null) {
        throw FormatException(
          'outdated/upgrade path must not include @ref (`$raw`)',
        );
      }
      if (!mod.requires.containsKey(remote.path)) {
        throw FormatException('`$remote.path` is not in klin.mod requires');
      }
      paths.add(remote.path);
    }
  }
  paths.sort();

  final out = <OutdatedPackage>[];
  for (final path in paths) {
    final current = mod.requires[path]!;
    final latest = await resolveLatest(parseRemoteImport(path));
    if (isUpgradeTarget(current, latest)) {
      out.add(OutdatedPackage(path: path, current: current, latest: latest));
    }
  }
  return out;
}

String formatOutdatedReport(List<OutdatedPackage> rows) {
  if (rows.isEmpty) return 'all packages up to date\n';
  final buf = StringBuffer();
  for (final row in rows) {
    buf.writeln('${row.path}\t${row.current}\t${row.latest}');
  }
  return buf.toString();
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

/// Whether an installed cache entry can satisfy a fetch without network.
///
/// When [gitRef] looks like a commit SHA (lock prefer-SHA), the cached
/// `.commit` must match — otherwise stale pin+wrong-SHA would skip repair.
bool cacheSatisfiesRemoteFetch({
  required String? cachedPin,
  required String pinValue,
  required String? cachedCommit,
  required String gitRef,
}) {
  if (cachedPin != pinValue || cachedCommit == null) return false;
  if (!RegExp(r'^[0-9a-fA-F]{7,40}$').hasMatch(gitRef)) return true;
  final want = gitRef.toLowerCase();
  final have = cachedCommit.toLowerCase();
  return have.startsWith(want) || want.startsWith(have);
}

/// Fetch [remote] at [gitRef] into the package cache.
///
/// Returns `(pkgDir, commitSha)`. [pin] is written to `.pin` (klin.mod version);
/// defaults to [gitRef]. [force] replaces an existing install.
Future<(String pkgDir, String commit)> fetchRemote(
  RemoteImport remote, {
  required String gitRef,
  String? pin,
  String? cacheRoot,
  bool force = false,
}) async {
  final pinValue = pin ?? gitRef;
  final pkgDir = packageCacheDir(remote, cacheRoot: cacheRoot);
  if (!force && isPackageInstalled(pkgDir)) {
    final existing = readPin(pkgDir);
    if (existing != pinValue) {
      throw StateError(
        'package `${remote.path}` is already installed at `$existing`; '
        'use `klin update ${remote.path}@$pinValue` to change',
      );
    }
    final commit = readCommit(pkgDir);
    if (cacheSatisfiesRemoteFetch(
      cachedPin: existing,
      pinValue: pinValue,
      cachedCommit: commit,
      gitRef: gitRef,
    )) {
      return (pkgDir, commit!);
    }
    // Missing `.commit`, or pin matches but SHA ≠ locked gitRef — re-fetch.
  }

  final tmp = Directory.systemTemp.createTempSync('klin_get_');
  final staging = Directory.systemTemp.createTempSync('klin_stage_');
  try {
    final commit = await _gitCheckoutRef(remote.gitUrl, gitRef, tmp.path);

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
        .writeAsStringSync('$pinValue\n');
    File('${staging.path}${Platform.pathSeparator}.commit')
        .writeAsStringSync('${commit.toLowerCase()}\n');

    final parent = Directory(pkgDir).parent;
    parent.createSync(recursive: true);
    if (Directory(pkgDir).existsSync()) {
      Directory(pkgDir).deleteSync(recursive: true);
    }
    staging.renameSync(pkgDir);
    return (pkgDir, commit.toLowerCase());
  } finally {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  }
}

/// Checkout [ref] into [dest]; returns full commit SHA.
Future<String> _gitCheckoutRef(String url, String ref, String dest) async {
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
    if (clone.exitCode == 0) {
      return _gitRevParseHead(dest);
    }
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
  return _gitRevParseHead(dest);
}

Future<String> _gitRevParseHead(String repo) async {
  final result = await Process.run('git', ['-C', repo, 'rev-parse', 'HEAD']);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      ['rev-parse', 'HEAD'],
      '${result.stderr}'.trim(),
      result.exitCode,
    );
  }
  final sha = '${result.stdout}'.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sha)) {
    throw ProcessException(
      'git',
      ['rev-parse', 'HEAD'],
      'unexpected HEAD sha `$sha`',
    );
  }
  return sha;
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

/// Ensure [remote] is installed per [mod] / lock policy.
///
/// Returns `(pkgDir, version pin, modWasUpdated)`.
/// When [lock] has a matching version entry and [force] is false, fetches by
/// locked commit SHA and verifies the content hash (issue 065).
Future<(String pkgDir, String ref, bool modUpdated)> ensureRemotePackage({
  required RemoteImport remote,
  required KlinMod mod,
  required File modFile,
  KlinLock? lock,
  File? lockFile,
  String? cacheRoot,
  bool force = false,
}) async {
  var modUpdated = false;
  String version;
  if (remote.ref != null) {
    version = remote.ref!;
    if (mod.requires[remote.path] != version) {
      modUpdated = true;
    }
  } else if (mod.requires.containsKey(remote.path)) {
    version = mod.requires[remote.path]!;
  } else {
    version = await resolveLatestRef(remote);
    modUpdated = true;
  }

  final lockEntry = lock?.packages[remote.path];
  final useLock = !force &&
      lockEntry != null &&
      lockEntry.version == version &&
      RegExp(r'^[0-9a-f]{7,40}$').hasMatch(lockEntry.commit);
  final gitRef = useLock ? lockEntry.commit : version;

  final (pkgDir, commit) = await fetchRemote(
    remote,
    gitRef: gitRef,
    pin: version,
    cacheRoot: cacheRoot,
    force: force,
  );

  final hash = packageContentHash(pkgDir);
  if (useLock) {
    if (lockEntry.hash != hash) {
      throw StateError(
        'klin.lock hash mismatch for `${remote.path}@$version` '
        '(expected sha256:${lockEntry.hash}, got sha256:$hash)',
      );
    }
    if (!commit.startsWith(lockEntry.commit) &&
        !lockEntry.commit.startsWith(commit)) {
      throw StateError(
        'klin.lock commit mismatch for `${remote.path}@$version` '
        '(expected ${lockEntry.commit}, got $commit)',
      );
    }
  }

  // Write klin.mod / klin.lock only after a successful fetch so a failed get
  // cannot leave a pin that was never installed.
  if (modUpdated || mod.requires[remote.path] != version) {
    mod.requires[remote.path] = version;
    saveKlinMod(modFile, mod);
    modUpdated = true;
  }

  final outLock = lock ?? KlinLock.empty();
  final prev = outLock.packages[remote.path];
  if (prev == null ||
      prev.version != version ||
      prev.commit != commit ||
      prev.hash != hash) {
    outLock.packages[remote.path] = KlinLockEntry(
      version: version,
      commit: commit,
      hash: hash,
    );
    final outFile = lockFile ?? klinLockFileFor(modFile);
    saveKlinLock(outFile, outLock);
  }
  return (pkgDir, version, modUpdated);
}
