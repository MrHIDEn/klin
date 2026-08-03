# Directory package = one module

`import geom` loads the **directory** `geom/` as a single module.

## What

```text
examples/pkg_geom/
  app.kl
  geom/
    vec.kl
    len.kl
    len_test.kl   # *_test.kl — skipped on package load
```

Private `sq` in `len.kl` is visible to `len_sq` in the same package; only `pub`
symbols are usable from `app.kl`.

## Why

Issue [047](../../issues/047-directory-modules.md): split a module across files
without changing the import name (Go-style package directory). `*_test.kl` is
omitted from production load, like Go `_test.go`.

## How

```sh
cd examples/pkg_geom
dart run ../../bin/klin.dart run app.kl
# → 25
```

## Links

- [docs/11-klin-libraries.md](../../docs/11-klin-libraries.md)
- [docs/12-modules.md](../../docs/12-modules.md)
- File-per-module layout: [`../modules/`](../modules/)
