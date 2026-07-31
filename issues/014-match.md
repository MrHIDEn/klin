# 014 — `match` (domyślny break)

**Status:** ✅ ukończone
**Zależy od:** 003

> **Uwaga historyczna.** Wczesna, kompletna implementacja `match` powstała na
> branchu `issue-014-match` (2026-07-30), ale nigdy nie została scalona do
> `main` — powstała względem starego frontendu i dziś konfliktuje w rdzeniu
> (`lexer`/`parser`/`ast`/`checker`/`emit_c`). Posłużyła jako **referencja
> projektowa** (składnia, testy, docs); właściwa implementacja powstała od zera
> na świeżym branchu z `origin/main`. Stary branch można usunąć.

## Zakres

- keyword `match` (nie `switch`)
- **domyślny break** — brak fallthrough, brak słowa `fallthrough`
- grupowanie: `1, 2, 3`
- zakres inclusive: `4..=10`
- forma instrukcji i forma wyrażenia

## Składnia

Bez przypisania (instrukcja):

```
match x {
    1, 2, 3 {
        puts("abc")
    }
    4..=10 {
        puts("def")
    }
    else {
        puts("other")
    }
}
```

Z przypisaniem (wyrażenie):

```
let a = match x {
    1, 2, 3 { 10 }
    4..=10  { 20 }
    else    { 30 }
}
```

## Decyzje

- Emisja: łańcuch `if` / `else if` (subject raz do zmiennej tymczasowej)
- Wzorce `>= 4` itd. — później
- `else` wymagane w formie wyrażenia; w instrukcji opcjonalne
- Podmiot musi być całkowitoliczbowy (`i8`…`u64`, `int`); `f64` / struktury —
  błąd checkera
- Forma wyrażenia tylko jako inicjalizator `let` albo prawa strona
  przypisania (obniża się do instrukcji, nie do wyrażenia C)
- Ramiona zwracają wartość, nie napis — `str` nie jest jeszcze typem
  pierwszej klasy (przykład z `"abc"` z wczesnego szkicu nie przechodzi
  checkera również poza `match`)

Szczegóły: [note/15-match.md](../note/15-match.md).

## Kryterium ukończenia

- [x] `match` jako instrukcja — test złoty (`test/match_stmt.kl`)
- [x] `let a = match …` — test złoty (`test/match_expr.kl`)
- [x] brak fallthrough między ramionami (emisja bez `switch`/`case`)
- [x] błędy checkera: `else` nie na końcu, brak `else` w wyrażeniu,
      podmiot nie-całkowity, `match` jako wyrażenie w złej pozycji
- [x] `klin fmt` (`test/fmt_match.kl`), przykład
      [`examples/match.kl`](../examples/match.kl)
