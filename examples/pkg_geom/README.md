# Directory package = one module (issue 047)

`import geom` loads the **directory** `geom/` (both production `.kl` files share
`module geom`). Private `sq` in `len.kl` is visible to `len_sq` in the same
package; only `pub` symbols are usable from `app.kl`.

`geom/len_test.kl` matches `*_test.kl` and is **skipped** when loading the
package (like Go `_test.go`) — it does not affect `klin run app.kl`.

```text
examples/pkg_geom/
  app.kl
  geom/
    vec.kl
    len.kl
    len_test.kl   # omitted from package load
```

```sh
cd examples/pkg_geom
dart run ../../bin/klin.dart run app.kl
# → 25
```

Search paths: [docs/11-klin-libraries.md](../../docs/11-klin-libraries.md).
Modules / `pub`: [docs/12-modules.md](../../docs/12-modules.md).
