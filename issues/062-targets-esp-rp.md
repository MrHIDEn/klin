# 062 — MCU targets beyond STM32: ESP32, RP2040, RP2350

**Status:** 💭 under consideration (low priority — non-blocking)
**Depends on:** [010](010-bare-metal.md); nice to have [022](022-biblioteki-asm.md), [027](027-svd-ergonomic-api.md), [031](031-biblioteki-hal.md), [053](053-device-board-assets.md), [054](054-embedded-project-layout.md)

## Context (conversation notes)

Klin emits **C** — frontend is not “STM32 only”. Today the ready
bare-metal path is mainly **STM32 Cortex-M** (`examples/stm32/…`). Question: can we
target **ESP32**, **RP2040**, **RP2350**?

## Short verdict

| Target | Realistic? | Notes |
|---|---|---|
| **RP2040** | Closest to “yes” | Cortex-M0+, `arm-none-eabi`, pico-sdk / own startup+`ld`, SVD. Same model as blink F411: Klin → `.c` + `.s` / `@[link]` + linker. |
| **RP2350** | Same model | M33 (and on some variants RISC-V) — different SDK/toolchain than 2040, still “C + startup”. |
| **ESP32** | Possible, harder | Classic ESP32 = **Xtensa**; C3/C6… = **RISC-V**. Usually **ESP-IDF** (init, partitions, often Wi‑Fi). No Klin+ESP example; FFI to IDF or freestanding without network stack. |

## What already carries to these MCUs

- single `.c` emit, checker, `#line`
- `@[codename]` / ISR, `@[cimport]` / `@[link]` (C and ASM)
- SVD → typed registers ([011](011-svd.md) / [027](027-svd-ergonomic-api.md)), when chip SVD exists
- rule: startup / vector table / clock stay explicit (not language magic)

## What is not out of the box

- board pack / `examples/rp2040/…` or `examples/esp32/…` example
- automatic ESP-IDF or pico-sdk in Klin CLI
- “like MicroPython `machine`” API — separate backlog [061](061-micropython-machine-api.md)

## Order sketch (whenever)

1. **RP2040** blink (closest to STM32) — Makefile + startup + optional SVD/pico-sdk.  
2. **RP2350** — M33 variant of same path (or separate example).  
3. **ESP32** — first “hello UART/LED” freestanding or minimal IDF + `@[cimport]`; Wi‑Fi out of MVP.

## Out of scope

- implementation in this issue (placeholder / decision only)
- promise of full portability like µPython between ports
- priority relative to language core / current STM32 path

## Links

- Bare-metal STM32: [010](010-bare-metal.md)  
- Project layout: [054](054-embedded-project-layout.md)  
- Device/board assets: [053](053-device-board-assets.md)  
- Vendor HAL: [031](031-biblioteki-hal.md)  
- `machine`-style API: [061](061-micropython-machine-api.md)  
