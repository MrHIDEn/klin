# Examples

Runnable Klin demos (not golden tests — those live in `test/`).

```sh
dart run bin/klin.dart run examples/hello.kl
dart run bin/klin.dart fmt examples/hello.kl          # stdout
dart run bin/klin.dart fmt -w examples/hello.kl       # write in place
dart run bin/klin.dart test examples/                 # *_test.kl
```

**Host (laptop):** zwykłe `*.kl` powyżej — **bez** `linker.ld` / `startup.s` /
Makefile (`klin run` + CRT/libc systemu). Make + ld + startup tylko w
bare-metal `stm32/…` ([075](../issues/075-board-pack-init-host.md)).

Style: [note/05-fmt.md](../note/05-fmt.md) (`klin fmt`). Sources with `$…` macros
are not valid Klin until expand — format `point.kl` (or `--emit-pp` output), not
`point_macro.kl` / `stm32/.../blink.kl` as-is.

| Path | Notes |
|---|---|
| `hello.kl` | Minimal `puts` |
| `vec2.kl` | Struct + methods |
| `point.kl` | `Vec2i` + `len_sq` (canonical Klin) |
| `point_macro.kl` | Same via `$fn` ([note/04-makra.md](../note/04-makra.md)) |
| `slice_sum.kl` | Arrays / slices |
| `fn_ptr.kl` | Function pointers without capture ([017](../issues/017-collection-methods.md) phase 2) |
| `slice_ops.kl` | `stdlib/slice` map/filter/reduce ([017](../issues/017-collection-methods.md), [note/16](../note/16-slice.md)) |
| `slice_alloc_demo.kl` | `stdlib/slice_alloc` + explicit `Allocator` ([017](../issues/017-collection-methods.md), [note/16](../note/16-slice.md)) |
| `short_decl.kl` | `:=` sugar for `let mut` ([055](../issues/055-short-decl.md), [note/14](../note/14-short-decl.md)) |
| `destructure.kl` | Destructuring `let { x, y } = p` / `let [a, b] = xs` (+ rename / `_` / bare `{}=`) ([056](../issues/056-destructuring.md)) |
| `multi_assign.kl` | Multi-assignment / swap `a, b = b, a` ([056](../issues/056-destructuring.md)) |
| `match.kl` | `match` stmt + expr, no fallthrough ([014](../issues/014-match.md), [note/15](../note/15-match.md)) |
| `add_test.kl` | Sample `klin test` (`import testing`) |
| `interp.kl` | String interpolation → `printf` ([note/07-interpolacja.md](../note/07-interpolacja.md)) |
| `time_demo.kl` | `stdlib/time` — Instant / Duration / format ([note/08-time.md](../note/08-time.md)) |
| `mem_heap.kl` | `stdlib/mem` — explicit `Allocator` heap ([note/14-allocator.md](../note/14-allocator.md)) |
| `ffi_add/` | Host C `.a` via `@[cimport]` + `@[link]` ([note/09-ffi-c.md](../note/09-ffi-c.md)) |
| `cexport_add/` | Klin → C via `@[cexport, codename]` ([note/09-ffi-c.md](../note/09-ffi-c.md)) |
| `asm_add/` | Host `.S` via `@[link]` + `@[cimport]` ([note/10-asm.md](../note/10-asm.md)) |
| `klin_lib/` | `lib/` + `-I` / `$KLIN_PATH` ([note/11-biblioteki-klin.md](../note/11-biblioteki-klin.md)) |
| `pkg_geom/` | Katalog = jeden moduł (`geom/*.kl`, [note/11](../note/11-biblioteki-klin.md) / [12](../note/12-moduly.md)) |
| `remote_osa/` | Remote `import "github/mrhiden/osa"` po `klin get` ([049](../issues/049-remote-imports.md)) |
| `sketch_async_eventloop.kl` | **Szkic** — `async`/`await` + `github/mrhiden/eventloop` ([029](../issues/029-async-event-loop.md)); nie `klin run` |
| `modules/` | `module` / `import` ([note/12-moduly.md](../note/12-moduly.md)) |
| `stm32/blink_f411/` | Nucleo-F411RE LED — lokalne `$peripherals_from_svd` + `@[link("startup.s")]` → `out/*.link` |
| `stm32/device_f411/` | To samo przez `$device` + `klin.mod` / `klin get` ([053](../issues/053-device-board-assets.md)) |

Bare-metal boards go under `stm32/<name>/` (tu dopiero `startup.s` + `linker.ld`
— pack/scaffold, nie wymóg hosta; [075](../issues/075-board-pack-init-host.md)).
