# Klin

Klin is a systems programming language that compiles to C. Its Dart frontend
parses and checks Klin source, then emits one readable `.c` file for
`gcc`, `clang`, or `tcc`.

## Toolchain

```sh
dart run bin/klin.dart run examples/hello.kl
dart run bin/klin.dart examples/hello.kl          # alias for run
dart run bin/klin.dart fmt -w examples/hello.kl
dart run bin/klin.dart test examples/
dart run bin/klin.dart --emit-c examples/hello.kl
dart run bin/klin.dart --emit-pp examples/point_macro.kl
```

| Command / flag | Role |
|---|---|
| `run <file.kl>` | Compile to C, host `cc`, execute |
| bare path | Same as `run` |
| `fmt [-w]` | Go-style format ([note/05-fmt.md](note/05-fmt.md)) |
| `test` | Run `*_test.kl` (`import testing`) |
| `--emit-c` | Write generated `.c` only |
| `--emit-pp` | Write preprocessor output (`.pp.kl`) |
| `-l` / `-L` | Host linker libs / search paths ([note/09-ffi-c.md](note/09-ffi-c.md)) |

CLI summary (PL): [note/06-cli.md](note/06-cli.md).

Optional host I/O and clocks: [`stdlib/`](stdlib/) (`import io`, `import testing`,
`import time` — see [note/08-time.md](note/08-time.md)).
C FFI — import (`@[cimport]` / `@[link]`) **and** export (`@[cexport]`):
[note/09-ffi-c.md](note/09-ffi-c.md), examples
[`ffi_add/`](examples/ffi_add/) and [`cexport_add/`](examples/cexport_add/).
ASM units (`.s` / `.S` via `@[link]`): [note/10-asm.md](note/10-asm.md),
[`examples/asm_add/`](examples/asm_add/).
Bare-metal programs omit host stdlib imports. STM32 demos:
[`examples/stm32/`](examples/stm32/) — see [`examples/README.md`](examples/README.md).

### Macros and SVD

`$fn` macros and `$peripherals_from_svd(...)` expand before parsing
([note/04-makra.md](note/04-makra.md)). Inspect with `--emit-pp`.
Fluent MMIO (`RCC.AHB1ENR.GPIOAEN.set(1)`) lowers to zero-cost
`static inline` accessors (same as `svd2klin`).

### String interpolation

Ordinary `"…"` strings may contain `$name` / `${expr}` / `${expr:format}`
and lower to `printf` (no hidden allocation). Formats: native printf
(`%d`, `%.2f`), masks (`0.00`, `0.###`), `s8` truncate, `hex` / `sci`.
**Print-only MVP** — use as the sole argument to `puts` / `printf` /
`io.print` / `io.println`. Details: [note/07-interpolacja.md](note/07-interpolacja.md),
example: [`examples/interp.kl`](examples/interp.kl).

## Test

```sh
dart test   # compiler / golden tests
```

Design docs and roadmap (Polish):

- [Roadmap](issues/sorted.md)
- [Design notes](note/)
