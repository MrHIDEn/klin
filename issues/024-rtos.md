# 024 — RTOS (FreeRTOS / Zephyr / …)

**Status:** 💭 do rozważenia
**Zależy od:** 010 (bare metal), 021 (FFI/C), 022 (ASM); nie w kolejce głównej

## Pytanie

Czy w Klinie da się sensownie ogarnąć **RTOS** (np. FreeRTOS, Zephyr,
RT-Thread) — taski, kolejki, mutexy, handlery ISR — bez łamania zasady
nadrzędnej (brak ukrytej alokacji / magicznego runtime)?

## Wstępna odpowiedź (hipoteza)

**Tak, jako klient C API**, nie jako „Klin-RTOS”:

- RTOS zostaje biblioteką C (`.a` / źródła vendor) linkowaną obok emisji
- Klin deklaruje FFI (`xTaskCreate`, `osMutexAcquire`, …) + ewentualnie
  cienkie wrappery w `.kl`
- handlery / entry pointy tasków: `@[codename("…")]` (D4) jak w 010
- stack / heap RTOS: **jawne** (statyczne bufory, `configTOTAL_HEAP_SIZE`,
  alokator użytkownika) — bez ukrytego `malloc` w języku

Czego **nie** obiecywać w rdzeniu: własnego schedulera, green threads,
async/await z runtime, GC, ani „task” jako ukrytej cechy składni.

## Co musi być wcześniej

| Krok | Potrzeba pod RTOS |
|---|---|
| 010 | freestanding, `codename`, ISR, link ze startupem |
| 021 | link `-l` / ścieżki, deklaracje sygnatur C |
| 022 | obok RTOS często `.s` / port vendor |
| 007 | wskaźniki / `volatile` — już pod rejestry i callbacki |

## Do decyzji później

- jeden „oficjalny” port (np. FreeRTOS na Nucleo) jako przykład w
  `examples/`, czy tylko dokumentacja wzorca FFI
- czy cienki moduł `rtos` w Klinie (012-style: opcjonalny, nie builtin)
- ISR vs task: te same reguły co C (`FromISR`, priorytety) — Klin nie
  ukrywa

## Kryterium (gdy kiedyś wchodzi do prac)

- [ ] task + delay + toggle LED na znanym RTOS, kod Klin + link z portem C
- [ ] `objdump` / zachowanie porównywalne z wersją C (bez narzutu „magii”)
