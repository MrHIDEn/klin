# Klin — kolejność prac

Kroki definiowane przez **to, co się kompiluje**, nie przez to, jakie
komponenty istnieją.

## Kolejka główna (fundament) — ✅

| # | Zadanie | Status | Zależy od |
|---|---|---|---|
| [000](000-decyzje-fundamentalne.md) | Trzy decyzje fundamentalne | ✅ | — |
| [001](001-pusty-przelot.md) | **Pusty przelot: hello world** | ✅ | 000 |
| [002](002-tablica-symboli-checker.md) | Tablica symboli i type checker | ✅ | 001 |
| [003](003-przeplyw-sterowania.md) | Przepływ sterowania | ✅ | 002 |
| [004](004-funkcje.md) | Funkcje | ✅ | 003 |
| [005](005-struktury-metody.md) | Struktury i metody | ✅ | 004 |
| [006](006-moduly.md) | Moduły | ✅ | 005 |
| [007](007-wskazniki-tablice-slice.md) | Wskaźniki, tablice, slice'y | ✅ | 006 |
| [008](008-defer.md) | `defer` | ✅ | 007 |
| [009](009-bledy.md) | Błędy jako wartości | ✅ | 008 |
| [010](010-bare-metal.md) | **Bare metal: LED na STM32** | ✅ | 009 |
| [011](011-svd.md) | Generator SVD (`svd2klin`) | ✅ | 010 |

Po **010** język robi to, po co powstał. Po **011** jest generator rejestrów
z SVD. Dalsza praca to rozwój (backlog poniżej), nie budowa rdzenia od zera.

---

## Backlog — zrobione

| # | Zadanie | Status | Zależy od |
|---|---|---|---|
| [012](012-stdlib-io.md) | Opcjonalny moduł I/O (`io.print` / `println`) | ✅ | 006 |
| [014](014-match.md) | `match` (domyślny break, `1,2,3` / `4..=10`, stmt+expr) | ✅ | 003 |
| [016](016-string-interpolation.md) | Interpolowane napisy | ✅ | 012 |
| [017](017-collection-methods.md) | Metody kolekcji (`slice` + `slice_alloc`; +typy i64/f64, +ops) | ✅ | 007, 057 |
| [019](019-default-int-types.md) | Domyślne typy (`int` / `float` → `i32` / `f64`) | ✅ | 002 |
| [020](020-biblioteki-klin.md) | Własne biblioteki Klina (`lib/` / `-I` / `KLIN_PATH`) | ✅ | 006 |
| [021](021-biblioteki-c.md) | Biblioteki C (FFI / link) | ✅ | 006, 010 |
| [022](022-biblioteki-asm.md) | Jednostki ASM (`.s` via `@[link]`) | ✅ | 021 |
| [023](023-examples.md) | Katalog `examples/` (+ `stm32/`) | ✅ | 001+ |
| [025](025-english-project.md) | English project (except `issues/` + `note/`) | ✅ | — |
| [026](026-preprocessor.md) | Preprocessor (`$fn`…, D3) | ✅ | 010+ |
| [027](027-svd-ergonomic-api.md) | Ładne API SVD (`$peripherals_from_svd`) | ✅ | 011, 026 |
| [032](032-klin-run.md) | CLI: `klin run <plik.kl>` | ✅ | 001 |
| [033](033-gofmt-style.md) | Formatowanie w stylu Go (`klin fmt`) | ✅ | 005+ |
| [035](035-klin-test.md) | `klin test` (jak `go test`, kod Klina) | ✅ | 032 |
| [036](036-docs-catchup.md) | Docs catch-up (CLI / stdlib / cechy ✅) | ✅ | 026–035 |
| [037](037-datetime-format.md) | Formatowanie daty/czasu (`stdlib/time`) | ✅ | 016 |
| [038](038-time-api.md) | Ergonomia API `time` (`until` / `abs` / `as_s`) | ✅ | 037 |
| [039](039-time-calendar.md) | Kalendarzowe `add_days` / miesiące / lata | ✅ | 037 |
| [045](045-cexport.md) | Eksport Klin → C (`@[cexport]`) | ✅ | 021 |
| [046](046-emit-h.md) | `--emit-h` (nagłówek C z `@[cexport]`) | ✅ | 045 |
| [047](047-directory-modules.md) | Katalog = jeden moduł (jak Go/V) | ✅ | 006, 020 |
| [055](055-short-decl.md) | Skrót `:=` (= `let mut`) | ✅ | 002 |
| [057](057-allocator.md) | `Allocator` (jawny alokator, D1) — `stdlib/mem` | ✅ | 007, 008 |

---

## Backlog — do rozważenia

