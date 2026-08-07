# Klin for VS Code / Cursor

TextMate grammar and language configuration for `*.kl` files
([issue 093](../../issues/093-syntax-highlight.md)). Diagnostics, format,
hover, and go-to-definition come from `klin lsp` — this pack only highlights.

## Install (dev)

From the repo root:

```bash
# Cursor
ln -s "$(pwd)/editors/vscode" ~/.cursor/extensions/klin-lang.klin-0.1.0

# VS Code
ln -s "$(pwd)/editors/vscode" ~/.vscode/extensions/klin-lang.klin-0.1.0
```

Reload the window (`Developer: Reload Window`), then open any `.kl` file.

To remove: delete the symlink.

## IntelliJ

See **[../intellij/README.md](../intellij/README.md)** — thin plugin ([087](../../issues/087-intellij-plugin.md))
with bundled TextMate + LSP4IJ (`./gradlew runIde` / Install from Disk).

## Scope

Keywords and primitive types match the Klin lexer / completion lists. Line
comments are `//` only (no block comments). Strings support `\n \t \\ \" \$`
escapes and `${…}` / `${…:fmt}` interpolation highlighting. Character literals
`'A'` / `'\n'` highlight as single-quoted constants.
