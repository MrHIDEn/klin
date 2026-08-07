# Klin in IntelliJ / JetBrains IDEs

There is **no Marketplace “Klin” plugin yet** ([087](../../issues/087-intellij-plugin.md)).
Until it lands, use the manual setup below. The future plugin lives in **this
repo** under `editors/intellij/` (same pattern as [`../vscode/`](../vscode/)).

## Today: highlight only (TextMate)

1. Install [TextMate Bundle](https://plugins.jetbrains.com/plugin/14055-textmate-bundle).
2. **Settings → Languages & Frameworks → TextMate Bundles → +**.
3. Add
   [`../vscode/syntaxes/klin.tmLanguage.json`](../vscode/syntaxes/klin.tmLanguage.json)
   (or the `editors/vscode` folder, depending on the UI).
4. Scope name: `source.klin`. File type / extension: `*.kl`.

You get keyword/string/comment colors. No Klin diagnostics or format from this
step alone.

## Today: diagnostics / format / hover (LSP by hand)

`klin lsp` already speaks stdio ([086](../../issues/086-lsp.md),
[docs/06-cli.md](../../docs/06-cli.md)). IntelliJ does not start it for `.kl`
automatically.

1. Install [LSP4IJ](https://plugins.jetbrains.com/plugin/23257-lsp4ij) (or use
   built-in LSP support if your IDE edition exposes it).
2. Register a language server for `*.kl`:
   - **Installed Klin:** command `klin`, args `lsp`
   - **Dev from this repo:**  
     `dart` / `run` / `bin/klin.dart` / `lsp`  
     (working directory = repo root; Dart SDK on `PATH`)
3. Open a `.kl` file — squiggles and format should come from the same frontend
   as `klin check` / `klin fmt`.

Semantic tokens ([094](../../issues/094-lsp-semantic-tokens.md)) are backlog;
TextMate + LSP diagnostics are enough for MVP editing.

## Building the Klin plugin (087)

Thin JetBrains plugin — **not** a second Klin parser:

| Ship | Do not ship |
|---|---|
| File type `*.kl` | Grammar-Kit / full PSI |
| Embed or point at TextMate from 093 | Duplicate keyword lists in Java/Kotlin |
| Spawn `klin lsp` (LSP4IJ API or IntelliJ LSP) | Reimplement hover/goto in the IDE |
| Format via LSP | Custom formatter |

Suggested layout (when code exists):

```text
editors/intellij/
  build.gradle.kts          # IntelliJ Platform Gradle Plugin
  src/main/kotlin/...       # file type, LSP config, optional run configs
  src/main/resources/
    META-INF/plugin.xml
    textmate/klin.tmLanguage.json   # copy or symlink from ../vscode/syntaxes/
```

Scaffold with the official
[IntelliJ Platform Plugin Template](https://github.com/JetBrains/intellij-platform-plugin-template)
or `gradle-intellij-plugin`, Kotlin preferred. Point the LSP command at
`klin lsp` with a settings UI fallback to a custom path / `dart run …`.

### Local test **before** Marketplace

1. **Run IDE sandbox** (fastest loop):

   ```bash
   cd editors/intellij
   ./gradlew runIde
   ```

   A fresh IDE window opens with the plugin pre-installed. Open a `.kl` sample
   from `examples/`, break a type, confirm diagnostics; run Format.

2. **Install from disk** (closer to users):

   ```bash
   ./gradlew buildPlugin
   # → build/distributions/klin-intellij-*.zip
   ```

   In a normal IntelliJ: **Settings → Plugins → ⚙️ → Install Plugin from Disk…**
   → choose the zip → restart. Verify highlight + LSP on a real project.

3. **Smoke checklist**

   - [ ] `.kl` associated with Klin / TextMate scopes
   - [ ] `klin lsp` process starts (Activity Monitor / LSP4IJ console)
   - [ ] Syntax error or unknown type → squiggle
   - [ ] Format Document matches `klin fmt`
   - [ ] Hover / definition if 086 features are wired

4. **Marketplace** only after the above works on a clean install (no
   hand-linked TextMateBundle). Publish via JetBrains Marketplace / Wizard;
   CI can run `./gradlew verifyPlugin` + `runIde` headless checks later.

### Separate repo?

Keep the plugin **in `klin-lang/klin`** (`editors/intellij/`) for MVP — same as
VS Code TextMate and `klin lsp`. Split to `klin-intellij` only if Gradle /
Marketplace packaging fights the Dart package root.
