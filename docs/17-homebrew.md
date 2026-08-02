# Homebrew — installing the Klin compiler (issue 067)

`brew upgrade klin` = upgrade the **compiler**, not `.kl` packages
([066](../issues/066-klin-upgrade-outdated.md)).

## Status

- Formula in repo: [`Formula/klin.rb`](../Formula/klin.rb)
- CI release on tag `v*`: [`.github/workflows/release.yml`](../.github/workflows/release.yml)
- Name `klin` free in homebrew-core; own **tap** first, core later
- Repo `klin` may be private — then `brew` works only for people with access
  (HTTPS token / SSH) or after going public + release

## Platforms in Release ([076](../issues/076-release-windows-arm.md))

On tag `v*` workflow builds 6 assets (`dart compile exe` per host — no
cross-compilation):

| Platform | Asset |
|---|---|
| macOS arm64 / x64 | `klin-macos-arm64.tar.gz` / `klin-macos-amd64.tar.gz` |
| Linux x64 / arm64 | `klin-linux-amd64.tar.gz` / `klin-linux-arm64.tar.gz` |
| Windows x64 / arm64 | `klin-windows-amd64.zip` / `klin-windows-arm64.zip` |

Each asset has `.sha256`. Homebrew covers macOS/Linux; Windows for now via
`.zip` from Release (Scoop/WinGet — future). On Windows host C compiler for
`klin run` is MSVC / clang / mingw.

## Install (HEAD / from clone)

Requires [Dart tap](https://github.com/dart-lang/homebrew-dart) to build:

```sh
brew tap dart-lang/dart
# from this repository directory:
brew install --HEAD --formula Formula/klin.rb
klin --version
```

Or a separate tap (recommended long-term):

```sh
# once: create public MrHIDEn/homebrew-klin and copy Formula/klin.rb
brew tap mrhiden/klin
brew install --HEAD mrhiden/klin/klin
```

## Stable (after public tag)

1. Make repo public (or host tarball) and push tag `v0.1.0`
2. `release` workflow builds binaries + assets
3. Compute source sha:

```sh
curl -sL \
  "https://github.com/MrHIDEn/klin/archive/refs/tags/v0.1.0.tar.gz" \
  | shasum -a 256
```

4. In `Formula/klin.rb` uncomment `url` / `sha256` and update checksum
5. Copy formula to `homebrew-klin` (if separate tap)

```sh
brew install mrhiden/klin/klin
brew upgrade klin
```

## Install layout

- `bin/klin` — AOT (`dart compile exe`)
- `share/klin/stdlib/` — stdlib (`pkgshare`); compiler also looks for `stdlib/`
  next to binary ([`lib/project.dart`](../lib/project.dart))

Host `gcc` / `clang` / `tcc` still required for `klin run`.
