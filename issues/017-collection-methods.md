# 017 — Metody kolekcji (`map` / `filter` / …)

**Status:** 💭 do rozważenia (projekt API zamknięty; kod nie)
**Zależy od:** 007 (slice ✅); implementacja: wskaźniki na funkcje; warstwa 2: `Allocator`

## Kontekst

W JS: `arr.map(…)`, `filter`, `reduce`, `find`, `forEach`. Wygodne, ale w
językach systemowych łatwo o ukrytą alokację i ukryty koszt (callback, heap).

## Decyzje API

### Zasada

Żadnego gołego `xs.map(f)` w stylu JS. Każda operacja produkująca dane albo
bierze gotowy bufor, albo (warstwa 2) jawny `Allocator`. `defer` zawsze po
stronie callera — API nigdy nie rejestruje zwolnienia ani autofree.

```
// OK — zero alokacji
let n = slice.filter_into(xs, dst, pred)
let y = slice.reduce(xs, 0, add)

// OK później — widać koszt
let out = slice.map_alloc(a, xs, f)!
defer a.free(out)
```

### Nazewnictwo

- Zero alokacji, krótkie: `each`, `find` / `index_of`, `any`, `all`, `count`,
  `reduce`
- Produkcja do bufora: zawsze sufiks `_into` (`map_into`, `filter_into`)
- Alokacja: zawsze sufiks `_alloc` (`map_alloc`, `filter_alloc`) — warstwa 2
- Unikać gołych `map` / `filter` bez sufiksu

### Forma wywołania (nie metody na `[]T`)

Checker dziś wymaga structa jako receivera metody. Slice to nie struct.

API jako **wolne funkcje** w module `slice` (wzorzec jak `io` w 012):

```
import slice
slice.map_into(xs, dst, f)
```

Opcjonalne `fn (xs: []T) …` dopiero po świadomym rozszerzeniu receivera o
slice (osobna decyzja).

### Ownership — bez `using` (C#)

Nie dodajemy `using` / `IDisposable` (RAII / blisko autofree z D1/D6). Scope
cleanup w Klinie to **`defer` u callera**.

| Wariant | Co powstaje | Kto zwalnia |
|---|---|---|
| `*_into(dst, …)` | nic nowego — zapis do bufora callera | nikt (caller ma `dst`) |
| `*_alloc(a, …)` | **nowy** bufor (nazwa `_alloc` to mówi) | caller: `defer a.free(out)` |

Sufiks `_alloc` + jawny `a` krzyczą w składni; `defer` pilnuje `return` /
`break` (008). Arena: jeden `defer arena.deinit()` zamiast per-wynik.

### Callback

Implementacja stdlib **po** wskaźnikach na funkcje **bez capture** (emisja =
wskaźnik C, zero heap). Domknięcia (D7) i lazy (018) — poza tym issue.
Makra z ciałem wyrażenia — ewentualna alternatywa później; nie blokują
zapisu API.

## Warstwa 0 + 1 (MVP)

| Funkcja | Alokacja | Uwagi |
|---|---|---|
| `each` | brak | efekt uboczny |
| `find` / `index_of` | brak | przy braku: **`-1`** |
| `any` / `all` / `count` | brak | |
| `reduce` | brak | akumulator + funkcja |
| `map_into` | brak | `dst.len == xs.len` (błąd frontendu / assert) |
| `filter_into` | brak | zwraca liczbę zapisanych; `dst.cap >= xs.len` |

Poza MVP: `flatMap`, `groupBy`, lazy iteratory (018), sort z
comparator-domknięciem.

## Warstwa 2 (`*_alloc`) — to samo issue, faza późniejsza

Nie osobny ticket. Wymaga typu `Allocator` (dziś tylko D1 w
`note/01-decyzje.md`).

- API: `map_alloc(a, xs, f)`, `filter_alloc(a, xs, pred)`
- `filter_alloc`: dwa przebiegi albo `cap = xs.len` + trim — jawne w docs
- Caller: `defer a.free(out)` albo `defer arena.deinit()`

## Fazy

1. **Docs (ta iteracja)** — ten plik: zamknięty projekt API.
2. **Fn-pointer** — typy wskaźników na funkcje bez capture.
3. **stdlib `slice` warstwa 0+1** — odczyty + `*_into`.
4. **`Allocator`** + warstwa 2 `*_alloc`.

## Non-goals

- Kopiowanie JS 1:1 (`map` zawsze nowa tablica z GC).
- `using` / RAII / autofree wyniku.
- Domknięcia (D7), generyki w rdzeniu (034), generatory (018) — nie
  wymagane na MVP.
- Metody na `[]T` przed decyzją o receiverze slice.

## Kryteria ukończenia

### Faza docs

- [x] Projekt API / nazwy / ownership / fazy spisane w tym issue

### Faza warstwa 0+1 (później)

- [ ] Moduł `slice` z funkcjami MVP
- [ ] Testy złote
- [ ] Test zasady nadrzędnej (`objdump` vs ręczna pętla w C)

### Faza warstwa 2 (później)

- [ ] `map_alloc` / `filter_alloc` + dokumentacja `defer a.free`
- [ ] Testy złote z jawnym `Allocator`
