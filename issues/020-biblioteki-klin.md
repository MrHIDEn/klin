# 020 — Własne biblioteki Klina

**Status:** ✅ zrobione
**Zależy od:** [006](006-moduly.md)

## Zakres MVP

- `import name` bez nowej składni; search:
  sibling → `lib/` → `-I` → `$KLIN_PATH` → `$KLIN_STDLIB` / repo `stdlib/`
- CLI `-I <dir>` (także `-Idir`); `$KLIN_PATH` (PATH-style)
- emisja: jeden `.c` (jak 006); `pub` = API biblioteki
- przykład: [`examples/klin_lib/`](../examples/klin_lib/)
- nota: [`note/11-biblioteki-klin.md`](../note/11-biblioteki-klin.md)

## Czego nie robimy

- menedżer pakietów / wersje / rejestr
- manifest projektu
- nested `import a/b`
- osobne jednostki `.c`/`.a` z lib Klin
- mieszanie z FFI C (021) / ASM (022) w tym kroku
