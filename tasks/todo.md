# Sprint Backlog

## Sprint: comment visibility label — 2026-06-04 (iter-126) [Tier B]

BUT-914 — tell the comment author who will see their comment. Ships to **In Review**
(copy + personal-recipe behaviour want Malin's eyes).

- [x] **A1. Privacy-correct audience helper** `[Tier B]` — `lib/views/recipe_detail/comment_visibility.dart`: `commentVisibilityAudience(recipe, currentUserId)` = owner + collaborative members minus self; empty for non-collaborative. Mirrors `FirebaseRecipeOwnershipResolver._resolveSharedIds` (canonical source — can't mis-state). 4 unit tests green. (BUT-914)
- [x] **A2. "Synlig för: …" line under the composer** `[Tier B]` — `recipe_detail_comments.dart`: resolves audience IDs → names (friendsList + denormalized ownerDisplayName), truncates to 3 + "+N", hidden for non-collaborative recipes AND when no name resolves (no misleading partial). l10n `recipeCommentVisibleTo` sv/en. (BUT-914)

**Deferred (follow-up):** tap→full-list dialog (nicety); the all-unresolved-names edge currently hides the line.

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079.

---
## ARCHIVED — iter-125 (triage: BUT-1206 Done/obsolete, BUT-914 scoped) · iter-124 (BUT-1209 — Done) · iter-123 (BUT-1204 — Done) · iter-122 (BUT-1207 — Done) · earlier: BUT-1201/1208/1200/1203/1192/488/904
