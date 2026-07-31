# 055 — `Allocator` (jawny alokator)

**Status:** ✅ ukończone
**Zależy od:** [007](007-wskazniki-tablice-slice.md), [008](008-defer.md); D1 w [note/01-decyzje.md](../note/01-decyzje.md)

## Kontekst

Model pamięci (D1): ręczny + `defer` + **alokator jako jawny argument**
(Zig/Odin). Bez typu `Allocator` stdlib nie może oferować `*_alloc` bez
ukrytego `malloc`.

## MVP (zrobione)

Moduł [`stdlib/mem.kl`](../stdlib/mem.kl) — host heap (libc):

```klin
import mem

fn main() {
    let mut a = mem.heap()
    let mut buf = a.alloc_bytes(16) or { mem.empty_u8() }
    defer a.free_bytes(buf)
    // typed: mem.alloc_i32(&a, n) / mem.free_i32(&a, xs)
}
```

- `Allocator` + `heap()`; metody `alloc_bytes` / `free_bytes`; wolne `alloc_u8` /
  `alloc_i32` (+ `free_*`); `empty_u8` / `empty_i32` do bezpiecznych `or`
- Emisja: `klin_mem_*` → `malloc` / `free` tylko przy `import mem`
- `n < 0` / OOM → `!T`; `n == 0` → pusty slice bez `malloc`
- Docs: [note/14-allocator.md](../note/14-allocator.md); golden `test/mem_alloc.kl`;
  example `examples/mem_heap.kl`

**Bez** `a.alloc(u8, n)` w gramatyce — **nie obiecywać** w MVP (brak argumentu
typu w wywołaniu; D3/`$fn`, ewentualnie [034](034-typy-generyczne.md) później).
Szczegóły: [note/14-allocator.md](../note/14-allocator.md) § „Nie obiecywać”.

## Follow-up (później)

- `a.alloc(T, n)` — cukier / generyki (034), nie w tym issue
- Arena / `deinit`, vtable wielu alokatorów
- [017](017-collection-methods.md) warstwa 2 — `slice.map_alloc_*` / `filter_alloc_*`

## Czego nie robić

- GC, autofree, RAII / `using`
- Ukrytego `malloc` w emisji „dla wygody”
- Wymuszania alokatora na freestanding (import opcjonalny)
