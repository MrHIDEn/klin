# 021 — Biblioteki C (FFI / link)

**Status:** 💭 do rozważenia
**Zależy od:** 006?, deklaracje zewnętrzne (dziś cienkie `puts`/`printf` bez sygnatur)

## Kontekst

Dziś wywołania nieznanych nazw idą do C bez sprawdzania sygnatury. Na
hostcie linkuje się libc (`stdio` itd.). Brak modelu: własna `.a` / `.so`,
nagłówki, `-l`, deklaracje `extern` z typami Klin.

## Propozycja (później)

- jawne deklaracje FFI z typami (arity + typy argumentów/zwrotu)
- flaga / manifest: `-lfoo`, ścieżki `-L`, ewentualnie `#include` tylko
  przez cienką warstwę emitowaną przez frontend (gcc nie powinien być
  źródłem błędów typów użytkownika)
- bare-metal: ta sama ścieżka, inne liby (HAL, startup)

Konkretny trop HAL (STM32Cube / LL) → [031](031-biblioteki-hal.md).

Test zasady nadrzędnej: FFI nie ukrywa alokacji ani ownership — to
kontrakt użytkownika z C.

## Czego nie robić teraz

- Nie dopisywać pełnego parsera nagłówków C.
- Nie mieszać z bibliotekami Klina (020) ani ASM (022) w jednym issue.
