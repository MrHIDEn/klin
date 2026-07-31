# Biblioteki Klina (issue 020)

Wielokrotnego użytku `.kl` bez kopiowania źródeł — to **ścieżki search**
dla istniejącego `import name` → `name.kl` (moduły z [006](../issues/006-moduly.md)).
Bez menedżera pakietów, bez nowego składniowego importu.

## Resolucja

Pierwszy istniejący plik wygrywa:

1. `<katalog_importera>/name.kl` — sibling
2. `<katalog_importera>/lib/name.kl` — lokalny `lib/`
3. każdy `-I <dir>/name.kl` (kolejność flag CLI)
4. każdy element `$KLIN_PATH` (`:` na Unix, `;` na Windows)
5. `$KLIN_STDLIB` / repo `stdlib/` — jak wcześniej

`$KLIN_STDLIB` zostaje override’em stdlib; nie łączyć z `$KLIN_PATH`.

## Przykład

```klin
// examples/klin_lib/app.kl
import mathx
fn main() {
    printf("%d\n", mathx.add(2, 3))
}
```

`mathx` leży w `lib/mathx.kl` (`pub fn add`). Emisja nadal **jeden** `.c`.
API biblioteki = `pub` z 006.

```sh
dart run bin/klin.dart run examples/klin_lib/app.kl
dart run bin/klin.dart run -I /path/to/vendor app.kl
KLIN_PATH=/path/to/vendor dart run bin/klin.dart run app.kl
```

## Poza zakresem

Manifest / wersje / rejestr, nested `import a/b`, osobne `.a` z lib Klin.
FFI C: [09-ffi-c.md](09-ffi-c.md). CLI: [06-cli.md](06-cli.md).
