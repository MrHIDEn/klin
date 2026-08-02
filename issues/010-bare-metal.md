# 010 — Bare metal: blinking LED on STM32

**Status:** ✅ done
**Depends on:** 009
**Milestone:** first real target of the project

## Scope

- `-ffreestanding`, no libc
- annotations `@[codename("...")]` — mangling disableable
- annotations `@[cimport]`, `@[cinclude]`, `@[link]`
- inline ASM
- integration with linker script and startup in `.s`

## Critical notes

**Symbol names must match exactly** the vector table
(`TIM2_IRQHandler`, `SysTick_Handler`). Hence `codename`.

**Startup stays raw `.s` alongside.** Vector table, reset handler,
copying `.data` from flash to RAM, zeroing `.bss`. Do not wrap it.

**Do not parse CMSIS headers** — they are built from macros and bitfields.
STM32F411 registers now come from the SVD generator ([011](011-svd.md));
signatures for remaining FFI are still declared manually.

Flags: `-Os`, `-ffunction-sections -fdata-sections`, `--gc-sections`.

## Completion criteria

- [x] example `examples/stm32/blink_f411/` (SysTick → PA5) + freestanding Makefile
- [x] `arm-none-eabi-objdump` / `nm`: symbol `SysTick_Handler` (test skipped without toolchain)

Manual verification (LED on Nucleo) is optional — outside CI criteria.

Directory layout: [023](023-examples.md). Cleaner project look /
scaffold: [054](054-embedded-project-layout.md). Board pack / `klin init` vs
host (laptop does not need ld/startup): [075](075-board-pack-init-host.md).
Other MCUs (ESP32, RP2040/2350): [062](062-targets-esp-rp.md).
