# CLI Klin

Wejście: `dart run bin/klin.dart <subcommand|plik.kl> …`

## Meta

| Flaga | Sens |
|---|---|
| `--version` / `-v` | Wypisz `klin <wersja>` (z `lib/version.dart` / `pubspec.yaml`) |
| `--help` / `-h` | Usage na stdout, exit 0 |
| *(bez argumentów)* | Jak `--help` |

## Subkomendy

| Komenda | Sens |
|---|---|
| `run <plik.kl>` | Preprocess → parse → check → emit C → host `cc` → uruchom |
| *(bare path)* | Alias `run` — `klin examples/hello.kl` |
| `fmt [-w] <plik.kl>` | Canonical printer (4 spacje, K&R). Bez `-w` → stdout; z `-w` → zapis |
| `test [ścieżka…]` | Szuka `*_test.kl`, uruchamia `test_*` (jak `go test`) |
| `get [path[@ref]…]` | Pobierz remote (`github`/`gitlab`) do cache + `klin.mod` ([049](../issues/049-remote-imports.md)) |
| `update [path[@ref]…]` | Force ponowne pobranie (bez args = wszystkie z `klin.mod`) |

`run` / `test` **nie** otwierają sieci na remote — tylko cache.

## Flagę przed / przy `run`

| Flaga | Sens |
|---|---|
| `--emit-c` | Zapisz wygenerowany `.c` (domyślnie `out/`), bez kompilacji / run |
| `--emit-h` | Zapisz nagłówek C z prototypami `@[cexport]` (`out/<base>.h`) |
| `--emit-pp` | Zapisz wynik preprocessora (`.pp.kl`), bez dalszych etapów |
| `--cc <gcc\|clang\|tcc>` | Host C compiler (domyślnie `gcc`) |
| `-I <dir>` / `-Idir` | Szukaj źródeł Klin (`import` → `name.kl`) w `dir` |
| `-l <name>` / `-lname` | Link `-lname` (jak cc; FFI C) |
| `-L <dir>` / `-Ldir` | Szukaj libów C w `dir` |

Ścieżki Klin (`lib/`, `-I`, `$KLIN_PATH`): [11-biblioteki-klin.md](11-biblioteki-klin.md).
Moduły (`module` / `import` / `pub`): [12-moduly.md](12-moduly.md).
Szczegóły fmt: [05-fmt.md](05-fmt.md). Makra / SVD: [04-makra.md](04-makra.md).
FFI (import `@[cimport]`/`@[link]` i export `@[cexport]`): [09-ffi-c.md](09-ffi-c.md).
