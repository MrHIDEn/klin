# 023 — Katalog `examples/`

**Status:** ✅ zrobione (zalążek + układ STM32)
**Zależy od:** bieżącego stanu języka (001–012+)

## Cel

Katalog **`examples/`** z krótkimi, uruchamialnymi programami Klina —
nie testami złotymi (`test/`), tylko materiałem do nauki i demo:

```bash
dart run bin/klin.dart run examples/hello.kl
```

## Układ

```
examples/
  README.md
  hello.kl, vec2.kl, slice_sum.kl, modules/
  stm32/
    blink_f411/     # Nucleo-F411RE — SysTick → PA5
```

- Host: `klin run examples/…`
- MCU: `examples/stm32/<nazwa>/` + Makefile freestanding
- Kolejne dema STM32 / FreeRTOS (028): też pod `stm32/`

## Kryterium ukończenia

- [x] `examples/stm32/blink_f411/` (przeniesione z `examples/blink_f411/`)
- [x] ścieżki Makefile / test ARM zaktualizowane
- [x] krótki `examples/README.md`

## Czego nie mieszać

- Nie zastępować `test/*.kl` — złote zostają w `test/`.
- Nie obiecywać pełnego tutoriala (to bliżej README / 013).
