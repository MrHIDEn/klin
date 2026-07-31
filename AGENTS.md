# AGENTS.md

## Cursor Cloud specific instructions

Klin is a Dart-written compiler for the Klin language that emits one `.c` file and
invokes a host C compiler. Standard commands live in `README.md` and `Taskfile.yml`;
this section only records non-obvious, durable setup/run context for cloud agents.

### Toolchain already present (installed into the VM snapshot)

- Dart SDK is installed via the official apt package at `/usr/lib/dart` and symlinked
  to `/usr/bin/dart`, so `dart` is on `PATH` globally (no `nvm`/`mise`-style shims).
- `gcc` and `clang` are installed. `gcc` is the **default** C backend used by
  `klin run`/`klin test` (see `--cc`, default set in `bin/klin.dart`).
- `tcc` is **not** installed, so `dart run bin/klin.dart run --cc tcc <file.kl>` fails.
  Install `tcc` first if you need that backend.
- `go-task` (`task`) is **not** installed. `Taskfile.yml` targets are just thin
  wrappers over `dart` commands — run the underlying `dart …` commands directly, or
  install go-task if you prefer `task get/test/analyze`.

### Running / testing

- The update script runs `dart pub get`; no other bootstrap is needed.
- Lint: `dart analyze` (a pre-existing `unused_local_variable` warning in
  `test/pipeline_test.dart` is expected and non-blocking).
- Tests: `dart test` (Dart golden/pipeline suite). These spawn `gcc` to compile
  emitted C, so a host C compiler must stay on `PATH`.
- End-to-end run: `dart run bin/klin.dart run examples/hello.kl` compiles Klin → C →
  `gcc` → executes the binary.
- Compiler output goes to `out/` (gitignored). Do not commit `out/`, `build/`, or
  `.dart_tool/`.
