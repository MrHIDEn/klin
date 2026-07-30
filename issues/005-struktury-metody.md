# 005 — Struktury i metody

**Status:** ✅ ukończone
**Zależy od:** 004

## Opis

**To jest to, po co cały projekt powstał.**

## Zakres

```
pub struct Vec2 {
    x: f64
    y: f64
}

pub fn (v: Vec2) len(): f64 { ... }         // kopia
pub fn (mut v: Vec2) translate(dx: f64) { } // wskaźnik
```

Emisja:

```c
typedef struct { double x, y; } Vec2;
double Vec2_len(Vec2 v);
void   Vec2_translate(Vec2 *v, double dx);
```

- mangling `Typ_metoda`
- receiver jako pierwszy argument
- `mut` → wskaźnik; brak `mut` → kopia
- automatyczne referencjonowanie przy wywołaniu metody (za Neluą)
- inicjalizacja struktur: nazwana i pozycyjna

## Test zasady nadrzędnej

`mut` musi **zniknąć** w emisji — zostaje samo `*`. Niezmienność to
zjawisko czasu kompilacji, zero kosztu w runtime.

## Kryterium ukończenia

- [x] `Vec2` z metodami działa
- [x] błąd przy wywołaniu metody mutującej na niemutowalnej zmiennej
- [x] wygenerowany C czytelny i identyczny z tym, co napisałbym ręcznie
