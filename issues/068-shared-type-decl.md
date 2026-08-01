# 068 — Wspólna adnotacja typu (`a, b: i32`)

**Status:** 💭 do rozważenia
**Zależy od:** [002](002-tablica-symboli-checker.md), [004](004-funkcje.md), [005](005-struktury-metody.md)

## Motywacja

Dziś każda nazwa niesie własny typ:

```
fn add(a: i32, b: i32) -> i32 { … }
struct Point { x: f64, y: f64 }
let a: i32 = 1, b: i32 = 2   // jeśli kiedyś multi-let
```

W Go (i podobnie w V) ten sam typ można podać raz dla grupy nazw:

```
fn add(a, b: i32) -> i32 { … }
struct Point { x, y: f64 }
```

Skrót znika w AST / emisji C — to tylko cukier parsera (D1 OK).

## Reguła

**Oba podejścia są legalne** i oznaczają to samo:

| Forma | Znaczenie |
|---|---|
| `a: i32, b: i32` | jawnie, jak dziś |
| `a, b: i32` | wspólny typ dla listy nazw |

Mieszanie w jednej liście OK, np. `a, b: i32, c: f64` ≡ `a: i32, b: i32, c: f64`.
Każda grupa kończy się `: typ`; nazwy bez typu przed przecinkiem należą do
następnej grupy z adnotacją.

## Zakres (propozycja)

1. **Parametry funkcji** — MVP, największy zysk czytelności.
2. **Pola struktur** — naturalne rozszerzenie (`x, y: f64`).
3. **Lokalne `let` / `let mut`** — tylko jeśli kiedyś będzie multi-deklaracja
   w jednym zdaniu; dziś nie wymuszać.

`klin fmt` może zostawić formę źródłową (nie rozwijać `a, b: T` do
`a: T, b: T`), albo normalizować — decyzja przy implementacji (jak przy [055](055-short-decl.md)).

## Poza zakresem

- zmiana semantyki typów / domyślnych wartości
- generyki / wspólny typ jako „parametr typu” ([034](034-typy-generyczne.md))
- wymuszanie jednej formy — obie zostają

## Kryterium ukończenia

- [ ] parser: `a, b: T` w parametrach (i ewent. polach struct)
- [ ] checker / emisja: jak przy rozwinięciu do osobnych `name: T`
- [ ] złoty test + błąd przy `a, b` bez `: typ`
- [ ] wpis w `note/` / README (składnia)
