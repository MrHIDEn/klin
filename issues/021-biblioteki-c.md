# 021 — Biblioteki C (FFI / link)

**Status:** ✅ zrobione
**Zależy od:** 006 (moduły), atrybuty z 010

## Zakres MVP

- jawne `@[cimport]` z typami (arity + typy argumentów/zwrotu)
- `@[cinclude]` → `#include` w emisji (bez parsera nagłówków C)
- `@[link("…")]` przekazywane do host `cc` przy `klin run` / `klin test`
  - string zaczynający się od `-` → flaga as-is (`-lm`, `-L…`)
  - inaczej → ścieżka `.a` / `.o` / `.so` względem katalogu `.kl`
- CLI: `-l <name>`, `-L <dir>` (także sklejone `-lm`, `-L/path`)
- nieznane wywołania = błąd checkera, **oprócz** host builtins `puts` / `printf`
- przykład: [`examples/ffi_add/`](../examples/ffi_add/)
- nota: [`note/09-ffi-c.md`](../note/09-ffi-c.md)

Test zasady nadrzędnej: FFI nie ukrywa alokacji ani ownership — kontrakt
użytkownika z C.

HAL (STM32Cube / LL) → [031](031-biblioteki-hal.md).

## Poza zakresem / później

- [ ] Pełny parser nagłówków C
- [ ] Biblioteki Klina (020) / jednostki ASM (022) — osobne issue
- [ ] Manifest projektu (JSON/toml) zamiast attrs + CLI
- [ ] `cexport`, rpath / `LD_LIBRARY_PATH`
- [ ] Pełne typowanie varargs (`printf`) poza allowlistą builtins
