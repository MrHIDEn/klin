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

Wykonanie callbacka jest **wewnątrz** `run()` (gdy timer/zdarzenie dojrzeje),
nie w linii `every_ms`. `every_ms` tylko rejestruje fn-pointer. W tym modelu
**nie ma** `async`/`await` — sama kooperacyjna pętla + zwykłe `fn`.

## Werdykt: lib vs rdzeń vs Promise (ustalone kierunkowo)

### Event loop — część Klina czy user?

**Pętla = opcjonalna biblioteka, nie cecha języka.**

| | Gdzie |
|---|---|
| `eloop.init` / `every_ms` / `run` / kolejka | lib (stdlib opcjonalna *albo* paczka usera / [049](049-remote-imports.md)) |
| `$event_loop { … }` | makro w tej libce |
| Obowiązkowy loop w każdym programie | **nie** |

User **może napisać własną** implementację (inny poll, WFI, host `select`).
Oficjalna lib (gdy powstanie) to domyślny prosty wariant — styl [012](012-stdlib-io.md),
nie runtime jak GC.

### `async` / `await` — część Klina?

**Jeśli w ogóle — feature rdzenia** (parser + emit → maszyna stanów). Lib sama
nie doda prawdziwego `await`.

**Nie jest wymagane** do event-loopa. Najpierw lib z callbackami; `async`/`await`
to osobna, późna decyzja (też [018](018-generators-yield.md)).

```
opcjonalnie:  [ lib eloop ]     ← bez zmian języka
później?:     [ async/await ]   ← tylko kompilator
```

### Czy `async`/`await` wymaga Promise/Future (jak JS)?

**Nie.** Sensowny model pod Klin (bliżej Rust / desugar, nie Node):

- `async fn` → kompilator robi **struct stanu** + `poll` / resume (albo switch),
- `await` → zapisz stan, wróć do loopa, wznów potem,
- executor = **jawna** pętla (`eloop.run` / task RTOS) — nie ukryty runtime,
- **bez** heapowego `Promise` na każdą metodę / bez GC microtasków.

Metody mogą być `async`, ale to nie znaczy „każda metoda zwraca Promise”.
Wynik to zwykły typ / `!T` + maszyna stanów; stan na stosie / w buforze
callera, nie magiczny Future w runtime.

| Model JS | Model bliższy Klinowi |
|---|---|
| `Promise` na stercie | stan na stosie / w buforze callera |
| domyślny event loop runtime | `eloop.run()` / task — jawne |
| każda async metoda = Promise | desugar → state machine |

Taski RTOS / ticki event-loop **nie** wymagają zamiany metod w Promise/Future —
wystarczą wolne `fn` (+ opcjonalnie `$rtos_task` / `$event_loop`).

### Szkic 1-plikowy: `async`/`await` (styl Rust) + remote lib

**Niekompilowalne dziś.** Plik roboczy:
[`examples/sketch_async_eventloop.kl`](../examples/sketch_async_eventloop.kl).
Wymaga feature rdzenia (`async`/`await`) oraz paczki po
`klin get github/mrhiden/eventloop@…` ([049](049-remote-imports.md)).

```klin
/// SKETCH — Rust-like state machine + explicit executor (no JS Promise).

import "github/mrhiden/eventloop"
import io

async fn delay_ms(ms: i32) {
    eventloop.sleep_ms(ms).await
}

async fn ticker() {
    while true {
        io.println("tick")
        delay_ms(100).await
    }
}

fn main() {
    let mut queue_buf: [64]u8
    let mut ex = eventloop.Executor{}
    ex.init(queue_buf[:])
    ex.spawn(ticker)   // stan maszyny w executorze / buforze — nie heap Promise
    ex.run()           // tu jest „życie”: poll timerów → resume po await
}
```

Gdzie co się dzieje:

| Fragment | Rola |
|---|---|
| `async fn ticker` | cukier rdzenia → struct stanu + `poll` (jak Rust) |
| `delay_ms(100).await` | zawieś `ticker`, wróć do executora |
| `eventloop.Executor` / `run` | **biblioteka zdalna** — jawna pętla |
| `queue_buf` | pamięć callera — zero ukrytego malloc |

Bez `async` ten sam efekt = callbacki + `every_ms` + `run` (sekcja wyżej).

## Hipotezy techniczne (nie zobowiązanie)

- **A)** opcjonalny moduł + jawny executor / `Allocator` (raczej host)
- **B)** desugar do jawnej state machine w `.c`
- **C)** cukier nad FreeRTOS (028), nie „Node na MCU”

Wejścia (warianty z 028): `main` + dekorowane `fn` **lub** `main_N` / `task_N`.

## Czego nie robić na start

Promise GC, ukryty scheduler, async jako domyślny bare-metal, **wymuszenie**
loopa na każdym tasku, ukryte automatyczne mutexy, wymuszanie Promise/Future
na metodach jak w JS.
