# Klin stdlib

Optional modules resolved after project / user library paths.

Search order for `import io` (first hit wins; in each slot, `io.kl` **or**
directory `io/` — both at once is an error):

1. `./io.kl` or `./io/` next to the importing file
2. `./lib/io.kl` or `./lib/io/`
3. each `-I <dir>/…` (CLI)
4. each `$KLIN_PATH` entry (`:` on Unix, `;` on Windows)
5. `$KLIN_STDLIB/…` if set
6. `<repo>/stdlib/…` (package root with `pubspec.yaml`)

User libraries / directory packages: [note/11-biblioteki-klin.md](../note/11-biblioteki-klin.md).

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
