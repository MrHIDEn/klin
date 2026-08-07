# 093 — Syntax highlight (TextMate / tree-sitter)

**Status:** 💭 0%
**Depends on:** 086?, 087

## Goal

Editor syntax highlighting for Klin — **not** part of `klin lsp`. Ship a
TextMate grammar and/or tree-sitter grammar for VS Code / Neovim / IntelliJ
TextMate bridge.

Natural home: alongside [087](087-intellij-plugin.md) or a small editor-pack
repo path under `editors/`.

## Out of scope

- PSI / Grammar-Kit full IntelliJ parser
- Semantic tokens via LSP (possible later enhancement to 086)

## Completion criteria

- [ ] TextMate JSON (or plist) covering keywords, types, comments, strings
- [ ] Optional tree-sitter grammar + queries
- [ ] Docs: how to install in VS Code / IntelliJ
