# 028 — Ładna współpraca z FreeRTOS

**Status:** 💭 do rozważenia
**Zależy od:** 024, 010, 021, 022?; 026 mile widziane

Osobno od ogólnego [024](024-rtos.md) (FFI + hipoteza „klient C API”).

## Cel

Ergonomiczna warstwa Klin nad FreeRTOS na znanym porcie (np. Nucleo + F411),
bez własnego schedulera i bez ukrytej alokacji.

- cienki opcjonalny moduł / przykłady: task create, delay, queue, mutex, `FromISR`
- entry pointy: `@[codename("…")]` (010); stack/TCB/queue **jawne**
- vendor FreeRTOS jako C obok; opcjonalnie D3 (026) pod wzorce

## Rozważania / przykłady myślowe (nie speć)

- oznaczanie tasków: `@[task]` / `@[rtos]` / `@[task(id=0)]` na zwykłych `fn`,
  **albo** konwencja `main` + `task_N` / `main_N`
- wariant do dyskusji: jedno `main` (init + start scheduler) + dowolne nazwy
  tasków z dekoratorami vs sztywne `task_0`…
- most do [029](029-async-event-loop.md): event-loop **opcjonalny** na `main`
  i/lub na wybranych taskach

## Mutexy / dane współdzielone (krytyczne)

- wiele tasków + wspólny stan = wyścigi, torn reads, deadlocks, inwersja
  priorytetu — **poważne kryzysy**, nie edge case
- Klin **nie** ukrywa synchronizacji: brak magicznego „async-safe” ani
  automatycznych locków przy globalach
- warianty: jawne FFI `xSemaphoreTake` / cienkie `@[mutex]` + `lock`/`unlock`
  z widocznym kosztem; `FromISR` osobno
- event-loop **nie zastępuje** mutexa między taskami
- ewentualny checker później (global mutowany z >1 taska bez sekcji krytycznej)
  — tylko idea
- zasada nadrzędna: mutex = wywołanie RTOS / jawna sekcja

## Kryterium

`examples/freertos_blink/` — ≥2 taski, delay, LED; bez narzutu vs C+FreeRTOS.
