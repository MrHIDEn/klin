# 093 — Syntax highlight (TextMate / tree-sitter)

**Status:** ✅ TextMate MVP (tree-sitter deferred)
**Depends on:** 086 (editors pack lives beside LSP), 087 (reuses grammar)

## Goal

Editor syntax highlighting for Klin — **not** part of `klin lsp`. Ship a
TextMate grammar and/or tree-sitter grammar for VS Code / Neovim / IntelliJ
TextMate bridge.

Natural home: [`editors/`](../editors/README.md).

## Done

- TextMate JSON: [`editors/vscode/syntaxes/klin.tmLanguage.json`](../editors/vscode/syntaxes/klin.tmLanguage.json)
- VS Code / Cursor pack: [`editors/vscode/`](../editors/vscode/) (`package.json` + language config)
- Keywords / primitive types aligned with lexer + completion
- Install docs: [`editors/vscode/README.md`](../editors/vscode/README.md)
- Smoke tests: [`test/editors_grammar_test.dart`](../test/editors_grammar_test.dart)

## Deferred

- tree-sitter grammar + queries (optional criterion)

## Out of scope

- PSI / Grammar-Kit full IntelliJ parser → [087](087-intellij-plugin.md)
- Semantic tokens via LSP (possible later enhancement to 086)

## Completion criteria

- [x] TextMate JSON covering keywords, types, comments, strings
- [ ] Optional tree-sitter grammar + queries — deferred
- [x] Docs: how to install in VS Code / IntelliJ (TextMateBundle note)
