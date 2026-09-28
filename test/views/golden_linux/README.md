# Key-screen goldens (Linux)

Eleven key screens, light and dark, pumped through the design-state harness
(`test/views/design_states`). The PNGs in `goldens/` are made on Linux and
compared on Linux only, in the `views (ubuntu)` job of `test.yml`. On Windows
and macOS the tests report as skipped, and `--update-goldens` refuses to run.

The ten older Windows-pinned PNGs under `test/widget/` are separate and
unchanged (`test/widget/golden/golden_helper.dart`).

## Landed

The 20 PNGs in `goldens/` were made by the `goldens-linux-update` workflow
(run 36387805864) and committed in package 8. A missing or changed PNG now
fails `views (ubuntu)`, and so does a missing `goldens/` directory (the
test `the Linux baselines are committed`).

## Regenerate

1. Push the branch.
2. Run the workflow: `gh workflow run goldens-linux-update.yml -f ref=<branch>`.
3. Fetch the PNGs: `gh run download <run-id> -n goldens-linux-<run-id> -D test/views/golden_linux/goldens`.
4. Look at every PNG, in both modes, before anything else.
5. Commit them with a normal push, so `views (ubuntu)` runs against them.
6. Merge only with no red check (read the checks with `awk -F'\t' '$2=="fail"'`).

The workflow only uploads an artifact. It never pushes: a push made with
`GITHUB_TOKEN` starts no workflow runs, so the checks would never run against
the new PNGs.

Re-run it when `ubuntu-latest` moves to a new image or Flutter is bumped
(`FLUTTER_VERSION` in both workflows): the comparison is exact.

## Smoke run off Linux

`BUTLERY_GOLDEN_SMOKE=1 flutter test test/views/golden_linux` pumps every
screen without taking a picture, to see that the hosts still build.

## Blocked screens

`inkopslista` is skipped, with BUT-2186 as the reason, until that ticket
is fixed: the open list's header fails its layout, and a picture of that
would become the baseline. When it is fixed, remove `blockedBy`, run the
workflow and commit `inkopslista_light.png` and `inkopslista_dark.png`.
