# Host FFI: C static library

Call a tiny C function from Klin through `@[cimport]` + `@[link]`.

## What

Build `libadd.a` from `add.c`, then `main.kl` imports `add` and links the
archive.

## Why

Demonstrates issue [021](../../issues/021-c-libraries.md) / host FFI: Klin does
not wrap libc for you — you declare the C symbol and pass the library to the
host linker.

## How

```sh
cd examples/ffi_add
gcc -c add.c -o add.o
ar rcs libadd.a add.o
dart run ../../bin/klin.dart run main.kl
# → 5
```

Equivalent without `@[link]` on the function (still needs `@[cimport]`):

```sh
dart run ../../bin/klin.dart run -L. -ladd main.kl
```

## Links

- [docs/09-ffi-c.md](../../docs/09-ffi-c.md)
- [issues/021](../../issues/021-c-libraries.md)
