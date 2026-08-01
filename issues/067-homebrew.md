# 067 — Homebrew: `brew install klin`

**Status:** 💭 do rozważenia (zablokowane na razie)
**Zależy od:** publiczne release’y kompilatora (repo **`klin` celowo private**)

## Nazwa

`klin` **wolne** w homebrew-core (brak formula/cask). Podobne, ale inne:
`kin`, `klim`.

## Czy łatwo?

| Ścieżka | Trudność | Uwagi |
|---|---|---|
| Własny tap `MrHIDEn/homebrew-klin` | łatwe | `Formula/klin.rb` + URL + sha256 + test `--version` |
| Prebuilt z GitHub Releases | wygodne dla usera | CI artefakty macOS/Linux |
| Build from source (Dart SDK) | średie | `depends_on` + `dart compile exe` |
| homebrew-core | trudniejsze | review, popularność, bottles |

**Zalecenie:** najpierw tap (`brew install mrhiden/klin/klin`), core później.

`brew upgrade klin` = upgrade **kompilatora**, nie pakietów `.kl`
([066](066-klin-upgrade-outdated.md)).

## Blokada

Dopóki `klin` jest private — bez publicznego źródła/release’ów formula
nie ma sensu. Issue zostaje w backlogu.
