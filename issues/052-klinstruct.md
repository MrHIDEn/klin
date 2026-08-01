# 052 — `klinstruct`: pack/unpack buforów (para do `@mrhiden/cstruct`)

**Status:** 💭 do rozważenia — MVP atomów w [klinstruct](https://github.com/MrHIDEn/klinstruct); bogatsza deklaracja → [059](059-kstruct-macros.md)
**Zależy od:** [007](007-wskazniki-tablice-slice.md); mile [020](020-biblioteki-klin.md) / [047](047-directory-modules.md); remote → [049](049-remote-imports.md); deklaracje `$kstruct` → [059](059-kstruct-macros.md)

## Kontekst

[`@mrhiden/cstruct`](https://github.com/MrHIDEn/cstruct) (TS/JS) pakuje/odpakowuje
binarne bufory (Buffer ⇔ obiekt) wg modelu typów (LE/BE, atomy, offsety).

Cel: osobna biblioteka **Klin** — roboczo `klinstruct` / repo
`github/mrhiden/klinstruct` — **to samo podejście po stronie Klina**, żeby
JS (cstruct) i Klin mówiły wspólnym wire formatem.

To **nie** jest FFI do npm ani port TypeScriptu do Klina. Dwie implementacje,
jeden kontrakt binarny.

## Szkic (później)

- pakiet Klin: model pól → `make` / `read` na `u8[]` / wskaźniku + długość
- endian LE/BE jak cstruct; zgodność layoutu (kolejność, rozmiary, padding)
- testy krzyżowe: ten sam hex bufora z cstruct i klinstruct
- ewent. makra `$…` pod modele → [059](059-kstruct-macros.md) (zależne od [026](026-preprocessor.md))
- po [049](049-remote-imports.md): `import "github.com/mrhiden/klinstruct" kstruct`

## Poza zakresem

- zależność runtime od Node / `@mrhiden/cstruct`
- generowanie TS z Klina w MVP (osobna decyzja / narzędzie)
- priorytet względem rdzenia języka / embedded
