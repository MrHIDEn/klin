# Slice helpers — zero-alloc i `*_alloc`

Issue: [017](../issues/017-collection-methods.md). Fn-pointery: [13-fn-ptr.md](13-fn-ptr.md).
Alokator: [14-allocator.md](14-allocator.md).

## Dwa moduły

| Moduł | Rola | Heap |
|---|---|---|
| [`stdlib/slice.kl`](../stdlib/slice.kl) | odczyty + `*_into` | nie — freestanding-safe |
| [`stdlib/slice_alloc.kl`](../stdlib/slice_alloc.kl) | `map_alloc_*` / `filter_alloc_*` | tak — `import mem` |

Osobny `slice_alloc`, bo emit nie usuwa nieużywanych `pub`: gdyby `*_alloc`
siedział w `slice.kl`, każdy `import slice` wciągałby `klin_mem_*` / `malloc`.

Nazwy monomorficzne przez `$fn` (`_i32`, `_u8`) — brak generyków w gramatyce.

## Warstwa 0+1 (`import slice`)

```klin
import slice

fn times2(x: i32): i32 { return x + x }
fn is_pos(x: i32): bool { return x > 0 }
fn add(a: i32, b: i32): i32 { return a + b }

fn main() {
    let xs: [4]i32 = [1, 0 - 2, 3, 0]
    let mut out: [4]i32 = [0, 0, 0, 0]
    let _ = slice.map_into_i32(xs[:], out[:], times2) or { 0 }
    let n = slice.filter_into_i32(xs[:], out[:], is_pos) or { 0 }
    let s = slice.reduce_i32(xs[:], 0, add)
}
```

| Funkcja | Uwagi |
|---|---|
| `each_*` | efekt uboczny |
| `index_of_*` | indeks albo `-1` |
| `any_*` / `all_*` / `count_*` | |
| `reduce_*` | akumulator + `fn(T,T): T` |
| `map_into_*` | `dst.len == xs.len`; `!i32` (`0` / `error(1)`) |
| `filter_into_*` | `dst.len >= xs.len`; `!i32` = liczba zapisanych |

Zapis `dst[i]` na slice jest dozwolony (nagłówek to wartość; bufor współdzielony
z callerem — jak Go).

Example: [`examples/slice_ops.kl`](../examples/slice_ops.kl).  
Golden: `test/slice_ops.kl`.

## Warstwa 2 (`import mem` + `import slice_alloc`)

```klin
import mem
import slice_alloc

fn times2(x: i32): i32 { return x + x }

fn main() {
    let mut a = mem.heap()
    let xs: [3]i32 = [1, 2, 3]
    let mut out = slice_alloc.map_alloc_i32(&a, xs[:], times2) or {
        mem.empty_i32()
    }
    defer mem.free_i32(&a, out)
}
```

| Funkcja | Zachowanie |
|---|---|
| `map_alloc_*` | `alloc(xs.len)` + mapowanie; `![]T` |
| `filter_alloc_*` | dwa przebiegi: `count` → `alloc(n)` → kopiowanie; `![]T` |

- Alokator: `*mut mem.Allocator` (jak `mem.alloc_i32`)
- Błędy alokacji (`n < 0` / OOM) z `mem` przez `!` / `or`
- **Caller** zwalnia: `defer mem.free_i32(&a, out)` — API nie robi `defer`
- Predykat w `filter_alloc` jak w `count`: bez side-effectów między przebiegami

Example: [`examples/slice_alloc_demo.kl`](../examples/slice_alloc_demo.kl)
(nie nazywaj pliku `slice_alloc.kl` obok `import slice_alloc` — kolizja ścieżki).  
Golden: `test/slice_alloc_ops.kl`.

## Non-goals

- Gołe `xs.map(f)` / ukryty `malloc`
- `using` / autofree wyniku
- Domknięcia (D7), generyki w rdzeniu (034)
- Metody na `[]T` jako receiver
