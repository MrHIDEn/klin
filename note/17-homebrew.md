# Homebrew — instalacja kompilatora Klin (issue 067)

`brew upgrade klin` = upgrade **kompilatora**, nie pakietów `.kl`
([066](../issues/066-klin-upgrade-outdated.md)).

## Stan

- Formula w repo: [`Formula/klin.rb`](../Formula/klin.rb)
- CI release przy tagu `v*`: [`.github/workflows/release.yml`](../.github/workflows/release.yml)
- Nazwa `klin` wolna w homebrew-core; najpierw **własny tap**, core później
- Repo `klin` może być private — wtedy `brew` działa tylko dla osób z dostępem
  (HTTPS token / SSH) albo po upublicznieniu + release

## Platformy w Release ([076](../issues/076-release-windows-arm.md))

Na tag `v*` workflow buduje 6 assetów (`dart compile exe` per host — brak
cross-kompilacji):

| Platforma | Asset |
|---|---|
| macOS arm64 / x64 | `klin-macos-arm64.tar.gz` / `klin-macos-amd64.tar.gz` |
| Linux x64 / arm64 | `klin-linux-amd64.tar.gz` / `klin-linux-arm64.tar.gz` |
| Windows x64 / arm64 | `klin-windows-amd64.zip` / `klin-windows-arm64.zip` |

Każdy asset ma `.sha256`. Homebrew obejmuje macOS/Linux; Windows na teraz przez
`.zip` z Release (Scoop/WinGet — przyszłość). Na Windows host C-kompilator do
`klin run` to MSVC / clang / mingw.

## Instalacja (HEAD / z clone)

Wymaga [Dart tap](https://github.com/dart-lang/homebrew-dart) do zbudowania:

```sh
brew tap dart-lang/dart
# z katalogu tego repozytorium:
brew install --HEAD --formula Formula/klin.rb
klin --version
```

Albo osobny tap (zalecane na stałe):

```sh
# raz: utwórz publiczne MrHIDEn/homebrew-klin i skopiuj Formula/klin.rb
brew tap mrhiden/klin
brew install --HEAD mrhiden/klin/klin
```

## Stable (po publicznym tagu)

1. Upublicznij repo (albo hostuj tarball) i wypchnij tag `v0.1.0`
2. Workflow `release` zbuduje binarki + assets
3. Policz sha źródła:

```sh
curl -sL \
  "https://github.com/MrHIDEn/klin/archive/refs/tags/v0.1.0.tar.gz" \
  | shasum -a 256
```

4. W `Formula/klin.rb` odkomentuj `url` / `sha256` i zaktualizuj sumę
5. Skopiuj formulę do `homebrew-klin` (jeśli tap osobny)

```sh
brew install mrhiden/klin/klin
brew upgrade klin
```

## Layout instalacji

- `bin/klin` — AOT (`dart compile exe`)
- `share/klin/stdlib/` — stdlib (`pkgshare`); kompilator szuka też `stdlib/`
  obok binarki ([`lib/project.dart`](../lib/project.dart))

Hostowy `gcc` / `clang` / `tcc` nadal potrzebny do `klin run`.
