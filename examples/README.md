# Examples

Runnable Klin demos (not golden tests — those live in `test/`).

```sh
dart run bin/klin.dart run examples/hello.kl
dart run bin/klin.dart fmt examples/hello.kl          # stdout
dart run bin/klin.dart fmt -w examples/hello.kl       # write in place
dart run bin/klin.dart test examples/                 # *_test.kl
```

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
| `add_test.kl` | Sample `klin test` (`import testing`) |
| `interp.kl` | String interpolation → `printf` ([note/07-interpolacja.md](../note/07-interpolacja.md)) |
| `time_demo.kl` | `stdlib/time` — Instant / Duration / format ([note/08-time.md](../note/08-time.md)) |
| `ffi_add/` | Host C `.a` via `@[cimport]` + `@[link]` ([note/09-ffi-c.md](../note/09-ffi-c.md)) |
| `cexport_add/` | Klin → C via `@[cexport, codename]` ([note/09-ffi-c.md](../note/09-ffi-c.md)) |
| `asm_add/` | Host `.S` via `@[link]` + `@[cimport]` ([note/10-asm.md](../note/10-asm.md)) |
| `klin_lib/` | `lib/` + `-I` / `$KLIN_PATH` ([note/11-biblioteki-klin.md](../note/11-biblioteki-klin.md)) |
| `modules/` | `module` / `import` (`app.kl` entry) |
| `stm32/blink_f411/` | Nucleo-F411RE LED — `$peripherals_from_svd` + `@[link("startup.s")]` → `out/*.link` |

Bare-metal boards go under `stm32/<name>/`.
