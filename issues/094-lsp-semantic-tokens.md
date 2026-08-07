# 094 — LSP semantic tokens

**Status:** 💭 backlog (deferred)
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

## Approach (when implemented)

1. Advertise `semanticTokensProvider` in LSP initialize (legend: token types /
   modifiers).
2. Walk `AnalysisResult.program` (and defs from navigate/checker) for the open
   buffer; remap via `SourceMap` when present (same as hover / diagnostics).
3. Prefer `full` first; `range` if cheap; delta only if profiling needs it.
4. Skip or degrade when `positionsSkewed` / no program (same as completion).

## Out of scope

- Replacing TextMate ([093](093-syntax-highlight.md)) or tree-sitter
- IntelliJ Grammar-Kit / PSI ([087](087-intellij-plugin.md))
- Changing Klin grammar or emission

## Completion criteria

- [ ] Legend + `textDocument/semanticTokens/full` (and/or range) in `klin lsp`
- [ ] Tokens respect `SourceMap` / open-buffer path rules like other nav APIs
- [ ] Smoke test (Dart) for a small fixture
- [ ] Note under [086](086-lsp.md) / [docs/06-cli.md](../docs/06-cli.md)
