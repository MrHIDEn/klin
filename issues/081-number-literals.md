# 081 — Numeric and character literals (binary, float exponent, character, octal?)

**Status:** ✅ done (`0b`, `0o`, float exponent, character `'A'`)
**Depends on:** [002](002-symbol-table-checker.md) (lexer/types); related to [078](078-bitwise-ops.md) (masks)

## Done

- Binary `0b1010` / `0B…`, **octal `0o755` / `0O…`** (both with `_`), and
  float exponent `1e9` / `1.5e-3` / `2.5E+2` (with and without dot). Lexer: validate
  digit after `0b`/`0o`; exponent consumed only when digit follows `e`/`E` (optional sign),
  so `1end` = `1` + `end`.
- **Character** `'A'` / `'\n'` / `'\t'` / `'\0'` / `'\''` / `'\\'`: lexer path `'…'`;
  token is `intLit` with source spelling; type = untyped int (coerce to `u8`/`i32`);
  emission `'A'` (portable C). ASCII only; no multi-char literals.
- Portable emission: `0b…`/`0o…` → `0x…` (same value; no `0b`/`0o` in
  output → gcc/clang/tcc OK); exponents and characters verbatim. Array length
  accepts `0b…`/`0o…`/`'A'`. **Do not** adopt C octal with leading zero (`010`
  here is decimal `10`).
- `fmt` preserves source spelling. Example: `examples/number_literals.kl`,
  golden: `test/number_literals.kl`.

## Design decisions

- **Portability:** literals illegal/uncertain in C (`0b`, `0o`) accepted by lexer,
  but **emission converts to `0x…`** (same bit pattern) — principle “gcc/tcc do not
  error". `fmt` preserves source spelling (`0b`/`0o`/`'A'`).
- **Octal explicit only** `0o755` — **not** C form with leading zero
  (`010` ≠ 10, classic footgun).
- **Float exponent** emitted verbatim (C understands `1e9`).
- **Character** `'A'`: value as untyped int; emission `'A'` (portable).
- Separator `_` allowed in all numeric forms (not inside `'…'`).

## Grouping

- **Group 1 — ✅:** binary `0b` + float exponent `1e…`.
- **Octal `0o` — ✅:** explicit prefix `0o755`, emission → `0x…`.
- **Group 2 — ✅:** character literals `'A'`.

## Out of scope

- Literal type suffixes (`123u`, `1i64`) — Klin has untyped int/float + coercion.
- hex-float, multiline/raw string literals — separately, if at all.
- Multi-char or non-ASCII character literals.
