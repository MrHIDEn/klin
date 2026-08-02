# 036 — Docs nie pokrywają nowych cech Klina

**Status:** ✅ zrobione (catch-up w PR z 016)
**Zależy od:** cech ✅ na `main` (026–035) oraz 016

## Cel

Użytkownik / contributor czyta README + `docs/` + przykłady i widzi pełny
obraz tego, co już działa — bez przepisywania `issues/` na EN.

## Zakres

- README: toolchain (`run` / `fmt` / `test` / `--emit-c` / `--emit-pp`), makra,
  SVD fluent, interpolacja
- `docs/06-cli.md` — subkomendy i flagi
- `docs/07-interpolacja.md` — składnia 016
- `stdlib/README.md` — `io` + `testing`
- `examples/README.md` — sync z plikami na dysku

## Poza zakresem

- Tłumaczenie `issues/` / `docs/` na EN
- Pełny language reference
