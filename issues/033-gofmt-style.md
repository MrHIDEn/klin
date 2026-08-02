# 033 — Formatowanie w stylu Go (`gofmt`)

**Status:** ✅ zrobione
**Zależy od:** stabilna gramatyka (praktycznie po 005+); nie blokuje kolejki głównej

## Cel

Jeden kanoniczny styl źródła Klina — jak `gofmt` w Go: **mało opcji,
zawsze ten sam wynik**, żeby dało się formatować automatycznie bez dyskusji
o tabach, nawiasach i łamaniu linii.

## MVP (zrobione)

- CLI: `klin fmt [-w] <plik.kl…>` — domyślnie stdout, `-w` zapis na miejscu
- `lib/fmt.dart`: lex → `parseUnit` → pretty-print (4 spacje, K&R, spacje przy op)
- Kolejność deklaracji zachowana (`ModuleUnit.decls`)
- Styl: [docs/05-fmt.md](../docs/05-fmt.md)
- Golden: `test/fmt_ugly.kl` → `test/fmt_ugly.fmt.kl` + idempotencja

## Poza MVP (na później)

- Formatowanie **ciał makr** / wyniku `--emit-pp` (dedent + `fmt`)
- Zachowanie komentarzy (`//`)
- LSP / editor `formatDocument`
- `klin fmt ./...` rekursywnie

## Kryterium

- [x] `klin fmt` na przykładach bez `$` daje powtarzalny wynik
- [x] dokument stylu w `docs/05-fmt.md`
- [x] golden brzydki → sformatowany
