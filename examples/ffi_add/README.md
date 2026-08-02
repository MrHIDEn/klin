# Host FFI: link a C static library

Build a tiny `.a`, then run Klin with `@[cimport]` + `@[link]`:

```sh
cd examples/ffi_add
gcc -c add.c -o add.o
ar rcs libadd.a add.o
dart run ../../bin/klin.dart run main.kl
# → 5
```

Equivalent CLI without `@[link]` on the function:

```sh
dart run ../../bin/klin.dart run -L. -ladd main.kl
```

(still needs `@[cimport]` for `add`). Details: [docs/09-ffi-c.md](../../docs/09-ffi-c.md).
