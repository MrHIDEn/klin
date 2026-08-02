# Nazwa, rozszerzenie, licencja

## Nazwa: Klin

Cztery litery, jedna sylaba, wymawialne po polsku i po angielsku
(/klin/, /klɪn/). Anglojęzyczny przeczyta poprawnie za pierwszym razem.

**Metafora jest trafna:** klin to najstarsza maszyna prosta — zero
ruchomych części, zero narzutu. Język jest cienką warstwą wbijaną między
programistę a C. Nie zastępuje C, tylko się w nie wklinowuje.

Brzmienie: `K` to fonetyczne `C`, więc "Klin" ≈ "C lin". Przypadek,
ale przyjemny.

### Sprawdzone kolizje

- **Języki programowania** — czysto. Najbliżej: Grotsky (`.gr`), grot
  (solver MES w Pythonie). Żadne w tej przestrzeni.
- Konto GitHub `klin` istnieje (3 repo, nie języki).
- "Klein" to inna nazwa, inne litery — szum, nie kolizja.
- Po polsku "klin" zwróci stolarkę i siatkówkę; po angielsku miasto Klin
  pod Moskwą.

**Wniosek:** wszędzie pisać **"Klin language"** albo **"klin-lang"**.
To jest tag, pod którym się znajdzie.

### Odrzucone kandydatury

| Nazwa | Powód odrzucenia |
|---|---|
| NeV | Nev = edytor tekstu; Neva = język dataflow kompilujący do Go; `nev` = kod ISO języka nyaheun |
| `.nc` / NewC | **nesC** — rozszerzenie C pod TinyOS, ta sama domena, używa `.nc`. Plus NetCDF i G-code CNC |
| Grot | po brytyjsku "grot" = brud, "grotty" = obskurny. Recenzja pisze się sama: *"Grot is grotty"*. Plus MSBS Grot i Warhammer 40k |
| C3, E | zajęte (C3 = język Lernö na LLVM; E = język Millera z 1997) |

**Lekcja ogólna:** cała przestrzeń dwu-trzyliterowych kombinacji wokół
C jest wyczerpana trzydziestoma latami prób. Poza tym nazwa typu "NewC"
mówi, czym język *nie* jest. Zig, Rust, Odin, Hare, Nim — żaden nie
nazwał się po przodku i wszystkie na tym wygrały.

### Do zaklepania

- [ ] domena `klin.dev` albo `klin-lang.org`
- [ ] organizacja `klin-lang` na GitHubie
- [ ] `crates.io`, `npm`, `pypi` (nawet jeśli nigdy tam nie trafię —
      zajęta nazwa pakietu to sygnał, że słowo jest już oswojone
      w kontekście programowania)

## Rozszerzenie: `.kl`

Wolne. Alternatywa `.klin`, jeśli potrzebna jednoznaczność.

## Licencja: MIT

**Kluczowe:** licencja kompilatora nie może rzutować na kod, który ktoś
w nim napisze. GPL straszy ludzi nawet gdy prawnie nie ma podstaw — GCC
musiało to rozwiązać osobnym Runtime Library Exception.

Wszyscy sąsiedzi wybrali permisywnie: Nelua (MIT — wprost stwierdza,
że dla programów w Nelui można użyć dowolnej licencji), Go, Rust, Zig, V.

### Podział

| Część | Licencja |
|---|---|
| kompilator | MIT |
| biblioteka standardowa | MIT + jawne zdanie w README |

Zdanie do README:

> Kod wygenerowany przez kompilator Klin oraz fragmenty biblioteki
> standardowej wkompilowane w Twój program nie podlegają żadnym
> ograniczeniom — Twój program jest Twój.

To zdanie oszczędza dziesiątek pytań.

### MIT vs Apache-2.0

Apache-2.0 dodaje jawną klauzulę patentową. Rust używa dual
`MIT OR Apache-2.0` i to standard w ekosystemie systemowym.

Dla projektu solo na start: **MIT** — krótszy, każdy zna. Przejście
później na dual jest łatwe, dopóki jestem jedynym autorem. Odwrotny
kierunek (GPL → MIT) jest praktycznie niemożliwy po pojawieniu się
kontrybutorów.

**Plik `LICENSE` przy pierwszym commicie.** Repozytorium bez niego jest
domyślnie całkowicie zastrzeżone — nikt nie może go legalnie użyć ani
forknąć, nawet jeśli jest publiczne.

## .gitignore

Szablon **Dart** z GitHuba plus:

```gitignore
/out/          # całe wyjście kompilatora — .c, .o, binarki
.idea/
*.iml
.DS_Store
```

Dwie pułapki:

1. **Nie ignorować `*.c` wzorcem.** W kroku 10 pojawią się ręcznie pisane
   moduły C i startup, których ignorować nie wolno. Lepiej wymusić, żeby
   kompilator pisał wyłącznie do `out/`.
2. **`pubspec.lock` commitować.** Ignoruje się go dla bibliotek; Klin
   jest aplikacją CLI.

`test/` zawiera pliki `.kl` i oczekiwane wyjścia — muszą być w repo,
trzymać z dala od `out/`.
