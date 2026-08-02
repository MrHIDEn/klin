# 045 — Klin → C export (`@[cexport]`)

**Status:** ✅ done
**Depends on:** [021](021-c-libraries.md)

## Context

021 = C → Klin (`@[cimport]` / `@[link]`).
The reverse: Klin code called from C / ASM.

Partially worked already with `@[codename("…")]` + body (ISR, e.g. `SysTick_Handler`).
Issue 045 adds the explicit `@[cexport]` marker.

## API

```klin
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
    return a + b
}
```

- `@[cexport]` — fn with body; global symbol in C emission
- `@[codename("…")]` — **required** with `cexport` (stable name for C)
- `@[codename]` without `cexport` — still OK (ISR / legacy)
- Do not combine with `@[cimport]`

Example: [`examples/cexport_add/`](../examples/cexport_add/).
Note: [`docs/09-ffi-c.md`](../docs/09-ffi-c.md) (import **and** export).

## Out of scope / later

- `--emit-h` (C header with prototypes) → [046](046-emit-h.md) ✅
- automatic `.a` / `.so`
- `cexport` on methods / types
- rpath / `LD_LIBRARY_PATH`
