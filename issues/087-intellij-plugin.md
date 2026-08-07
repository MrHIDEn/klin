# 087 — IntelliJ plugin for Klin (over LSP)

**Status:** 💭 under consideration (not started)
**Depends on:** [086](086-lsp.md) (`klin lsp` MVP ✅), [093](093-syntax-highlight.md) (TextMate ✅)

## Goal

Edit `.kl` in IntelliJ IDEA / JetBrains IDEs with diagnostics and format —
**reuse** [`klin lsp`](086-lsp.md), do **not** maintain a second Klin parser
(Grammar-Kit / full PSI) as the primary path.

Rationale: author already works in IntelliJ ([docs/02-architecture.md](../docs/02-architecture.md));
LSP is editor-agnostic; a thin JetBrains LSP client avoids dual grammar drift
(`async` / `.await`, `$fn`, `match`, …).

**Home:** same repo — `editors/intellij/` (see
[howto](../editors/intellij/README.md)). Not a separate `klin-intellij` repo for
MVP.

## Today (no plugin yet)

Manual steps are documented in
[`editors/intellij/README.md`](../editors/intellij/README.md):

1. TextMate Bundle → `editors/vscode/syntaxes/klin.tmLanguage.json` (`*.kl`)
2. Optional: LSP4IJ → `klin lsp` or `dart run bin/klin.dart lsp`

## Approach (plugin)

1. **Highlight** — embed/reuse TextMate from
   [`editors/vscode/syntaxes/klin.tmLanguage.json`](../editors/vscode/syntaxes/klin.tmLanguage.json)
   ([093](093-syntax-highlight.md)).
2. **Language Server** — spawn `klin lsp` (or `dart run bin/klin.dart lsp` in
   dev) via LSP4IJ / built-in LSP; map `*.kl`.
3. **Format** — `textDocument/formatting` from 086.
4. **Optional later** — run configurations (`klin run` / `klin test`); deeper
   PSI only if JetBrains-native refactor is worth the cost.

## Dev / test before Marketplace

Documented in detail in [`editors/intellij/README.md`](../editors/intellij/README.md):

- `./gradlew runIde` — sandbox IDE with the plugin loaded
- `./gradlew buildPlugin` → zip → **Install Plugin from Disk**
- Smoke: highlight, LSP process, squiggles, format
- Marketplace only after a clean Install-from-Disk pass

## Non-goals (MVP plugin)

- Full Grammar-Kit grammar duplicating the Dart frontend
- Go-to-definition / hover until LSP is wired (086 already has them — expose via LSP client)
- Debugger UI beyond attaching gdb/lldb to emitted C + `#line`
  (full story → [088](088-dap-debug.md); DAP ≠ LSP)

## Progress

| Piece | Status |
|---|---|
| Issue / plan | ✅ (this file) |
| How-to doc (`editors/intellij/README.md`) | ✅ |
| TextMate / keyword highlight | ✅ grammar in [093](093-syntax-highlight.md) / `editors/vscode/` |
| Wire `klin lsp` in IntelliJ | ❌ 0% |
| Plugin publish (Marketplace / local zip) | ❌ 0% |

## Completion criteria (when work starts)

- [ ] `*.kl` opens with Klin highlight (keywords include `async` / `await` / …)
- [ ] Diagnostics from `klin lsp` appear as inspections / squiggles
- [ ] Format action uses LSP `formatting` (same as `klin fmt`)
- [ ] Short note in docs (how to install / point at `klin` binary) — howto ✅; plugin install TBD
- [ ] Cross-link from [029](029-async-event-loop.md) IDE row → done
- [ ] `runIde` / Install from Disk verified before Marketplace
