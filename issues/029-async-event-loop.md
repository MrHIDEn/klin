# 029 — Event loop / `async`·`await` (styl JS)

**Status:** 💭 do rozważenia
**Zależy od:** decyzji D1/D3; prawdopodobnie 018, 026, 028

## Pytanie

Czy (i jak) da się mieć wygodę w stylu JS — event loop + `async`/`await` —
**bez** ukrytej alokacji / ukrytego runtime, które łamie zasadę nadrzędną.

Pokrewne: [018](018-generators-yield.md), [024](024-rtos.md), [028](028-freertos.md).

## Model warstw (pełna elastyczność, nie wymuszenie)

1. **samo `main`** — bare metal / pętla ręczna / WFI; bez event-loopa i bez RTOS
2. **`main` + event-loop** — jeden opcjonalny loop w `main` (dekorator), bez RTOS
3. **`main` + taski RTOS + event-loopy gdzie chcemy** — dekorator na `main`,
   dekorator na wybranym tasku; loop tylko tam, gdzie go założono.
   Nie „jeden globalny Node-loop na cały firmware”.

## Współdzielenie danych vs loop

Single-threaded event-loop w jednym tasku może serializować pracę *w tym*
tasku; **nie** chroni przed innym taskiem / ISR — tam nadal mutex / queue /
critical section z [028](028-freertos.md). `await` nie jest domyślnym lockiem.

## Hipotezy techniczne (nie zobowiązanie)

- **A)** opcjonalny moduł + jawny executor / `Allocator` (raczej host)
- **B)** desugar do jawnej state machine w `.c`
- **C)** cukier nad FreeRTOS (028), nie „Node na MCU”

Wejścia (warianty z 028): `main` + dekorowane `fn` **lub** `main_N` / `task_N`.

## Czego nie robić na start

Promise GC, ukryty scheduler, async jako domyślny bare-metal, **wymuszenie**
loopa na każdym tasku, ukryte automatyczne mutexy.
