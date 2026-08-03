# FreeRTOS + `$rtos_task` + `$event_loop`

Same layer-3 layout as [`../freertos_eventloop/`](../freertos_eventloop/) /
[`../freertos_eventloop_async/`](../freertos_eventloop_async/), but the `net`
task uses `$event_loop(ex) { … }` instead of hand-written `init` / `run`.

## What

| File | Role |
|---|---|
| `app.kl` | `$rtos_task(net)` → `$event_loop` + `every_ms` callbacks |
| `async_app.kl` | `$rtos_task(net)` → `$event_loop` + `spawn` / `async` |
| `$rtos_task(idle_work, …)` | Only `freertos.task_delay` — no executor |
| `main` | `start_*()` then `task_start_scheduler()` |

## Why

Shows nesting from issue [029](../../issues/029-async-event-loop.md): loop only
on the task that asks for it. Manual API siblings stay in
[`../freertos_eventloop/`](../freertos_eventloop/) and
[`../freertos_eventloop_async/`](../freertos_eventloop_async/).

## Prerequisites

```sh
# from this directory (klin.mod pins freertos @v0.2.0 + eventloop @v0.3.0)
dart run ../../bin/klin.dart update
```

## How

Stub headers under `freertos_stubs/` stand in for a real kernel (emit / compile
check only).

```sh
dart run ../../bin/klin.dart --emit-pp app.kl
dart run ../../bin/klin.dart --emit-c app.kl
dart run ../../bin/klin.dart --emit-pp async_app.kl
make -C .
```

**Not** a host `klin run` demo without a real FreeRTOS kernel.

## Links

- Issues: [028](../../issues/028-freertos.md), [029](../../issues/029-async-event-loop.md)
- Packages: [klin_freertos](https://github.com/klin-lang/klin_freertos), [eventloop](https://github.com/klin-lang/eventloop) (`$event_loop` @v0.3.0)
- Host + `$event_loop`: [`../remote_eventloop_macro/`](../remote_eventloop_macro/)
- Manual FreeRTOS + callbacks: [`../freertos_eventloop/`](../freertos_eventloop/)
- Manual FreeRTOS + async: [`../freertos_eventloop_async/`](../freertos_eventloop_async/)
