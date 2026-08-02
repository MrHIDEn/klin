# 000 — Three fundamental decisions

**Status:** ✅ resolved (see `docs/01-decisions.md`)
**Blocks:** everything

## Description

Before the first line of the parser, make three decisions that permeate
the symbol table, checker, and codegen. Changing them later means rewriting.

1. **Memory model** → manual + `defer` + allocator as an explicit argument
2. **Error model** → `!T` + propagation operator + `or { }`
3. **Generics** → preprocessor, not grammar

## Completion criteria

Recorded in `docs/01-decisions.md` with justification for each rejection.
