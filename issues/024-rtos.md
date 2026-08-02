# 024 — RTOS (FreeRTOS / Zephyr / …)

**Status:** 💭 to consider
**Depends on:** 010 (bare metal), 021 (FFI/C), 022 (ASM); not on main queue

## Question

Can Klin sensibly handle **RTOS** (e.g. FreeRTOS, Zephyr,
RT-Thread) — tasks, queues, mutexes, ISR handlers — without breaking the prime
rule (no hidden allocation / magical runtime)?

## Preliminary answer (hypothesis)

**Yes, as a C API client**, not as "Klin-RTOS":

- RTOS stays a C library (`.a` / vendor sources) linked alongside emission
- Klin declares FFI (`xTaskCreate`, `osMutexAcquire`, …) + optionally
  thin wrappers in `.kl`
- handlers / task entry points: `@[codename("…")]` (D4) as in 010
- RTOS stack / heap: **explicit** (static buffers, `configTOTAL_HEAP_SIZE`,
  user allocator) — no hidden `malloc` in the language

What **not** to promise in the core: own scheduler, green threads,
async/await with runtime, GC, or "task" as a hidden language feature.

## Summary: two layers (C engine, bindings as library)

Separate two things:

1. **RTOS engine** — always a C library (vendor `.a` / sources), Klin is
   client via FFI. Never reimplement scheduler/queues/mutexes in
   Klin (would break prime rule: no hidden runtime/allocation).
2. **Klin binding layer** (FFI declarations + thin wrappers + `@[codename]`
   patterns for tasks/ISR) — eventually **separate Klin library**, not
   stdlib module.

Why external library (via remote import [049](049-remote-imports.md),
after [048](048-import-aliases.md)/[047](047-directory-modules.md)/[020](020-biblioteki-klin.md)),
not stdlib:

- RTOS is **vendor/board/config-specific** (port, `FreeRTOSConfig.h`,
  priorities, `configTOTAL_HEAP_SIZE`) — there is no single universal binding for the
  core.
- **Versioning** independent of compiler — bindings keep pace with RTOS/port
  without a new Klin release.
- **Core stays lean/freestanding.** Emit does not remove unused `pub` (as in
  [017](017-collection-methods.md) — `slice_alloc` separate from `slice`), so RTOS
  in stdlib would risk pulling dependencies everywhere.

Consequence: Klin core provides only foundation (FFI/`codename`/link from 010/021/022);
this issue remains **decision + FFI pattern**, and the "official" example
([028](028-freertos.md)) as package/example (eventually repo with remote-import),
not as stdlib module.

## What must come first

| Step | Needed for RTOS |
|---|---|
| 010 | freestanding, `codename`, ISR, link with startup |
| 021 | link `-l` / paths, C signature declarations |
| 022 | alongside RTOS often vendor `.s` / port |
| 007 | pointers / `volatile` — already for registers and callbacks |

## To decide later

- one "official" port (e.g. FreeRTOS on Nucleo) as example in
  `examples/`, or only FFI pattern documentation
- bindings as **external library** (remote import 049), not stdlib module
  — see "Summary" above (resolved)
- ISR vs task: same rules as C (`FromISR`, priorities) — Klin does not
  hide them
- concrete FreeRTOS example described in [028](028-freertos.md), and
  ISR annotations to consider in [030](030-isr-decorators.md)
- task "decorators" from `klinrtos` lib: API/macros/`codename` — yes; real
  `@[task]` only with compiler — settled in [028](028-freertos.md);
  preferred sugar: `$rtos_task("blink", 512, 2) { … }` (not user-`@[…]`)

## Criteria (when this eventually enters work)

- [ ] task + delay + toggle LED on known RTOS, Klin code + link with C port
- [ ] `objdump` / behavior comparable to C version (no "magic" overhead)
