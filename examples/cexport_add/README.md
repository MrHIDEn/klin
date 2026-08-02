# Export Klin → C (`@[cexport]`)

Klin still requires a `main` in the `.kl` entry file; rename it in the
emitted C so your C program owns the entry point.

From the **repo root**:

```sh
dart run bin/klin.dart --emit-c --emit-h examples/cexport_add/lib.kl
# Rename Klin's empty main (required by the frontend):
sed -i.bak 's/int main(void)/static int klin_lib_main(void)/g' out/lib.c
gcc -I out examples/cexport_add/caller.c out/lib.c -o out/add_demo
./out/add_demo
# → 5
```

Or from `examples/cexport_add/` (emit writes `out/` under the current directory):

```sh
cd examples/cexport_add
dart run ../../bin/klin.dart --emit-c --emit-h lib.kl
sed -i.bak 's/int main(void)/static int klin_lib_main(void)/g' out/lib.c
gcc -I out caller.c out/lib.c -o add_demo
./add_demo
```

`lib.kl` uses `@[cexport, codename("klin_add")]`. `--emit-h` writes
`out/lib.h` with the C prototype. ISR-style exports can still use
`@[codename("…")]` alone (see `examples/stm32/`). Details:
[docs/09-ffi-c.md](../../docs/09-ffi-c.md).
