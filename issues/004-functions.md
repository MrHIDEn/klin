# 004 — Functions

**Status:** ✅ done
**Depends on:** 003

## Scope

- parameters with types, return value
- multiple functions in a file
- recursion
- **topological sort of declarations + forward declarations in emission**

## Key note

In Klin, function order in a file does not matter. In C it does.
Codegen must sort and emit prototypes in the declaration section itself.

This is the first moment when generated C stops being a mirror of the source.

## Completion criteria

- [x] function called before its definition in the file works
- [x] recursion (fibonacci)
- [x] error on wrong number/type of arguments
