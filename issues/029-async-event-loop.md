# 029 — Event loop / `async`·`await` (styl JS)

**Status:** 💭 do rozważenia
**Zależy od:** decyzji D1/D3; prawdopodobnie 018, 026, 028

## Pytanie

Czy (i jak) da się mieć wygodę w stylu JS — event loop + `async`/`await` —
**bez** ukrytej alokacji / ukrytego runtime, które łamie zasadę nadrzędną.

Pokrewne: [018](018-generators-yield.md), [024](024-rtos.md), [028](028-freertos.md).

## Model warstw (pełna elastyczność, nie wymuszenie)

1. **samo `main`** — bare metal / pętla ręczna / WFI; bez event-loopa i bez RTOS
2. **`main` + event-loop** — jeden opcjonalny loop w `main` (makro / API lib),
   bez RTOS
3. **`main` + taski RTOS + event-loopy gdzie chcemy** — makro/API na `main`
   i/lub na wybranym tasku; loop tylko tam, gdzie go założono.
   Nie „jeden globalny Node-loop na cały firmware”.

## Współdzielenie danych vs loop

Single-threaded event-loop w jednym tasku może serializować pracę *w tym*
tasku; **nie** chroni przed innym taskiem / ISR — tam nadal mutex / queue /
critical section z [028](028-freertos.md). `await` nie jest domyślnym lockiem.

## Podsumowanie: co biblioteka, a co rdzeń

W odróżnieniu od RTOS ([024](024-rtos.md), gdzie silnik to zawsze biblioteka C),
event loop rozpada się na dwie części o różnym statusie:

1. **Mechanizm pętli** (loop + kolejka tasków/timerów, poll → uruchom gotowe →
   WFI) — **biblioteka** i **może być napisany w Klinie** (kooperacyjna pętla
   jest zero-cost, bez ukrytego runtime). Wariant bez alokacji (statyczne
   bufory) jak `slice`; wariant z kolejką na stercie osobno, z jawnym
   `Allocator` (jak `slice_alloc`, warstwa 2). Nie jest vendor-specyficzny, więc
   może być opcjonalnym modułem stdlib (styl 012) **albo** biblioteką zewnętrzną
   (import zdalny [049](049-remote-imports.md)).
2. **Cukier `async`/`await` (i generatory)** — to **feature rdzenia**
   (parser/emit, desugar do jawnej maszyny stanów, hipoteza B poniżej), nie da
   się dostarczyć jako `.kl`. Spięte z [018](018-generators-yield.md) i decyzją
   D1/D3. Cukier zakładający loop na `main`/tasku: **makra lib** (jak
   `$rtos_task` w [028](028-freertos.md)), nie user-`@[…]` ani obowiązkowy
   atrybut w rdzeniu.

Wniosek: sam runtime pętli → biblioteka (najlepiej w Klinie); `async`/`await` →
rdzeń, jeśli w ogóle. „Raczej jako biblioteka" dotyczy tylko punktu 1.

## Preferowany cukier: `$event_loop` (makro lib)

Ten sam kierunek co `$rtos_task` w 028 — ergonomia w bibliotece, expand jawny,
bez ukrytego schedulera / alokacji kolejki.

### Samo `main` + loop (bez RTOS)

```klin
$event_loop() {
    fn main() {
        // init; rejestracja timerów / fd / IRQ → kolejka
    }
    fn on_tick() { … }
}
```

Albo ciaśniej (ciało ≈ setup + run):

```klin
$event_loop() {
    eloop.every_ms(100, on_tick)
    // expand → main z while { eloop.poll(); wfi() } / jawnym run()
}
```

### Z RTOS — loop tylko na wybranym tasku

```klin
$rtos_task("net", 1024, 3) {
    $event_loop() {
        eloop.on(sock_readable, handle_pkt)
    }
}

$rtos_task("blink", 512, 2) {
    // bez loopa — delay / toggle
}
```

| | `$event_loop` (lib / 026) | `async` / `await` |
|---|---|---|
| Pętla poll + kolejka + WFI | tak | — |
| Jawne bufory / `Allocator` | tak | — |
| Cukier `await foo()` | nie | feature rdzenia (018 / tu) |

Minimalny obraz po expandzie (idea):

```klin
fn main() {
    eloop.init(queue_buf[:])
    eloop.every_ms(100, on_tick)
    eloop.run()   // while { poll(); } — jawne, w lib
}
```

Porównanie `$…` vs `@[meta]` / `@[task]`: tabela w [028](028-freertos.md).

## Hipotezy techniczne (nie zobowiązanie)

- **A)** opcjonalny moduł + jawny executor / `Allocator` (raczej host)
- **B)** desugar do jawnej state machine w `.c`
- **C)** cukier nad FreeRTOS (028), nie „Node na MCU”

Wejścia (warianty z 028): `main` + dekorowane `fn` **lub** `main_N` / `task_N`.

## Czego nie robić na start

Promise GC, ukryty scheduler, async jako domyślny bare-metal, **wymuszenie**
loopa na każdym tasku, ukryte automatyczne mutexy.
