# Klin — kolejność prac

Kroki definiowane przez **to, co się kompiluje**, nie przez to, jakie
komponenty istnieją. Inaczej się w tym tonie.

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
| [011](011-svd.md) | Generator SVD | ✅ | 010* |

\* 011 jest projektem niezależnym — może powstać wcześniej jako osobne
narzędzie. Generator SVD nie ma nic wspólnego z kompilatorem: czyta XML,
wypluwa plik z definicjami rejestrów. Wejście → wyjście, koniec.

---

## Do rozważenia (nie w kolejce głównej)

| # | Zadanie | Status | Zależy od |
|---|---|---|---|
| [012](012-stdlib-io.md) | Opcjonalny moduł I/O (`println`) | 💭 | 006 |
| [016](016-string-interpolation.md) | Interpolowane napisy | 💭 | 012? |
| [017](017-collection-methods.md) | Metody kolekcji (`map`/`filter`/…) | 💭 | 007 |
| [018](018-generators-yield.md) | Generatory / `yield` | 💭 | 004+ |
| [019](019-default-int-types.md) | Domyślne typy (`int` / literały) | ✅ | 002 |
| [020](020-biblioteki-klin.md) | Własne biblioteki Klina | 💭 | 006 |
| [021](021-biblioteki-c.md) | Biblioteki C (FFI / link) | 💭 | 006? |
| [022](022-biblioteki-asm.md) | Biblioteki / jednostki ASM | 💭 | 010? |
| [023](023-examples.md) | Katalog `examples/` (demo) | 💭 | 001+ |
| [024](024-rtos.md) | RTOS (FreeRTOS / Zephyr / …) | 💭 | 010+ |
| [025](025-english-project.md) | English project (except pl-PL) | ✅ | — |
| [026](026-preprocessor.md) | Preprocessor (`$…`, D3) | 💭 | 010+ |
| [027](027-svd-ergonomic-api.md) | Ładne API SVD | 💭 | 011, 026 |
| [028](028-freertos.md) | Ładna współpraca z FreeRTOS | 💭 | 024, 010, 021 |
| [029](029-async-event-loop.md) | Event loop / async·await | 💭 | 018?, 028? |
| [030](030-isr-decorators.md) | Przerwania przez dekoratory | 💭 | 010 |
| [031](031-biblioteki-hal.md) | Biblioteki HAL (Cube / LL) | 💭 | 010, 021 |

---

## Dwa kamienie milowe

**Po 001** — cały rurociąg działa. Każda następna cecha to dokładanie
do działającej maszyny, a nie budowa od zera.

**Po 010** — język robi to, po co powstał. Wszystko wcześniej to droga,
wszystko później to rozwój.

---

## Zasady obowiązujące w każdym kroku

Szczegóły w `note/02-architektura.md`.

1. **Testy złote** — plik `.kl` + oczekiwane wyjście. Bez tego po trzech
   tygodniach przestanę cokolwiek zmieniać ze strachu.
2. **`#line` w emisji** od pierwszego dnia. Lekser nosi pozycję w każdym
   tokenie.
3. **Wszystkie błędy łapie frontend.** Jeśli gcc krzyczy na wygenerowany
   kod — to mój bug.
4. **Ręczny parser zejściem rekurencyjnym.** Bez generatorów.
5. **Test zasady nadrzędnej** przy każdej nowej cesze: `objdump -d`
   wersji w Klinie vs wersji ręcznej w C. Identyczne albo cecha wypada.

---

## Czego pilnować, żeby nie utonąć

- **Nie rozszerzać zakresu kroku.** Zwłaszcza 001 — pokusa dopisania
  zmiennych jest ogromna i jest głównym ryzykiem projektu.
- **Nie wracać do nazwy.** Zamknięte: Klin, `.kl`, MIT.
- **Nie zaczynać od SVD.** To osobny, ukończalny w weekend projekt —
  kuszący, ale nie jest krokiem w stronę kompilatora.
- **Nie przepisywać na inny język przed 005.** Większość projektów tego
  typu nie dochodzi do 005; optymalizowanie pod ten scenariusz jest
  przedwczesne.
