# 087 — IntelliJ plugin for Klin (over LSP)

**Status:** 💭 under consideration (not started)
**Depends on:** [086](086-lsp.md) (`klin lsp` MVP ✅)

## Goal

Edit `.kl` in IntelliJ IDEA / JetBrains IDEs with diagnostics and format —
**reuse** [`klin lsp`](086-lsp.md), do **not** maintain a second Klin parser
(Grammar-Kit / full PSI) as the primary path.

Rationale: author already works in IntelliJ ([docs/02-architecture.md](../docs/02-architecture.md));
LSP is editor-agnostic; a thin JetBrains LSP client avoids dual grammar drift
(`async` / `.await`, `$fn`, `match`, …).

## Approach

1. **Highlight** — TextMate / TextMateBundle or simple keyword highlighter
   (closes “IDE keywords” from [029](029-async-event-loop.md): `async`, `.await`, …).
2. **Language Server** — spawn `klin lsp` (or `dart run bin/klin.dart lsp` in
   dev) via LSP4IJ / built-in LSP support; map `file` association for `*.kl`.
3. **Format** — `textDocument/formatting` already provided by 086.
4. **Optional later** — run configurations (`klin run` / `klin test`),
   deeper PSI only if JetBrains-native refactor is worth the cost.

## Non-goals (MVP plugin)

- Full Grammar-Kit grammar duplicating the Dart frontend
- Go-to-definition / hover until LSP grows those features (086 follow-up)
- Debugger UI beyond attaching gdb/lldb to emitted C + `#line`
  (full story → [088](088-dap-debug.md); DAP ≠ LSP)

## Progress

| Piece | Status |
|---|---|
| Issue / plan | ✅ (this file) |
| TextMate / keyword highlight | ❌ 0% |
| Wire `klin lsp` in IntelliJ | ❌ 0% |
| Plugin publish (Marketplace / local zip) | ❌ 0% |

## Completion criteria (when work starts)

- [ ] `*.kl` opens with Klin highlight (keywords include `async` / `await` / …)
- [ ] Diagnostics from `klin lsp` appear as inspections / squiggles
- [ ] Format action uses LSP `formatting` (same as `klin fmt`)
- [ ] Short note in docs (how to install / point at `klin` binary)
- [ ] Cross-link from [029](029-async-event-loop.md) IDE row → done
