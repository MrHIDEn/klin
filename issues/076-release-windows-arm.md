# 076 — Release: Windows/ARM targets + release + checksums

**Status:** 🔨 in progress (workflow extended; v* release = maintainer action)
**Depends on:** [067](067-homebrew.md)

## Goal

Extend [`.github/workflows/release.yml`](../.github/workflows/release.yml)
with more platforms and document release process + checksum verification.

## Build targets (on tag `v*`)

| Platform | Runner | Asset |
|---|---|---|
| macOS arm64 | `macos-15` | `klin-macos-arm64.tar.gz` |
| macOS x64 | `macos-15-intel` | `klin-macos-amd64.tar.gz` |
| Linux x64 | `ubuntu-22.04` | `klin-linux-amd64.tar.gz` |
| Linux arm64 | `ubuntu-24.04-arm` | `klin-linux-arm64.tar.gz` |
| Windows x64 | `windows-latest` | `klin-windows-amd64.zip` |
| Windows arm64 | `windows-11-arm` | `klin-windows-arm64.zip` (`continue-on-error`) |

`dart compile exe` builds for host (no cross-compilation) — hence runner per
target. Windows: `.zip` + `Get-FileHash` (pwsh); Unix: `.tar.gz` + `shasum`. Each
asset has `.sha256`.

Windows ARM64 is the newest runner (`windows-11-arm`) — marked
experimental (`continue-on-error`) so it does not block the whole release if it
fails.

## Release process (maintainer action — agent does not do this)

1. `git tag vX.Y.Z && git push origin vX.Y.Z` → workflow builds 6 assets +
   publishes GitHub Release.
2. Fill `sha256` in [`Formula/klin.rb`](../Formula/klin.rb) from source
   (job `source-checksum` provides URL/command) — like `go.sum` for Homebrew.
3. Verify `.sha256` on assets.

## Distribution

- macOS/Linux: Homebrew ([067](067-homebrew.md)).
- Windows: no Homebrew — for now `.zip` from Release; Scoop/WinGet channels =
  future (separate).

## Possible automation (future, optional)

Pipeline already builds and publishes all 6 versions from one tag (matrix,
`fail-fast: false`, job `publish`). To close “one button":

- **Auto-`sha256` in Homebrew**: after release compute source sum and update
  `sha256` in [`Formula/klin.rb`](../Formula/klin.rb) (commit/PR to tap),
  instead of manual step from `source-checksum`.
- **Smoke after build**: on each runner after compile run
  `klin --version` and compile `examples/hello.kl` (where host C exists), so
  release does not ship broken binary. Note: Windows needs C compiler
  on runner (MSVC/clang/mingw) — consider whether smoke only where
  `cc` is available.
- **`.sha256` verification**: `shasum -c` / `Get-FileHash` step checking
  sidecar consistency before publish.

## Note

Released binary is Klin **frontend**; `klin run` still needs host
C compiler (gcc/clang/tcc; on Windows MSVC/clang/mingw).

## Criteria

- [x] `release.yml`: 6 targets (macOS arm64/x64, Linux x64/arm64, Windows x64/arm64).
- [x] Per-OS packaging (`tar.gz`/`zip`) + `.sha256`.
- [ ] First tag `v*` passes end-to-end (test on real release).
- [ ] Docs: platform list + note about C compiler on Windows.
