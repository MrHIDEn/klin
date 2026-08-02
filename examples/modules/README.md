# Modules — `module` / `import` / `pub` (issue 006)

Three files = three modules. `app` imports `geom` and `util`; only `pub`
symbols are visible across module boundaries.

```text
examples/modules/
  app.kl     # module app — entry
  geom.kl    # module geom — pub Vec2 + len_sq
  util.kl    # module util — pub add
```

```sh
cd examples/modules
dart run ../../bin/klin.dart run app.kl
# → len_sq=25
# → 2+3=5
```

Details: [docs/12-moduly.md](../../docs/12-moduly.md).

Directory package (many files, one module): [`../pkg_geom/`](../pkg_geom/) —
[docs/11-biblioteki-klin.md](../../docs/11-biblioteki-klin.md).
