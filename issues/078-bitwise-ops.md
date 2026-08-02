# 078 — Bitwise operators (`| & ^ ~ << >>`)

**Status:** ✅ done (MVP)
**Depends on:** [002](002-symbol-table-checker.md) (types/checker), [019](019-default-int-types.md) (integer types)

## Goal

Add bitwise operators to Klin for integer types. Bit manipulation
previously existed only in **generated C** for SVD registers
(`lib/svd/emit.dart`) — not in Klin source.

## Scope (MVP) — done

| Klin | Meaning | C |
|---|---|---|
| `a & b` | bitwise AND | `a & b` |
| `a \| b` | bitwise OR | `a \| b` |
| `a ^ b` | bitwise XOR | `a ^ b` |
| `~a` | bitwise NOT (unary) | `~a` |
| `a << b` | left shift | `a << b` |
| `a >> b` | right shift | `a >> b` |
| `a &= b` etc. | compound assignment | `a &= b` … (`\|= ^= <<= >>=`) |

Semantic rules:
- **Integer types only** (`i8..u64`, `usize`/`isize`); error on `bool`/`float`/
  pointers (checker), like `%`.
- `>>` on signed types = arithmetic shift (like C on two's complement); unsigned — logical.
- Shift operand (`b` in `a << b`) — integer; result has left operand type. Negative/too-large count is UB in C — no lint in MVP.
- Emission 1:1 to C (including C integer promotions in “bare" expressions);
  assignment to narrower type truncates like C.

## Precedence (settled — like Rust, not C)

Design decision: [docs/01-decisions.md](../docs/01-decisions.md) **D8**.

```
* / %  →  + -  →  << >>  →  &  →  ^  →  |  →  comparisons  →  == !=
```

So `a & b == c` is `(a & b) == c`, not C trap
`a & (b == c)`. Binary `&` vs unary `&` (address) — distinguished by position,
like `*` (multiply vs dereference).

## Implementation points

- `lib/token.dart` + `lib/lexer.dart`: `pipe |`, `caret ^`, `tilde ~`,
  `lessLess <<`, `greaterGreater >>`.
- `lib/parser.dart`: layers `_shift` / `_bitAnd` / `_bitXor` / `_bitOr` + `~`
  in `_unary`.
- `lib/checker.dart`: `_bitOps` / `_inferShift`; `~` in unary inference.
- Emission: existing `BinaryExpr` / `UnaryExpr` (parenthesize `(a op b)`).
- `lib/fmt.dart`: `~` like other unary prefixes.

## Relation to other issues

- Unblocks “bitflags" for enums ([072](072-enums.md)) — `Flags.A | Flags.B`
  needs these operators (and enum bitflag semantics — separately).
- Useful for HAL/registers ([031](031-hal-libraries.md), [011](011-svd.md))
  on Klin source side.

## Out of scope

- Bit rotations, `popcount`/`clz` etc. (functions/`@cimport`, not operators).
- Bitflags as enum feature — belongs to [072](072-enums.md).
- UB shift warnings (negative/too-large count) — possibly with lint later.

Arithmetic compound (`+= -= *= /= %=`) uses same `AssignStmt.compoundOp`
as bitwise — separate follow-up PR, not part of bitwise semantics.

## Criteria

- [x] Tokens + parser (Rust-like precedence, unary `~`, infix `&`).
- [x] Checker: integer types only; errors on `bool`/`float`.
- [x] Portable emission (gcc/clang/tcc), `#line`; goldens.
- [x] `fmt` prints operators idempotently.
- [x] Compound bitwise `&= |= ^= <<= >>=` (emission 1:1 C `op=`).

See [`examples/bitwise.kl`](../examples/bitwise.kl), `test/bitwise.kl`.
