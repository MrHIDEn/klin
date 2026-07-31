# 035 — `klin test` (testy w Klinie, jak `go test`)

**Status:** 💭 do rozważenia
**Zależy od:** [032](032-klin-run.md) (`klin run`); ew. mały `stdlib/testing`

## Go ma testy?

Tak — wbudowane w toolchain:

- pliki `*_test.go` (nie wchodzą do zwykłego builda),
- funkcje `TestXxx(t *testing.T)`,
- komenda **`go test`** (+ pakiet `testing`: `t.Error` / `t.Fatal`, table-driven,
  później benchmarki / fuzz).

To nie osobny framework — konwencja nazw + runner w CLI.

## Czy `klin test` jest realne?

**Tak, w uproszczonej formie** — Klin już umie compile→cc→run ([032](032-klin-run.md)).
Brakuje tylko konwencji „co jest testem” i agregacji wyniku (pass/fail, exit ≠ 0).

Dziś testy **kompilatora** to Dart + złote `.kl`/`.out` w `test/` — to zostaje.
`klin test` to testy **programów pisanych w Klinie** (biblioteki, przykłady,
ew. kod użytkownika), nie zastępstwo `dart test`.

## Propozycja MVP

```bash
klin test                  # katalog bieżący / entry
klin test path/to/pkg      # albo konkretny plik
```

Konwencja (jak Go, bez 1:1 API):

- pliki `*_test.kl` (albo katalog `tests/`),
- funkcje `test_foo()` / `fn test_foo()` wywoływane przez generowany harness,
  **albo** jeden `fn main()` na plik i porównanie stdout (bliżej dzisiejszych złotych),
- asercje: najpierw proste `assert(cond)` / `assert_eq(a, b)` w `stdlib/testing`
  (emit: `if (!cond) { fprintf(stderr,…); exit(1); }` — jawny koszt, OK w testach),
- podsumowanie: `ok` / `FAIL` + exit code.

## Poza MVP

- table-driven / subtesty jak `t.Run`,
- benchmarki (`go test -bench`),
- testy bare-metal (host-only najpierw),
- równoległość, coverage.

## Kryterium

- [ ] `klin test` na małym `*_test.kl` zielone lokalnie
- [ ] fail asercji → exit ≠ 0 i czytelny komunikat
- [ ] dokument: to testuje kod Klina; kompilator nadal przez `dart test`
