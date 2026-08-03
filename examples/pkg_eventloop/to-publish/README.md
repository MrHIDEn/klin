# Ready-to-push snapshot: `MrHIDEn/eventloop@v0.2.0`

Folder **`MrHIDEn-eventloop/`** = **cała zawartość** repo
https://github.com/MrHIDEn/eventloop (root), tag `v0.2.0`.

```text
MrHIDEn-eventloop/
  LICENSE
  README.md
  eventloop/
    version.kl      # version() → 2
    executor.kl     # timers + sleep_ms + spawn + run
    executor_test.kl
```

Nie składaj z kawałków. Skopiuj **ten katalog 1:1** do roota `eventloop`.

## Agent — wklej to

```text
Repo: MrHIDEn/eventloop (write access required).

Also clone MrHIDEn/klin @ main.

Copy EVERYTHING from:
  klin/examples/pkg_eventloop/to-publish/MrHIDEn-eventloop/
into the root of MrHIDEn/eventloop (overwrite LICENSE, README.md, eventloop/).

Then:
  git add -A
  git commit -m "Release v0.2.0: sleep_ms + spawn for Klin async/await."
  git push origin main
  git tag v0.2.0
  git push origin v0.2.0

Reply with commit SHA and https://github.com/MrHIDEn/eventloop/releases/tag/v0.2.0
Do not invent files. The snapshot is complete.
```

## Human one-liner

```sh
rsync -a --delete examples/pkg_eventloop/to-publish/MrHIDEn-eventloop/ /path/to/eventloop/
```
(then commit + tag `v0.2.0` in that clone)
