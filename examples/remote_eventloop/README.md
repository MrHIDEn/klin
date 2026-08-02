# Remote eventloop (`github/mrhiden/eventloop`)

Callback timer executor — issue [029](../../issues/029-async-event-loop.md) MVP
(no `async`/`await`).

```sh
# from repo root — writes klin.mod + klin.lock in CWD if missing
dart run bin/klin.dart get github/mrhiden/eventloop@v0.1.0
dart run bin/klin.dart run examples/remote_eventloop/app.kl
```

Requires network once for `get`. Later `run` uses `$KLIN_CACHE` / `~/.klin`.
Package repo: https://github.com/MrHIDEn/eventloop
