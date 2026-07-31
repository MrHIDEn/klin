# 047 — Katalog = jeden moduł (jak Go/V)

**Status:** ✅ zrobione
**Zależy od:** [006](006-moduly.md), [020](020-biblioteki-klin.md)

## Kontekst

Dziś jeden plik `.kl` = jeden moduł (`import mathx` → `mathx.kl`).
Go/V: pakiet = katalog, wiele plików w jednej przestrzeni nazw.

## Zakres MVP

- `import name` → `name.kl` **albo** katalog `name/*.kl` (oba naraz = błąd)
- pliki w `name/` muszą mieć `module name`
- `pub` jak 006: domyślnie private (widoczne w pakiecie); `pub` = eksport przy `import`
- entry: siblings z tym samym `module` też się ładują
- `*_test.kl` w katalogu pakietu: **pomijane** przy ładowaniu (jak Go `_test.go`)
- search jak 020 (sibling / `lib/` / `-I` / `KLIN_PATH` / stdlib)
- jeden `.c`; przykład [`examples/pkg_geom/`](../examples/pkg_geom/)
- nota: [`note/11-biblioteki-klin.md`](../note/11-biblioteki-klin.md)

## Poza zakresem

- nested `geom/vec/`, `import a.b`
- menedżer pakietów / manifest wersji
- `*_test.kl` jako osobny pakiet testowy w katalogu (osobny krok)
- aliasy importów / `import "…"` → [048](048-import-aliases.md)
- importy zdalne (GitHub) → [049](049-remote-imports.md)
