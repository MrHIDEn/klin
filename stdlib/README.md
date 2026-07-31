# Klin stdlib

Optional modules resolved after a sibling `.kl` of the same name.

Search order for `import io`:

1. `./io.kl` next to the importing file
2. `$KLIN_STDLIB/io.kl` if set
3. `<repo>/stdlib/io.kl` (package root with `pubspec.yaml`)

| Module | Role |
|---|---|
| `io` | Host `print` / `println` |
| `testing` | `assert` / `assert_eq_i32` for `klin test` |

Bare-metal programs simply do not import these modules.
