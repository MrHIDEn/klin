# 002 — Symbol table and type checker

**Status:** ✅ done
**Depends on:** 001

## Description

**This is where the project really begins.** Until now I was writing a text
translator; from here on I am writing a compiler.

## Scope

```
let x: i32 = 2 + 3
let mut y = x * 2
```

- variable declarations, `let` / `let mut`
- nested scopes
- type inference where obvious
- type compatibility checking in expressions
- **error on attempting to mutate an immutable variable**
- primitive types + mapping to C (`i8..i64`, `u8..u64`, `f32/f64`,
  `bool`, `usize`/`isize`)

## Notes

- The point: to translate `p.move(1,2)` to `Point_move(&p,1,2)`, you need
  the **static type** of `p`. A simple textual precompiler is not enough.
- Default zeroing (ZII) — a variable without a value is initialized to zero.

## Completion criteria

- [x] arithmetic expressions with correct typing
- [x] error message on type mismatch, with position
- [x] error message on mutating `let` without `mut`
- [x] golden tests for both errors
