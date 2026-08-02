# 020 — Klin libraries

**Status:** ✅ done
**Depends on:** [006](006-modules.md)

## MVP scope

- `import name` without new syntax; search:
  sibling → `lib/` → `-I` → `$KLIN_PATH` → `$KLIN_STDLIB` / repo `stdlib/`
- CLI `-I <dir>` (also `-Idir`); `$KLIN_PATH` (PATH-style)
- emission: single `.c` (like 006); `pub` = library API
- example: [`examples/klin_lib/`](../examples/klin_lib/)
- note: [`docs/11-klin-libraries.md`](../docs/11-klin-libraries.md)

## What we are not doing

- package manager / versions / registry
- project manifest
- nested `import a/b`
- separate `.c`/`.a` units from Klin lib
- mixing with C FFI (021) / ASM (022) in this step
- aliases / string import → [048](048-import-aliases.md)
- remote GitHub → [049](049-remote-imports.md)
