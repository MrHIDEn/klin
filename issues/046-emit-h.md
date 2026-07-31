# 046 — Nagłówek C z eksportów (`--emit-h`)

**Status:** 💭 do rozważenia
**Zależy od:** [045](045-cexport.md)

## Kontekst

Po `@[cexport, codename]` C woła symbole Klin, ale prototypy trzeba pisać
ręcznie w `.h`. Flaga `--emit-h` mogłaby emitować nagłówek z deklaracjami
dla wyeksportowanych funkcji.

## Szkic (później)

- `klin --emit-h foo.kl` → `out/foo.h` (prototypy C z typami Klina)
- spójność z `--emit-c` / `#line` / `codename`
- nie zastępuje pełnego pack `.a` / `.so`

## Poza zakresem teraz

Implementacja — tylko placeholder w roadmapie. Szczegóły przy realizacji 045
„poza zakresem”.
