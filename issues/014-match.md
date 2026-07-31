# 014 — `match` (domyślny break)

**Status:** 💭 backlog (do rozważenia)
**Zależy od:** 003

> **Uwaga historyczna.** Wczesna, kompletna implementacja `match` powstała na
> branchu `issue-014-match` (2026-07-30), ale nigdy nie została scalona do
> `main` — powstała względem starego frontendu i dziś konfliktuje w rdzeniu
> (`lexer`/`parser`/`ast`/`checker`/`emit_c`). Traktować ją jako **referencję
> projektową** (składnia, testy, docs), a nie jako gotowy do merge kod. Przy
> realizacji: świeży branch z `origin/main` i implementacja od zera pod
> aktualny frontend.

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
    1, 2, 3 { "abc" }
    4..=10  { "def" }
    else    { "other" }
}
```

## Decyzje

- Emisja: łańcuch `if` / `else if` (subject raz do zmiennej tymczasowej)
- Wzorce `>= 4` itd. — później
- `else` wymagane w formie wyrażenia; w instrukcji opcjonalne

## Kryterium ukończenia

- [ ] `match` jako instrukcja — test złoty
- [ ] `let a = match …` — test złoty
- [ ] brak fallthrough między ramionami
