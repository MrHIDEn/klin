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
| [`slice`](slice.kl) | Zero-alloc `each` / `map_into` / `filter_into` / … (fn-ptr; `$fn` per `T`) |

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

## `slice`

Zero-alloc helpers via fn-pointers ([issue 017](../issues/017-collection-methods.md),
[note/13-fn-ptr.md](../note/13-fn-ptr.md)). Names are monomorphized (`_i32`, `_u8`):

```klin
import slice

fn times2(x: i32): i32 { return x + x }

fn main() {
    let xs: [3]i32 = [1, 2, 3]
    let mut ys: [3]i32 = [0, 0, 0]
    let _ = slice.map_into_i32(xs[:], ys[:], times2) or { 0 }
}
```
