# Sprint Backlog

## Sprint: iter-112 — Tier A CPI→LoadingIndicator wave (image cluster) — 2026-06-01 (Mon)

Tight, low-risk mechanical wave (context large; picked the arch-test-guarded CPI migration). Migrate
the 4 fully-indeterminate `CircularProgressIndicator` sites in the image widget cluster to the project
`LoadingIndicator` wrapper + de-allowlist them. Guarded by `test/architecture/architecture_test.dart`.

### Agent A — CPI→LoadingIndicator (BUT-1168 wave)
- [x] **A1. BUT-1168 wave: migrate the image cluster (4 files)** `[Tier A]`
  - `lib/widgets/image/avatar_image_widget.dart` (strokeWidth 2, valueColor→color cs.primary, size 24)
  - `lib/widgets/image/simple_image_widget.dart` (bare const CPI)
  - `lib/widgets/image/components/empty_image_state.dart` (strokeWidth 2, color cs.primary, size iconSizeXl)
  - `lib/widgets/image/editable_image_widget.dart` (color cs.surfaceContainerHighest)
  - All fully indeterminate (no `value:`) — verified. Remove the 4 from the arch-test allowlist; the guard
    proves they're actually clean. BUT-1168 stays In Progress (~19 files remain).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean on changed files
- [ ] Arch CPI guard green with the 4 de-allowlisted
- [ ] Commit, push to main
- [ ] BUT-1168 progress comment (stays In Progress)

---

## Prior sprints (shipped)
iter-104 `b80aac380`, iter-106 `c03789f69`, iter-107 `d881cbf27`, iter-108 `9159fbce9`, iter-109
`0181823fa` (BUT-1168 social cluster), iter-110 `329991f0a` (BUT-1056/1171/1172), iter-111 `664372faf`
(BUT-1174/1175 test-gaps). Durable record: Linear + git.

> Tree hygiene: parallel session owns `tools/corpus/`, `test/corpus/`, `.gitignore`/`dart_test.yaml` edits
> + a todo.md side-project section — NOT mine, leave it. Do NOT `git add -A` blindly.
