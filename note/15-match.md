# `match` — dopasowanie z domyślnym breakiem

Issue: [014](../issues/014-match.md).

## Składnia

Instrukcja:

```
match x {
    1, 2, 3 {
        puts("small")
    }
    4..=10 {
        puts("mid")
    }
    else {
        puts("big")
    }
}
```

Wyrażenie (tylko jako inicjalizator `let` albo prawa strona przypisania):

```
let fee = match x {
    0      { 0 }
    1..=5  { 10 }
    else   { 25 }
}
```

Wzorce ramienia:

- grupa wartości: `1, 2, 3`
- zakres **domknięty obustronnie**: `4..=10` (osobny token `..=`;
  `..<` pozostaje półotwartym zakresem `for`)
- `else` — musi być ostatnie

## Semantyka

- **Domyślny break.** Wykonuje się pierwsze pasujące ramię; brak fallthrough
  i brak słowa `fallthrough`.
- Podmiot jest **całkowitoliczbowy** (`i8`…`u64`, `int`). `f64`, struktura,
  wskaźnik → błąd checkera.
- Ramię to blok, nie `case`: `break` / `continue` w ramieniu odnoszą się do
  otaczającej pętli, `return` wraca z funkcji (i uruchamia `defer`).
- W instrukcji `else` jest opcjonalne — bez niego brak dopasowania nic nie
  robi. W wyrażeniu `else` jest **wymagane** (nie ma wartości „w przeciwnym
  razie").
- Typ wyrażenia: wspólny typ ramion (unifikacja jak w literałach tablicy);
  `match` liczy się jako zwracający na wszystkich ścieżkach tylko wtedy, gdy
  ma `else` i każde ramię zwraca.

## Emisja

Łańcuch `if` / `else if` / `else`. Podmiot ląduje **raz** w zmiennej
tymczasowej, więc wzorzec wielowartościowy ani zakres go nie przeliczają:

```c
int32_t klin_val_0 = x;
if (klin_val_0 == 1 || klin_val_0 == 2 || klin_val_0 == 3) {
    puts("small");
} else if ((klin_val_0 >= 4 && klin_val_0 <= 10)) {
    puts("mid");
} else {
    puts("big");
}
```

Forma wyrażenia obniża się do deklaracji celu + przypisania w gałęziach
(dlatego jest dozwolona tylko w pozycji `let` / przypisania):

```c
int32_t fee;
int32_t klin_val_0 = x;
if (klin_val_0 == 0) { fee = 0; } else if (…) { fee = 10; } else { fee = 25; }
```

Świadomie **nie** `switch`: `switch` nie obsługuje zakresów przenośnie
(`case 4 ... 10` to rozszerzenie GCC), a `break` w `case` kolidowałby z
`break` pętli. Łańcuch `if` daje ten sam kod maszynowy co ręczny C —
zasada nadrzędna spełniona.

## Ograniczenia MVP

- brak wzorców relacyjnych (`>= 4`), brak `|` jako alternatywy — jest `,`
- brak dopasowania po napisach i strukturach (`str` nie jest jeszcze typem
  wartościowym)
- brak sprawdzania wyczerpania (poza wymaganym `else` w wyrażeniu) i
  ostrzeżeń o martwych ramionach
- `match` jako wyrażenie tylko w `let` / przypisaniu; w argumencie wywołania
  → błąd checkera z podpowiedzią
- podmiot w nagłówku nie przyjmuje gołego literału struktury
  (`match Point{…}.x` — użyj nawiasów: `match (Point{…}).x`), bo `{`
  otwiera blok ramion

Przykład: [`examples/match.kl`](../examples/match.kl).
Testy: `test/match_stmt.kl`, `test/match_expr.kl`, `test/fmt_match.kl`.
