# Klin stdlib

Optional modules resolved after a sibling `.kl` of the same name.

Search order for `import io`:

1. `./io.kl` next to the importing file
2. `$KLIN_STDLIB/io.kl` if set
3. `<repo>/stdlib/io.kl` (package root with `pubspec.yaml`)

| Module | Role |
|---|---|
| [`io`](io.kl) | Host `print` / `println` (thin libc wrappers) |
| [`testing`](testing.kl) | `assert` / `assert_eq_i32` for `klin test` |

## `io`

```klin
import io

io.print("no newline")
io.println("with newline")
```

Do **not** import on bare metal (pulls `stdio`).

## `testing`

Used by `klin test` on `*_test.kl` files. The harness injects `main` that
calls each `test_*` function:

```klin
import testing

fn test_add() {
    testing.assert_eq_i32(1 + 1, 2)
}
```

```sh
dart run bin/klin.dart test examples/
```

Bare-metal programs simply do not import these modules.
