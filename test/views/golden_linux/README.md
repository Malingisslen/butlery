# Key-screen goldens (Linux)

Entries, light and dark, pumped through the design-state harness
(`test/views/design_states`): the key screens, Mina recept as the real
`MinaReceptView` (a host in `golden_hosts.dart` that fakes the services under
it), and the recipe detail again at 200 % text (`receptdetalj_200`). The PNGs in `goldens/` are made on Linux and
compared on Linux only, in the `views (ubuntu)` job of `test.yml`. On Windows
and macOS the tests report as skipped, and `--update-goldens` refuses to run.

The ten older Windows-pinned PNGs under `test/widget/` are separate and
unchanged (`test/widget/golden/golden_helper.dart`).

## Landed

A missing or changed PNG in `goldens/` now
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
