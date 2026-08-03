# 062 — MCU targets beyond STM32: ESP32, RP2040, RP2350

**Status:** 🚧 — RP2040 + RP2350 Arm blink via [`machine_rp`](https://github.com/MrHIDEn/machine_rp); ESP32 still open
**Depends on:** [010](010-bare-metal.md); nice to have [022](022-asm-libraries.md), [027](027-svd-ergonomic-api.md), [031](031-hal-libraries.md), [053](053-device-board-assets.md), [054](054-embedded-project-layout.md)

## Context (conversation notes)

Klin emits **C** — frontend is not “STM32 only”. Today the ready
bare-metal path is mainly **STM32 Cortex-M** (`examples/stm32/…`). Question: can we
target **ESP32**, **RP2040**, **RP2350**?

## Short verdict

| Target | Realistic? | Notes |
|---|---|---|
| **RP2040** | ✅ path exists | Cortex-M0+, `arm-none-eabi`, freestanding + boot2 (no pico-sdk cmake). Package: [`machine_rp`](https://github.com/MrHIDEn/machine_rp) + `examples/blink_pico`. |
| **RP2350** | Same model | M33 (and on some variants RISC-V) — different SDK/toolchain than 2040, still “C + startup”. |
| **ESP32** | Possible, harder | Classic ESP32 = **Xtensa**; C3/C6… = **RISC-V**. Usually **ESP-IDF** (init, partitions, often Wi‑Fi). No Klin+ESP example; FFI to IDF or freestanding without network stack. |

## What already carries to these MCUs

- single `.c` emit, checker, `#line`
- `@[codename]` / ISR, `@[cimport]` / `@[link]` (C and ASM)
- SVD → typed registers ([011](011-svd.md) / [027](027-svd-ergonomic-api.md)), when chip SVD exists
- rule: startup / vector table / clock stay explicit (not language magic)

## What is not out of the box

- board pack / Klin-tree `examples/rp2040/…` (lives in [`machine_rp`](https://github.com/MrHIDEn/machine_rp) instead)
- automatic ESP-IDF or pico-sdk in Klin CLI
- RP2350 / ESP32 examples

## Order sketch

1. **RP2040** blink + `machine` Pin — ✅ [`machine_rp`](https://github.com/MrHIDEn/machine_rp)  
2. **RP2350** — same repo, separate example (M33 / boot differs).  
3. **ESP32** — first “hello UART/LED” freestanding or minimal IDF + `@[cimport]`; Wi‑Fi out of MVP.

## Out of scope

- implementation in this issue (placeholder / decision only)
- promise of full portability like µPython between ports
- priority relative to language core / current STM32 path

## Links

- RP package: https://github.com/MrHIDEn/machine_rp  
- Bare-metal STM32: [010](010-bare-metal.md)  
- Project layout: [054](054-embedded-project-layout.md)  
- Device/board assets: [053](053-device-board-assets.md)  
- Vendor HAL: [031](031-hal-libraries.md)  
- `machine`-style API: [061](061-micropython-machine-api.md)  
