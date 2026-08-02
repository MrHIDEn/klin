# 081 — Numeric and character literals (binary, float exponent, character, octal?)

**Status:** 🔨 in progress — done: `0b`, `0o`, float exponent; Group 2 remains (character `'A'`)
**Depends on:** [002](002-symbol-table-checker.md) (lexer/types); related to [078](078-bitwise-ops.md) (masks)

## Done (Group 1 + octal)

- Binary `0b1010` / `0B…`, **octal `0o755` / `0O…`** (both with `_`), and
  float exponent `1e9` / `1.5e-3` / `2.5E+2` (with and without dot). Lexer: validate
  digit after `0b`/`0o`; exponent consumed only when digit follows `e`/`E` (optional sign),
  so `1end` = `1` + `end`.
- Portable emission: `0b…`/`0o…` → `0x…` (same value; no `0b`/`0o` in
  output → gcc/clang/tcc OK); exponents verbatim. Array length accepts
  `0b…`/`0o…`. **Do not** adopt C octal with leading zero (`010` here is
  decimal `10`).
- `fmt` preserves source spelling. Example: `examples/number_literals.kl`,
  golden: `test/number_literals.kl`.

## Current state (lexer)

- Decimal integers: `123`, separator `1_000`.
- Hex: `0xFF` / `0X…`, with `_`.
- Floating point: `1.5`, `1_000.5` — **only** dot form.
- Strings `"…"` (escapes `\n \t \\ \" \$`), `true`/`false`.

## Candidates

| Literal | Example | Value | C emission | Cost |
|---|---|---|---|---|
| binary | `0b1010` | high (masks/registers) | `0b` uncertain in C/tcc → convert to `0x…` | small |
| float exponent | `1e9`, `1.5e-3` | high (f64) | verbatim (C understands) | small |
| character | `'A'` | medium (bytes/ASCII) | verbatim `'A'` (or int code); type = untyped int | medium |
| octal | `0o755` | low (host) | `0o` illegal in C → `0x…`/dec | small |
| hex-float | `0x1.8p3` | low (niche) | — | skip |

## Design decisions

- **Portability:** literals illegal/uncertain in C (`0b`, `0o`) accepted by lexer,
  but **emission converts to `0x…`** (same bit pattern) — principle “gcc/tcc do not
  error". `fmt` preserves source spelling (`0b`/`0o`).
- **Octal explicit only** `0o755` — **not** C form with leading zero
  (`010` ≠ 10, classic footgun).
- **Float exponent** emitted verbatim (C understands `1e9`); extend float path
  in `_number` with `e`/`E` and optional `+`/`-`.
- **Character** `'A'`: new lexer path `'…'` with escapes; value as
  untyped int (coerce to `u8`/`i32`); emission `'A'` (portable).
- Separator `_` allowed in all numeric forms.

## Grouping

- **Group 1 — ✅ done:** binary `0b` + float exponent `1e…`. Covers real
  needs (bits + f64), portable emission.
- **Octal `0o` — ✅ done:** explicit prefix `0o755`, emission → `0x…`
  (no C leading-zero form).
- **Group 2 — 💭:** character literals `'A'` (larger lexer change) → separately.

## Implementation points

- `lib/lexer.dart` `_number`: `0b`/`0o` branches, exponent in float; new `'…'` path.
- Emission (`lib/emit/expr.dart` `IntLit`, `lib/emit_c.dart` enum values):
  helper normalizing `0b`/`0o` → `0x…`; `dec`/`0x`/`1e…`/`'A'` unchanged.
- `lib/checker.dart`: array length parsing from `0b`/`0o` (radix 2/8).
- `lib/fmt.dart`: unchanged (lexeme preserved); round-trip tests.
- Goldens + error tests (e.g. `0b`/`0o` without digit), gcc/tcc sanity; README (literals section).

## Out of scope

- Literal type suffixes (`123u`, `1i64`) — Klin has untyped int/float + coercion.
- hex-float, multiline/raw string literals — separately, if at all.
