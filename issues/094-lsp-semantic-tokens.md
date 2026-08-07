# 094 — LSP semantic tokens

**Status:** ✅ MVP (`textDocument/semanticTokens/full`)
**Depends on:** [086](086-lsp.md)

## Goal

Add LSP `textDocument/semanticTokens` (full / range, optional delta later) to
`klin lsp`, so editors can color identifiers from the **checked AST** — not
only from the TextMate grammar ([093](093-syntax-highlight.md)).

Examples of what TextMate cannot decide but the frontend can:

- `foo` in `foo()` → function vs local / param
- `Point` → struct / enum type vs variable named `Point`
- `Color.Red` → enum member
- `@[cimport]` symbols vs ordinary Klin funcs
- `mut` / readonly locals via token modifiers when useful

## Why separate from 093

| Layer | Where | What |
|---|---|---|
| TextMate | [`editors/vscode/`](../editors/vscode/) | Keywords, comments, strings, crude types |
| Semantic tokens | `klin lsp` | Resolve + types after analyze |

Editors may stack both (VS Code / Cursor do). IntelliJ thin plugin
([087](087-intellij-plugin.md)) benefits once LSP advertises the capability.

## Done (MVP)

1. Advertise `semanticTokensProvider` + legend in initialize
   ([`lib/lsp/semantic_tokens.dart`](../lib/lsp/semantic_tokens.dart)).
2. `textDocument/semanticTokens/full` from `allNavTargets` + struct/enum decls;
   remap via `SourceMap` when present; empty when `positionsSkewed` / no program.
3. Modifiers: `declaration`, `readonly` (non-mut `let`), `defaultLibrary`
   (`@[cimport]` fns).
4. Decl name positions via `FuncDecl` / `StructDecl` / `EnumDecl.namePos`.
5. Unit tests in [`test/lsp_test.dart`](../test/lsp_test.dart).

## Out of scope (still)

- Range / delta requests
- Replacing TextMate ([093](093-syntax-highlight.md)) or tree-sitter
- IntelliJ Grammar-Kit / PSI ([087](087-intellij-plugin.md))
- Coloring `: Type` annotations without richer AST positions

## Completion criteria

- [x] Legend + `textDocument/semanticTokens/full` in `klin lsp`
- [x] Tokens respect `SourceMap` / open-buffer path rules like other nav APIs
- [x] Smoke test (Dart) for a small fixture
- [x] Note under [086](086-lsp.md) / [docs/06-cli.md](../docs/06-cli.md)
