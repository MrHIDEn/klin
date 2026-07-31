# Examples

Runnable Klin demos (not golden tests — those live in `test/`).

```sh
dart run bin/klin.dart run examples/hello.kl
```

| Path | Notes |
|---|---|
| `hello.kl`, `vec2.kl`, `slice_sum.kl`, `modules/` | Host demos |
| `macro_point.kl` / `macro_point_plain.kl` | `$fn` vs hand-written expand ([note/04-makra.md](../note/04-makra.md)) |
| `stm32/blink_f411/` | Nucleo-F411RE LED — fluent SVD (`$peripherals_from_svd`, needs `arm-none-eabi-gcc`) |

Bare-metal boards go under `stm32/<name>/`.
