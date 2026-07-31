# Export Klin → C (`@[cexport]`)

Klin still requires a `main` in the `.kl` entry file; rename it in the
emitted C so your C program owns the entry point.

```sh
cd examples/cexport_add
dart run ../../bin/klin.dart --emit-c lib.kl
# Rename Klin's empty main (required by the frontend):
sed -i.bak 's/int main(void)/static int klin_lib_main(void)/g' ../../out/lib.c
gcc caller.c ../../out/lib.c -o add_demo
./add_demo
# → 5
```

`lib.kl` uses `@[cexport, codename("klin_add")]`. ISR-style exports can still
use `@[codename("…")]` alone (see `examples/stm32/`). Details:
[note/09-ffi-c.md](../../note/09-ffi-c.md).
