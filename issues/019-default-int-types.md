# 019 — Domyślne typy (`int` / literały)

**Status:** 💭 do rozważenia
**Zależy od:** 002 (już: untyped int → domyślnie `i32`, float → `f64`)

## Kontekst

Dziś literał `42` bez kontekstu staje się **`i32`**, `1.0` → **`f64`**. Nie ma aliasów `int` / `float` w składni użytkownika — tylko jawne `i8`…`i64` itd.

V ma `int` (= platformowy / domyślny całkowity). C ma `int` o niejednoznacznym rozmiarze — na bare-metal to pułapka.

## Propozycja (później)

Do decyzji, czy w ogóle:

| Opcja | Semantyka |
|---|---|
| A. Zostawić jak jest | Tylko `i32`/`i64`/…; literał → `i32` |
| B. Alias `int` = `i32` (lub `isize`) | Cukier nazw, stały rozmiar w docs |
| C. `int` = `isize` (szerokość wskaźnika) | Jak „native int”; gorsze na małych MCU |

Nie wprowadzać C-owego „`int` zależy od ABI” bez adnotacji platformy.

## Czego nie robić teraz

- Nie dodawać `int` obok `i32` przed decyzją bare-metal (010).
- Nie zmieniać domyślnego literału z `i32` bez testów złotych i emisji.
