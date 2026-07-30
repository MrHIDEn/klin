# 008 — defer

**Status:** ✅ ukończone
**Zależy od:** 007

## Zakres

```
let buf = a.alloc(u8, n)
defer a.free(buf)
```

Emisja: wspólny epilog + `goto cleanup`.

## Pułapki

Kolejność odwrotna. Musi zadziałać przed **każdym** wyjściem z zakresu:
`return`, `break`, `continue`, normalne zakończenie bloku.
Konflikt z wczesnymi wyjściami to główne źródło błędów w implementacji.

## Kryterium ukończenia

- [x] `defer` przed `return` w środku pętli
- [x] `defer` przed `break`
- [x] dwa `defer` w jednym zakresie — kolejność odwrotna
- [x] testy złote na wszystkie trzy
