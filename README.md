# Klin

Klin is a systems programming language that compiles to C. Its Dart frontend
parses and checks Klin source, then emits one readable `.c` file for
`gcc`, `clang`, or `tcc`.

## Build and run

```sh
dart run bin/klin.dart run examples/hello.kl
```

`run` compiles to C, invokes the host C compiler, and executes the binary.
A bare path (`klin examples/hello.kl`) is still accepted as an alias for `run`.

Optional host I/O lives in [`stdlib/`](stdlib/) (e.g. `import io` →
`io.print` / `io.println`). Bare-metal programs simply omit that import.
STM32 demos live under [`examples/stm32/`](examples/stm32/) (see
[`examples/README.md`](examples/README.md)).

Pass `--emit-c` to write the generated C source without compiling or running
it:

```sh
dart run bin/klin.dart --emit-c examples/hello.kl
```

`$fn` macros expand before parsing. Inspect the result with `--emit-pp`
(`out/<file>.pp.kl`).

## Test

```sh
dart test
```

The design documents and roadmap are maintained in Polish:

- [Roadmap](issues/sorted.md)
- [Design notes](note/)