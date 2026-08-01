# 060 — Mapa KV (hash map)

**Status:** 💭 do rozważenia (niski priorytet — nieblokujące)
**Zależy od:** [007](007-wskazniki-tablice-slice.md); przy heap: [057](057-allocator.md); mile [021](021-biblioteki-c.md)

## Kontekst (notatki z rozmowy)

### C

- **Brak** wbudowanych map KV w języku i w libc.
- Lookup „po kluczu”: własna hash table / drzewo, albo `qsort`+`bsearch` na
  posortowanej tablicy, albo biblioteka (np. uthash, khash).
- `enum` w C to nazwane stałe **całkowite** (nie „enum na dowolnym typie”).
  Dopiero **C23** ma `enum E : uint8_t` (underlying type nadal integer).

### Trudność implementacji

- **MVP** (np. `string`/`int` → wskaźnik, open addressing / chaining): realne
  w krótkim czasie.
- **Mapa „produkcyjna”**: hashe, resize, delete, ownership kluczy, OOM,
  custom allocator — tu robi się trudno.
- Bare-metal bez `malloc`: zwykle fixed capacity / arena; ogólna mapa z heapa
  często nie pasuje do MCU.

### uthash / khash

Obie **małe** (header-only, ~1k linii lub mniej) — nie GLib. Runtime: overhead
na element + (zwykle) dynamiczny resize. Na host OK; na bare-metal nadal trzeba
świadomie o alokacji.

### Go / V

Obie mają **wbudowane** `map[K]V` w języku/runtime (V mocno jak Go). W C tego
poziomu nie ma — stąd osobne headery albo własny kod.

## Co to znaczy dla Klina

Zasada nadrzędna: **żadnej ukrytej alokacji / kosztu**. Jeśli mapa kiedyś
powstanie:

- nie jako magiczny builtin z ukrytym heaped grow przy `m[k] = v`,
- albo jawny `Allocator` ([057](057-allocator.md)) + API w stylu
  [017](017-collection-methods.md) (`map_*` / `put` z widocznym kosztem),
- albo cienki wrapper FFI na C (uthash/khash/`-l…`) jak [050](050-sqlite-wrapper.md),
- albo na embedded: tablica + `bsearch` / compile-time / ideal hash — bez ogólnej
  hash mapy w stdlib.

## Szkic (później — nie teraz)

1. Decyzja: język vs `stdlib/map` vs tylko przykład FFI.
2. Klucze MVP: `i32` / `u32` / `str`? (ownership stringów).
3. Host najpierw; bare-metal = fixed / arena albo poza zakresem.
4. Testy złote + `objdump` vs ręczny C przy grow/lookup.

## Poza zakresem

- implementacja w tym issue (tylko placeholder w roadmapie)
- ordered map / drzewo jako wymóg MVP
- priorytet względem rdzenia / embedded LED / bieżących issue
