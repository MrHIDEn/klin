# Directory package = one module (issue 047)

`import geom` loads the **directory** `geom/` (both `.kl` files share
`module geom`). Private `sq` in `len.kl` is visible to `len_sq` in the same
package; only `pub` symbols are usable from `app.kl`.

```sh
cd examples/pkg_geom
dart run ../../bin/klin.dart run app.kl
# → 25
```

Details: [note/11-biblioteki-klin.md](../../note/11-biblioteki-klin.md).
