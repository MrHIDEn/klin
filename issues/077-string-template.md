# 077 — Podmiana w napisach / szablony runtime (`format` / `template`)

**Status:** 💭 do rozważenia (niski priorytet — nieblokujące)
**Zależy od:** [007](007-wskazniki-tablice-slice.md) (slice/bufory), [057](057-allocator.md) (heap jawnie); w kontraście do [016](016-string-interpolation.md); KV jak [060](060-map-kv.md); miejsce/API jak [017](017-collection-methods.md), [012](012-stdlib-io.md)

## Pomysł (z rozmowy)

Chcę lib albo część w Klinie, która **podmienia wąsy** w napisie **w runtime**:

- **pozycyjnie**: `"{0}, {1}"`, `arg1`, `arg2`
- **słownikowo (KV)**: `"{aaa}, {bbb}"`, lista_kv

Czyli szablon-jako-**dane** (napis może być zmienną / z pliku / z konfiguracji),
a nie znany w czasie kompilacji.

## Różnica względem 016 (to nie to samo)

[016](016-string-interpolation.md) = **interpolacja compile-time**: `"$name"`,
`"${expr}"`, `"${x:0.00}"`. Wąsy i wyrażenia są znane kompilatorowi → emisja to
`printf` (zero alokacji, zero runtime). Tu przeciwnie: **wzorzec jest wartością**,
więc podmiana dzieje się w czasie działania (skan napisu, dopasowanie klucza).
Oba mają rację bytu i się uzupełniają.

## Zasada nadrzędna (kształtuje API)

Brak ukrytej alokacji / kontroli / kosztu. Zatem **nie** `str format(...)`
z magicznym heapem, tylko:

- **warstwa 1 (zero-alloc)** — pisanie do bufora dostarczonego przez callera:
  `fn render(tmpl: str, ..., out: []u8): !i32` (zwraca liczbę zapisanych bajtów;
  `!` = przepełnienie/zły wzorzec),
- **warstwa 2 (heap jawnie)** — przez `Allocator` ([057](057-allocator.md)), jak
  `slice_alloc`: `fn render_alloc(a: Allocator, tmpl: str, ...): !str` + `defer`
  u callera.

## Warianty

### A. Pozycyjne `{0} {1} …`

- Argumenty jako `[]str` (MVP: same napisy — bez generyków w gramatyce, D3).
- Typy inne niż `str` woła się po uprzednim sformatowaniu (`time.fmt`,
  interpolacja 016) → dostajemy `str` i wkładamy do listy.
- `{0}` może wystąpić wiele razy; indeks poza zakresem → błąd (`!`).

### B. Słownikowe `{klucz}`

- Lista par KV: `[]KV` gdzie `struct KV { key: str; val: str }` (proste,
  liniowe wyszukiwanie) — bez pełnej mapy z [060](060-map-kv.md).
- Klucz nieznaleziony → decyzja: błąd (`!`) czy pusto/„zostaw wąsy”
  (do ustalenia; MVP: błąd).

## Do ustalenia

- **Escapowanie**: `{{` / `}}` → literalne `{` / `}` (jak .NET/Rust `format!`).
- **Brak dopasowania**: błąd vs zostawienie `{x}` w wyjściu.
- **Jeden skan czy dwa** (najpierw policz rozmiar, potem pisz) dla warstwy 2.
- **Tylko `str`** w MVP (typowane wartości → wcześniej przez 016/`time`), czy
  później warianty typowane przez `$fn` (`render_i32`, …).
- **Nazwa/moduł**: `stdlib/strfmt`? `stdlib/template`? część `str`/`io`?

## Szkic (później — nie teraz)

```
struct KV { key: str; val: str }

# pozycyjne, zero-alloc: "{0}, {1}" + [arg0, arg1] -> out
fn render_pos(tmpl: str, args: []str, out: []u8): !i32 { /* skan {N} */ }

# słownikowe, zero-alloc: "{aaa}, {bbb}" + [KV{...}, ...] -> out
fn render_kv(tmpl: str, kvs: []KV, out: []u8): !i32 { /* skan {klucz} */ }

# warstwa 2 (heap jawnie)
fn render_pos_alloc(a: Allocator, tmpl: str, args: []str): !str { /* + defer */ }
```

## Poza zakresem

- implementacja w tym issue (placeholder w roadmapie),
- pełna mapa KV / hash ([060](060-map-kv.md)) — MVP to liniowa lista par,
- typowane argumenty mieszane (`{0:%.2f}`) jako wymóg MVP — najpierw same `str`,
- format-specyfikatory w wąsach (`{0:...}`) — to raczej rozszerzenie 016,
- lokalizacja / pluralizacja / ICU MessageFormat.
