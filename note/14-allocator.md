# `Allocator` — jawny heap (stdlib `mem`)

Model D1 ([01-decyzje.md](01-decyzje.md)): ręczny + `defer` + alokator jako
**jawny** argument. Brak GC / autofree / ukrytego `malloc` w rdzeniu języka.

## MVP (`import mem`)

```klin
import mem

fn main() {
    let mut a = mem.heap()
    let mut buf = a.alloc_bytes(16) or {
        // n < 0 lub OOM — pusty slice (bezpieczny z free_*)
        mem.empty_u8()
    }
    defer a.free_bytes(buf)

    let mut xs = mem.alloc_i32(&a, 4) or { mem.empty_i32() }
    defer mem.free_i32(&a, xs)
}
```

| API | Uwagi |
|---|---|
| `mem.heap()` | host libc heap (pusty `Allocator` pod przyszłe arena/vtable) |
| `a.alloc_bytes(n)` / `a.free_bytes` | `![]u8`; metody na `mut Allocator` |
| `mem.alloc_i32` / `free_i32` (+ `u8`) | wolne funkcje z `*mut Allocator` |
| `mem.empty_u8` / `empty_i32` | `{NULL,0}` — fallback w `or`, bezpieczny z `free_*` |

- `n < 0` → `error(1)`; OOM → `error(2)`; `n == 0` → pusty slice **bez** `malloc`
- `free_*` na pustym / NULL = no-op (`free(NULL)` w C)
- Emisja: `klin_mem_alloc_*` / `klin_mem_free_*` (+ `#include <stdlib.h>`) tylko gdy
  program importuje `mem` / woła te symbole
- Freestanding: **nie** `import mem`

Issue: [057](../issues/057-allocator.md). Example: [`examples/mem_heap.kl`](../examples/mem_heap.kl).

## Nie obiecywać w MVP / później

Szkic D1 `a.alloc(u8, n)` wymaga **argumentu typu** w wywołaniu metody.
Klin tego nie ma w gramatyce (D3 = `$fn` / monomorfizacja, nie generyki —
[034](../issues/034-typy-generyczne.md)). **Nie obiecywać** `a.alloc(u8, n)`
jako API publiczne dopóki nie będzie cukru albo generyków.

Dziś zamiast tego:

- bajty: `a.alloc_bytes(n)` / `a.free_bytes`
- typowane: jawne `mem.alloc_i32` / `free_i32` (i `u8`) — ewentualnie
  rozszerzenie przez `$fn` jak w planie `slice`, nie przez składnię `alloc(T, n)`

**Później (osobne kroki, nie w 057):**

| Temat | Gdzie |
|---|---|
| `a.alloc(T, n)` / cukier albo generyki | 034 / D3 |
| Arena + `deinit` (jeden `defer`) | follow-up po 057 |
| Vtable wielu alokatorów | follow-up (dziś wystarczy heap + pusty struct) |
| `slice_alloc.map_alloc_*` / `filter_alloc_*` | [017](../issues/017-collection-methods.md) warstwa 2 ✅ |
| GC / autofree / ukryty `malloc` w rdzeniu | **nigdy** (zasada nadrzędna) |
