# 003 — Przepływ sterowania

**Status:** ⬜ do zrobienia
**Zależy od:** 002

## Zakres

`if` / `else`, `while`, `for`, `return`, `break`, `continue`.

Prosto, bo C ma to samo — mapowanie niemal jeden do jednego.

## Decyzje do podjęcia

- `for` w stylu C czy zakresowy (`for i in 0..<5`)?
- czy `switch`/`match`? Jeśli tak — bez domyślnego przechodzenia dalej,
  jawny `fallthrough` (za Neluą).
- czy `goto`? Prawdopodobnie nie w składni użytkownika, ale codegen
  będzie go używał wewnętrznie (patrz 008).

## Kryterium ukończenia

- [ ] fizzbuzz działa
- [ ] pętla z `break` i `continue`
- [ ] testy złote
