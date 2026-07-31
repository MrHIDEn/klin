# 035 — `klin test` (testy w Klinie, jak `go test`)

**Status:** ✅ ukończone
**Zależy od:** [032](032-klin-run.md) (`klin run`); `stdlib/testing`

## Cel

Testy **programów w Klinie** (nie kompilatora — ten zostaje na `dart test`).

## MVP (zrobione)

```bash
klin test                     # *_test.kl w cwd
klin test path/to/dir         # katalog
klin test path/foo_test.kl    # jeden plik
klin test --cc clang …
```

- pliki `*_test.kl`
- funkcje `fn test_*(…)` bez parametrów — runner wstrzykuje `main`, które je woła
  (opcjonalnie własny `main` zamiast harnessu)
- `import testing` → `assert` / `assert_eq_i32` (`stdlib/testing.kl`)
- wynik: `ok` / `FAIL` + `PASS` albo `FAIL n/m`, exit ≠ 0 przy failu
- przykład: [`examples/add_test.kl`](../examples/add_test.kl)

## Poza MVP

- table-driven / subtesty, benchmarki, coverage, bare-metal

## Kryterium

- [x] `klin test examples/add_test.kl` zielone
- [x] fail asercji → exit ≠ 0 i komunikat `FAIL: assert_eq_i32…`
- [x] dokument: kod Klina vs `dart test` kompilatora
