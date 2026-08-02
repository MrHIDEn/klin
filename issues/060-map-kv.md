# 060 — KV map (hash map)

**Status:** 💭 under consideration (low priority — non-blocking)
**Depends on:** [007](007-wskazniki-tablice-slice.md); with heap: [057](057-allocator.md); nice to have [021](021-biblioteki-c.md)

## Context (conversation notes)

### C

- **No** built-in KV maps in the language or libc.
- Key lookup: own hash table / tree, or `qsort`+`bsearch` on
  sorted array, or a library (e.g. uthash, khash).
- `enum` in C is named **integer** constants (not “enum on arbitrary type”).
  Only **C23** has `enum E : uint8_t` (underlying type still integer).

### Implementation difficulty

- **MVP** (e.g. `string`/`int` → pointer, open addressing / chaining): feasible
  in short time.
- **“Production” map**: hashes, resize, delete, key ownership, OOM,
  custom allocator — gets hard here.
- Bare-metal without `malloc`: usually fixed capacity / arena; general heap map
  often does not fit MCU.

### uthash / khash

Both **small** (header-only, ~1k lines or less) — not GLib. Runtime: overhead
per element + (usually) dynamic resize. OK on host; on bare-metal still need to be
explicit about allocation.

### Go / V

Both have **built-in** `map[K]V` in language/runtime (V heavily like Go). C does not have that
level — hence separate headers or own code.

## What it means for Klin

Overarching rule: **no hidden allocation / cost**. If a map ever
appears:

- not as magic builtin with hidden heap grow on `m[k] = v`,
- or explicit `Allocator` ([057](057-allocator.md)) + API in style of
  [017](017-collection-methods.md) (`map_*` / `put` with visible cost),
- or thin FFI wrapper on C (uthash/khash/`-l…`) like [050](050-sqlite-wrapper.md),
- or on embedded: array + `bsearch` / compile-time / ideal hash — without general
  hash map in stdlib.

## Sketch (later — not now)

1. Decision: language vs `stdlib/map` vs FFI example only.
2. MVP keys: `i32` / `u32` / `str`? (string ownership).
3. Host first; bare-metal = fixed / arena or out of scope.
4. Golden tests + `objdump` vs hand-written C on grow/lookup.

## Out of scope

- implementation in this issue (roadmap placeholder only)
- ordered map / tree as MVP requirement
- priority relative to core / embedded LED / current issues
