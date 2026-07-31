# Examples

Runnable Klin demos (not golden tests — those live in `test/`).

```sh
dart run bin/klin.dart run examples/hello.kl
dart run bin/klin.dart fmt examples/hello.kl          # stdout
dart run bin/klin.dart fmt -w examples/hello.kl       # write in place
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
| `modules/` | `module` / `import` (`app.kl` entry) |
| `stm32/blink_f411/` | Nucleo-F411RE LED — `$peripherals_from_svd` + fluent MMIO (`arm-none-eabi-gcc`) |

Bare-metal boards go under `stm32/<name>/`.
