# FreeRTOS + eventloop (callbacks)

Cooperative **eventloop** inside one FreeRTOS task; a second task has **no**
loop — issue [029](../../issues/029-async-event-loop.md) phase 3 (layer 3).

## What

| Piece | Role |
|---|---|
| `$rtos_task(net, …)` | Owns `eventloop.Executor`: `init` → `every_ms` → `run()` |
| `$rtos_task(idle_work, …)` | Only `freertos.task_delay` — no executor |
| `main` | `start_*()` then `task_start_scheduler()` |

Callback style (same API as [`../remote_eventloop/app.kl`](../remote_eventloop/app.kl)).
For `async` / `.await` in a FreeRTOS task, see
[`../freertos_eventloop_async/`](../freertos_eventloop_async/).

## Why

Klin does **not** force a Node-style global loop on the whole firmware.
The eventloop is optional **per task**: put `run()` only where you want it.
FreeRTOS still schedules tasks; the executor serializes work *inside* `net`
only (mutex/queue still needed across tasks / ISRs — [028](../../issues/028-freertos.md)).

## Prerequisites

```sh
# from repo root
dart run bin/klin.dart get github/klin-lang/klin_freertos@v0.2.0
dart run bin/klin.dart get github/klin-lang/eventloop@v0.2.0
```

## How

Stub headers under `freertos_stubs/` stand in for a real kernel (emit / compile
check only — **not** a FreeRTOS port).

```sh
# expand $rtos_task
dart run bin/klin.dart --emit-pp examples/freertos_eventloop/app.kl

# emit C (needs packages in cache + klin.mod)
dart run bin/klin.dart --emit-c examples/freertos_eventloop/app.kl

# optional: compile check against stubs
make -C examples/freertos_eventloop
```

**Not** a host `klin run` demo: linking and running need a real FreeRTOS kernel,
port, `FreeRTOSConfig.h`, and board/host bring-up. Board blink with LED remains
[028](../../issues/028-freertos.md) (`examples/stm32/freertos_blink/` — open).

### Wiring a real FreeRTOS

1. Drop or ignore `freertos_stubs/`.
2. Put FreeRTOS + MCU/host port + `FreeRTOSConfig.h` on `-I`.
3. Link kernel objects / library from your Makefile (same contract as
   [`klin_freertos`](https://github.com/klin-lang/klin_freertos)).

## Links

- Issues: [024](../../issues/024-rtos.md), [028](../../issues/028-freertos.md), [029](../../issues/029-async-event-loop.md)
- Packages: [klin_freertos](https://github.com/klin-lang/klin_freertos), [eventloop](https://github.com/klin-lang/eventloop)
- Sibling (async): [`../freertos_eventloop_async/`](../freertos_eventloop_async/)
