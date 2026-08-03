# 029 — Event loop / `async`·`await` (big beast)

**Status:** 🔨 lib published (`github/klin-lang/eventloop@v0.2.0` — callbacks +
`sleep_ms`/`spawn`); phase 4 **async/await MVP in core** ✅; phase 3 RTOS
examples ✅ (emit-c sketches); `$event_loop` / IDE keywords / board blink still open
**Depends on:** D1/D3 decisions; probably 018, 026, 028; remote lib → 049

## Question

Can (and how) we have JS/Rust-style convenience — event loop + optionally
`async`/`await` — **without** hidden allocation / hidden runtime that breaks
the prime rule.

This is a **big beast**: not one PR. Lib with callbacks first; `async`/`await`
in the language only when lib and executor model are clear.

Related: [018](018-generators-yield.md), [024](024-rtos.md), [028](028-freertos.md).

## Layer model (full flexibility, not forced)

1. **`main` only** — bare metal / manual loop / WFI; no event-loop and no RTOS
2. **`main` + event-loop** — one optional loop in `main` (macro / lib API),
   without RTOS
3. **`main` + RTOS tasks + event-loops where we want** — macro/API on `main`
   and/or on selected task; loop only where we set it up.
   Not "one global Node-loop for entire firmware".

## Shared data vs loop

Single-threaded event-loop in one task can serialize work *in that*
task; **does not** protect from another task / ISR — there still mutex / queue /
critical section from [028](028-freertos.md). `await` is not a default lock.

## Summary: what is library, what is core

Unlike RTOS ([024](024-rtos.md), where engine is always C library),
event loop splits into two parts with different status:

1. **Loop mechanism** (loop + task/timer queue, poll → run ready →
   WFI) — **library** and **can be written in Klin** (cooperative loop
   is zero-cost, no hidden runtime). Variant without allocation (static
   buffers) like `slice`; variant with heap queue separately, with explicit
   `Allocator` (like `slice_alloc`, layer 2). Not vendor-specific, so
   can be optional stdlib module (012 style) **or** external library
   (remote import [049](049-remote-imports.md)).
2. **Sugar `async`/`await` (and generators)** — **core feature**
   (parser/emit, desugar to explicit state machine, hypothesis B below), cannot
   be delivered as `.kl`. Tied to [018](018-generators-yield.md) and
   D1/D3 decision. Sugar assuming loop on `main`/task: **lib macros** (like
   `$rtos_task` in [028](028-freertos.md)), not user-`@[…]` or mandatory
   core attribute.

Conclusion: loop runtime alone → library (best in Klin); `async`/`await` →
core, if at all. "Rather as library" applies only to point 1.

## Preferred sugar: `$event_loop` (lib macro)

Same direction as `$rtos_task` in 028 — ergonomics in library, explicit expand,
no hidden scheduler / queue allocation.

### `main` only + loop (no RTOS)

```klin
$event_loop() {
    fn main() {
        // init; register timers / fd / IRQ → queue
    }
    fn on_tick() { … }
}
```

Or tighter (body ≈ setup + run):

```klin
$event_loop() {
    eloop.every_ms(100, on_tick)
    // expand → main with while { eloop.poll(); wfi() } / explicit run()
}
```

### With RTOS — loop only on selected task

```klin
$rtos_task("net", 1024, 3) {
    $event_loop() {
        eloop.on(sock_readable, handle_pkt)
    }
}

$rtos_task("blink", 512, 2) {
    // no loop — delay / toggle
}
```

| | `$event_loop` (lib / 026) | `async` / `await` |
|---|---|---|
| Poll loop + queue + WFI | yes | — |
| Explicit buffers / `Allocator` | yes | — |
| Sugar `await foo()` | no | core feature (018 / here) |

Minimal picture after expand (idea):

```klin
fn main() {
    eloop.init(queue_buf[:])
    eloop.every_ms(100, on_tick)
    eloop.run()   // while { poll(); } — explicit, in lib
}
```

Comparison `$…` vs `@[meta]` / `@[task]`: table in [028](028-freertos.md).

