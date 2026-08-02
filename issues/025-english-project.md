# 025 — English project (except pl-PL)

**Status:** ✅ done
**Depends on:** —

## Goal

Review the repo and move to English **everything except the Polish corpus**.

## PL stayed (pl-PL) — superseded

Originally `issues/` and `docs/` were the official PL corpus (roadmap, decisions,
architecture) and were not translated in 025. **That exception is being superseded:**
issues and docs are moving to English (full migration tracked in [082](082-english-issues-docs.md)).
Do not translate to `docs/pl-PL/{issues,note}` unless link breakage is avoided — out of
025 scope or a separate micro-step.

## Moved to English

- [x] frontend / CLI messages (`lib/*`, `bin/*`, `svd2klin`)
- [x] tests: assertions on error text, `test(...)` descriptions, comments in `test/`
- [x] `README.md`, `pubspec.yaml` description, CLI help
- [x] `CLAUDE.md` / agent rules: EN + links to pl-PL `docs/` / `issues/` (links updated as corpus migrates)
- [x] compiler code comments (eventually all EN; when editing a file — EN)

## Criteria

Contributor without Polish can handle build/test/diagnostics; design is read from
`issues/` + `docs/` (now migrating to EN per 082).
