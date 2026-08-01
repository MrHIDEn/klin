# 076 — Release: cele Windows/ARM + wydanie + sumy kontrolne

**Status:** 🔨 w toku (workflow rozszerzony; wydanie v* = akcja maintainera)
**Zależy od:** [067](067-homebrew.md)

## Cel

Rozszerzyć [`.github/workflows/release.yml`](../.github/workflows/release.yml)
o więcej platform i opisać proces wydania + weryfikację sum kontrolnych.

## Cele build (na tag `v*`)

| Platforma | Runner | Asset |
|---|---|---|
| macOS arm64 | `macos-15` | `klin-macos-arm64.tar.gz` |
| macOS x64 | `macos-15-intel` | `klin-macos-amd64.tar.gz` |
| Linux x64 | `ubuntu-22.04` | `klin-linux-amd64.tar.gz` |
| Linux arm64 | `ubuntu-24.04-arm` | `klin-linux-arm64.tar.gz` |
| Windows x64 | `windows-latest` | `klin-windows-amd64.zip` |
| Windows arm64 | `windows-11-arm` | `klin-windows-arm64.zip` (`continue-on-error`) |

`dart compile exe` buduje pod hosta (brak cross-kompilacji) — stąd runner per
cel. Windows: `.zip` + `Get-FileHash` (pwsh); Unix: `.tar.gz` + `shasum`. Każdy
asset ma `.sha256`.

Windows ARM64 to najświeższy runner (`windows-11-arm`) — oznaczony jako
eksperymentalny (`continue-on-error`), by nie blokować całego release'u, jeśli
zawiedzie.

## Proces wydania (akcja maintainera — nie robi tego agent)

1. `git tag vX.Y.Z && git push origin vX.Y.Z` → workflow buduje 6 assetów +
   publikuje GitHub Release.
2. Wypełnić `sha256` w [`Formula/klin.rb`](../Formula/klin.rb) ze źródła
   (job `source-checksum` podaje URL/komendę) — jak `go.sum` dla Homebrew.
3. Zweryfikować `.sha256` przy assetach.

## Dystrybucja

- macOS/Linux: Homebrew ([067](067-homebrew.md)).
- Windows: brak Homebrew — na teraz `.zip` z Release; kanały Scoop/WinGet =
  przyszłość (osobno).

## Uwaga

Wydana binarka to **frontend** Klina; do `klin run` nadal potrzebny hostowy
kompilator C (gcc/clang/tcc; na Windows MSVC/clang/mingw).

## Kryteria

- [x] `release.yml`: 6 celów (macOS arm64/x64, Linux x64/arm64, Windows x64/arm64).
- [x] Pakowanie per-OS (`tar.gz`/`zip`) + `.sha256`.
- [ ] Pierwszy tag `v*` przechodzi end-to-end (test przy realnym wydaniu).
- [ ] Docs: lista platform + nota o C-kompilatorze na Windows.
