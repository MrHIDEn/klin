# 007 — Pointers, arrays, slices

**Status:** ✅ done
**Depends on:** 006

## Scope

- `&` reference, dereference
- `*T` pointer type
- fixed-size arrays
- slice: `struct { T* ptr; size_t len; }`
- `cast(*volatile u32, 0x4000_1000)` — needed for bare metal

## Notes

- Slice forces generics → dependency on D3 (preprocessor).
- Pointer arithmetic: Nelua forbids it and requires explicit cast
  to a number. Consider the same — too restrictive for MCU?
- Consider bounds checking on slice (disable in release).

## Completion criteria

- [x] slice passed to a function without copy
- [x] write to register via cast volatile pointer