Callback runs **inside** `run()` (when timer/event is due),
not on the `every_ms` line. `every_ms` only registers fn-pointer. In this model
**there is no** `async`/`await` — cooperative loop + plain `fn` only.

## Verdict: lib vs core vs Promise (directionally settled)

### Event loop — part of Klin or user?

**Loop = optional library, not language feature.**

| | Where |
|---|---|
| `eloop.init` / `every_ms` / `run` / queue | lib (optional stdlib *or* user package / [049](049-remote-imports.md)) |
| `$event_loop { … }` | macro in that lib |
| Mandatory loop in every program | **no** |

User **can write own** implementation (different poll, WFI, host `select`).
Official lib (when it exists) is default simple variant — [012](012-stdlib-io.md) style,
not GC-like runtime.

### `async` / `await` — part of Klin?

**If at all — core feature** (parser + emit → state machine). Lib alone
cannot add real `await`.

**Not required** for event-loop. Lib with callbacks first; `async`/`await`
is separate, late decision (also [018](018-generators-yield.md)).

```
optional:  [ lib eloop ]     ← no language change
later?:     [ async/await ]   ← compiler only
```

### Does `async`/`await` require Promise/Future (like JS)?

**No.** Sensible model for Klin (closer to Rust / desugar, not Node):

- `async fn` → compiler makes **state struct** + `poll` / resume (or switch),
- `await` → save state, return to loop, resume later,
- executor = **explicit** loop (`eloop.run` / RTOS task) — no hidden runtime,
- **no** heap `Promise` per method / no GC microtasks.

Methods can be `async`, but that does not mean "every method returns Promise".
Result is plain type / `!T` + state machine; state on stack / in caller buffer,
not magical Future in runtime.

| JS model | Model closer to Klin |
|---|---|
| `Promise` on heap | state on stack / in caller buffer |
| default runtime event loop | `eloop.run()` / task — explicit |
| every async method = Promise | desugar → state machine |

RTOS tasks / event-loop ticks **do not** require turning methods into Promise/Future —
plain `fn` suffice (+ optional `$rtos_task` / `$event_loop`).

### Single-file sketch: `async`/`await` (Rust style) + remote lib

**Runnable** (phase 4 MVP): after `klin get github/klin-lang/eventloop@v0.2.0`,
[`examples/remote_eventloop/async_app.kl`](../examples/remote_eventloop/async_app.kl)
or [`examples/sketch_async_eventloop.kl`](../examples/sketch_async_eventloop.kl).

```klin
/// Rust-like state machine + explicit executor (no JS Promise).

import "github/klin-lang/eventloop"
import io

async fn delay_ms(ms: i64) {
    eventloop.sleep_ms(ms).await
}

async fn ticker() {
    let mut n: i32 = 0
    while n < 3 {
        io.println("tick")
        n = n + 1
        delay_ms(50).await
    }
}

fn main() {
    let mut ex: eventloop.Executor
    let _ = eventloop.init(&ex) or { 1 }
    let _ = eventloop.spawn(&ex, ticker) or { 1 }  // task slot, not Promise
    eventloop.run(&ex)             // poll timers + async tasks
}
```

What happens where:

| Fragment | Role |
|---|---|
| `async fn ticker` | core sugar → state struct + `poll` (like Rust) |
| `delay_ms(50).await` | suspend `ticker`, return to executor |
| `eventloop.Executor` / `run` | **library** — explicit loop |
| task slot `state: [256]u8` | fixed buffer in `Executor` — zero hidden malloc |

### Alongside: same effect **without** `async`/`await` (works today)

