# 008 — defer

**Status:** ✅ done
**Depends on:** 007

## Scope

```
let buf = a.alloc(u8, n)
defer a.free(buf)
```

Emission: shared epilogue + `goto cleanup`.

## Pitfalls

Reverse order. Must work before **every** exit from scope:
`return`, `break`, `continue`, normal end of block.
Conflict with early exits is the main source of implementation bugs.

## Completion criteria

- [x] `defer` before `return` inside a loop
- [x] `defer` before `break`
- [x] two `defer`s in one scope — reverse order
- [x] golden tests for all three
