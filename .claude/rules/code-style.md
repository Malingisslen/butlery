# Code Style

## File Size
- 500 lines max. Use facade pattern for larger files.
- Exemplary: `recipe_form_viewmodel.dart` - delegates to 6 focused managers
- **33 files intentionally >500 lines** - see `/docs/architecture/ACCEPTED_LARGE_FILES.md` for list with reasons. Don't refactor these without reviewing the rationale first.

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
- Before creating any `.md` file, ask: Is this genuinely necessary? Could it go in an existing file?
- Prefer updating existing docs over creating new ones
- Avoid: README files for every directory, V1/V2 versions (update in place), analysis reports that won't be acted upon
- Cleanup mindset: Delete implementation plans once implemented, remove debug docs when resolved
