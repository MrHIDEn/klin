# 019 — Default types (`int` / literals)

**Status:** ✅ done
**Depends on:** 002 (already: untyped int → default `i32`, float → `f64`); 010 (bare metal)

## Context

Literal `42` without context becomes **`i32`**, `1.0` → **`f64`**.
V has `int` (= platform / default integer). C has `int` of ambiguous
size — on bare metal that is a trap.

## Decision: B — fixed-size aliases

| Name | Means | C emission |
|---|---|---|
| `int` | `i32` | `int32_t` |
| `float` | `f64` | `double` |

- Context-free literals unchanged: int → `i32`, float → `f64`.
- **No** C-style "`int` depends on ABI".
- `isize` / `usize` remain separate (pointer width).
- `int` / `float` cannot be variable / function names (C keywords)
  — caught by frontend.

## Completion criteria

- [x] `int` / `float` in type annotations and signatures
- [x] emission always `int32_t` / `double` (not C `int` / `float`)
- [x] golden test + frontend rejects `let int = …`
