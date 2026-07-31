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
| [`time`](time.kl) | Wall / monotonic clocks, `Duration`, format, UTC calendar `add_*` |

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

## `time`

Host clocks and formatting ([note/08-time.md](../note/08-time.md)):

```klin
import time

fn main() {
    let t = time.unix(1704067200)
    let mut buf: [32]u8
    time.format(buf[:], "%Y-%m-%d", t)
    printf("%s\n", &buf[0])
}
```

`now()` = wall, `mono()` = monotonic. RTC / CPU cycles are separate APIs.
Calendar: `add_days` / `add_months` / `add_years` / `add_date` (UTC, `!Instant`).
Do **not** import on freestanding targets without libc `time`.
