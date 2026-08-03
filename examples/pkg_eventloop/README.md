# eventloop (local package — publish as `github/mrhiden/eventloop`)

Cooperative executor for Klin (issue 029): callback timers **and**
`async` / `.await` task slots (`sleep_ms` + `spawn`).

```sh
dart run bin/klin.dart run examples/pkg_eventloop/app.kl
dart run bin/klin.dart run examples/pkg_eventloop/async_app.kl
dart run bin/klin.dart test examples/pkg_eventloop/
```

See [PACKAGE.md](PACKAGE.md) to publish `v0.2.0` to
[MrHIDEn/eventloop](https://github.com/MrHIDEn/eventloop).
