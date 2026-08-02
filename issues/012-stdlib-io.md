# 012 — Optional I/O module (`println` etc.)

**Status:** ✅ done
**Depends on:** 006 (modules)

## Context

In 001 hello world goes through C `puts` — that is deliberately thin FFI,
not Klin's standard library.

V has builtin `print` / `println` / `eprint` / `eprintln`. Klin **should not**
have two parallel APIs in the core (`puts` + `println`).

## Decision

Optional module `stdlib/io.kl`, imported explicitly — not in builtins:

```
import io

fn main() {
    io.print("hello")
    io.println(" world")
}
```

- Name: `io` (not `vstd`).
- `println` → `@[cimport, codename("puts")]` (with newline, zero overhead).
- `print` → thin `printf("%s", …)` wrapper (no newline).
- Type `str` = `const char*` (FFI / stdlib parameters; string literals).
- On bare metal simply do not import.
- Search: sibling → `$KLIN_STDLIB` → `<repo>/stdlib/`.

## Completion criteria

- [x] `import io` + `io.print` / `io.println` in golden test
- [x] `println` emits `puts` (not `io_println(`)
- [x] `puts` in core still works without import (thin FFI as in 001)
