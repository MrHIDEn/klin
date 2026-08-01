# 010 — Bare metal: mrugający LED na STM32

**Status:** ✅ zrobione
**Zależy od:** 009
**Kamień milowy:** pierwszy realny cel projektu

## Zakres

- `-ffreestanding`, brak libc
- adnotacje `@[codename("...")]` — mangling wyłączalny
- adnotacje `@[cimport]`, `@[cinclude]`, `@[link]`
- inline ASM
- integracja ze skryptem linkera i startupem w `.s`

## Uwagi krytyczne

**Nazwy symboli muszą zgadzać się co do znaku** z tablicą wektorów
(`TIM2_IRQHandler`, `SysTick_Handler`). Stąd `codename`.

**Startup zostaje surowym `.s` obok.** Tablica wektorów, reset handler,
kopiowanie `.data` z flash do RAM, zerowanie `.bss`. Nie opakowywać.

**Nie parsować nagłówków CMSIS** — są zbudowane z makr i bitfieldów.
Rejestry STM32F411 pochodzą teraz z generatora SVD ([011](011-svd.md));
sygnatury pozostałego FFI nadal są deklarowane ręcznie.

Flagi: `-Os`, `-ffunction-sections -fdata-sections`, `--gc-sections`.

## Kryterium ukończenia

- [x] przykład `examples/stm32/blink_f411/` (SysTick → PA5) + Makefile freestanding
- [x] `arm-none-eabi-objdump` / `nm`: symbol `SysTick_Handler` (test skip bez toolchaína)

Weryfikacja ręczna (LED na Nucleo) jest opcjonalna — poza kryterium CI.

Układ katalogu: [023](023-examples.md). Czytelniejszy wygląd projektu /
scaffold: [054](054-embedded-project-layout.md). Inne MCU (ESP32, RP2040/2350):
[062](062-targets-esp-rp.md).
