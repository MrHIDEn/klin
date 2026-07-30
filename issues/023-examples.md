# 023 — Katalog `examples/`

**Status:** 💭 do rozważenia (zalążek już w repo)
**Zależy od:** bieżącego stanu języka (001–007+)

## Cel

Katalog **`examples/`** z krótkimi, uruchamialnymi programami Klina —
nie testami złotymi (`test/`), tylko materiałem do nauki i demo:

```bash
dart run bin/klin.dart examples/hello.kl
```

## Zakres (docelowy)

- `examples/hello.kl` — minimalny start
- struktury / metody, moduły (kilka plików), slice / wskaźniki
- później: bare-metal (010), stdlib I/O (012), gdy będą gotowe
- nazwy plików / podkatalogi jako „dokumentacja” (lekser na razie
  **nie ma** komentarzy `//` — dopisać osobno albo po wsparciu komentarzy)

## Czego nie mieszać

- Nie zastępować `test/*.kl` — złote zostają w `test/`.
- Nie obiecywać pełnego tutoriala (to bliżej README / 013).
