# 080 — `stdlib/str` — porównania i pomocnicy do napisów

**Status:** 💭 do rozważenia
**Zależy od:** [012](012-stdlib-io.md) (wzorzec modułu stdlib), [021](021-biblioteki-c.md) (FFI/libc); powiązane z [016](016-string-interpolation.md), [077](077-string-template.md)

## Problem

`str` w Klinie to `const char*`. `==` na `str` **nie działa** (porównałoby adresy,
nie treść — cicha pułapka), więc dziś porównanie treści robi się surowo:

```klin
@[cimport, codename("strcmp")]
fn strcmp(a: str, b: str): i32

if strcmp(s, "red") == 0 { … }
```

Wady: powtarzany boilerplate `@cimport`, łatwo pomylić kierunek / zapomnieć
`== 0`. Chcemy dojrzalej, ale **bez** łamania zasady nadrzędnej.

## Decyzja projektowa (dlaczego nie operator)

- **Nie** przeciążamy `==` dla `str` na „porównanie treści”. `==` na `int` znika
  w emisji (1 instrukcja); `strcmp` to pętla O(n), która **nie znika** — ukryty
  koszt za operatorem łamie zasadę („jeśli cecha nie znika w emisji C, łamie
  regułę"). Koszt ma być widoczny → funkcja, nie operator.
- Analogicznie **nie** dodajemy „string‑match" (`match s { "red" {…} }`) — to też
  łańcuch `strcmp`. `match` zostaje int/enum‑only.

## Propozycja: cienki moduł biblioteczny

`stdlib/str` — opakowanie libc, koszt widoczny (wywołanie), czyta się dobrze,
znika powtarzany `@cimport`:

```klin
module str

@[cimport, codename("strcmp")]
fn c_strcmp(a: str, b: str): i32

@[cimport, codename("strlen")]
fn c_strlen(s: str): usize

pub fn eq(a, b: str): bool { return c_strcmp(a, b) == 0 }
pub fn len(s: str): usize { return c_strlen(s) }
// docelowo (do rozważenia): starts_with, ends_with, contains (przez strstr)
```

Użycie:

```klin
import str
if str.eq(s, "red") { … }
```

Model jak Go (`strings`) / Zig — funkcje w bibliotece, nie magia operatora.

## MVP

- [ ] `stdlib/str` z `eq` (i `len`), przez `@cimport` na `strcmp`/`strlen`.
- [ ] Golden + przykład; wpięcie w mechanizm importu stdlib (jak `io`/`mem`).
- [ ] Docs (README, stdlib README).

## Poza zakresem

- Przeciążanie `==` / „string‑match" (świadomie, patrz wyżej).
- Napisy właścicielskie / mutowalne / alokacja (to `Allocator` + [077](077-string-template.md)).
- Unicode/locale (libc `strcmp` jest bajtowe) — ewentualnie później.
