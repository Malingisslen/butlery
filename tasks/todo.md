# Sprint Backlog

## Sprint: iter-57 — BUT-896 form field labelText — STEP 0 RESCOPE — 2026-05-24 (Sun)

Theme: A11y bug. Plan-fil FÖRST per discipline.

### Step 0 — premise verification

Ticket lists 2 sites:
1. **comment composer in `recipe_detail_comments.dart`**: verified `recipe_detail_comments.dart:347-353` — `TextField` in edit-comment dialog uses `InputDecoration(hintText: ...)` only. Bug confirmed.
2. **`auth_view.dart` password-reset field**: ticket says "bare TextField with no decoration". Verified `auth_view.dart:633-640` — actually **already** has `InputDecoration(labelText: ..., hintText: ...)`. Premise stale. No action needed.

l10n: `commentEditHint` exists but is the hint text. Need a separate `commentEditLabel` for the persistent label. Inline option: add ARB key. Alternative: reuse existing `commentEditHint` as both label and hint (acceptable since the dialog title already says "Edit comment" — label = "Comment" is redundant; hint may be more useful).

Best UX: label = "Comment" (persistent identity, screen reader anchor); hint = existing `commentEditHint` (placeholder guidance). Need new l10n key `commentLabel`.

### Design choices

- Add `commentLabel` to both ARB files: en "Comment", sv "Kommentar".
- Run `flutter gen-l10n`.
- Switch comment-edit-dialog's InputDecoration to `labelText: commentLabel + hintText: commentEditHint`.

### Ship this sprint

- [ ] **A1. ARB**: add `commentLabel` in sv + en.
- [ ] **A2. gen-l10n**: regenerate localizations.
- [ ] **A3. recipe_detail_comments.dart**: add `labelText: context.l10n.commentLabel` to edit-dialog InputDecoration.
- [ ] **A4. Verify Linear**: comment on BUT-896 that auth_view part of premise was stale; only fix comment composer.

### Acceptance

- [ ] Screen reader announces "Comment" when focus enters the edit dialog field.
- [ ] `flutter analyze` clean.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Stäng BUT-896 i Linear → Done with rescope note

---

## Archived iter-56 (commit `2b4e9e8c0`) — 2026-05-24 (Sun)

BUT-898 cooking-mode title fontScale. Single-line copyWith fix. +17 / -15. BUT-898 → Done.
