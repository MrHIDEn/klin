# 025 — English project (except pl-PL)

**Status:** ✅ zrobione
**Zależy od:** —

## Cel

Przegląd repo i przeniesienie na angielski **wszystkiego poza korpusem polskim**.

## PL zostaje (pl-PL)

- `issues/`
- `docs/`

To oficjalny korpus PL (roadmapa, decyzje, architektura). Nie tłumaczyć w 025.
Ewentualny późniejszy move do `docs/pl-PL/{issues,note}` tylko jeśli nie
rozwali linków — poza zakresem 025 albo osobny mikro-krok.

## Na angielski

- [x] komunikaty frontendu / CLI (`lib/*`, `bin/*`, `svd2klin`)
- [x] testy: asercje na treść błędów, opisy `test(...)`, komentarze w `test/`
- [x] `README.md`, opis w `pubspec.yaml`, help CLI
- [x] `CLAUDE.md` / reguły agenta: EN + linki do pl-PL `docs/` / `issues/`
- [x] komentarze w kodzie kompilatora (docelowo całość EN; przy edycji pliku — EN)

## Kryterium

Contributor bez PL ogarnia build/test/diagnostics; design czyta z
`issues/` + `docs/` (PL).
