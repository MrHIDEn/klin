# 028 — Ergonomic FreeRTOS integration

**Status:** 💭 to consider
**Depends on:** 024, 010, 021, 022?; 026 welcome

Separate from general [024](024-rtos.md) (FFI + "C API client" hypothesis).

## Goal

Ergonomic Klin layer over FreeRTOS on a known port (e.g. Nucleo + F411),
without own scheduler and without hidden allocation.

- thin optional module / examples: task create, delay, queue, mutex, `FromISR`
- entry points: `@[codename("…")]` (010); stack/TCB/queue **explicit**
- vendor FreeRTOS as C alongside; optionally D3 (026) for patterns

## Considerations / thought examples (not spec)

- marking tasks: `@[task]` / `@[rtos]` / `@[task(id=0)]` on plain `fn`,
  **or** convention `main` + `task_N` / `main_N`
- variant for discussion: single `main` (init + start scheduler) + arbitrary task
  names with decorators vs fixed `task_0`…
- bridge to [029](029-async-event-loop.md): event-loop **optional** on `main`
  and/or on selected tasks

## `klin_freertos` library vs task "decorators" (settled)

Package: [`github.com/MrHIDEn/klin_freertos`](https://github.com/MrHIDEn/klin_freertos)
(portable FreeRTOS C API client — not STM32-only; board HAL stays in `machine_*`).

Question: can external Klin lib (RTOS bindings, not stdlib — [024](024-rtos.md))
provide decorators to mark fn/methods as tasks?

**Attributes (`@[…]`) are handled by the compiler**,
not a `.kl` package. The library alone **cannot** add real `@[task]` if the frontend
does not know it (cf. ISR: [030](030-isr-decorators.md)).

What the lib **can** (without core magic):

| Mechanism | Realism |
|---|---|
| API + fn-pointer: `rtos.create(blink_task, stack[:], prio)` | yes |
| `$…` macros (026) generating entry + registration ("decorator-like") | yes |
| `@[codename("…")]` on entry (like 010) | yes — already in language |
| Real `@[task(stack=…, prio=…)]` in checker/emit | only with compiler support or macro expand to known code |

**Methods as tasks:** FreeRTOS usually wants `void task(void*)` (C prototype), not
a method on `self`. Sensible: free `fn` + context in `arg`, optionally macro
generating wrapper. Magic `fn (mut app: App) run()` as task without wrapper
ABI — weak.

Prime rule: decorator / macro **does not** hide TCB/stack allocation or
scheduler start — stack/TCB/prio stay explicit.

### Preferred ergonomics direction: macro in lib (not user-`@[…]`)

Goal "lib simplifies app" is OK. Open decorators like Python/TS
(`@[moj]` defined in lib) — **no**: attributes are compiler allowlist;
wrapping fn at runtime does not fit C model / prime rule.

Tool in Klin: **`$…` macros ([026](026-preprocessor.md))** or explicit API.
Preferred syntax sketch (directional — not implementation spec):

```klin
$rtos_task("blink", 512, 2) {
    // task body — expand → fn + codename + registration / table
}
```

Equivalently, without macro (still simple, zero magic):

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

`@[task(…)]` in compiler — only when same pattern recurs in many libs
and we want one attribute syntax; by default **do not** build general
user-decorator system. Cf. ISR: [030](030-isr-decorators.md).

Sugar comparison (same effect underneath: fn + stack + registration):

| | `$rtos_task` (lib / 026) | `@[meta("rtos.task", …)]` | `@[task(…)]` |
|---|---|---|---|
| Works without new core attribute | yes | no (hook / plugin) | no (allowlist) |
| Syntax "like decorator" | medium (`$` + block) | closer to TS/Python | closer to TS/Python |
| stack/prio params explicit | yes | yes | yes |
| Lib without compiler fork | yes | weak | no |

`@[meta]` sketch (hypothetical — **not** in language today):

```klin
@[meta("rtos.task", stack=512, prio=2)]
fn blink(arg: *mut u8) { … }
```

Or string form: `@[meta("rtos.task:stack=512,prio=2")]`. Who reads `meta`?
Either macro/scanner in lib, or compiler with hook — almost a plugin system.
Hence preferred `$rtos_task`, not general user-`@[…]`.

Event-loop in task: same macro approach — [029](029-async-event-loop.md)
(`$event_loop`, nestable in `$rtos_task`).

## Mutexes / shared data (critical)

- multiple tasks + shared state = races, torn reads, deadlocks, priority
  inversion — **serious crises**, not edge case
- Klin **does not** hide synchronization: no magical "async-safe" or
  automatic locks on globals
- variants: explicit FFI `xSemaphoreTake` / thin `@[mutex]` + `lock`/`unlock`
  with visible cost; `FromISR` separately
- event-loop **does not replace** mutex between tasks
- eventual checker later (global mutated from >1 task without critical section)
  — idea only
- prime rule: mutex = RTOS call / explicit section

## Criteria

`examples/stm32/freertos_blink/` — ≥2 tasks, delay, LED; no overhead vs C+FreeRTOS.
