# 068 — Shared type annotation (`a, b: i32`)

**Status:** ✅ (parameters + struct fields; `let` out of scope)
**Depends on:** [002](002-tablica-symboli-checker.md), [004](004-funkcje.md), [005](005-struktury-metody.md)

## Motivation

Today each name carries its own type:

```
fn add(a: i32, b: i32) -> i32 { … }
struct Point { x: f64, y: f64 }
let a: i32 = 1, b: i32 = 2   // if multi-let ever exists
```

In Go (and similarly in V) the same type can be given once for a group of names:

```
fn add(a, b: i32) -> i32 { … }
struct Point { x, y: f64 }
```

The shorthand disappears in AST / C emission — parser sugar only (D1 OK).

## Rule

**Both forms are legal** and mean the same thing:

| Form | Meaning |
|---|---|
| `a: i32, b: i32` | explicit, as today |
| `a, b: i32` | shared type for a list of names |

Mixing in one list OK, e.g. `a, b: i32, c: f64` ≡ `a: i32, b: i32, c: f64`.
Each group ends with `: type`; names without a type before a comma belong to
the next annotated group.

## Scope (proposal)

1. **Function parameters** — MVP, biggest readability win.
2. **Struct fields** — natural extension (`x, y: f64`).
3. **Local `let` / `let mut`** — only if multi-declaration in one statement
   ever exists; do not force today.

`klin fmt` may keep the source form (do not expand `a, b: T` to
`a: T, b: T`), or normalize — decision at implementation time (as with [055](055-short-decl.md)).

## Out of scope

- changing type semantics / default values
- generics / shared type as a “type parameter” ([034](034-typy-generyczne.md))
- mandating one form — both remain

## Completion criteria

- [x] parser: `a, b: T` in parameters and struct fields (names accumulate until
  `: type`; mixing `a, b: i32, c: f64` OK)
- [x] checker / emission: identical to expanding into separate `name: T`
  (pure parser sugar — same AST)
- [x] golden test [`test/shared_type.kl`](../test/shared_type.kl) + errors for
  `a, b` without `: type` (params and fields)
- [x] README entry (syntax)

`let` / `let mut`: out of scope (no multi-declaration in one statement).
`klin fmt` normalizes to expanded form (`a: T, b: T`) — AST does not store
grouping.
