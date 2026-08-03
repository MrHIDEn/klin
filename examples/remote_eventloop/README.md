# Remote eventloop (`github/klin-lang/eventloop@v0.2.0`)

Cooperative executor — issue [029](../../issues/029-async-event-loop.md):
callback timers **and** `async` / `.await` (`sleep_ms` + `spawn`).

```sh
# from repo root — writes klin.mod + klin.lock in CWD if missing
dart run bin/klin.dart get github/klin-lang/eventloop@v0.2.0
dart run bin/klin.dart run examples/remote_eventloop/app.kl
dart run bin/klin.dart run examples/remote_eventloop/async_app.kl
```

| File | API |
|---|---|
| `app.kl` | v0.1-style `every_ms` + callback |
| `async_app.kl` | `async fn` + `spawn` / `sleep_ms` |

Also: [`../sketch_async_eventloop.kl`](../sketch_async_eventloop.kl) (same async API).

Requires network once for `get`. Later `run` uses `$KLIN_CACHE` / `~/.klin`.
Package: https://github.com/klin-lang/eventloop
