# Code Style

## File Size

500 lines max; use the facade pattern above it. `recipe_form_viewmodel.dart` is the
worked example — it delegates to six focused managers.

Exempt: every file listed in `docs/architecture/ACCEPTED_LARGE_FILES.md`, each with a
rationale worth reading before proposing a refactor. The size guard warns on the write
and names the allowlist, the facade option, and the local-override sentinel.

## Service Access

- `ServiceLocator.get<T>()` — constructor injection in DI modules, ServiceLocator in widgets/ViewModels.
- Never `FirebaseFirestore.instance` directly — inject FirestoreRepository.
- Unified services use `.personal`, `.social`, `.realtime` modules (see `butlery-architecture` skill).
- New code uses the project mixins and base classes (see `mixin-advisor` skill).

## Syntax

- Color: `withValues(alpha: 0.8)`, not the deprecated `withOpacity(0.8)`.
- Use proper models, not Map-based data access.

## Commenting

- WHY not WHAT — code shows what, comments explain intent.
- No doc comments on simple getters or private methods; no section dividers.
- Comments in English. UI strings stay Swedish.
- A wrong comment gets STRUCK, not reworded — delete the false sentence rather than write a
  truer version; correct in place only when the true wording is directly readable from the
  code and needs no counting.

## Documentation files

**Default to not creating one.** Docs that explain what the code does are debt — delete
them and spend the effort on making the code self-explanatory instead. A new committed doc
needs both a reason to exist (decision record, glossary, thin navigation pointer, operating
instructions, machine-consumed data, or written for Malin) **and** something pointing at it,
or a future session never reads it.

Full rubric: `docs/ops/doc-taxonomy.md`. Repo-wide audit: `/docs-sweep`. Scratch notes for
the current task go in `tasks/` and are disposable.
