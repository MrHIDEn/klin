# Remote import fixture (`osa`)

```sh
# from repo root — writes klin.mod here or in CWD
dart run bin/klin.dart get github/mrhiden/osa@v0.1.0
dart run bin/klin.dart run examples/remote_osa/app.kl
```

Requires network once for `get`. Later `run` uses `$KLIN_CACHE` / `~/.klin` offline.
See [issues/049](../../issues/049-remote-imports.md), [issues/063](../../issues/063-remote-fixture-osa.md).
