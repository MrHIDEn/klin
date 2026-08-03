# Remote import — `osa` fixture

Fetch and run a tiny remote Klin package used for e2e of `klin get` / lockfile.

## What

`app.kl` does `import "github/klin-lang/osa"` after the package is in the Klin
cache (`klin.mod` / `klin.lock` in this directory pin `v0.1.0`).

## Why

Stable fixture for issues [049](../../issues/049-remote-imports.md) /
[063](../../issues/063-remote-fixture-osa.md) / [065](../../issues/065-project-lockfile.md)
— not part of the compiler stdlib.

## How

```sh
# from repo root (or this directory) — fills cache + lock
dart run bin/klin.dart get github/klin-lang/osa@v0.1.0
dart run bin/klin.dart run examples/remote_osa/app.kl
```

Network once for `get`. Later `run` uses `$KLIN_CACHE` / `~/.klin` offline.
Commit `klin.lock` for reproducible SHAs + content hashes.

## Links

- Package: https://github.com/klin-lang/osa
- [issues/049](../../issues/049-remote-imports.md), [063](../../issues/063-remote-fixture-osa.md), [065](../../issues/065-project-lockfile.md)
