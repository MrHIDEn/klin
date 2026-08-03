# 084 — `match`: `when` guards + relational patterns

**Status:** ✅ complete
**Depends on:** 014

## Scope

Extend `match` beyond MVP (014):

- keyword `when` — boolean guard after a pattern
- relational patterns: `>`, `>=`, `<`, `<=`, `!=`
- wildcard `_` with required `when` (unguarded catch-all stays `else`)

## Syntax

```
match x {
    1, 2 when flag != 0 { … }
    4..=10 when (x & 1) == 0 { … }
    > 0 { … }
    >= n when ready { … }
    != 0 { … }
    _ when special { … }
    else { … }
}
```

Same rules for the expression form (`let a = match …`).

## Decisions

- `when` is a keyword (like `match` / `async`)
- Guard type must be `bool`
- `else` cannot have `when`; bare `_` without `when` is a parse error
  (hint: use `else`)
- No `==` relational form — use a value group
- No combining relational ops with `,` / `..=` in one arm
- Enum subjects: value groups + `when` + `else` only (no range / rel)
- Emission unchanged: subject once into a temp; `if` / `else if` chain;
  guard AND-ed into the condition (`_ when g` → `(g)`)

Details: [docs/15-match.md](../docs/15-match.md).

## Completion criteria

- [x] `when` on lit / range / rel arms — golden (`test/match_when.kl`)
- [x] relational patterns — golden (`test/match_rel.kl`)
- [x] `_ when …` works; bare `_` / `else when` are errors
- [x] checker: non-bool guard, rel on enum
- [x] `klin fmt` covers `when` / rel / `_`
- [x] docs + example updated
