# FreeRTOS + eventloop (`async` / `.await`)

Same RTOS layout as [`../freertos_eventloop/`](../freertos_eventloop/)
(issue [029](../../issues/029-async-event-loop.md) phase 3), but the `net` task
uses **`async fn` + `spawn` / `sleep_ms`** (phase 4 MVP) instead of `every_ms`
callbacks.

## What

| Piece | Role |
|---|---|
| `$rtos_task(net, …)` | `init` → `spawn(ticker)` → `run()`; ticker uses `delay_ms(…).await` |
| `$rtos_task(idle_work, …)` | Only `freertos.task_delay` — no executor |
| `main` | `start_*()` then `task_start_scheduler()` |

Async API matches [`../remote_eventloop/async_app.kl`](../remote_eventloop/async_app.kl),
nested inside a FreeRTOS task. Callback variant:
[`../freertos_eventloop/`](../freertos_eventloop/).

## Why

`async` / `.await` is sugar over the same cooperative executor — still **no**
hidden global Node loop. Putting `run()` in one `$rtos_task` keeps the loop
scoped; other tasks stay plain FreeRTOS code ([029](../../issues/029-async-event-loop.md)
layer 3). Cross-task shared data still needs mutex/queue
([028](../../issues/028-freertos.md)); `await` is not a lock.

## Prerequisites

```sh
# from repo root
dart run bin/klin.dart get github/klin-lang/klin_freertos@v0.2.0
dart run bin/klin.dart get github/klin-lang/eventloop@v0.2.0
```

## How

Stub headers under `freertos_stubs/` are for emit / compile checks only.

```sh
dart run bin/klin.dart --emit-pp examples/freertos_eventloop_async/app.kl
dart run bin/klin.dart --emit-c examples/freertos_eventloop_async/app.kl
make -C examples/freertos_eventloop_async
```

**Not** a host `klin run` demo without a real FreeRTOS kernel. Board LED demo:
[028](../../issues/028-freertos.md).

### Wiring a real FreeRTOS

Same as the callback sibling: replace stubs with real includes, link the kernel
([klin_freertos](https://github.com/klin-lang/klin_freertos) contract).

## Links

- Issues: [024](../../issues/024-rtos.md), [028](../../issues/028-freertos.md), [029](../../issues/029-async-event-loop.md)
- Packages: [klin_freertos](https://github.com/klin-lang/klin_freertos), [eventloop](https://github.com/klin-lang/eventloop)
- Sibling (callbacks): [`../freertos_eventloop/`](../freertos_eventloop/)
