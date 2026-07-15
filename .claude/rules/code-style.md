# Code Style

## File Size
- 500 lines max. Use facade pattern for larger files.
- Exemplary: `recipe_form_viewmodel.dart` - delegates to 6 focused managers
- **177 files currently >500 lines** (live count, `tools/count_large_files.sh`, 2026-07-14) — see `/docs/architecture/ACCEPTED_LARGE_FILES.md` for the rationale per file. The inventory was reconciled to a **complete, 0-unlisted** state on 2026-07-01 at 171 files (BUT-1420); ~6 files have drifted above the threshold since then and may not have a rationale row yet, so a large-file finding on a genuinely *unlisted* file can still be in scope — confirm with `--list` before filing. Don't refactor *listed* files without reviewing the rationale first. Run `bash tools/count_large_files.sh` to recount (`--list` to spot unlisted files).

## Service Access
- `ServiceLocator.get<T>()` — constructor injection in DI modules, ServiceLocator in widgets/ViewModels
- Never use `FirebaseFirestore.instance` directly - inject FirestoreRepository
- Unified services use `.personal`, `.social`, `.realtime` modules (see `butlery-architecture` skill)

## Syntax
- Color: `withValues(alpha: 0.8)` not `withOpacity(0.8)` (deprecated)
- Type safety: Use proper models, not Map-based data access

## Commenting
- WHY not WHAT - code shows what, comments explain intent
- No doc comments on simple getters/private methods
- No section dividers (`// ===== SECTION =====`)
- All comments in English (UI strings stay Swedish)
- **Butler voice (UI strings):** Swedish/English UI copy follows `docs/design/butler-voice-guide.md` — no exclamation marks (rule #1), no "Grattis!" (rule #4), speak about the action not to the user. Auto-applies when editing `lib/l10n/*.arb`.

## Documentation Files — the self-explanatory-code principle

Docs that explain what code does are debt: **delete them, and spend the saved tokens
making the code self-explanatory** (names, structure, targeted WHY comments). A committed
doc may exist ONLY as one of six classes:

1. **Decision record (ADR)** — alternatives considered, why X over Y, dated calls
   (`accepted-deviations.md`, `ACCEPTED_LARGE_FILES.md` rationales).
2. **Glossary / domain language** — meaning the code cannot express.
3. **Navigation pointer** — THIN link-chains forming the roads Claude navigates by
   (workflow map, `RECIPE_PIPELINE.md`). Thin is load-bearing: a nav doc that
   re-explains the code gets condensed.
4. **Operating instructions** — CLAUDE.md, `.claude/rules/`, skills, `*.knowledge.md`,
   runbooks.
5. **Machine-consumed data** — files read by CI, hooks, or scripts.
6. **For-Malin docs** — plain-language, explicitly for the founder.

Rules that follow from it:
- **Default to no new doc file — apply the auto-reachability test.** Before writing a
  `.md`/`.html`, ask: will a future session read this *on its own* — because a
  `.claude/rules/` file, an agent `*.knowledge.md`, a `/command`, or a code comment
  points at it — **or** is it explicitly for Malin? If neither, don't create it. An
  exception class grants the right to exist; reachability makes it findable — a doc
  needs BOTH. "Felt thorough to write" is not a reason; write-only docs (analysis
  reports, audit verdicts, status snapshots) rot and get deleted later.
- Scratch space for the current task lives in `tasks/` and is disposable — delete plans
  once implemented, debug docs when resolved.
- Prefer updating an existing doc of the same class over creating a new one. No V1/V2
  copies — update in place. No per-directory READMEs.
- `/docs-sweep` (workflow-guards plugin) audits the whole repo against this taxonomy —
  run it when docs feel stale.
