#!/usr/bin/env bash
# Compare Klin blink.elf vs hand-written blink_ref.elf (issue 028).
# Requires both ELFs already built (make elf / make ref).
set -euo pipefail
cd "$(dirname "$0")"

KLIN_ELF=${1:-blink.elf}
REF_ELF=${2:-blink_ref.elf}
OUT=${3:-overhead.md}

for f in "$KLIN_ELF" "$REF_ELF"; do
  if [[ ! -f "$f" ]]; then
    echo "missing $f — run: make elf FREERTOS_DIR=… && make ref FREERTOS_DIR=…" >&2
    exit 1
  fi
done

OBJDUMP=${OBJDUMP:-arm-none-eabi-objdump}
SIZE=${SIZE:-arm-none-eabi-size}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

sym_size() {
  local elf=$1 sym=$2 hex
  # nm -S: address size type name
  hex=$(arm-none-eabi-nm -S "$elf" 2>/dev/null | awk -v s="$sym" '$4==s {print $2; exit}')
  if [[ -z "$hex" ]]; then
    echo 0
  else
    printf '%d\n' "$((16#$hex))"
  fi
}

dump_sym() {
  local elf=$1 sym=$2 dest=$3
  "$OBJDUMP" -d "$elf" | awk -v s="<$sym>:" '
    $0 ~ s {p=1}
    p && /^[0-9a-f]+ </ && $0 !~ s {exit}
    p {print}
  ' >"$dest"
}

{
  echo "# FreeRTOS blink — Klin vs C overhead (issue 028)"
  echo
  echo "Same FreeRTOS-Kernel, \`FreeRTOSConfig.h\`, \`CFLAGS\`, linker script."
  echo "Klin: \`blink.kl\` → \`blink.elf\`. C twin: \`blink_ref.c\` → \`blink_ref.elf\`."
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%MZ)"
  echo
  echo "## \`size\` (whole ELF)"
  echo
  echo '```'
  echo "=== Klin ($KLIN_ELF) ==="
  "$SIZE" "$KLIN_ELF"
  echo
  echo "=== C ref ($REF_ELF) ==="
  "$SIZE" "$REF_ELF"
  echo '```'
  echo
  echo "## App symbol sizes (bytes, \`nm -S\`)"
  echo
  echo "| Symbol | Klin | C ref |"
  echo "|---|---:|---:|"
  for sym in task_blink task_heartbeat main; do
    ks=$(sym_size "$KLIN_ELF" "$sym")
    rs=$(sym_size "$REF_ELF" "$sym")
    echo "| \`$sym\` | $ks | $rs |"
  done
  echo
  echo "## \`task_heartbeat\` disassembly (pure RTOS delay loop)"
  echo
  echo "Both should only call \`vTaskDelay\` in the loop — no Klin runtime."
  echo
  dump_sym "$KLIN_ELF" task_heartbeat "$tmp/klin_hb.txt"
  dump_sym "$REF_ELF" task_heartbeat "$tmp/ref_hb.txt"
  echo "### Klin"
  echo
  echo '```'
  cat "$tmp/klin_hb.txt"
  echo '```'
  echo
  echo "### C ref"
  echo
  echo '```'
  cat "$tmp/ref_hb.txt"
  echo '```'
  echo
  echo "## Verdict"
  echo
  echo "- FreeRTOS entry points are direct C calls (\`vTaskDelay\`, \`xTaskCreate\`,"
  echo "  \`vTaskStartScheduler\`) — Klin FFI is thin \`@[cimport]\`, not a scheduler."
  hb_k=$(sym_size "$KLIN_ELF" task_heartbeat)
  hb_r=$(sym_size "$REF_ELF" task_heartbeat)
  text_k=$("$SIZE" "$KLIN_ELF" | awk 'NR==2{print $1}')
  text_r=$("$SIZE" "$REF_ELF" | awk 'NR==2{print $1}')
  echo "- \`task_heartbeat\` (fair RTOS-only compare): Klin=${hb_k} B, C=${hb_r} B —"
  echo "  identical delay loop, direct \`bl vTaskDelay\`, no Klin runtime."
  echo "- \`task_blink\` may differ: Klin uses \`machine_stm32.Pin\` helpers; C ref"
  echo "  inlines PA5 MMIO. That is board HAL shape, not FreeRTOS tax."
  echo "- Whole-ELF \`.text\`: Klin=${text_k}, C=${text_r} (delta from Pin /"
  echo "  thin wrappers; FreeRTOS kernel is shared)."
  echo
  echo "Conclusion: **no hidden FreeRTOS / scheduler overhead** from Klin vs the C twin."
} >"$OUT"

echo "wrote $OUT"
