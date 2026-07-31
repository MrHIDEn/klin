# 032 — `klin run <plik.kl>`

**Status:** 💭 do rozważenia
**Zależy od:** 001 (rurociąg compile→run już istnieje)

## Cel

Wygodna komenda jak `go run` / `cargo run`:

```bash
klin run an-file.kl
```

od razu: parse → check → emit → cc → uruchomienie (stdout/stderr procesu).

Dziś to samo robi domyślna ścieżka `klin <plik.kl>` /
`dart run bin/klin.dart <plik.kl>`, ale **bez podkomendy** — chcę jawnego
`run` w CLI (czytelniej, miejsce na `klin build`, `klin check`, …).

## Zakres (szkic)

- subcommand `run` (wymagany plik `.kl`)
- zachować flagi typu `--cc gcc|clang|tcc`
- `klin <plik.kl>` bez subcommand — do decyzji: alias `run` albo deprecate później
- opcjonalnie później: `klin build` (tylko binarka), `klin check` (bez cc)

## Czego nie robić w pierwszym cięciu

- Nie menedżer pakietów / `KLIN_PATH` (to bliżej 020).
- Nie emulator / flash na MCU — tylko hostowy run jak dziś.
