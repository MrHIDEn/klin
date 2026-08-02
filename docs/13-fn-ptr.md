# Function pointers (no capture)

Type `fn(T1, T2): Ret` — pointer to a top-level function (emission = C fn pointer).
No closures / capture ([D7](01-decisions.md)).

```klin
fn is_pos(x: i32): bool {
    return x > 0
}

fn apply(pred: fn(i32): bool, x: i32): bool {
    return pred(x)
}

fn main() {
    let ok = apply(is_pos, 3)
    let mut p: fn(i32): bool = is_pos
    printf("%d\n", p(1))
}
```

Part of [issue 017](../issues/017-collection-methods.md) (phase 2). Example:
[`examples/fn_ptr.kl`](../examples/fn_ptr.kl).

Modules [`stdlib/slice.kl`](../stdlib/slice.kl) (layer 0+1) and
[`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl) (layer 2) use these
types as callbacks (`map_into_i32`, `map_alloc_i32`, …) —
details: [docs/16-slice.md](16-slice.md).