| # | Zadanie | Status | Zależy od |
|---|---|---|---|
| [018](018-generators-yield.md) | Generatory / `yield` | 💭 | 004+ |
| [024](024-rtos.md) | RTOS (FreeRTOS / Zephyr / …) | 💭 | 010+ |
| [028](028-freertos.md) | Ładna współpraca z FreeRTOS | 💭 | 024, 010, 021 |
| [029](029-async-event-loop.md) | Event loop / async·await (duże zwierzę; MVP = lib bez async) | 💭 | 018?, 028?, 049? |
| [030](030-isr-decorators.md) | Przerwania przez dekoratory | 💭 | 010 |
| [031](031-biblioteki-hal.md) | Biblioteki HAL (Cube / LL) | 💭 | 010, 021 |
| [034](034-typy-generyczne.md) | Generyki w gramatyce — nie teraz (D3/`$fn`; ew. cukier później) | 💭 | 026 |
| [040](040-time-zones.md) | Strefy IANA + DST | 💭 | 037 |
| [041](041-time-locale-relative.md) | Locale dat + relative strings | 💭 | 037 |
| [042](042-time-format-luxon.md) | Dialekt formatu `yyyy-MM-dd` w `time` | 💭 | 037 |
| [043](043-rtc.md) | RTC → `Instant` (osobny moduł) | 💭 | 010, 031? |
| [044](044-cpu-cycles.md) | Cykle CPU / SysTick → `Duration` | 💭 | 010 |
| [048](048-import-aliases.md) | Aliasy importów (+ string lokalny) | ✅ | 006, 047 |
| [049](049-remote-imports.md) | Importy zdalne + `klin.mod` + `klin get` / `update` | ✅ | 048, 020, 047, 063 |
| [063](063-remote-fixture-osa.md) | Fixture zdalny `mrhiden/osa` (e2e 049) | ✅ | 047 |
| [065](065-project-lockfile.md) | `klin.lock` / sumy (jak go.sum) | ✅ | 049 |
| [066](066-klin-upgrade-outdated.md) | `klin upgrade` / outdated (nowsze deps) | ✅ | 049 |
| [067](067-homebrew.md) | Homebrew: `brew install klin` (formula + CI) | ✅ | — |
| [050](050-sqlite-wrapper.md) | Opakowanie SQLite (FFI, niski priorytet) | 💭 | 021 |
| [070](070-host-orm-sqlite.md) | ORM-like / typed repo nad SQLite (host, niski priorytet) | 💭 | 050, 021 |
| [051](051-json-wrapper.md) | Opakowanie JSON + ścieżki `$…` (niski priorytet) | 💭 | 021, 026? |
| [052](052-klinstruct.md) | `klinstruct` — pack/unpack jak cstruct (niski priorytet) | 💭 | 007, 020/047 |
| [053](053-device-board-assets.md) | `$device` + Go-like fetch SVD (IOC/board) | 💭 | 027, 049? |
| [054](054-embedded-project-layout.md) | Wygląd / układ projektu embedded | 💭 | 023, 010 |
| [056](056-destructuring.md) | Dekonstrukcja (`{}` / `[]` / multi-assign; bez tupli) | ✅ (A+A′+B+C+D; bare `[]=` pominięte) | 005, 007? |
| [058](058-source-file-split.md) | Podział dużych plików źródłowych kompilatora (dług techn.) | 💭 | — |
| [059](059-kstruct-macros.md) | Makra `$kstruct` / `$kstruct_from` (bogatsze klinstruct) | 💭 | 026, 052 |
| [060](060-map-kv.md) | Mapa KV (hash map) — język / stdlib / C | 💭 | 007, 057? |
| [061](061-micropython-machine-api.md) | API w stylu MicroPython `machine` (PWM, UART, …) | 💭 | 010, 031? |
| [062](062-targets-esp-rp.md) | Cele MCU: ESP32 / RP2040 / RP2350 | 💭 | 010 |
| [064](064-if-cond-struct-literal-parse.md) | Warunek `if`/`while` kończący się nazwą mylony z literałem struktury | ✅ | — |
| [068](068-shared-type-decl.md) | Wspólna adnotacja typu (`a, b: i32` jak Go; obie formy OK) | 💭 | 002, 004, 005 |
| [069](069-eventemitter-signals.md) | Observer / EventEmitter / Signals (biblioteka; JS-signals jawnie) | 💭 | 013, 057 |
| [071](071-lambda.md) | Lambdy / `fn (…) => expr` (werdykt: nie teraz; po D7) | 💭 | fn-ptr, D7 |

---

## Zasady (zawsze)

Szczegóły w `note/02-architektura.md`.

1. **Testy złote** — `.kl` + oczekiwane wyjście.
2. **`#line` w emisji** — każdy token nosi pozycję.
3. **Błędy łapie frontend** — gcc nie powinien krzyczeć na wygenerowany kod.
4. **Ręczny parser** zejściem rekurencyjnym — bez generatorów.
5. **Zasada nadrzędna** — brak ukrytej alokacji / przepływu / kosztu; przy nowej
   cesze `objdump` Klin vs ręczny C.
6. **Nie rozszerzać zakresu** bieżącego kroku z tej listy.
