# Code Style

## File Size
- 500 lines max. Use facade pattern for larger files.
- Exemplary: `recipe_form_viewmodel.dart` - delegates to 6 focused managers
- **170 files currently >500 lines** (re-counted 2026-06-28; was 148 on 2026-06-21) — see `/docs/architecture/ACCEPTED_LARGE_FILES.md` for the rationale per file. ⚠️ ~53 of these have **no individual rationale row yet** (reconciliation pending, BUT-1420), so a large-file finding on an unlisted file may still be in scope. Don't refactor *listed* files without reviewing the rationale first. Run `bash tools/count_large_files.sh` to recount (`--list` to spot unlisted files).

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

## Documentation Files
- Prefer minimal documentation. Code should be self-documenting.
- **Default to no new doc file — apply the auto-reachability test.** Before writing a `.md`/`.html`, ask: will a future session read this *on its own* — because a `.claude/rules/` file, an agent `*.knowledge.md`, a `/command`, or a code comment points at it — **or** is it explicitly for Malin? If neither, don't create it. "Felt thorough to write" is not a reason; write-only docs (analysis reports, audit verdicts, status snapshots) rot and get deleted later. Need scratch space for the current task? Keep it in `tasks/` and treat it as disposable, not a durable artifact.
- Before creating any `.md` file, ask: Is this genuinely necessary? Could it go in an existing file?
- Prefer updating existing docs over creating new ones
- Avoid: README files for every directory, V1/V2 versions (update in place), analysis reports that won't be acted upon
- Cleanup mindset: Delete implementation plans once implemented, remove debug docs when resolved
