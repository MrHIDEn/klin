# Function pointers (bez capture)

Typ `fn(T1, T2): Ret` — wskaźnik na funkcję top-level (emisja = C fn pointer).
Bez domknięć / capture ([D7](01-decyzje.md)).

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

Część [issue 017](../issues/017-collection-methods.md) (faza 2). Example:
[`examples/fn_ptr.kl`](../examples/fn_ptr.kl).

Moduły [`stdlib/slice.kl`](../stdlib/slice.kl) (warstwa 0+1) i
[`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl) (warstwa 2) używają tych
typów jako callbacków (`map_into_i32`, `map_alloc_i32`, …).
