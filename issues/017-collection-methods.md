# 017 — Metody kolekcji (`map` / `filter` / …)

**Status:** 💭 do rozważenia (projekt API zamknięty; kod nie)
**Zależy od:** 007 (slice ✅); implementacja: wskaźniki na funkcje; warstwa 2: `Allocator` ([057](057-allocator.md) ✅)

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

- Zero alokacji, krótkie: `each`, `index_of`, `any`, `all`, `count`, `reduce`
  (`index_of` zwraca indeks, nie element — nie mylić z JS `find`)
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
| `index_of` | brak | zwraca indeks; przy braku: **`-1`** |
| `any` / `all` / `count` | brak | |
| `reduce` | brak | akumulator + funkcja |
| `map_into` | brak | wymaga `dst.len == xs.len` (błąd frontendu / assert) |
| `filter_into` | brak | wymaga `dst.len >= xs.len` (miejsce na worst-case; slice ma tylko `ptr`/`len`, bez `cap` — 007); zwraca liczbę zapisanych `n` (`0…xs.len`); przy za małym `dst` — błąd frontendu / assert (przepełnienie nie milczy) |

Poza MVP: `flatMap`, `groupBy`, lazy iteratory (018), sort z
comparator-domknięciem.

## Warstwa 2 (`*_alloc`) — po [057](057-allocator.md) ✅

Typ `Allocator` jest w [`stdlib/mem`](../stdlib/mem.kl)
([note/14-allocator.md](../note/14-allocator.md)). Warstwa 2 `*_alloc` nadal
otwarta.

- API: `map_alloc(a, xs, f)`, `filter_alloc(a, xs, pred)`
- `filter_alloc`: dwa przebiegi albo alokacja na `xs.len` elementów i
  zwrócenie slice z `len = n` (bez pola `cap` w typie slice — 007)
- Caller: `defer a.free_bytes(out)` / `mem.free_i32` albo później `defer arena.deinit()`

## Fazy

1. **Docs** — ten plik: zamknięty projekt API. ✅
2. **Fn-pointer** — typy `fn(...): T` bez capture. ✅
3. **stdlib `slice` warstwa 0+1** — odczyty + `*_into`.
4. **`Allocator`** ([057](057-allocator.md) ✅) + warstwa 2 `*_alloc` (otwarte).

## Fn-pointer (faza 2)

Składnia typu: `fn(i32): bool`. Top-level `fn` jako wartość (decay jak C);
parametr / lokalna zmienna typu `fn(...)`; wywołanie `pred(x)`.

Golden: `test/fn_ptr.kl`. Example: `examples/fn_ptr.kl`.
Emisja: wskaźnik C — zero heap, bez domknięć (D7).

## Kryteria ukończenia

### Faza docs

- [x] Projekt API / nazwy / ownership / fazy spisane w tym issue

### Faza fn-pointer

- [x] Typ `fn(...): T` + przekazanie / wywołanie
- [x] Golden + example

### Faza warstwa 0+1 (później)

- [ ] Moduł `slice` z funkcjami MVP
- [ ] Testy złote
- [ ] Test zasady nadrzędnej (`objdump` vs ręczna pętla w C)

### Faza warstwa 2 (później)

- [ ] `map_alloc` / `filter_alloc` + dokumentacja `defer a.free`
- [ ] Testy złote z jawnym `Allocator`
