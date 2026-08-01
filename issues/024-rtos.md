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

## Podsumowanie: dwie warstwy (silnik C, wiązania jako biblioteka)

Rozdzielić dwie rzeczy:

1. **Silnik RTOS** — zawsze biblioteka C (vendor `.a` / źródła), Klin jest
   klientem przez FFI. Nigdy nie reimplementować schedulera/kolejek/mutexów w
   Klinie (łamałoby zasadę nadrzędną: brak ukrytego runtime/alokacji).
2. **Warstwa wiązań Klina** (deklaracje FFI + cienkie wrappery + wzorce
   `@[codename]` dla tasków/ISR) — docelowo **osobna biblioteka Klina**, nie
   moduł stdlib.

Dlaczego biblioteka zewnętrzna (przez import zdalny [049](049-remote-imports.md),
po [048](048-import-aliases.md)/[047](047-directory-modules.md)/[020](020-biblioteki-klin.md)),
a nie stdlib:

- RTOS jest **vendor/board/config-specyficzny** (port, `FreeRTOSConfig.h`,
  priorytety, `configTOTAL_HEAP_SIZE`) — nie ma jednego uniwersalnego wiązania do
  rdzenia.
- **Wersjonowanie** niezależne od kompilatora — wiązania nadążają za RTOS/portem
  bez wydania nowego Klina.
- **Rdzeń zostaje chudy/freestanding.** Emit nie usuwa nieużywanych `pub` (jak w
  [017](017-collection-methods.md) — `slice_alloc` osobno od `slice`), więc RTOS
  w stdlib groziłby ciągnięciem zależności wszędzie.

Konsekwencja: rdzeń Klina dostarcza tylko fundament (FFI/`codename`/link z 010/021/022);
to issue zostaje **decyzją + wzorcem FFI**, a „oficjalny" przykład
([028](028-freertos.md)) jako paczka/przykład (docelowo repo z remote-import),
nie jako moduł stdlib.

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
- wiązania jako **biblioteka zewnętrzna** (import zdalny 049), nie moduł stdlib
  — patrz „Podsumowanie" wyżej (rozstrzygnięte)
- ISR vs task: te same reguły co C (`FromISR`, priorytety) — Klin nie
  ukrywa
- konkretny przykład FreeRTOS jest opisany w [028](028-freertos.md), a
  adnotacje ISR do rozważenia w [030](030-isr-decorators.md)
- „dekoratory” tasków z lib `klinrtos`: API/makra/`codename` — tak; prawdziwy
  `@[task]` tylko z kompilatorem — ustalone w [028](028-freertos.md)

## Kryterium (gdy kiedyś wchodzi do prac)

- [ ] task + delay + toggle LED na znanym RTOS, kod Klin + link z portem C
- [ ] `objdump` / zachowanie porównywalne z wersją C (bez narzutu „magii”)
