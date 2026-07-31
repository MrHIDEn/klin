# 055 — Skrót `:=` (= `let mut`)

**Status:** ✅ zrobione
**Zależy od:** 002

## Opis

Składnia w stylu Go/V: `name := expr` jako cukier składniowy dla
`let mut name = expr`.

```
x := 1          // ≡ let mut x = 1
x = x + 1       // przypisanie (bez zmian)
```

`let` / `let mut` zostają. `:=` **nie** wprowadza niemutowalnej zmiennej
(w przeciwieństwie do V, gdzie `:=` domyślnie jest immutable, a `mut`
trzeba dopisać). W Klinie niezmienność domyślna to `let`; `:=` jest
wyłącznie skrótem mutowalnej deklaracji.

## Zakres

- token `:=` w lexerze
- `name := expr` → `LetStmt(isMut: true, …)` (wymagany initializer)
- w C-`for`: `for i := 0; …` obok istniejącego `for i = 0; …`
- `klin fmt` zachowuje `:=` (nie rozwija do `let mut`)
- brak adnotacji typu przy `:=` w MVP (`x: i32 := 1` — poza zakresem;
  użyj `let mut x: i32 = 1`)

## Poza zakresem

- `:=` w destrukturyzacji / multi-assign
- przeładowanie `:=` na typach użytkownika
- zmiana semantyki istniejącego `let` / `let mut`

## Kryterium ukończenia

- [x] złoty test: `:=` + mutacja działa, emisja bez `mut` w C
- [x] `klin fmt` zachowuje `:=`
- [x] frontend łapie `:=` bez prawej strony
- [x] wpis w `issues/sorted.md` + krótka wzmianka w README / note
