# 031 — HAL libraries

**Status:** 💭 to consider
**Depends on:** 010 (bare metal), 021 (FFI/C), 011/027 welcome (registers from SVD)

## Context

After blink with manual/SVD MMIO the question arises about vendor **HAL**
(e.g. STM32Cube HAL / LL): GPIO init, UART, DMA, clock tree — more convenient than
raw registers, but a large C surface with macros and often hidden
assumptions about allocation / callbacks.

Architecture already says: **do not parse CMSIS headers** (macros, bitfields).
HAL therefore enters as **vendor C alongside** + explicit Klin declarations, not as
header translator.

## Goal (to consider)

Sensible HAL cooperation **without** rewriting CubeMX to Klin and **without**
breaking the prime rule:

- link HAL sources / `.a` like [021](021-biblioteki-c.md)
- thin `@[cimport]` / `@[cinclude]` only on used API (not entire HAL)
- example on known chip (e.g. F411): init GPIO / UART via HAL **or**
  via LL (lower level, closer to registers)
- clear split vs [011](011-svd.md) / [027](027-svd-ergonomic-api.md):
  SVD = typed registers; HAL = vendor higher API — can use separately
  or together (HAL underneath often touches same registers)
- chip/board packages and `$device`/`$board` (without mixing with HAL):
  [053](053-device-board-assets.md)
- higher API "like MicroPython `machine`" (PWM/UART/…) separately:
  [061](061-micropython-machine-api.md)

## Considerations / thought examples (not spec)

- **LL vs HAL:** LL closer to prime rule (less magic); full HAL
  more convenient, but more hidden state (`handle`, callbacks)
- generation of thin wrappers from Cube / from list of used symbols — optionally
  later; not in first cut
- clock / `SystemInit`: stays in C/startup as today, not in "magical" Klin
- conflict with SVD accessors: avoid double, conflicting model of same
  peripheral in one module without conscious choice

## What not to do

- Do not promise full STM32Cube as "Klin stdlib".
- Do not parse `stm32*.h` / generate entire HAL from XML.
- Do not hide allocation / DMA queues behind syntax sugar.

## Criteria (when this eventually enters work)

- [ ] Klin + vendor HAL/LL example on Nucleo (e.g. LED or UART)
- [ ] freestanding build like 010; objdump / behavior without Klin "magic" overhead
- [ ] documentation: when SVD, when HAL, when both
