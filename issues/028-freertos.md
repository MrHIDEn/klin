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

## Biblioteka `klinrtos` a „dekoratory” tasków (ustalone)

Pytanie: czy zewnętrzna lib Klin (wiązania RTOS, nie stdlib — [024](024-rtos.md))
może dostarczać dekoratory do oznaczania fn/metod jako tasków?

**Atrybuty (`@[…]`) obsługuje kompilator**, nie paczka `.kl`. Sama biblioteka
**nie** dodaje prawdziwego `@[task]`, jeśli frontend tego nie zna (por. ISR:
[030](030-isr-decorators.md)).

Co lib **może** (bez magii w rdzeniu):

| Mechanizm | Realizm |
|---|---|
| API + fn-pointer: `rtos.create(blink_task, stack[:], prio)` | tak |
| Makra `$…` (026) generujące entry + rejestrację („dekorator-like”) | tak |
| `@[codename("…")]` na entry (jak 010) | tak — już w języku |
| Prawdziwy `@[task(stack=…, prio=…)]` w checkerze/emit | tylko ze wsparciem kompilatora albo ekspandem makra do znanego kodu |

**Metody jako taski:** FreeRTOS zwykle chce `void task(void*)` (prototyp C), nie
metodę na `self`. Sensowniej: wolna `fn` + kontekst w `arg`, ewentualnie makro
generujące wrapper. Magiczne `fn (mut app: App) run()` jako task bez wrappera
ABI — słabo.

Zasada nadrzędna: dekorator / makro **nie** ukrywa alokacji TCB/stacku ani
startu schedulera — stack/TCB/prio pozostają jawne.

### Preferowany kierunek ergonomii: makro w lib (nie user-`@[…]`)

Cel „lib upraszcza app” jest OK. Otwarte dekoratory jak w Python/TS
(`@[moj]` zdefiniowany w libce) — **nie**: atrybuty to allowlista kompilatora;
owijanie fn w runtime nie pasuje do modelu C / zasady nadrzędnej.

Narzędzie w Klinie: **makra `$…` ([026](026-preprocessor.md))** albo jawne API.
Preferowany szkic składni (ustalenie kierunkowe — nie speć implementacji):

```klin
$rtos_task("blink", 512, 2) {
    // ciało taska — expand → fn + codename + rejestracja / tabela
}
```

Równoważnie, bez makra (nadal proste, zero magii):

```klin
@[codename("blink_task")]
fn blink_task(arg: *mut u8) { … }

fn main() {
    rtos.create(blink_task, stack[:], prio)
    rtos.start()
}
```

`@[task(…)]` w kompilatorze — tylko gdy ten sam wzorzec wraca w wielu libkach
i chcemy jedną składnię atrybutów; domyślnie **nie** budować ogólnego systemu
user-dekoratorów. Por. ISR: [030](030-isr-decorators.md).

Porównanie cukru (ten sam efekt pod spodem: fn + stack + rejestracja):

| | `$rtos_task` (lib / 026) | `@[meta("rtos.task", …)]` | `@[task(…)]` |
|---|---|---|---|
| Działa bez nowego atrybutu w rdzeniu | tak | nie (hook / plugin) | nie (allowlista) |
| Składnia „jak dekorator” | średnio (`$` + blok) | bliżej TS/Python | bliżej TS/Python |
| Parametry stack/prio jawne | tak | tak | tak |
| Lib bez forka kompilatora | tak | słabo | nie |

Szkic `@[meta]` (hipotetyczny — **nie** w języku dziś):

```klin
@[meta("rtos.task", stack=512, prio=2)]
fn blink(arg: *mut u8) { … }
```

Albo stringowo: `@[meta("rtos.task:stack=512,prio=2")]`. Kto czyta `meta`?
Albo makro/skaner w libce, albo kompilator z hookiem — prawie plugin system.
Dlatego preferowane `$rtos_task`, nie ogólne user-`@[…]`.

Event-loop w tasku: to samo podejście makrami — [029](029-async-event-loop.md)
(`$event_loop`, zagnieżdżalne w `$rtos_task`).

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

`examples/stm32/freertos_blink/` — ≥2 taski, delay, LED; bez narzutu vs C+FreeRTOS.
