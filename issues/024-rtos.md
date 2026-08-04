# 024 — RTOS (FreeRTOS / Zephyr / …)

**Status:** ✅ settled (pattern); FreeRTOS package shipped; other RTOS deferred
**Depends on:** 010 (bare metal), 021 (FFI/C), 022 (ASM); not on main queue

## Question

Can Klin sensibly handle **RTOS** (e.g. FreeRTOS, Zephyr,
RT-Thread) — tasks, queues, mutexes, ISR handlers — without breaking the prime
rule (no hidden allocation / magical runtime)?

## Answer

**Yes, as a C API client**, not as "Klin-RTOS":

- RTOS stays a C library (`.a` / vendor sources) linked alongside emission
- Klin declares FFI + optionally thin wrappers / `$…` macros in an **external**
  package (not stdlib)
- handlers / task entry points: `@[codename("…")]` (D4) as in 010
- RTOS stack / heap: **explicit** — no hidden `malloc` in the language

What **not** to promise in the core: own scheduler, green threads,
async/await with runtime, GC, or "task" as a hidden language feature.

## Two layers (C engine, bindings as library)

1. **RTOS engine** — always a C library (vendor `.a` / sources), Klin is
   client via FFI. Never reimplement scheduler/queues/mutexes in Klin.
2. **Klin binding layer** — separate Klin library via remote import
   ([049](049-remote-imports.md)), not stdlib (board/port/config-specific;
   independent versioning; core stays lean/freestanding).

## FreeRTOS (done as the reference)

Package: [`github.com/klin-lang/klin_freertos`](https://github.com/klin-lang/klin_freertos)
(`@v0.2.0`: FFI tasks/queues/semaphores + `$rtos_task`).

- Portable FreeRTOS **kernel** API client — not a board HAL
- App supplies FreeRTOS sources, MCU port, `FreeRTOSConfig.h`, heap, startup
- Same Klin module on STM32, Pico/RP, AVR, host POSIX, …
- Ergonomics / blink demo: [028](028-freertos.md)

```klin
import "github/klin-lang/klin_freertos" freertos
```

## Zephyr / RT-Thread — summary (not now)

Same product class as FreeRTOS (MCU RTOS), all open-source / free to use:

| | FreeRTOS | Zephyr | RT-Thread |
|---|---|---|---|
| License | MIT | Apache 2.0 | Apache 2.0 |
| Shape | small kernel + port | larger OS (kernel + drivers + net + DTS) | kernel + rich component ecosystem |
| Typical API | `xTaskCreate`, queues, semaphores | `k_thread_*`, `k_mutex_*`, … | `rt_thread_create`, mailbox, … |
| App build | often Makefile + port `.c` | west / CMake + device tree | SDK / scons or similar |
| Klin binding idea | `klin_freertos` ✅ | future `klin_zephyr` (same FFI pattern) | future `klin_rtthread` |

**Decision for now: do not start Zephyr or RT-Thread packages.**

Reasons:

- FreeRTOS already validates the Klin RTOS model; little new language learning
- Zephyr’s build/DTS world is a larger integration cost than another thin FFI
- No concrete project demand yet; prefer finishing FreeRTOS follow-ups
  (board blink ✅ / static create open — [028](028-freertos.md); `FromISR` ✅ `@v0.3.0` with [030](030-isr-decorators.md))

Revisit when a real app targets Zephyr or RT-Thread — then a **separate**
repo (not stdlib), same “C engine + Klin client” rules as FreeRTOS.

## Prerequisites (foundation — already ✅)

| Step | Needed for RTOS |
|---|---|
| 010 | freestanding, `codename`, ISR, link with startup |
| 021 | link `-l` / paths, C signature declarations |
| 022 | alongside RTOS often vendor `.s` / port |
| 007 | pointers / `volatile` — registers and callbacks |
| 026 / path-import `$fn` | `$rtos_task` / library macros |

## Settled / deferred

- bindings as **external library** (remote import 049), not stdlib — settled
- FreeRTOS reference package — settled ([028](028-freertos.md))
- real `@[task]` in the compiler — no by default; prefer `$rtos_task` in lib
- Zephyr / RT-Thread packages — **deferred** (see above)
- ISR vs task: same rules as C (`FromISR`, priorities) — Klin does not hide them
  ([030](030-isr-decorators.md))

## Criteria

- [x] RTOS as C API client (no Klin scheduler) — validated by `klin_freertos`
- [x] external package + remote import (not stdlib)
- [ ] task + delay + toggle LED on a known board (FreeRTOS) — still [028](028-freertos.md)
- [ ] `objdump` / behavior comparable to C version (no "magic" overhead) — with blink
