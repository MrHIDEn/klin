# 002 — Tablica symboli i type checker

**Status:** ⬜ do zrobienia
**Zależy od:** 001

## Opis

**Tu projekt naprawdę się zaczyna.** Do tej pory pisałem tłumacz tekstu,
od teraz piszę kompilator.

## Zakres

```
let x: i32 = 2 + 3
let mut y = x * 2
```

- deklaracje zmiennych, `let` / `let mut`
- zakresy (scope) zagnieżdżone
- dedukcja typów tam, gdzie oczywista
- sprawdzanie zgodności typów w wyrażeniach
- **błąd przy próbie mutacji niemutowalnej zmiennej**
- typy prymitywne + mapowanie na C (`i8..i64`, `u8..u64`, `f32/f64`,
  `bool`, `usize`/`isize`)

## Uwagi

- Sedno: żeby przetłumaczyć `p.move(1,2)` na `Point_move(&p,1,2)`, trzeba
  znać **statyczny typ** `p`. Prosty tekstowy prekompilator nie wystarczy.
- Zerowanie domyślne (ZII) — zmienna bez wartości inicjalizowana zerami.

## Kryterium ukończenia

- [ ] wyrażenia arytmetyczne z poprawnym typowaniem
- [ ] komunikat błędu przy niezgodności typów, z pozycją
- [ ] komunikat błędu przy mutacji `let` bez `mut`
- [ ] testy złote na oba błędy
