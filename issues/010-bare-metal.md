# 010 — Bare metal: mrugający LED na STM32

**Status:** ⬜ do zrobienia
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

**Nie parsować nagłówków CMSIS** — są zbudowane z makr i bitfieldów,
sygnatury pisane ręcznie jako deklaracje FFI.

Flagi: `-Os`, `-ffunction-sections -fdata-sections`, `--gc-sections`.

## Kryterium ukończenia

- [ ] LED mruga na Nucleo
- [ ] `arm-none-eabi-objdump -d` — instrukcje identyczne jak w wersji
      napisanej ręcznie w C
- [ ] handler przerwania wywoływany poprawnie
