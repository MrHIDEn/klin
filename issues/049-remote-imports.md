# 049 — Importy zdalne (GitHub / path jak Go)

**Status:** 💭 do rozważenia
**Zależy od:** [048](048-import-aliases.md) (string + alias), [020](020-biblioteki-klin.md), [047](047-directory-modules.md)

## Kontekst

Go: `import "github.com/user/repo/pkg"`. Klin mógłby w przyszłości
ściągać / cache’ować źródła `.kl` z hosta, bez kopiowania ręcznego.

## Proponowana składnia

```klin
import "github/mrhiden/osa"       // qualifier = osa (ostatni segment)
import "github/mrhiden/osa" oso   // qualifier = oso
```

## Szkic (później)

- jawny cache na dysku (katalog użytkownika / projektu) — zero ukrytej sieci
  przy samym `klin run` bez wcześniejszego fetch, **albo** jawna komenda
  `klin get` (do decyzji przy realizacji)
- wersjonowanie / pin (lockfile lub tag w path) — minimum
- zaufanie: tylko jawne hosty / allowlista
- po pobraniu: ten sam model pakietu co 047 (katalog = moduł)

Zasada nadrzędna: brak ukrytego kosztu / magii — pobieranie musi być
widoczne w UX i w buildzie.

## Poza zakresem

- pełny registry jak npm / centrala Klin
- prywatne git bez jawnej konfiguracji
- implementacja aliasów lokalnych (to [048](048-import-aliases.md))
