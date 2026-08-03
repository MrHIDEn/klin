# 062 — MCU targets beyond STM32: ESP32, RP2040, RP2350

**Status:** 🚧 — RP2040 + RP2350 (Arm + RISC-V) via [`machine_rp`](https://github.com/MrHIDEn/machine_rp); ESP32-C3 Pin via [`machine_esp`](https://github.com/MrHIDEn/machine_esp) (minimal IDF blink)
**Depends on:** [010](010-bare-metal.md); nice to have [022](022-asm-libraries.md), [027](027-svd-ergonomic-api.md), [031](031-hal-libraries.md), [053](053-device-board-assets.md), [054](054-embedded-project-layout.md)

## Context (conversation notes)

Klin emits **C** — frontend is not “STM32 only”. Today the ready
bare-metal path is mainly **STM32 Cortex-M** (`examples/stm32/…`). Question: can we
target **ESP32**, **RP2040**, **RP2350**?

## Short verdict

| Target | Realistic? | Notes |
|---|---|---|
| **RP2040** | ✅ path exists | Cortex-M0+, `arm-none-eabi`, freestanding + boot2 (no pico-sdk cmake). Package: [`machine_rp`](https://github.com/MrHIDEn/machine_rp) + `examples/blink_pico`. |
| **RP2350** | ✅ Arm + RISC-V | Arm M33: `blink_pico2`. RISC-V Hazard3: `blink_pico2_riscv` (`riscv64-unknown-elf-gcc` `-march=rv32imac`). Same `pin_out_rp2350`. |
| **ESP32-C3** | ✅ Pin MVP | RISC-V. Package: [`machine_esp`](https://github.com/MrHIDEn/machine_esp) — MMIO `Pin` + `examples/blink_c3` (minimal **ESP-IDF** boot/flash; no Wi‑Fi). Freestanding later. |
| **ESP32** (classic / other) | Later | Classic = **Xtensa**; C6/S3 etc. separate from C3 MVP. |

## What already carries to these MCUs

- single `.c` emit, checker, `#line`
- `@[codename]` / ISR, `@[cimport]` / `@[link]` (C and ASM)
- SVD → typed registers ([011](011-svd.md) / [027](027-svd-ergonomic-api.md)), when chip SVD exists
- rule: startup / vector table / clock stay explicit (not language magic)

## What is not out of the box

- board pack / Klin-tree `examples/rp2040/…` (lives in [`machine_rp`](https://github.com/MrHIDEn/machine_rp) instead)
- automatic ESP-IDF or pico-sdk in Klin CLI (example ships its own `idf.py` flow)
- freestanding ESP image (no IDF)
- Classic Xtensa ESP32 / C6 / S3 ports

## Order sketch

1. **RP2040** blink + `machine` Pin — ✅ `examples/blink_pico`  
2. **RP2350** Arm blink + Pin — ✅ `examples/blink_pico2`  
3. **RP2350** RISC-V blink — ✅ `examples/blink_pico2_riscv`  
4. **ESP32-C3** Pin + blink — ✅ [`machine_esp`](https://github.com/MrHIDEn/machine_esp) `examples/blink_c3` (minimal IDF); Wi‑Fi / freestanding out of MVP.

## Out of scope

- implementation in this issue (placeholder / decision only)
- promise of full portability like µPython between ports
- priority relative to language core / current STM32 path

## Links

- RP package: https://github.com/MrHIDEn/machine_rp  
- ESP package: https://github.com/MrHIDEn/machine_esp  
- Bare-metal STM32: [010](010-bare-metal.md)  
- Project layout: [054](054-embedded-project-layout.md)  
- Device/board assets: [053](053-device-board-assets.md)  
- Vendor HAL: [031](031-hal-libraries.md)  
- `machine`-style API: [061](061-micropython-machine-api.md)  
