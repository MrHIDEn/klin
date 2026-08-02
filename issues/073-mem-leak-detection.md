# 073 — Detecting potential memory leaks

**Status:** 💭 under consideration
**Depends on:** 055/057 (`Allocator`, [docs/14](../docs/14-allocator.md)), 008 (`defer`)

## Question

Should Klin detect potential memory leaks — and is that even
possible without breaking the overarching principle (no hidden runtime / cost)?

## Short answer

Partially. Full, **sound** detection is generally undecidable and
would require an ownership/borrow system (à la Rust) — large, at odds with Klin
simplicity. But several cheaper mechanisms are realistic, and Klin's model helps:
explicit `Allocator` ([`stdlib/mem.kl`](../stdlib/mem.kl)), `defer` for cleanup,
no GC and no hidden allocation.

## Variants (cheapest first)

1. **External tools on emitted C** — Klin emits readable `.c`/binary,
   so Valgrind / ASan+LSan work directly on host builds. Zero language cost.
   Strongest pragmatic path; document the pattern
   (e.g. in CI / `docs/`).
2. **Debug allocator (optional, host)** — `mem` variant that counts
   `alloc`/`free`, tags allocation site, and reports unfreed blocks at end.
   Library / opt-in (like `slice_alloc`); bare-metal without heap does not
   pull it in. Zero “magic" in core.
3. **Conservative static lint (frontend)** — within a function: result of
   `mem.alloc_*` / `alloc_bytes` assigned to a variable should have matching
   `defer mem.free_*` / explicit `free` before end of scope; otherwise **warning**
   “alloc without free". Cheap, but heuristic only (see limitations).

## Limitations (honestly)

- Static lint is inherently incomplete: aliases, passing ownership to another
  function, returning buffer from function, conditional paths → false positives or
  misses.
- Sound check would require ownership/borrow model — changes the language; out of scope.
- Therefore: lint as **warning** (not hard error), and “hard" detection
  via Valgrind/ASan in CI.

## Proposed scope (when work starts)

- [ ] Note/pattern: Valgrind + ASan/LSan on host build (CI) — that first.
- [ ] Optional debug allocator in `stdlib` (counter + unfreed report).
- [ ] (Optional) conservative intra-procedural lint “alloc without
  free/defer" as warning, with explicit opt-out for ownership transfer.

## Non-goals

- GC / reference counting in core.
- Ownership / borrow-checker as language feature.
- “Autofree" of result / hidden `defer`.
- Full, sound inter-procedural leak analysis.
