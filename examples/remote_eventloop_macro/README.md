# Remote eventloop + `$event_loop` (`@v0.3.0`)

Same host demos as [`../remote_eventloop/`](../remote_eventloop/), but setup
uses the library macro `$event_loop(ex) { … }` instead of hand-written
`init` / `run`.

## What

| File | API |
|---|---|
| `app.kl` | `$event_loop` + `every_ms` callback |
| `async_app.kl` | `$event_loop` + `async fn` / `spawn` / `sleep_ms` |

Expand shape: `let mut ex` → `init` (return on fail) → body → `run(&ex)`.

## Why

Issue [029](../../issues/029-async-event-loop.md): sugar in the library (like
`$rtos_task`), explicit in `--emit-pp`, no hidden scheduler. Keep the manual
API examples beside these so both styles stay visible.

## How

```sh
# from this directory (klin.mod pins @v0.3.0)
dart run ../../bin/klin.dart run app.kl
dart run ../../bin/klin.dart run async_app.kl
dart run ../../bin/klin.dart --emit-pp app.kl
```

From repo root, if cache is empty:

```sh
cd examples/remote_eventloop_macro
dart run ../../bin/klin.dart update
```

## Links

- Package: https://github.com/klin-lang/eventloop (`$event_loop` since v0.3.0)
- Manual API: [`../remote_eventloop/`](../remote_eventloop/)
- FreeRTOS + `$event_loop`: [`../freertos_eventloop_macro/`](../freertos_eventloop_macro/)
- [issues/029](../../issues/029-async-event-loop.md)
