# CLI Klin

Wejście: `dart run bin/klin.dart <subcommand|plik.kl> …`

## Subkomendy

| Komenda | Sens |
|---|---|
| `run <plik.kl>` | Preprocess → parse → check → emit C → host `cc` → uruchom |
| *(bare path)* | Alias `run` — `klin examples/hello.kl` |
| `fmt [-w] <plik.kl>` | Canonical printer (4 spacje, K&R). Bez `-w` → stdout; z `-w` → zapis |
| `test [ścieżka…]` | Szuka `*_test.kl`, uruchamia `test_*` (jak `go test`) |

## Flagę przed / przy `run`

| Flaga | Sens |
|---|---|
| `--emit-c` | Zapisz wygenerowany `.c` (domyślnie `out/`), bez kompilacji / run |
| `--emit-pp` | Zapisz wynik preprocessora (`.pp.kl`), bez dalszych etapów |

Szczegóły fmt: [05-fmt.md](05-fmt.md). Makra / SVD: [04-makra.md](04-makra.md).
