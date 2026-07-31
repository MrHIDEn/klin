# 017 — Metody kolekcji (`map` / `filter` / …)

**Status:** ✅
**Zależy od:** 007 (slice ✅); fn-pointer (faza 2 ✅); warstwa 2: `Allocator` ([057](057-allocator.md) ✅)

## Kontekst

W JS: `arr.map(…)`, `filter`, `reduce`, `find`, `forEach`. Wygodne, ale w
językach systemowych łatwo o ukrytą alokację i ukryty koszt (callback, heap).

## Decyzje API

### Zasada

Żadnego gołego `xs.map(f)` w stylu JS. Każda operacja produkująca dane albo
bierze gotowy bufor, albo (warstwa 2) jawny `Allocator`. `defer` zawsze po
stronie callera — API nigdy nie rejestruje zwolnienia ani autofree.

```
// OK — zero alokacji (monomorficzne nazwy przez $fn)
let n = slice.filter_into_i32(xs, dst, pred) or { 0 }
let y = slice.reduce_i32(xs, 0, add)

// OK — widać koszt (osobny moduł, żeby `import slice` nie ciągnął heap)
let mut out = slice_alloc.map_alloc_i32(&a, xs, f) or { mem.empty_i32() }
defer mem.free_i32(&a, out)
```

Bez generyków w gramatyce: `each_i32` / `map_into_u8` (instancje w
[`stdlib/slice.kl`](../stdlib/slice.kl)); `map_alloc_i32` w
[`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl).

### Nazewnictwo

- Zero alokacji, krótkie: `each`, `index_of`, `any`, `all`, `count`, `reduce`
  (`index_of` zwraca indeks, nie element — nie mylić z JS `find`)
- Produkcja do bufora: zawsze sufiks `_into` (`map_into`, `filter_into`)
- Alokacja: zawsze sufiks `_alloc` (`map_alloc`, `filter_alloc`) — warstwa 2
- Unikać gołych `map` / `filter` bez sufiksu

### Forma wywołania (nie metody na `[]T`)

Warstwa 0+1 — moduł `slice` (bez `mem` / bez `malloc` w emisji):

```
import slice
slice.map_into_i32(xs, dst, f)
```

Warstwa 2 — osobny moduł `slice_alloc` (importuje `mem` + `slice`). Emit nie
usuwa nieużywanych `pub`, więc trzymanie `*_alloc` w `slice.kl` pociągnęłoby
heap przy każdym `import slice` (freestanding / zasada nadrzędna).

```
import mem
import slice_alloc
slice_alloc.map_alloc_i32(&a, xs, f)
```

### Ownership — bez `using` (C#)

| Wariant | Co powstaje | Kto zwalnia |
|---|---|---|
| `*_into(dst, …)` | nic nowego — zapis do bufora callera | nikt (caller ma `dst`) |
| `*_alloc(a, …)` | **nowy** bufor | caller: `defer mem.free_i32(&a, out)` |

### Callback

Wskaźniki na funkcje bez capture ([note/13-fn-ptr.md](../note/13-fn-ptr.md)).

Zapis przez `dst[i]` na slice: dozwolony (nagłówek slice to wartość; pamięć
elementów współdzielona z callerem — jak Go).

## Warstwa 0 + 1 (MVP) — ✅

| Funkcja | Alokacja | Uwagi |
|---|---|---|
| `each` | brak | efekt uboczny |
| `index_of` | brak | zwraca indeks; przy braku: **`-1`** |
| `any` / `all` / `count` | brak | |
| `reduce` | brak | akumulator + funkcja |
| `map_into` | brak | wymaga `dst.len == xs.len`; zwraca `!i32` (`0` / `error(1)`) |
| `filter_into` | brak | wymaga `dst.len >= xs.len`; zwraca `!i32` (liczba zapisanych / `error(1)`) |

Poza MVP: `flatMap`, `groupBy`, lazy iteratory (018), sort z
comparator-domknięciem.

## Warstwa 2 (`*_alloc`) — ✅

Typ `Allocator`: [`stdlib/mem`](../stdlib/mem.kl)
([note/14-allocator.md](../note/14-allocator.md)).

Moduł [`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl):

- `map_alloc_i32` / `map_alloc_u8(a, xs, f): ![]T` — `alloc(xs.len)` + mapowanie
- `filter_alloc_i32` / `filter_alloc_u8(a, xs, pred): ![]T` — dwa przebiegi
  (`count` → `alloc(n)` → kopiowanie)
- Alokator: `*mut mem.Allocator`; błędy `mem.alloc_*` przez `!` / `or`
- Caller: `defer mem.free_i32(&a, out)` (API nie rejestruje `defer`)

## Fazy

1. **Docs** — projekt API. ✅
2. **Fn-pointer** — `fn(...): T`. ✅
3. **stdlib `slice` warstwa 0+1** — ✅ ([`stdlib/slice.kl`](../stdlib/slice.kl))
4. **`Allocator`** ([057](057-allocator.md) ✅) + warstwa 2 `*_alloc` — ✅
   ([`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl))

Golden: `test/fn_ptr.kl`, `test/slice_ops.kl`, `test/slice_alloc_ops.kl`.  
Examples: `examples/fn_ptr.kl`, `examples/slice_ops.kl`,
`examples/slice_alloc_demo.kl`.

`map_into_*` / `filter_into_*` zwracają `!i32` (Klin nie ma `!void`): sukces
`0` / liczba elementów; błąd długości bufora → `error(1)`.

## Non-goals

- Kopiowanie JS 1:1 (`map` zawsze nowa tablica z GC).
- `using` / RAII / autofree wyniku.
- Domknięcia (D7), generyki w rdzeniu (034), generatory (018).
- Metody na `[]T` przed decyzją o receiverze slice.
- DCE nieużywanych `pub` w emit (dlatego osobny moduł `slice_alloc`).

## Kryteria ukończenia

### Faza docs

- [x] Projekt API / nazwy / ownership / fazy spisane w tym issue

### Faza fn-pointer

- [x] Typ `fn(...): T` + przekazanie / wywołanie
- [x] Golden + example

### Faza warstwa 0+1

- [x] Moduł `slice` z funkcjami MVP (`i32`, `u8`)
- [x] Testy złote
- [x] Brak `malloc` w emisji (pętla jak ręczny C)

### Faza warstwa 2

- [x] `map_alloc` / `filter_alloc` w `slice_alloc` + dokumentacja `defer mem.free_*`
- [x] Testy złote z jawnym `Allocator`
