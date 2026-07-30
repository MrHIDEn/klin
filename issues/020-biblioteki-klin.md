# 020 — Własne biblioteki Klina

**Status:** 💭 do rozważenia
**Zależy od:** 006 (moduły), ewentualnie 012

## Kontekst

Po 006 projekt może mieć wiele plików i `import`. Brakuje jeszcze modelu
**biblioteki**: pakiet `.kl` wielokrotnego użytku (lokalny katalog, później
ew. rejestr), który użytkownik dołącza do swojego programu bez kopiowania
źródeł ręcznie.

## Propozycja (później)

- katalog / manifest biblioteki (ścieżki, nazwa modułu, wersja — minimum)
- kompilator zna ścieżki search (`KLIN_PATH`, flaga CLI, lokalne `lib/`)
- emisja: jeden czytelny `.c` (albo jawne linkowanie kilku jednostek — do decyzji)
- `pub` z 006 steruje API biblioteki

Zgodność z zasadą nadrzędną: zero ukrytej alokacji / magii w „ładowaniu”
biblioteki — to tylko organizacja źródeł i mangling.

## Czego nie robić teraz

- Nie budować menedżera pakietów przed działającymi modułami (006).
- Nie mieszać z FFI do C (021) ani z ASM (022) w jednym kroku.
