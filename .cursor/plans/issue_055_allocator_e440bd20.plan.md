---
name: Issue 055 Allocator
overview: "MVP Allocator (issue 055): opcjonalny stdlib `mem` z host libc malloc/free, API na bajtach + cienkie `$fn` dla `[]u8`/`[]i32`; bez aren i bez slice `*_alloc` (017) w tym PR."
todos:
  - id: 055-api-ffi
    content: stdlib/mem.kl + emit/FFI klin_mem_alloc/free (heap)
    status: pending
  - id: 055-tests
    content: Golden test/mem_alloc + example mem_heap + pipeline
    status: pending
  - id: 055-docs-rcfix
    content: "Docs: note, 055 ✅, sorted, stdlib README; push+PR; rcfix"
    status: pending
isProject: false
---

# Issue 055 — `Allocator` MVP

## Zakres (ustalone)

**Tylko 055** — typ + host heap + docs/tests/example. **Bez** [017](issues/017-collection-methods.md) `map_alloc` / `filter_alloc` (osobny follow-up po 055). **Bez** aren w tym PR.

Workflow: branch z `origin/main` → implement → docs/examples → push+PR → `rcfix`.

## Blokada językowa vs szkic D1

Szkic `a.alloc(u8, n)` wymaga **argumentu typu** w wywołaniu metody — Klin tego nie ma (D3 = `$fn`, nie generyki w gramatyce).

**API MVP (ustalone):**

```klin
import mem

fn main() {
    let mut a = mem.heap()
    let buf = a.alloc_bytes(16) or { /* handle */ return }
    defer a.free_bytes(buf)
    // buf: []u8
}
```

Typed convenience przez `$fn` (jak `slice`):

```klin
let xs = mem.alloc_i32(&a, 4) or { ... }   // ![]i32
defer mem.free_i32(&a, xs)
```

Nie obiecywać `a.alloc(u8, n)` w MVP — ewentualnie później (034 / cukier).

## Model typów

W [`stdlib/mem.kl`](stdlib/mem.kl) (nazwa modułu `mem` — nie mylić z keyword):

```klin
module mem

/// Placeholder pod przyszły vtable / arena; heap MVP = ZII + metody → libc.
pub struct Allocator {
}

pub fn heap(): Allocator

pub fn (a: *mut Allocator) alloc_bytes(n: i32): ![]u8
pub fn (a: *mut Allocator) free_bytes(buf: []u8)

$fn mem_typed(T: type) {
  pub fn alloc_$T(a: *mut Allocator, n: i32): ![]$T
  pub fn free_$T(a: *mut Allocator, buf: []$T)
}
$mem_typed(u8)
$mem_typed(i32)
```

- `alloc_*`: `n < 0` lub OOM → `error(...)`; `n == 0` → pusty slice (`len=0`, ptr NULL) **bez** `malloc`
- `free_*`: no-op przy `len==0` / NULL
- Receiver `*mut Allocator` — widać mutację stanu (arena później); heap MVP może ignorować pola

## Emisja / FFI

- `@[cinclude("<stdlib.h>")]` + `cimport` `malloc` / `free` **albo** małe `klin_mem_*` w [`lib/emit_c.dart`](lib/emit_c.dart) (jak `klin_time_*`), jeśli wygodniej zbudować `klin_slice_T` w C
- Preferencja: **C helpers** `klin_mem_alloc` / `klin_mem_free` zwracające / biorące slice header — unikamy braku konstrukcji `[]T` z surowego ptr w samym Klinie
- `malloc` pojawia się **tylko** gdy program importuje `mem` / woła te symbole — nie w `time`/`io`/`slice` 0+1
- Freestanding: po prostu nie `import mem`

## Testy

- Golden `test/mem_alloc.kl` + `.out`: alloc → zapis bajtów → free; `alloc_i32`; OOM/negatywne `or`
- Pipeline: emit zawiera `malloc`/`free` (lub `klin_mem_*`); program **bez** `import mem` nadal bez `malloc`
- Example: `examples/mem_heap.kl`

## Docs

- [issues/055-allocator.md](issues/055-allocator.md) → ✅
- [issues/sorted.md](issues/sorted.md): 055 → ✅ (done)
- [note/](note/) krótki `note/14-allocator.md` (lub dopisek do D1) + [stdlib/README.md](stdlib/README.md) + README / examples README
- [017](issues/017-collection-methods.md): warstwa 2 nadal otwarta, zależy od 055 ✅

## Poza zakresem

- Arena / `deinit`
- Vtable wielu alokatorów (wystarczy jeden heap + pusty struct pod rozszerzenie)
- `a.alloc(T, n)` w gramatyce
- `slice.map_alloc_*` (017 faza 4)
- GC / autofree / ukryty malloc w rdzeniu języka
