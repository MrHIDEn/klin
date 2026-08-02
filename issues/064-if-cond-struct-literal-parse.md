# 064 — Condition ending in bare name confused with struct literal

**Status:** ✅ done
**Depends on:** —

(Number: previously collided with [063](063-remote-fixture-osa.md) fixture `osa` — this bug = **064**.)

## Symptom (fixed)

An `if`/`while`/`for …..<end` condition ending in a bare name right before `{`
was incorrectly parsed as a struct literal (`name { … }`):

```klin
fn main() {
    let a: i32 = 1
    let b: i32 = 2
    if a < b {          // OK: parentheses optional
        puts("less")
    }
    if (a < b) {        // also OK
        puts("paren")
    }
}
```

## Cause

In [`lib/parser.dart`](../lib/parser.dart) `_primary` treats `ident {` as a
struct literal when `_noStructLit == false`. `match` already suppressed literals
in the header; `if`/`while` (and end of `for …..<`) — did not.

## Fix

`_headerExpr()` (`_noStructLit = true`) around `if`/`while` conditions, end of
`for i in ..<end` range, and post `for` RHS. Struct literal in
condition still possible in parentheses: `if (Foo{...}).x { … }` (paren resets flag).

## Criteria

- [x] `if a < b { … }` / `while a < b { … }` / `for i in 0..<n { … }`
- [x] `if (cond) { … }` / `while (cond) { … }` — parentheses optional
- [x] `if (Point{ x: 3 }).x > 0 { … }` — literal in parentheses
- [x] goldens: `test/if_cond_bare_name.kl`, `test/if_cond_struct_paren.kl`

## Context

Found during [017](017-collection-methods.md) and fixture [063](063-remote-fixture-osa.md)
(`clamp`: `if v < lo {`).
