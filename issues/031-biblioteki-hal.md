# 031 — Biblioteki HAL

**Status:** 💭 do rozważenia
**Zależy od:** 010 (bare metal), 021 (FFI/C), mile widziane 011/027 (rejestry z SVD)

## Kontekst

Po blinku z ręcznym/SVD MMIO pojawia się pytanie o **HAL** producenta
(np. STM32Cube HAL / LL): GPIO init, UART, DMA, clock tree — wygodniej niż
surowe rejestry, ale to duża powierzchnia C z makrami i często ukrytymi
założeniami o alokacji / callbackach.

Architektura już mówi: **nie parsować nagłówków CMSIS** (makra, bitfieldy).
HAL wchodzi więc jako **vendor C obok** + jawne deklaracje Klin, nie jako
tłumacz headerów.

## Cel (do rozważenia)

Sensowna współpraca z HAL **bez** przepisywania Cubemx do Klina i **bez**
łamania zasady nadrzędnej:

- link źródeł / `.a` HAL jak w [021](021-biblioteki-c.md)
- cienkie `@[cimport]` / `@[cinclude]` tylko na używane API (nie cały HAL)
- przykład na znanym chipie (np. F411): init GPIO / UART przez HAL **albo**
  przez LL (niższy poziom, bliżej rejestrów)
- jasny podział względem [011](011-svd.md) / [027](027-svd-ergonomic-api.md):
  SVD = typowane rejestry; HAL = wyższe API vendora — można używać osobno
  lub razem (HAL pod spodem i tak często tyka tych samych rejestrów)

## Rozważania / przykłady myślowe (nie speć)

- **LL vs HAL:** LL bliższy zasadzie nadrzędnej (mniej magii); pełny HAL
  wygodniejszy, ale więcej ukrytych stanów (`handle`, callbacki)
- generacja cienkich wrapperów z Cube / z listy użytych symboli — opcjonalnie
  później; nie w pierwszym cięciu
- clock / `SystemInit`: zostaje w C/startup jak dziś, nie w „magicznym” Klin
- konflikt z SVD accessors: unikać podwójnego, sprzecznego modelu tego
  samego peryferium w jednym module bez świadomego wyboru

## Czego nie robić

- Nie obiecywać pełnego STM32Cube jako „stdlib Klina”.
- Nie parsować `stm32*.h` / generować całego HAL z XML.
- Nie ukrywać alokacji / kolejek DMA za cukrem składniowym.

## Kryterium (gdy kiedyś wejdzie do prac)

- [ ] przykład Klin + vendor HAL/LL na Nucleo (np. LED lub UART)
- [ ] build freestanding jak 010; objdump / zachowanie bez narzutu „magii” Klina
- [ ] dokumentacja: kiedy SVD, kiedy HAL, kiedy oba
