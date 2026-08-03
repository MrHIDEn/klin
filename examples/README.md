# Examples

Runnable Klin demos (not golden tests — those live in `test/`).

```sh
dart run bin/klin.dart run examples/hello.kl
dart run bin/klin.dart fmt examples/hello.kl          # stdout
dart run bin/klin.dart fmt -w examples/hello.kl       # write in place
dart run bin/klin.dart test examples/                 # *_test.kl
```

**Host (laptop):** ordinary `*.kl` demos above — **no** `linker.ld` / `startup.s` /
Makefile (`klin run` + system CRT/libc). Make + ld + startup only for bare-metal
`stm32/…` ([075](../issues/075-board-pack-init-host.md)).

Style: [docs/05-fmt.md](../docs/05-fmt.md) (`klin fmt`). Sources with `$…` macros
are not valid Klin until expand — format `point.kl` (or `--emit-pp` output), not
`point_macro.kl` / `stm32/.../blink.kl` as-is.

| Path | Notes |
|---|---|
| `hello.kl` | Minimal `puts` |
| `vec2.kl` | Struct + methods |
| `point.kl` | `Vec2i` + `len_sq` (canonical Klin) |
| `point_macro.kl` | Same via `$fn` ([docs/04-macros.md](../docs/04-macros.md)) |
| `slice_sum.kl` | Arrays / slices |
| `fn_ptr.kl` | Function pointers without capture ([017](../issues/017-collection-methods.md) phase 2) |
| `slice_ops.kl` | `stdlib/slice` map/filter/reduce ([017](../issues/017-collection-methods.md), [docs/16](../docs/16-slice.md)) |
| `slice_alloc_demo.kl` | `stdlib/slice_alloc` + explicit `Allocator` ([017](../issues/017-collection-methods.md), [docs/16](../docs/16-slice.md)) |
| `short_decl.kl` | `:=` sugar for `let mut` ([055](../issues/055-short-decl.md), [docs/14](../docs/14-short-decl.md)) |
| `destructure.kl` | Destructuring `let { x, y } = p` / `let [a, b] = xs` (+ rename / `_` / bare `{}=`) ([056](../issues/056-destructuring.md)) |
| `multi_assign.kl` | Multi-assignment / swap `a, b = b, a` ([056](../issues/056-destructuring.md)) |
| `match.kl` | `match` stmt + expr, no fallthrough ([014](../issues/014-match.md), [docs/15](../docs/15-match.md)) |
| `add_test.kl` | Sample `klin test` (`import testing`) |
| `interp.kl` | String interpolation → `printf` ([docs/07-interpolation.md](../docs/07-interpolation.md)) |
| `time_demo.kl` | `stdlib/time` — Instant / Duration / format ([docs/08-time.md](../docs/08-time.md)) |
| `mem_heap.kl` | `stdlib/mem` — explicit `Allocator` heap ([docs/14-allocator.md](../docs/14-allocator.md)) |
| `ffi_add/` | Host C `.a` via `@[cimport]` + `@[link]` ([docs/09-ffi-c.md](../docs/09-ffi-c.md)) |
| `cexport_add/` | Klin → C via `@[cexport, codename]` ([docs/09-ffi-c.md](../docs/09-ffi-c.md)) |
| `asm_add/` | Host `.S` via `@[link]` + `@[cimport]` ([docs/10-asm.md](../docs/10-asm.md)) |
| `klin_lib/` | `lib/` + `-I` / `$KLIN_PATH` ([docs/11-klin-libraries.md](../docs/11-klin-libraries.md)) |
| `pkg_geom/` | Directory = one module (`geom/*.kl`, [docs/11](../docs/11-klin-libraries.md) / [12](../docs/12-modules.md)) |
| `remote_osa/` | Remote `import "github/klin-lang/osa"` after `klin get` ([049](../issues/049-remote-imports.md)) |
| `remote_eventloop/` | Remote `github/klin-lang/eventloop@v0.2.0` — callbacks + async (`app.kl` / `async_app.kl`) ([029](../issues/029-async-event-loop.md)) |
| `sketch_async_eventloop.kl` | `async`/`await` + remote eventloop v0.2 ([029](../issues/029-async-event-loop.md)) |
| `freertos_eventloop/` | FreeRTOS + eventloop callbacks in one `$rtos_task` (emit-c / stubs; [029](../issues/029-async-event-loop.md) phase 3) |
| `freertos_eventloop_async/` | Same RTOS layout with `async` / `spawn` / `sleep_ms` ([029](../issues/029-async-event-loop.md) phase 3+4) |
| `modules/` | `module` / `import` ([docs/12-modules.md](../docs/12-modules.md)) |
| `stm32/blink_f411/` | Nucleo-F411RE LED — local `$peripherals_from_svd` + `@[link("startup.s")]` → `out/*.link` |
| `stm32/device_f411/` | Same via `$device` + `klin.mod` / `klin get` ([053](../issues/053-device-board-assets.md)) |

Bare-metal boards go under `stm32/<name>/` (`startup.s` + `linker.ld` live here
— pack/scaffold, not a host requirement; [075](../issues/075-board-pack-init-host.md)).
