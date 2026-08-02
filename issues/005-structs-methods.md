# 005 — Structs and methods

**Status:** ✅ done
**Depends on:** 004

## Description

**This is what the whole project exists for.**

## Scope

```
pub struct Vec2 {
    x: f64
    y: f64
}

pub fn (v: Vec2) len(): f64 { ... }         // copy
pub fn (mut v: Vec2) translate(dx: f64) { } // pointer
```

Emission:

```c
typedef struct { double x, y; } Vec2;
double Vec2_len(Vec2 v);
void   Vec2_translate(Vec2 *v, double dx);
```

- mangling `Typ_metoda`
- receiver as first argument
- `mut` → pointer; no `mut` → copy
- automatic referencing on method call (after Nelua)
- struct initialization: named and positional

## Prime rule test

`mut` must **disappear** in emission — only `*` remains. Immutability is a
compile-time phenomenon, zero runtime cost.

## Completion criteria

- [x] `Vec2` with methods works
- [x] error on calling a mutating method on an immutable variable
- [x] generated C is readable and identical to what I would write by hand
