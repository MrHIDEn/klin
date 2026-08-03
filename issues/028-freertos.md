# 028 — Ergonomic FreeRTOS integration

**Status:** 🔨 in progress (package + `$rtos_task` ✅; board blink / `FromISR` open)
**Depends on:** 024, 010, 021, 022?; 026 welcome

Separate from general [024](024-rtos.md) (FFI + "C API client" — settled).

## Goal

Ergonomic Klin layer over FreeRTOS on a known port (e.g. Nucleo + F411),
without own scheduler and without hidden allocation.

- thin optional module / examples: task create, delay, queue, mutex, `FromISR`
- entry points: `@[codename("…")]` (010); stack/TCB/queue **explicit**
- vendor FreeRTOS as C alongside; optionally D3 (026) for patterns

## Shipped: `klin_freertos`

Package: [`github.com/MrHIDEn/klin_freertos`](https://github.com/MrHIDEn/klin_freertos)
(portable FreeRTOS C API client — not STM32-only; board HAL stays in `machine_*`).

| Piece | Status |
|---|---|
| FFI: `task_*` / `queue_*` / `semaphore_*` | ✅ `@v0.1.0` |
| `$rtos_task(name, stack, prio) { … }` | ✅ `@v0.2.0` (needs Klin path-import macros + `block`) |
| smoke / emit-c stubs | ✅ |
| Board blink (≥2 tasks + LED) | open |
| Static create / `FromISR` sugar | open ([030](030-isr-decorators.md)) |

```klin
import "github/mrhiden/klin_freertos" freertos

$rtos_task(blink, 512, 2) {
    while true {
        freertos.task_delay(100)
    }
}

fn main() {
    start_blink()
    freertos.task_start_scheduler()
}
```

Equivalently, without macro:

```klin
import "github/mrhiden/klin_freertos" freertos

@[codename("blink_task")]
fn blink_task(arg: *mut void) { … }

fn main() {
    let mut handle = freertos.null_ptr()
    freertos.task_create(blink_task, "blink", 512, freertos.null_ptr(), 2, &handle)
    freertos.task_start_scheduler()
}
```

## `klin_freertos` library vs task "decorators" (settled)

Question: can external Klin lib (RTOS bindings, not stdlib — [024](024-rtos.md))
provide decorators to mark fn/methods as tasks?

**Attributes (`@[…]`) are handled by the compiler**,
not a `.kl` package. The library alone **cannot** add real `@[task]` if the frontend
does not know it (cf. ISR: [030](030-isr-decorators.md)).

What the lib **can** (without core magic):

| Mechanism | Realism |
|---|---|
| API + fn-pointer: `freertos.task_create(…)` | yes ✅ |
| `$…` macros (026) generating entry + registration | yes ✅ `$rtos_task` |
| `@[codename("…")]` on entry (like 010) | yes — already in language |
| Real `@[task(stack=…, prio=…)]` in checker/emit | only with compiler support |

**Methods as tasks:** FreeRTOS usually wants `void task(void*)` (C prototype), not
a method on `self`. Sensible: free `fn` + context in `arg`, optionally macro
generating wrapper.

Prime rule: decorator / macro **does not** hide TCB/stack allocation or
scheduler start — stack/TCB/prio stay explicit.

### Preferred ergonomics: macro in lib (not user-`@[…]`)

Tool in Klin: **`$…` macros ([026](026-preprocessor.md))** or explicit API.
`$rtos_task` is the chosen direction (shipped). Do **not** build a general
user-decorator system. Cf. ISR: [030](030-isr-decorators.md).

Event-loop in task: same macro approach — [029](029-async-event-loop.md)
(`$event_loop`, nestable in `$rtos_task` later).

## Mutexes / shared data (critical)

- multiple tasks + shared state = races, torn reads, deadlocks, priority
  inversion — **serious crises**, not edge case
- Klin **does not** hide synchronization: no magical "async-safe" or
  automatic locks on globals
- variants: explicit FFI `semaphore_take` / thin wrappers with visible cost;
  `FromISR` separately
- event-loop **does not replace** mutex between tasks
- prime rule: mutex = RTOS call / explicit section

## Other RTOS

Zephyr / RT-Thread: same FFI-client pattern possible later as separate packages.
**Not now** — see [024](024-rtos.md) (summary + deferral).

## Criteria

- [x] external package with task / delay / queue / mutex FFI
- [x] `$rtos_task` sugar without hidden alloc
- [ ] `examples/stm32/freertos_blink/` (or Pico) — ≥2 tasks, delay, LED
- [ ] no overhead vs C+FreeRTOS (`objdump` / behavior)
