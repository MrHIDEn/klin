# Event loop package (issue 029 MVP)

Local directory package — cooperative timers with explicit `run()`, no
`async`/`await`. Same sources are meant for remote
`github/mrhiden/eventloop` (see [PACKAGE.md](PACKAGE.md)).

```text
examples/pkg_eventloop/
  app.kl                 # ticker demo (stops after 3 ticks)
  PACKAGE.md             # package README for the remote repo
  eventloop/
    version.kl
    executor.kl
    executor_test.kl     # skipped on import; used by `klin test`
```

```sh
cd examples/pkg_eventloop
dart run ../../bin/klin.dart run app.kl
# → tick / tick / tick / ticks=3 version=1

dart run ../../bin/klin.dart test eventloop
```

API: `init` / `every_ms` / `once_ms` / `cancel` / `stop` / `run` — callbacks are
`fn(*mut u8): void` with explicit `ctx` (no closures). Capacity: 16 slots inside
`Executor`. Host idle: busy-wait on `time.mono()`.

Related: [029](../../issues/029-async-event-loop.md), sketch
[`../sketch_async_eventloop.kl`](../sketch_async_eventloop.kl) (async — not yet).
