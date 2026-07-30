# 018 — Generatory / `yield`

**Status:** 💭 do rozważenia
**Zależy od:** 004 (funkcje), ewentualnie domknięcia / stan (D7); nie w kolejce głównej

## Kontekst

JS/`async`/`function*`: `yield` zawiesza funkcję i oddaje wartość do iteratora. Wygodne do strumieni i lazy sekwencji, ale wymaga **ukrytego stanu** (ramka na stercie lub transformacja do state machine) — mocno gryzie się z zasadą nadrzędną Klina.

## Propozycja (później, jeśli w ogóle)

- Albo **nie** wprowadzać `yield` w rdzeniu.
- Albo jawny model: generator = struct ze stanem + metoda `next(): ?T` (jak iteratory w V/Zig/Rust), bez magicznego zawieszania stosu.
- Emisja do C: state machine wygenerowana jawnie (widać w `.c`) albo ręczne iteratory — zero ukrytej alokacji ramki bez `Allocator`.

## Czego nie robić

- Nie obiecywać `yield` jak w Pythonie/JS przed decyzją o koszcie i alokacji.
- Nie dodawać przed solidnymi funkcjami (004) i slice’ami/iteratorami (007).
- Test zasady nadrzędnej: generator vs ręczna pętla w C — ten sam kod maszynowy albo cecha wypada.

`yield` nie jest związany z generatorem SVD z [011](011-svd.md): tamten jest
narzędziem build-time, bez ukrytego stanu programu użytkownika.
