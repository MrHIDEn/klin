# 085 — `pick` (expression ternary)

**Status:** ✅ complete
**Depends on:** 003

## Scope

Two-way expression choice without overloading statement `if`:

```
let fee = pick cond { thenExpr } { elseExpr }
```

Emits as C `(cond ? thenExpr : elseExpr)`.

## Decisions

- Keyword `pick` (not expression-`if`, not `?:` in Klin source for MVP)
- Condition: `bool`; arms unify like `match` expression results
- True expression (usable anywhere an expr is allowed), not let/assign-only
- Nested `pick` allowed; arms must not contain `match` / `or` / `!`
  (statement-lowering forms break C ternary)
- No Klin version bump — stays `0.1.1` (language feature, not a release)

Details: [docs/18-pick.md](../docs/18-pick.md).

## Completion criteria

- [x] golden `test/pick_expr.kl` (incl. nested + `:=` / assign / call arg)
- [x] emits `?:` (not `if`/`else` statements)
- [x] checker: non-bool cond, arm type mismatch, forbidden `match`/`or`/`!` in arms
- [x] `klin fmt` (`test/fmt_pick.kl`), example [`examples/pick.kl`](../examples/pick.kl)
