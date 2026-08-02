# 057 — `Allocator` (explicit allocator)

**Status:** ✅ completed
**Depends on:** [007](007-pointers-arrays-slices.md), [008](008-defer.md); D1 in [docs/01-decisions.md](../docs/01-decisions.md)

## Context

Memory model (D1): manual + `defer` + **allocator as explicit argument**
(Zig/Odin). Without an `Allocator` type stdlib cannot offer `*_alloc` without
hidden `malloc`.

## MVP (done)

Module [`stdlib/mem.kl`](../stdlib/mem.kl) — host heap (libc):

```klin
import mem

fn main() {
    let mut a = mem.heap()
    let mut buf = a.alloc_bytes(16) or { mem.empty_u8() }
    defer a.free_bytes(buf)
    // typed: mem.alloc_i32(&a, n) / mem.free_i32(&a, xs)
}
```

- `Allocator` + `heap()`; methods `alloc_bytes` / `free_bytes`; free functions `alloc_u8` /
  `alloc_i32` (+ `free_*`); `empty_u8` / `empty_i32` for safe `or`
- Emission: `klin_mem_*` → `malloc` / `free` only with `import mem`
- `n < 0` / OOM → `!T`; `n == 0` → empty slice without `malloc`
- Docs: [docs/14-allocator.md](../docs/14-allocator.md); golden `test/mem_alloc.kl`;
  example `examples/mem_heap.kl`

**No** `a.alloc(u8, n)` in grammar — **do not promise** in MVP (no type
argument in call; D3/`$fn`, possibly [034](034-generic-types.md) later).
Details: [docs/14-allocator.md](../docs/14-allocator.md) § “Do not promise”.

## Done outside 057 (consumers)

- [017](017-collection-methods.md) layer 2 — [`slice_alloc`](../stdlib/slice_alloc.kl)
  (`map_alloc_*` / `filter_alloc_*`); note: [16-slice.md](../docs/16-slice.md)

## Follow-up (later)

- `a.alloc(T, n)` — sugar / generics (034), not in this issue
- Arena / `deinit`, vtable of multiple allocators

## What not to do

- GC, autofree, RAII / `using`
- Hidden `malloc` in emission “for convenience”
- Forcing allocator on freestanding (import optional)
