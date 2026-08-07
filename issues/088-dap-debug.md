# 088 — Debug (gdb / `#line` docs + optional DAP)

**Status:** 🔨 docs ✅ (`#line` / gdb); thin DAP / CLI `-g` profile / IDE run
configs still 💭
**Depends on:** 001+ (`#line` in emission ✅); IDE UX → [087](087-intellij-plugin.md); not [086](086-lsp.md)

## Goal

Debugging Klin programs by mapping stop locations back to `.kl` sources —
without inventing a Klin runtime or replacing the C toolchain.

## LSP ≠ debug

| Protocol | Role | Klin |
|---|---|---|
| **LSP** ([086](086-lsp.md)) | edit: diagnostics, format, … | `klin lsp` |
| **DAP** (this issue) | run/step/breakpoints | **not** built yet |
| **gdb / lldb / OpenOCD** | actual debugger today | works via emitted C + `#line` |

`klin lsp` does **not** start programs or set breakpoints. A Debug Adapter (DAP)
is a separate process/protocol. IntelliJ/VS Code can already attach **Native
Debug** / gdb to a binary built with `-g`; Klin’s job is correct `#line` (and
docs), not a second debugger engine.

## What already works

- Every token carries a source position; emission includes `#line`
  ([docs/02-architecture.md](../docs/02-architecture.md) Z2).
- Host: `klin` → `.c` → `gcc -g` → `gdb` / `lldb` (stack / breaks on `.kl`
  when the toolchain honors `#line`).
- MCU: same idea with OpenOCD / probe + `arm-none-eabi-gdb`.
- **Docs:** [docs/19-debug.md](../docs/19-debug.md) (+ pointer in
  [docs/06-cli.md](../docs/06-cli.md)).

## Scope

1. **Docs — ✅** — host debug recipe (`--emit-c` + `gcc -g`), MCU note,
   LSP ≠ DAP.
2. **Optional CLI sugar** — e.g. `klin` flag or documented `cc` args to always
   pass `-g` in a “debug” profile (no hidden runtime).
3. **Optional thin DAP** — adapter that launches/attaches **gdb** (or lldb)
   and forwards DAP ↔ MI; Klin does not interpret DWARF itself. Same pattern
   as “C with `#line`”, zero Klin VM.
4. **IDE wiring** — [087](087-intellij-plugin.md): run/debug configuration
   templates that point at gdb + binary, not through `klin lsp`.

## Non-goals

- Klin interpreter / VM for stepping
- DWARF emitter in the Klin frontend (C compiler owns that)
- Embedding DAP inside `klin lsp` (keep protocols separate)
- Sound “Klin-level” expression eval beyond what gdb sees in C

## Progress

| Piece | Status |
|---|---|
| `#line` in emission | ✅ (existing) |
| Issue / plan | ✅ (this file) |
| Debug docs (host + MCU) | ✅ [docs/19-debug.md](../docs/19-debug.md) |
| CLI `-g` / debug profile | ❌ 0% |
| Thin DAP over gdb | ❌ 0% |
| IntelliJ debug run config | ❌ 0% (see 087) |

## Completion criteria

- [x] Documented host path: `.kl` → C → `-g` → gdb/lldb breaks on `.kl`
- [x] Explicit note: LSP does not provide debug; DAP is optional follow-up
- [ ] If DAP lands: stdio DAP that delegates to gdb; smoke test in CI or
      manual checklist — no Klin runtime
