# eventloop

Cooperative timer + async-task executor for
[Klin](https://github.com/MrHIDEn/klin) (issue 029).

No heap `Promise`, no hidden malloc, no hidden scheduler. Callbacks and
`async fn` state machines share one explicit `run()`.

## Install

```sh
klin get github/mrhiden/eventloop@v0.2.0
```

```klin
import "github/mrhiden/eventloop"
```

## Callback example (v0.1 API)

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

## Async example (v0.2 — needs Klin with `async` / `.await`)

```klin
import "github/mrhiden/eventloop"
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
    let _ = eventloop.spawn(&ex, ticker) or { 1 }
    eventloop.run(&ex)
}
```

## API

| Function | Role |
|---|---|
| `version(): i32` | package version (`2` for v0.2.0) |
| `init(ex): !i32` | reset 16 timer slots + 8 task slots |
| `every_ms` / `once_ms` / `cancel` / `stop` | v0.1 callback timers |
| `sleep_ms(ms): SleepFuture` | awaitable deadline (`poll` → 0/1) |
| `spawn(ex, poll, init): !i32` | task slot; Klin sugar `spawn(&ex, async_fn)` |
| `run(ex)` | due callbacks **and** `poll` of async tasks |

- Timer capacity: 16 slots. Task capacity: 8 × 256-byte state buffers.
- Host idle: busy-wait on `time.mono()` (no `nanosleep` yet).
- Not for freestanding MCU without host `time`.

## Layout

```text
eventloop/
  version.kl
  executor.kl
  executor_test.kl   # klin test (skipped on import)
```
