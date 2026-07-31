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

- jawny cache na dysku (katalog użytkownika / projektu)
- wersjonowanie / pin (lockfile lub tag w path) — minimum
- zaufanie: tylko jawne hosty / allowlista
- po pobraniu: ten sam model pakietu co 047 (katalog = moduł)

Zasada nadrzędna: brak ukrytego kosztu / magii — pobieranie musi być
widoczne w UX i w buildzie.

## CLI: pobieranie i aktualizacja

Jak Go (`go get` / `go get -u`): osobne komendy, nie cicha sieć przy
samym `klin run` (albo run tylko z cache + jasny komunikat „uruchom
`klin get`” — do decyzji przy realizacji).

| Komenda | Sens (szkic) |
|---|---|
| `klin get [path…]` | Pobierz brakujące remote `import "…"` (i ewent. artefakty z [053](053-device-board-assets.md)) do cache / vendor |
| `klin update [path…]` | Odśwież już pobrane zależności do nowszej dozwolonej wersji (jak `go get -u`); bez args = wszystkie z lockfile / importów projektu |
| `klin update path@tag` | Pin / bump konkretnego modułu (tag, commit, semver — format przy realizacji) |

Zachowanie:

- `update` **zawsze jawne** — nie aktualizować przy zwykłym `run` /
  `build` bez flagi
- po `update`: zapisz nowe piny w lockfile (gdy będzie); diff widoczny w git
- `--dry-run` (opcjonalnie): pokaż co by ściągnął / zmienił
- `--offline` na `run`: tylko cache; brak pliku = błąd z podpowiedzią `klin get`
- ten sam mechanizm cache może obsługiwać `$device("github/…")` z [053](053-device-board-assets.md)
  (`klin update` też dla SVD w cache — jedna infrastruktura)

Nazwy robocze: `get` / `update`. Alternatywy przy realizacji: `klin mod download`
/ `klin mod tidy` (styl Go) — wybrać jedną konwencję, nie obie naraz w MVP.

## Poza zakresem

- pełny registry jak npm / centrala Klin
- prywatne git bez jawnej konfiguracji
- implementacja aliasów lokalnych (to [048](048-import-aliases.md))
- surowe `import "*.svd"` w składni modułów — artefakty to [053](053-device-board-assets.md)
  (`$device("github/…/….svd")` = Go-like fetch SVD; ten issue = remote **modułów** Klin)
- auto-update w tle / przy każdym CI bez jawnego kroku
