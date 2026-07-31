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

Nie ma w MVP: `a.alloc(u8, n)` (argument typu w wywołaniu), aren, vtable wielu
alokatorów, `slice.map_alloc_*` ([017](../issues/017-collection-methods.md)
warstwa 2).

Issue: [055](../issues/055-allocator.md). Example: [`examples/mem_heap.kl`](../examples/mem_heap.kl).
