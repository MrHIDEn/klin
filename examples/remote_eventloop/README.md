# Remote eventloop (`github/klin-lang/eventloop@v0.2.0`)

Host-runnable cooperative executor — callbacks and `async` / `.await`.

## What

| File | API |
|---|---|
| `app.kl` | `every_ms` + callback + `run` |
| `async_app.kl` | `async fn` + `spawn` / `sleep_ms` |

Same async API as [`../sketch_async_eventloop.kl`](../sketch_async_eventloop.kl).

## Why

Issue [029](../../issues/029-async-event-loop.md) layers 1–2: optional eventloop
in `main` **without** RTOS. FreeRTOS nesting (phase 3 sketches):
[`../freertos_eventloop/`](../freertos_eventloop/) and
[`../freertos_eventloop_async/`](../freertos_eventloop_async/).

## How

```sh
# from repo root — writes klin.mod + klin.lock in CWD if missing
dart run bin/klin.dart get github/klin-lang/eventloop@v0.2.0
dart run bin/klin.dart run examples/remote_eventloop/app.kl
dart run bin/klin.dart run examples/remote_eventloop/async_app.kl
```

Network once for `get`. Later `run` uses `$KLIN_CACHE` / `~/.klin`.

## Links

- Package: https://github.com/klin-lang/eventloop
- [issues/029](../../issues/029-async-event-loop.md)
- FreeRTOS + callbacks: [`../freertos_eventloop/`](../freertos_eventloop/)
- FreeRTOS + async: [`../freertos_eventloop_async/`](../freertos_eventloop_async/)