Compiler **does not** need to know `async`. Lib + plain `fn` (fn-pointer) suffice.
Remote package: [`github/klin-lang/eventloop@v0.2.0`](https://github.com/klin-lang/eventloop)
(still has v0.1 callbacks); consumer:
[`examples/remote_eventloop/app.kl`](../examples/remote_eventloop/app.kl).

```klin
import "github/klin-lang/eventloop"
import io

struct App {
    ticks: i32
    ex: *mut u8
}

fn on_tick(ctx: *mut u8) {
    let app = cast(*mut App, ctx)
    (*app).ticks = (*app).ticks + 1
    io.println("tick")
    if (*app).ticks >= 3 {
        eventloop.stop(cast(*mut eventloop.Executor, (*app).ex))
    }
}

fn main() {
    let mut ex: eventloop.Executor
    let mut app = App{ ticks: 0, ex: cast(*mut u8, &ex) }
    let _ = eventloop.init(&ex) or { 1 }
    let _ = eventloop.every_ms(&ex, 100, on_tick, cast(*mut u8, &app)) or { 0 }
    eventloop.run(&ex)
}
```

Notes vs early sketch: Klin has no globals/closures → callback is
`fn(*mut u8): void` + `ctx`; slices are primitive-element only → 16 slots
live inside `Executor` (not a caller `[]u8` buffer); public API is free
functions on `*mut Executor` (nested mut methods double the pointer in emit).

| | Without async (lib MVP) | With async sketch |
|---|---|---|
| Words `async` / `await` | no | yes |
| Lib API | `every_ms` + `run` | `spawn` + `run` (+ `sleep_ms`) |
| Where "tick" | `on_tick(ctx)` from inside `run()` | `ticker` body after `.await` |
| Klin language change | no | yes |

**Both columns** — implemented: Klin async MVP +
[`github/klin-lang/eventloop@v0.2.0`](https://github.com/klin-lang/eventloop).

### `async`/`await` syntax (phase 4) — Rust style, not JS

- `async` on **function**: `async fn ticker() { … }`
- `await` is **postfix** at end of expression: `delay_ms(100).await`
- **not** JS style: `await delay_ms(100)`

```klin
// Rust-style (MVP):
delay_ms(100).await

// NOT JS:
// await delay_ms(100)
```

### State today in compiler / IDE

| | Current Klin |
|---|---|
| Phase 4 **spec** (contract below) | **yes** |
| Parser `async` / `.await` | **yes** (MVP) |
| Desugar → state machine | **yes** (MVP: top-level void `async fn`) |
| Callback + async lib | **yes** — [`klin-lang/eventloop@v0.2.0`](https://github.com/klin-lang/eventloop) |
| Example (callbacks) | [`examples/remote_eventloop/app.kl`](../examples/remote_eventloop/app.kl) |
| Example (async) | [`examples/remote_eventloop/async_app.kl`](../examples/remote_eventloop/async_app.kl) |
| IDE keywords | **no** — still open |

IntelliJ plugin (highlight / parser) should learn `async` / `.await` after this
lands on `main` — not via an "eventloop plugin".

### Multiple loops: RTOS tasks and CPU cores (SMP)

Approach with explicit `Executor` / `run()` **enables** separate loops — that is
layer 3 goal, not accident.

On RTOS tasks ([028](028-freertos.md)):

```klin
$rtos_task("net", 1024, 3) {
    let mut buf_net: [64]u8
    let mut ex = eventloop.Executor{}
    ex.init(buf_net[:])
    ex.every_ms(10, on_net)
    ex.run()    // only in "net" task
}

$rtos_task("blink", 512, 2) {
    // no event-loop
}
```

On cores (SMP) — same pattern: **one executor per core / thread**,
separate queue buffer; not one hidden system loop.

```klin
// core 0
ex0.init(buf0[:]); ex0.run()
// core 1
ex1.init(buf1[:]); ex1.run()
```

Shared data between tasks/cores → still explicit mutex / RTOS queue
([028](028-freertos.md)). `await` **is not** a lock between cores.

Avoid: one global Node-loop for entire firmware.

### Phase 4 spec — `async` / `await` (implementation contract)

Direction was already Rust-like (above). This section locks the **first
implementation contract** so the Klin compiler and `eventloop@v0.2` do not
diverge. No Promise / GC / hidden scheduler.

#### 1. Awaitable = convention + core desugar (not a grammar-level `Poll` enum)

- In an `async fn`, `expr.await` means: drive `expr` through a `poll` step
  inside the generated state machine.
- Poll outcome (MVP): **Pending** (suspend; return to executor) or **Ready**
  (continue). Represented as a small tag/`i32` in emitted C / lib helpers —
  not a new user-facing enum feature in the grammar for the first PR.
- There is **no** heap `Promise`, no microtask queue, no built-in Future GC type.

#### 2. State machine storage = executor task slot (no hidden malloc)

- `async fn ticker` lowers to roughly:
  - `struct ticker_State { /* live locals */ stage: i32 }`
  - `ticker_poll(st: *mut ticker_State): i32` — `0` = Pending, `1` = Ready/done
    (exact names are emit details; behavior is fixed).
- `spawn` places that state in a **fixed task slot** inside `Executor`
  (separate from the v0.1 timer callback slots; explicit capacity / overflow
  → `error` like a full timer queue).
- Zero `malloc` inside the lib for task state. Caller still owns the
  `Executor` value (stack / static).

#### 3. `eventloop` v0.2 API (alongside existing callbacks)

Keep v0.1: `init` / `every_ms` / `once_ms` / `cancel` / `stop` / `run`.

Add for async:

| API | Role |
|---|---|
| `sleep_ms(ms)` | returns an awaitable timer future; `poll` → Pending until deadline, then Ready |
| `spawn(…)` | register an async state machine in a task slot (user writes `spawn(ticker)`; emit lowers to `poll` fn + state storage) |
| `run` (extended) | due timer callbacks **and** `poll` of active async tasks until idle / `stop` |

Async does **not** replace callbacks; both coexist in one `run()`.

#### 4. Core vs lib boundary

| Klin core | `eventloop` lib |
|---|---|
| `async fn`, postfix `.await` | `sleep_ms`, `spawn`, queues, `run` |
| desugar → `State` + `poll` | wake on deadline; invoke `poll` |
| checker: `await` only inside `async fn` | no async syntax |

Not in core: global default loop, auto-async `main`, Promise, hidden scheduler.

#### 5. Hard no for the first async PR (scope cap)

- Top-level `async fn` only — **no** async methods on structs yet.
- Body MVP: `let`, `if` / `while`, calls, `.await`, `return`.
- Async result MVP: **void** (sketch `ticker`); `!T` / value-returning async later.
- No recursive async; no `yield` ([018](018-generators-yield.md) separate).
- IDE keyword highlight only after syntax lands on `main`.

#### Success criterion

`klin run` on an updated
[`examples/sketch_async_eventloop.kl`](../examples/sketch_async_eventloop.kl)
(against `github/klin-lang/eventloop@v0.2.x`) prints ticks via `async` /
`.await` + explicit `run()`, with readable `#line` state-machine `.c`.

### Phases (so roadmap is not eaten)

1. **Docs / model** (this issue) — ✅ direction written  
2. **Callback lib** (`every_ms` / `run`) — ✅ `github/klin-lang/eventloop@v0.1.0`  
3. **RTOS example** — loop in one task, second without — ✅ emit-c sketches  
   [`examples/freertos_eventloop/`](../examples/freertos_eventloop/) (callbacks) +  
   [`examples/freertos_eventloop_async/`](../examples/freertos_eventloop_async/) (`async`/`spawn`).  
   Real kernel / board blink still [028](028-freertos.md).  
4. **`async`/`await` in core** + lib `sleep_ms`/`spawn` — ✅ MVP
   (`github/klin-lang/eventloop@v0.2.0` + runnable examples). IDE keywords still open.

Steps 2–3 do not wait for async. Step 4 MVP landed; IDE follow.

## Technical hypotheses (aligned with phase 4 spec)

- **A)** optional lib executor + explicit task slots (no hidden `Allocator` in MVP async)
- **B)** desugar to explicit state machine in `.c` (core)
- **C)** sugar over FreeRTOS (028) later — not "Node on MCU"

Entry points (variants from 028): `main` + decorated `fn` **or** `main_N` / `task_N`.

## What not to do at start

Promise GC, hidden scheduler, async as default bare-metal, **forcing**
loop on every task, hidden automatic mutexes, forcing Promise/Future
on methods like JS.
