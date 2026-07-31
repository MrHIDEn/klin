# 032 — `klin run <plik.kl>`

**Status:** ✅ ukończone
**Zależy od:** 001 (rurociąg compile→run już istnieje)

## Cel

Wygodna komenda jak `go run` / `cargo run`:

```bash
klin run an-file.kl
```

od razu: parse → check → emit → cc → uruchomienie (stdout/stderr procesu).

## Decyzja

- Subcommand **`run`** — jawna ścieżka compile→run.
- Bare `klin <plik.kl>` zostaje **aliasem** `run` (bez deprecate na razie).
- Flagi: `--cc gcc|clang|tcc`; `--emit-c` jak wcześniej (bez uruchamiania).
- `build` / `check` — później, nie w tym kroku.

## Kryterium ukończenia

- [x] `klin run test/hello.kl` wypisuje oczekiwane wyjście
- [x] bare `klin test/hello.kl` nadal działa
- [x] `klin run` bez pliku → usage, exit ≠ 0
