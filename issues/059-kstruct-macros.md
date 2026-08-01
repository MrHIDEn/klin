# 059 — Makra / codegen pod bogatsze `klinstruct` (`$kstruct`)

**Status:** 💭 do rozważenia (niski priorytet — nieblokujące)
**Zależy od:** [026](026-preprocessor.md); [052](052-klinstruct.md); mile wzmocnienie `$fn` (export przez `import`, lepsze diagnostyki); nie [034](034-typy-generyczne.md)

## Kontekst

MVP [`klinstruct`](https://github.com/MrHIDEn/klinstruct) = atomy `read_*` /
`write_*` + `Cursor` (native endian; JS: `CStructLE`/`BE`). Schematy ramek =
ręczne metody. [`@mrhiden/cstruct`](https://github.com/MrHIDEn/cstruct) ma
bogatszą deklarację (model → `make`/`read`).

Cel: ta sama ergonomia w Klinie przez **expand czasu kompilacji** (D3), bez
runtime DSL i bez ukrytego kosztu na MCU.

## Cel UX

```klin
import "github.com/mrhiden/klinstruct" kstruct

$kstruct Telemetry {
  seq: u16
  temp_c: i16
}

fn main() {
  let mut buf: [4]u8
  let t = Telemetry{ seq: 10, temp_c: -10 }
  t.pack(buf[:])!
  let back = Telemetry.unpack(buf)!
}
```

Albo builtin jak SVD ([027](027-svd-ergonomic-api.md)):

```klin
$kstruct_from("protocol/telemetry.kspec")
```

Expand → `struct` + `pack`/`unpack` wołające atomy. Emisja C monomorficzna.

## Co napisać gdzie (ścieżka dojścia)

### A. Repo `klin` — język / preprocessor

| Krok | Gdzie | Co |
|---|---|---|
| A1 | `lib/preprocess.dart` (+ testy) | Makra widoczne przez `import` / pakiet (dziś expand per plik) |
| A2 | `lib/preprocess.dart`, `note/04-makra.md` | Argument „blok pól” / lista `(name, type)` albo variadic |
| A3 | preprocess lub builtin jak `027` | Iteracja po polach w expandzie → tekst `write_*` / `read_*` |
| A4 | checker / preprocess | Diagnostyki zmapowane na wywołanie `$kstruct` |
| A5 | opcjonalnie `lib/…` builtin | `$kstruct_from("….kspec")` — parser pliku modelu → ten sam expand co A3 |
| A6 | [048](048-import-aliases.md) / [049](049-remote-imports.md) | `import "github.com/mrhiden/klinstruct" kstruct` |

**Nie:** generyki w gramatyce ([034](034-typy-generyczne.md)), refleksja runtime.

### B. Repo `klinstruct` — biblioteka

| Krok | Gdzie | Co |
|---|---|---|
| B0 | ✅ MVP | `klinstruct/atoms*.kl`, `atoms_host.c`, `Cursor` |
| B1 | `klinstruct/*.kl` lub makro w pakiecie | Po A1–A3: definicja `$kstruct` (albo tylko dokumentacja + przykłady jeśli builtin w `klin`) |
| B2 | testy + `fixtures/` | Golden hex vs cstruct dla wygenerowanego `pack`/`unpack` |
| B3 | później | Length-prefix, `sN`; `j*` z [051](051-json-wrapper.md) |

### C. Wspólny artefakt modelu (opcjonalnie, ścieżka „jak SVD”)

| Krok | Gdzie | Co |
|---|---|---|
| C1 | np. `protocol/*.kspec` / JSON jak cstruct `jsonModel` | Jedno źródło dla Klin (`$kstruct_from`) i TS (`fromCompiled`) |
| C2 | tooling poza MCU | Opcjonalny generator / check zgodności hex — nie w firmware |

## Kolejność implementacji

1. B0 atomy — zrobione w klinstruct  
2. A1 makra z pakietu  
3. A2–A3 `$kstruct { pola }` → expand  
4. B1–B2 przykłady + golden  
5. A5 `$kstruct_from` (gdy chcesz plik jak SVD)  
6. A6 remote import  
7. B3 bogatsze typy pól  

## Kontrakt binarny

Jak [052](052-klinstruct.md): packed, native endian; makro tylko generuje to,
co dziś pisze się ręcznie.

## Poza zakresem

- Runtime model parser jak w TS cstruct  
- Generyki w gramatyce jako warunek  
- Bitfieldy; wymuszanie LE/BE ≠ native  
- Priorytet względem rdzenia / embedded LED  
