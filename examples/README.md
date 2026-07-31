# Examples

Runnable Klin demos (not golden tests — those live in `test/`).

```sh
dart run bin/klin.dart run examples/hello.kl
```

| Path | Notes |
|---|---|
| `hello.kl`, `vec2.kl`, `slice_sum.kl`, `modules/` | Host demos |
| `stm32/blink_f411/` | Nucleo-F411RE LED (needs `arm-none-eabi-gcc`) |

Bare-metal boards go under `stm32/<name>/`.
