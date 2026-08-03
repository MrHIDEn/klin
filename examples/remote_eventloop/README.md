# Remote eventloop (`github/mrhiden/eventloop`)

Callback timer executor — issue [029](../../issues/029-async-event-loop.md).
Published pin here is `@v0.1.0` (callbacks). Async `sleep_ms` / `spawn` live in
local [`examples/pkg_eventloop/`](../pkg_eventloop/) until remote `@v0.2.0` is
tagged; see also [`sketch_async_eventloop.kl`](../sketch_async_eventloop.kl).

```sh
# from repo root — writes klin.mod + klin.lock in CWD if missing
dart run bin/klin.dart get github/mrhiden/eventloop@v0.1.0
dart run bin/klin.dart run examples/remote_eventloop/app.kl
```

Requires network once for `get`. Later `run` uses `$KLIN_CACHE` / `~/.klin`.
Package repo: https://github.com/MrHIDEn/eventloop
