# `:=` shorthand (`let mut`)

Issue: [055](../issues/055-short-decl.md).

## Syntax

```
name := expr          // ≡ let mut name = expr
name = expr           // assignment (unchanged)
let name = expr       // immutable (unchanged)
let mut name = expr   // equivalent to `:=`
```

In C-`for` init accepts `=` or `:=` (both introduce a mutable
loop variable):

```
for i := 0; i < n; i = i + 1 { … }
```

## Semantics

Like `let mut`: mutable local with initializer, type inference from
the right-hand side. In C emission there is no `mut` — a plain local remains.

## MVP limitations

- no type annotation with `:=` (`x: i32 := 1` — use `let mut x: i32 = 1`)
- `klin fmt` preserves `:=` in declarations; in C-`for` init normalizes to `=`

Example: [`examples/short_decl.kl`](../examples/short_decl.kl).
