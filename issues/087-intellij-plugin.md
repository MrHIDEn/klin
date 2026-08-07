# 087 — IntelliJ plugin for Klin (over LSP)

**Status:** ✅ MVP in repo (not on Marketplace)
**Depends on:** [086](086-lsp.md) (`klin lsp` MVP ✅), [093](093-syntax-highlight.md) (TextMate ✅)

## Goal

Edit `.kl` in IntelliJ IDEA / JetBrains IDEs with diagnostics and format —
**reuse** [`klin lsp`](086-lsp.md), do **not** maintain a second Klin parser
(Grammar-Kit / full PSI) as the primary path.

Rationale: author already works in IntelliJ ([docs/02-architecture.md](../docs/02-architecture.md));
LSP is editor-agnostic; a thin JetBrains LSP client avoids dual grammar drift
(`async` / `.await`, `$fn`, `match`, …).

**Home:** [`editors/intellij/`](../editors/intellij/) in this repo (not a separate
`klin-intellij` package for MVP).

## Done (MVP)

- Gradle IntelliJ Platform plugin under [`editors/intellij/`](../editors/intellij/)
- TextMate bundle via `com.intellij.textmate.bundleProvider` (pack from 093)
- LSP4IJ server `klinLsp` → `klin lsp` (stdio); `*.kl` file-name mapping
- Settings: Klin executable path (default `klin`)
- Docs: [`editors/intellij/README.md`](../editors/intellij/README.md) (`runIde` /
  Install from Disk)

## Approach

1. **Highlight** — embedded TextMate copy of
   [`editors/vscode/`](../editors/vscode/) (`./sync-textmate.sh` after grammar edits).
2. **Language Server** — LSP4IJ dependency +
   `OSProcessStreamConnectionProvider` for `klin lsp`.
3. **Format / hover / goto / rename** — whatever 086 already exposes over LSP.
4. **Optional later** — run configurations (`klin run` / `klin test`); Marketplace
   publish; deeper PSI only if worth the cost.

## Dev / test before Marketplace

```bash
cd editors/intellij
./gradlew runIde        # sandbox
./gradlew buildPlugin   # zip → Install Plugin from Disk
```

Details: [`editors/intellij/README.md`](../editors/intellij/README.md).

## Non-goals (MVP plugin)

- Full Grammar-Kit grammar duplicating the Dart frontend
- Semantic tokens ([094](094-lsp-semantic-tokens.md))
- Debugger UI (→ [088](088-dap-debug.md); DAP ≠ LSP)

## Progress

| Piece | Status |
|---|---|
| Issue / plan | ✅ |
| How-to + Gradle plugin sources | ✅ |
| TextMate highlight in plugin | ✅ |
| Wire `klin lsp` via LSP4IJ | ✅ |
| Plugin publish (Marketplace) | ❌ |

## Completion criteria

- [x] `*.kl` opens with Klin highlight (keywords include `async` / `await` / …)
- [x] Diagnostics path via `klin lsp` + LSP4IJ (verify locally with `klin` on PATH)
- [x] Format via LSP `formatting` (same as `klin fmt`)
- [x] Docs: install / executable path
- [ ] Cross-link from [029](029-async-event-loop.md) IDE row → done
- [ ] Marketplace publish after Install-from-Disk smoke on a clean machine
