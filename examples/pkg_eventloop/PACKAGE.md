# eventloop

Cooperative timer executor for [Klin](https://github.com/MrHIDEn/klin) (issue 029 MVP).

> **Publish:** copy this file to `README.md` at the root of
> [MrHIDEn/eventloop](https://github.com/MrHIDEn/eventloop) together with
> `LICENSE` and the `eventloop/` directory from
> [`examples/pkg_eventloop/`](./) in the Klin repo, then tag `v0.1.0`.

No `async`/`await`, no hidden malloc, no hidden scheduler. You register
callbacks, then call `run()` explicitly.

## Install

```sh
klin get github/mrhiden/eventloop@v0.1.0
```

```klin
import "github/mrhiden/eventloop"
```

## Example

```klin
import "github/mrhiden/eventloop"
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

## API

| Function | Role |
|---|---|
| `version(): i32` | package version (`1` for v0.1.0) |
| `init(ex): !i32` | reset 16 timer slots |
| `every_ms(ex, ms, cb, ctx): !i32` | repeating timer → slot id |
| `once_ms(ex, ms, cb, ctx): !i32` | one-shot timer → slot id |
| `cancel(ex, id)` | deactivate a slot |
| `stop(ex)` | end `run()` (ok from a callback) |
| `run(ex)` | poll deadlines → invoke ready callbacks |

- Callback type: `fn(*mut u8): void` — explicit `ctx` (Klin has no closures / globals).
- Capacity: 16 slots embedded in `Executor` (Klin slices are primitive-element only).
- Host idle: busy-wait on `time.mono()` (no `nanosleep` yet).
- Not for freestanding MCU without host `time`.

## Layout

```text
eventloop/
  version.kl
  executor.kl
  executor_test.kl   # klin test (skipped on import)
```

## Out of scope (later)

- `async` / `.await` in the Klin compiler
- `$event_loop` macro
- MCU WFI / SysTick idle
- `poll` / `select` I/O
- heap queue via `Allocator`
