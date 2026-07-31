# 019 — Domyślne typy (`int` / literały)

**Status:** ✅ ukończone
**Zależy od:** 002 (już: untyped int → domyślnie `i32`, float → `f64`); 010 (bare metal)

## Kontekst

Literał `42` bez kontekstu staje się **`i32`**, `1.0` → **`f64`**.
V ma `int` (= platformowy / domyślny całkowity). C ma `int` o niejednoznacznym
rozmiarze — na bare-metal to pułapka.

## Decyzja: B — aliasy o stałym rozmiarze

| Nazwa | Znaczy | Emisja C |
|---|---|---|
| `int` | `i32` | `int32_t` |
| `float` | `f64` | `double` |

- Literały bez kontekstu bez zmian: int → `i32`, float → `f64`.
- **Nie** ma C-owego „`int` zależy od ABI”.
- `isize` / `usize` zostają osobno (szerokość wskaźnika).
- `int` / `float` nie mogą być nazwami zmiennych / funkcji (słowa kluczowe C)
  — łapie frontend.

## Kryterium ukończenia

- [x] `int` / `float` w adnotacjach typów i sygnaturach
- [x] emisja zawsze `int32_t` / `double` (nie C `int` / `float`)
- [x] test złoty + frontend odrzuca `let int = …`
