# 003 — Przepływ sterowania

**Status:** ✅ ukończone
**Zależy od:** 002

## Zakres

`if` / `else`, `while`, `for`, `return`, `break`, `continue`.

Prosto, bo C ma to samo — mapowanie niemal jeden do jednego.

## Decyzje

- **`for` — obie formy** (jak w V):
  - zakresowy: `for i in 0..<5 { ... }` (`..<` exclusive; `i` zawsze mut)
  - C: `for i = 0; i < 5; i = i + 1 { ... }` (bez nawiasów; init wprowadza mut `i`)
- **`while`** osobno (nie kopiujemy V-owego `for cond`)
- **`switch`/`match`** — odłożone (nie w kryterium 003)
- **`goto`** — nie w składni użytkownika; codegen może użyć wewnętrznie (008)

## Kryterium ukończenia

- [x] fizzbuzz działa
- [x] pętla z `break` i `continue`
- [x] testy złote
