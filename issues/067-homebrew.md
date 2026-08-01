# 067 — Homebrew: `brew install klin`

**Status:** ✅ zrobione (formula + CI; publiczny tap/release = krok operatorski)
**Zależy od:** — (publiczne release’y odblokowują *stable*; HEAD działa z dostępem do repo)

## Nazwa

`klin` **wolne** w homebrew-core (brak formula/cask). Podobne, ale inne:
`kin`, `klim`.

## Dostarczone w repo

| Artefakt | Sens |
|---|---|
| [`Formula/klin.rb`](../Formula/klin.rb) | build from source (`dart compile exe`) + `pkgshare` stdlib |
| [`.github/workflows/release.yml`](../.github/workflows/release.yml) | tag `v*` → binarki macOS/Linux + GitHub Release |
| [`note/17-homebrew.md`](../note/17-homebrew.md) | instalacja / tap / sha256 |

Odkrywanie stdlib przy binarke / Homebrew `share/klin`: `lib/project.dart`.

```sh
brew tap dart-lang/dart
brew install --HEAD --formula Formula/klin.rb
```

**Zalecenie na stałe:** tap `MrHIDEn/homebrew-klin` → `brew install mrhiden/klin/klin`.
homebrew-core później.

`brew upgrade klin` = upgrade **kompilatora**, nie pakietów `.kl`
([066](066-klin-upgrade-outdated.md)).

## Checklista

- [x] `Formula/klin.rb` (HEAD + miejsce na stable url/sha256)
- [x] workflow release przy tagu `v*`
- [x] stdlib obok instalacji (pkgshare + search paths)
- [x] nota + README
- [ ] operatorsko: publiczne repo i/lub `homebrew-klin` + tag `v0.1.0` + wypełnienie sha256

## Poza zakresem

- PR do homebrew-core
- Windows (Homebrew nie jest ścieżką; `task release` / scoop później)
