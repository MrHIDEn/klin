# Modules — `module` / `import` / `pub`

Three files = three modules; only `pub` symbols cross boundaries.

## What

```text
examples/modules/
  app.kl     # module app — entry
  geom.kl    # module geom — pub Vec2 + len_sq
  util.kl    # module util — pub add
```

`app` imports `geom` and `util`.

## Why

Classic multi-module layout (issue [006](../../issues/006-modules.md)) before
directory packages. Contrast with [`../pkg_geom/`](../pkg_geom/) (many files,
one module).

## How

```sh
cd examples/modules
dart run ../../bin/klin.dart run app.kl
# → len_sq=25
# → 2+3=5
```

## Links

- [docs/12-modules.md](../../docs/12-modules.md)
- [docs/11-klin-libraries.md](../../docs/11-klin-libraries.md)
- Directory package: [`../pkg_geom/`](../pkg_geom/)
