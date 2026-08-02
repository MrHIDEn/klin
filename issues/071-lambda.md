# 071 — Lambdas / `fn (…) => expr` sugar

**Status:** 💭 under consideration (low priority — **not now**)
**Depends on:** fn-pointer ✅ ([docs/13-fn-ptr.md](../docs/13-fn-ptr.md));
  real closures → [D7](../docs/01-decyzje.md); optionally [055](055-short-decl.md) (`:=`)

## Summary

Proposed syntax (JS/C# inspiration + Klin-style types):

```klin
add := fn(a: i32, b: i32): i32 => a + b
let n = add(1, 2)
```

Today Klin has only **named** top-level `fn` + decay to `fn(...): T`
(C pointer, **no capture**). Go: `func(...) { }`, no `=>`.
V: `fn (...) { }` and short `|x| expr` for callbacks — also without `=>`.

Technically `fn (…) => expr` sugar can map to an anonymous function
without capture (emission ≈ nested / synthetic `static` fn in C + pointer).
That is **not** a closure yet: `fn(y) => x + y` with outer `x`
requires D7 (environment / fat pointer / heap — risk to overarching principle).

## Verdict

**Do not add for now.** Small gain with current model (named
`fn` + passing pointer to `slice.map_into` etc. is enough); large style cost
(Go-like Klin vs arrows) and risk of two ways to do the same thing.

Sensible order:

1. Keep fn-pointer without capture (status quo).
2. Possibly later **D7** (whether closures at all; how without hidden allocation).
3. Only then separate syntax decision: `fn (…) { }` vs `|x|` (V) vs `=>`.

Optional `=>` sugar **without** capture is not worth a separate PR before D7.
“Last expression = return” (Rust) — separate topic; also unlikely
(by design like Go: always `return`).

## Out of scope

- GC / autofree as capture substitute
- `klingc` / `klin --gc`
- full HOF like JS `arr.map(x => …)` with hidden allocation ([017](017-collection-methods.md))

## Criteria (if revisited)

- [ ] D7 decision written (yes/no + capture memory model)
- [ ] One chosen syntax (not three at once)
- [ ] Golden: anonymous fn without capture; negative: capture rejected or explicit
- [ ] Emission = plain C pointer when no capture (objdump vs manual fn)
