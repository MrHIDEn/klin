# Remote import fixture (`osa`)

```sh
# from repo root — writes klin.mod + klin.lock in CWD
dart run bin/klin.dart get github/klin-lang/osa@v0.1.0
dart run bin/klin.dart run examples/remote_osa/app.kl
```

Requires network once for `get`. Later `run` uses `$KLIN_CACHE` / `~/.klin` offline.
Commit `klin.lock` for reproducible `get` (SHA + content hash).
See [issues/049](../../issues/049-remote-imports.md), [issues/065](../../issues/065-project-lockfile.md),
[issues/063](../../issues/063-remote-fixture-osa.md).
