# 070 — ORM-like / typed repo nad SQLite (host)

**Status:** 💭 do rozważenia (niski priorytet — nieblokujące)
**Zależy od:** [050](050-sqlite-wrapper.md) (cienki FFI), [021](021-biblioteki-c.md);
  mile [026](026-preprocessor.md) / [057](057-allocator.md)

## Kontekst

Cel: aplikacje na **maszynach host** (desktop / serwer / Linux), nie bare-metal.
Unikać ręcznego klejenia SQL wszędzie — bez portowania Hibernate do C.

W czystym C pełnych ORMów prawie nie ma (brak refleksji / generyków). Sensowne
ORMy SQLite są zwykle w **C++** (`sqlite_orm`, sqlpp11, ODB). Klin kompiluje
do C → naturalna ścieżka to **sqlite3 C API** + warstwa Klin, nie binding C++.

Embedded: tylko gdy jest OS + heap + FS (np. RPi / SBC z Linuxem ≈ host).
Klasyczny STM32 bez heap — poza tym issue (SQLite i tak mallocuje wewnętrznie).

## Kierunek (nie klasyczny ORM)

1. **Warstwa 0** — [050](050-sqlite-wrapper.md): `open` / `prepare` / `bind` /
   `step` / `close`, link `-lsqlite3`.
2. **Warstwa 1 (to issue)** — typed helpers / „repo”:
   - codegen ze schematu (`.sql` / deklaracje) **albo** `$fn` (D3) generujący
     `insert` / `get_by_id` / proste `query_*` dla konkretnych structów;
   - ownership i alokacja **jawne** (`Allocator` / bufory callera / kontrakt C);
   - `defer` po stronie callera — bez autofree / RAII.
3. **Nie obiecywać** magicznego `users.filter(u => u.age > 18)` bez SQL ani
   bez własnego DSL + codegen.

Szkic użycia (host):

```klin
let db = sqlite.open("app.db")!
defer db.close()
let u = user_repo.get(db, id)!   // wygenerowane / $fn — typed, nie surowy SQL wszędzie
```

## Poza zakresem

- przepisanie SQLite w Klinie
- pełny ORM jak EF / Hibernate / Luxon-style lazy
- port C++ ORMa do Klina
- bare-metal / VFS na MCU (osobna decyzja; nie priorytet)
- priorytet względem rdzenia języka, embedded LED, FFI podstaw

## Kryteria (gdy kiedyś implementacja)

- [ ] Docs: model warstw 0/1 + ownership
- [ ] Zależność od działającego wrappera 050
- [ ] Przykład host + testy złote (deterministyczne, bez „żywego” internetu)
- [ ] Zero ukrytej alokacji po stronie API Klina (malloc SQLite = kontrakt C)
