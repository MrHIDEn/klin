# 062 — Cele MCU poza STM32: ESP32, RP2040, RP2350

**Status:** 💭 do rozważenia (niski priorytet — nieblokujące)
**Zależy od:** [010](010-bare-metal.md); mile [022](022-biblioteki-asm.md), [027](027-svd-ergonomic-api.md), [031](031-biblioteki-hal.md), [053](053-device-board-assets.md), [054](054-embedded-project-layout.md)

## Kontekst (notatki z rozmowy)

Klin emituje **C** — frontend nie jest „tylko STM32”. Dziś gotowy tor
bare-metal to głównie **STM32 Cortex-M** (`examples/stm32/…`). Pytanie: czy da
się celować w **ESP32**, **RP2040**, **RP2350**?

## Werdykt skrótowy

| Cel | Realne? | Uwagi |
|---|---|---|
| **RP2040** | Najbliżej „tak” | Cortex-M0+, `arm-none-eabi`, pico-sdk / własny startup+`ld`, SVD. Ten sam model co blink F411: Klin → `.c` + `.s` / `@[link]` + linker. |
| **RP2350** | Tak samo w modelu | M33 (i na części wariantów RISC-V) — inny SDK/toolchain niż 2040, nadal „C + startup”. |
| **ESP32** | Możliwe, ciężej | Klasyczny ESP32 = **Xtensa**; C3/C6… = **RISC-V**. Zwykle **ESP-IDF** (init, partycje, często Wi‑Fi). Brak przykładu Klin+ESP; FFI do IDF albo freestanding bez stacka sieciowego. |

## Co już przenosi się na te MCU

- emit jednego `.c`, checker, `#line`
- `@[codename]` / ISR, `@[cimport]` / `@[link]` (C i ASM)
- SVD → typowane rejestry ([011](011-svd.md) / [027](027-svd-ergonomic-api.md)), gdy jest SVD chipu
- zasada: startup / tablica wektorów / clock zostają świadome (nie magia języka)

## Czego nie ma z pudełka

- board pack / przykład `examples/rp2040/…` ani `examples/esp32/…`
- automatycznego ESP-IDF ani pico-sdk w CLI Klin
- API „jak MicroPython `machine`” — osobny backlog [061](061-micropython-machine-api.md)

## Szkic kolejności (gdy kiedyś)

1. **RP2040** blink (najbliższy STM32) — Makefile + startup + opcjonalnie SVD/pico-sdk.  
2. **RP2350** — wariant M33 tej samej ścieżki (albo osobny przykład).  
3. **ESP32** — najpierw „hello UART/LED” freestanding lub minimal IDF + `@[cimport]`; Wi‑Fi poza MVP.

## Poza zakresem

- implementacja w tym issue (tylko placeholder / decyzja)
- obietnica pełnej przenośności jak µPython między portami
- priorytet względem rdzenia języka / obecnego toru STM32

## Linki

- Bare-metal STM32: [010](010-bare-metal.md)  
- Layout projektów: [054](054-embedded-project-layout.md)  
- Device/board assets: [053](053-device-board-assets.md)  
- HAL vendora: [031](031-biblioteki-hal.md)  
- API w stylu `machine`: [061](061-micropython-machine-api.md)  
