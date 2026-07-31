# Klin

Klin is a systems programming language that compiles to C. Its Dart frontend
parses and checks Klin source, then emits one readable `.c` file for
`gcc`, `clang`, or `tcc`.

## Build and run

```sh
dart run bin/klin.dart examples/hello.kl
```

Pass `--emit-c` to write the generated C source without compiling or running
it:

```sh
dart run bin/klin.dart --emit-c examples/hello.kl
```

## Test

```sh
dart test
```

The design documents and roadmap are maintained in Polish:

- [Roadmap](issues/sorted.md)
- [Design notes](note/)