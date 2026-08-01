# 063 — Publiczna biblioteka-fixture `osa` (remote import)

**Status:** 💭 (repo publiczne jest; treść + tag `v0.1.0` do wypchnięcia)
**Zależy od:** [047](047-directory-modules.md) (katalog = moduł)
**Konsumowane przez:** [049](049-remote-imports.md)

## Cel

Osobne, **publiczne** repozytorium GitHub z minimalnym pakietem Klin —
stabilne źródło pod e2e / przykłady `import "github/mrhiden/osa"` i
`klin get` / `update` (049). Nie jest częścią stdlib Klin.

| | |
|---|---|
| Repo | https://github.com/MrHIDEn/osa |
| Path importu | `github/mrhiden/osa` |
| Forma | katalog-pakiet `osa/*.kl` (jak 047) |
| Zależności | brak (czysty Klin, bez FFI) |
| Licencja | MIT |
| Pin MVP | git tag `v0.1.0` (`version()` = `1`) |

## Layout

```text
osa/                 # root repo
  README.md
  LICENSE
  osa/
    version.kl       # module osa — pub fn version(): i32
    math.kl          # module osa — pub fn add / clamp
    math_test.kl     # *_test.kl — pomijane przy import (047)
```

## API (`v0.1.0`)

| Symbol | Sens |
|---|---|
| `version(): i32` | wersja pakietu (`1` przy `v0.1.0`) |
| `add(a, b): i32` | suma |
| `clamp(v, lo, hi): i32` | ograniczenie do `[lo, hi]` |

## Wersjonowanie

- Tag `v0.1.0` = MVP powyżej
- Później `v0.2.0` z `version()` → `2` wyłącznie pod test `klin update` (049)
- Bez registry — tylko git tags

## Checklista

- [x] publiczne repo `MrHIDEn/osa`
- [ ] treść (README, LICENSE, `osa/*.kl`) na `main`
- [ ] tag `v0.1.0` wypchnięty
- [x] ten issue + wpis w [sorted.md](sorted.md) + link w [049](049-remote-imports.md)

### Wypchnięcie treści (właściciel repo / token z `contents:write`)

Agent cloud ma instalację GitHub App tylko na `klin` — push do `osa`
kończy się 403. Lokalnie (konto z write):

```bash
git clone https://github.com/MrHIDEn/osa.git
cd osa
# wgraj pliki jak w Layout (treść: README EN, MIT, version/math/math_test)
git add -A
git commit -m "Initial osa fixture for Klin remote imports"
git push -u origin main
git tag v0.1.0 && git push origin v0.1.0
```

Po tagu: odznacz checklistę i ustaw **Status:** ✅ w tym pliku.

## Poza zakresem

- implementacja `klin get` / lockfile → [049](049-remote-imports.md)
- mirror GitLab
- kopia `osa` jako jedyne źródło prawdy w monorepo Klin
