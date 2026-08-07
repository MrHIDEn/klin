#!/usr/bin/env bash
# Copy TextMate / VS Code pack into plugin resources (run after editing editors/vscode).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/../vscode"
DST="$ROOT/src/main/resources/textmate/klin"
mkdir -p "$DST/syntaxes"
cp "$SRC/package.json" "$DST/package.json"
cp "$SRC/language-configuration.json" "$DST/language-configuration.json"
cp "$SRC/syntaxes/klin.tmLanguage.json" "$DST/syntaxes/klin.tmLanguage.json"
echo "Synced TextMate pack → $DST"
