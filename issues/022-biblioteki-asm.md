# 022 — Biblioteki / jednostki ASM

**Status:** ✅ zrobione
**Zależy od:** [021](021-biblioteki-c.md) (`@[link]` / `cimport` / `codename`)

## Zakres MVP

- `.s` / `.S` jako ścieżki w `@[link("…")]` (reuse 021; bez nowego atrybutu)
- symbole: Klin→ASM = `@[codename]` / `@[cexport]`; ASM→Klin = `@[cimport, codename]`
- host: `klin run` + test + [`examples/asm_add/`](../examples/asm_add/)
- bare-metal: blink `@[link("startup.s")]`; Makefile czyta `out/*.link`
  (bez przenoszenia `-T linker.ld` do Klina)
- nota: [`docs/10-asm.md`](../docs/10-asm.md)

## Czego nie robimy

- DSL / assembler wewnątrz `.kl`
- ABI per target / mangling bez `codename`
- CLI tylko pod ASM
