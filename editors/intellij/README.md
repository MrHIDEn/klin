# Klin IntelliJ plugin

Thin JetBrains plugin for `*.kl` ([087](../../issues/087-intellij-plugin.md)):
TextMate highlight + `klin lsp` via [LSP4IJ](https://plugins.jetbrains.com/plugin/23257-lsp4ij).
**No** second Klin parser (no Grammar-Kit / PSI).

Requires **IntelliJ IDEA 2024.2+** (and other IDEs on that platform).

## Install (dev)

```bash
cd editors/intellij
./gradlew buildPlugin
# → build/distributions/Klin-0.1.0.zip  (name may vary)
```

1. Install **LSP4IJ** from Marketplace (dependency of this plugin).
2. **Settings → Plugins → ⚙️ → Install Plugin from Disk…** → choose the zip.
3. Restart the IDE.
4. Ensure `klin` is on `PATH`, or set **Settings → Languages & Frameworks → Klin →
   Klin executable** (e.g. absolute path to a built `klin` binary).
5. Open any `.kl` file (try `examples/hello.kl`).

### Sandbox IDE

```bash
cd editors/intellij
./gradlew runIde
```

Opens a clean IDE with Klin + LSP4IJ preloaded. Put `klin` on `PATH` inside that
environment (or set the setting above).

## What it does

| Feature | How |
|---|---|
| Highlight | Bundled TextMate pack (`textmate/klin/`, synced from [`../vscode/`](../vscode/)) |
| Diagnostics / format / hover / goto / rename | LSP4IJ → `klin lsp` (stdio) |
| File association | `*.kl` via LSP4IJ `fileNamePatternMapping` (keeps TextMate colors) |

After changing the VS Code TextMate grammar, refresh the copy:

```bash
./sync-textmate.sh
```

## Manual fallback (no plugin)

Still valid: import [`../vscode/syntaxes/klin.tmLanguage.json`](../vscode/syntaxes/klin.tmLanguage.json)
via TextMate Bundles UI, and register `klin lsp` by hand in LSP4IJ.

## Layout

```text
editors/intellij/
  build.gradle.kts
  src/main/kotlin/org/klinlang/intellij/
    lsp/          # LSP4IJ LanguageServerFactory + process
    settings/     # Klin executable path
    textmate/     # TextMateBundleProvider
  src/main/resources/
    META-INF/plugin.xml
    textmate/klin/   # VS Code-shaped pack (package.json + grammar)
```

## Marketplace

Not published yet. Ship only after `runIde` + Install-from-Disk smoke:

- [ ] Highlight on `examples/hello.kl`
- [ ] LSP Console shows Klin server starting
- [ ] Type error → squiggle
- [ ] Format Document ≈ `klin fmt`
