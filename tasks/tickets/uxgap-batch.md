# Linear Ticket Drafts — UX Gap Audit (2026-05-22)

> Paste-ready ticket bodies. Linear MCP was not connected when these were prepared, so they have not been created in Linear yet. Each section below is one ticket — drop the title, labels, priority, and body into a new Triage ticket. Separator `---` marks ticket boundaries.

Findings rooted in the audit prompted by the multi-page recipe photo discovery. The throughline: the app frequently has plural data, half-wired plural UX, or natural plural expectations met by singular code paths.

---

## 1. Wire bulk tag / add-to-menu / share / export on existing recipe-list selection mode

**Labels:** `tech-debt`, `recipe`
**Priority:** High
**State:** Triage

### Opportunity
`lib/views/mina_recept_view.dart:290` already implements full selection mode — `isSelectionMode`, `selectedIds`, long-press entry, checkboxes on `recipe_card_widget.dart:71`. Only **bulk delete** is wired. Users who long-press a recipe reasonably expect to also tag, add-to-menu, share, or export the selection. This is the textbook twin of the `pickMultipleImages`-exists-but-unused gap that triggered the audit.

### Current State (2026-05-22)
- Selection infra: present, working.
- Bulk delete: works (with undo).
- Bulk tag / bulk add-to-menu / bulk share / bulk export: not wired.

### Proposed Improvement
Add a selection-mode action bar with: Tag…, Add to menu…, Share…, Export…, Delete. Each opens the existing single-recipe flow but iterates over `selectedIds`. Where the underlying service already takes a list (e.g. share to friends, see `universal_share_dialog_viewmodel.dart:144`), pass it directly; otherwise client-side loop is fine — no Cloud Function changes required.

### Effort vs Impact
Medium / high. Selection state already exists, so this is action-bar wiring + the four corresponding bulk operations. Single largest UX win in the audit.

---

## 2. Add recipe photo gallery viewer (data is already plural)

**Labels:** `idea`, `recipe`
**Priority:** High
**State:** Triage

### Opportunity
`lib/models/recipe_unified.dart:154` stores `List<String> imageUrls`. The editor accepts `maxImages: 5` (`lib/views/edit_recipe_view.dart:398`). But the recipe viewer only shows the first image as a hero — the other 4 slots are write-only. Same shape as the multi-page photo gap: infrastructure exists, surfacing doesn't.

### Current State
- Model: `List<String> imageUrls` populated up to 5.
- Editor: lets users upload N images.
- Viewer: shows `imageUrls.first` only.

### Proposed Improvement
Replace the single hero image in the recipe detail view with a swipeable carousel showing all `imageUrls` (with paging indicator). Tap → fullscreen lightbox with pinch-zoom and swipe between images. No model changes, no Cloud Function changes.

### Effort vs Impact
Small / high. Maybe a day of work — and it makes existing data useful instead of silently discarded.

---

## 3. Accept multi-share from OS share sheet (Android `SEND_MULTIPLE` + iOS multi-file)

**Labels:** `idea`, `import`
**Priority:** Medium
**State:** Triage

### Opportunity
A user multi-selects 3 photos in the gallery and taps Share → Butlery — they expect Butlery to receive all 3. Today it receives one, or none, depending on the OS.

### Current State
- `android/app/src/main/AndroidManifest.xml` registers only `android.intent.action.SEND`. No `SEND_MULTIPLE` filter.
- `lib/views/receive_share_view.dart:35` constructor takes a singular `String content`.
- iOS share-extension handling has the same singular shape.

### Proposed Improvement
- Add `SEND_MULTIPLE` intent filter to AndroidManifest with the same mime-type matchers as `SEND`.
- Extend `receive_share_view.dart` to accept `List<String> contents` (or a typed payload) and present the same multi-page-style picker (thumbnail strip, reorder, drop) before kicking off import.
- iOS share-extension parallel change.
- Couple this with ticket #19 (multi-photo photo import) so the receiving UI is shared.

### Effort vs Impact
Medium / medium. Native manifest + receive-view refactor. Real user-visible behaviour — currently silent data loss when the OS hands over multiple files.

---

## 4. Allow multiple URLs / recipe-index pages in URL import

**Labels:** `idea`, `import`, `parsing`
**Priority:** Medium
**State:** Triage

### Opportunity
`lib/viewmodels/url_import_viewmodel.dart:164` `fetchContentFromUrl(String url)` is single-URL only. A user with three browser tabs of recipes would naturally paste them as a list; a user landing on a "10 best curry recipes" listing page would expect the importer to do the right thing.

### Current State
- Single-text-field URL input (`lib/views/import_via_url_view.dart:56`).
- URL validator (`getUrlValidationErrors`, line 209) expects one URL per string.
- No index-page detection / recipe-link extraction.

### Proposed Improvement
- Detect multiple URLs in the input (newline / whitespace / list-style separators) and import each in parallel using the existing single-URL pipeline.
- Detect index pages (page contains many `<article>` / `Recipe` schema.org blocks, or many same-domain recipe-shaped links) and prompt the user "We found N recipes on this page — which to import?" with checkboxes.
- Per-URL progress + per-URL retry (mirror the per-page failure handling on multi-page photo import).

### Effort vs Impact
Medium / medium. The single-URL pipeline can be reused; the work is parallel orchestration + UI + index-page heuristic.

---

## 5. Support multiple photos per "I cooked this" (cook snap album)

**Labels:** `idea`, `social`, `recipe`
**Priority:** Medium
**State:** Triage

### Opportunity
`lib/models/cook_snap.dart:16` stores `String photoUrl` — singular. Users marking a recipe as cooked want "before / plated / leftovers" or just multiple angles. One shot per cook event feels like an Instagram limitation we don't have.

### Current State
- `CookSnap.photoUrl` (line 16): single URL.
- `CookSnap.thumbnailUrl` (line 17): single.
- `caption` (line 18): max 200 chars.

### Proposed Improvement
Change `photoUrl` → `photoUrls: List<String>` (with migration: keep old field, copy into list). Render as carousel in the social feed and on the recipe detail "people who cooked this" section. Cap at 5 to match the photo-import cap. Storage layout: `cook_snaps/{snapId}/photo_1.jpg ... photo_5.jpg`.

### Effort vs Impact
Medium / medium. Schema migration + carousel UI + cook-snap editor. Touches both the social feed and the recipe detail.

---

## 6. Bulk dismiss + mark-all-read on notifications

**Labels:** `idea`, `social`, `account`
**Priority:** Medium
**State:** Triage

### Opportunity
Every modern app has "mark all as read". `lib/viewmodels/notifications_viewmodel.dart:68` `markAsOpened()` is single-id only — no bulk path. Its absence reads as broken, not unbuilt.

### Current State
- `notifications_view.dart` lists notifications one per row.
- Each row taps to single-mark-as-read.
- No selection mode, no "mark all read" button.

### Proposed Improvement
- Add "Mark all as read" action in the app-bar overflow.
- Add long-press selection mode (mirror the recipe-list pattern) with: Mark read, Dismiss.
- Service-side: add a bulk method on the notifications repository that issues a batched Firestore write rather than N individual writes.

### Effort vs Impact
Small / medium. Mostly view + viewmodel. Single batched write for cost.

---

## 7. Auto-aggregate shopping list from weekly menu (with unit normalisation)

**Labels:** `idea`, `menu`, `shopping`
**Priority:** High
**State:** Triage

### Opportunity
The biggest structural product gap in the audit. Today there is **zero integration** between menu planning and shopping list — plan a week with two recipes that both need flour, and the user manually writes "flour" twice or gets two duplicate lines. In competitor apps (Paprika, Mealime, Whisk) this is the marquee feature of menu planning.

### Current State
- `lib/services/menu/weekly_menu_plan_service.dart` manages weekly plans.
- `lib/services/unified/unified_shopping_service.dart` manages shopping lists.
- Zero references between them.
- No ingredient normalisation utility (units, names, plurality).

### Proposed Improvement
- Add a "Generate shopping list from week" action on the weekly menu view.
- Aggregate all ingredients across the week's recipes:
  - Normalise units (200g flour + 0.5 cup flour → resolve to grams).
  - Normalise ingredient names (lowercase, stem, optionally fuzzy-match user-defined aliases).
  - Sum quantities by normalised key.
  - Group by section (produce, dairy, pantry, …) using existing tagging conventions if available, otherwise a simple seed map.
- Surface "Subtract what you have in the pantry" if pantry feature exists (see ticket #13).
- Make it idempotent — regenerating should diff against existing list, not blow it away.

### Effort vs Impact
Large / very high. Multi-week effort because unit normalisation is genuinely hard (locales, fractions, "to taste"), but this is the single biggest power-user differentiator. Worth scoping as its own epic.

---

## 8. Add per-step images to recipe instructions

**Labels:** `idea`, `recipe`
**Priority:** Medium
**State:** Triage

### Opportunity
`lib/models/recipe_unified.dart:130-133` — `List<String> instructions` is pure text. Modern recipe apps support a photo per step ("brown the butter — looks like this"). The richest content in a cookbook is often the per-step imagery, and Butlery currently drops it during import and can't add it during edit.

### Current State
- Step model: `String` only.
- No `stepImages` / per-step media field.

### Proposed Improvement
Change step model from `String` → `RecipeStep { text: String, imageUrl: String? }`. Migration: existing string-only steps upgrade to `{text, imageUrl: null}`. Editor gets a "+image" affordance per step (singular per step). Viewer shows the image inline below step text when present.

### Effort vs Impact
Medium / medium. Schema change + migration + editor + viewer + import pipeline (preserve step images when scraping recipe URLs that have them).

---

## 9. Persist source URL on recipes imported from video sources (YouTube, TikTok)

**Labels:** `tech-debt`, `recipe`, `import`
**Priority:** Medium
**State:** Triage

### Opportunity
YouTube import is supported (`lib/models/parsing/parse_metadata.dart` references YouTube), but the source video URL is not stored on the resulting recipe. Users lose the link back to the original video — they have the recipe text but no way to rewatch the technique.

### Current State
- Import pipeline parses YouTube/TikTok metadata.
- Recipe model has no `sourceVideoUrl` (or general `sourceUrl`) field.

### Proposed Improvement
Add `sourceUrl: String?` and `sourceType: enum {url, youtube, tiktok, photo, manual}` to the recipe model. Persist on every import. Render as a "View original" affordance in the recipe header. Bonus: when source is video, embed an inline player.

### Effort vs Impact
Small / medium. Model field + import-time wiring + a single UI affordance. High utility for video-imported recipes.

---

## 10. Allow images in recipe comments

**Labels:** `idea`, `social`, `recipe`
**Priority:** Medium
**State:** Triage

### Opportunity
`lib/models/recipe_comment.dart:22` is text-only. A user wanting to share a substitution result ("I used feta instead of paneer — here's how it looked") can only describe it. Visual feedback is the most useful kind in a cooking context.

### Current State
- `RecipeComment.text` only.
- `reactions` map supports emoji reactions but not images.

### Proposed Improvement
Add optional `imageUrls: List<String>` (cap at 3) to `RecipeComment`. Comment composer gets a "+image" attach button. Renderer shows thumbnails inline. Reuse existing image upload + thumbnail pipeline.

### Effort vs Impact
Small-medium / medium. Storage path + model field + composer + renderer.

---

## 11. Multi-recipe paste support in text import

**Labels:** `idea`, `import`, `parsing`
**Priority:** Low
**State:** Triage

### Opportunity
`lib/viewmodels/text_import_viewmodel.dart:90` treats pasted input as one block. A user with two recipes from a blog post or emailed list would naturally paste both, separated by blank lines or `---`.

### Current State
- Single-block text input, single recipe out.
- No separator detection.

### Proposed Improvement
Detect probable recipe boundaries in the pasted text: explicit separators (`---`, `===`, multiple blank lines), or LLM-detected recipe headings. Show a "We found N recipes — import all? Or pick which?" confirmation. Run the existing extraction pipeline per detected recipe in parallel.

### Effort vs Impact
Small-medium / low-medium. Most users will continue to use single-paste, but power users with email/blog content would benefit.

---

## 12. Add recipe-to-recipe relations (variations, used-in)

**Labels:** `idea`, `recipe`
**Priority:** Low
**State:** Triage

### Opportunity
Many recipes share components — "the pizza dough recipe is also the focaccia base" — but there's no way to link them. Users either duplicate the dough recipe N times or cross-reference manually in the notes field.

### Current State
- `recipe_unified.dart` has no relations field.
- Cooking-mode ingredient substitutions exist (`lib/models/cooking/ingredient_substitution.dart`) but not at the recipe level.

### Proposed Improvement
Add `relatedRecipeIds: List<String>` to the recipe model. Editor: "Link a related recipe…" picker. Viewer: "Related recipes" section showing thumbnails of linked recipes (bidirectional — if A links to B, B's view shows A under "Used in").

### Effort vs Impact
Medium / low-medium. Schema + picker + bidirectional reference handling (the latter is the tricky bit — symmetric updates without races).

---

## 13. Auto-add checked shopping items to pantry/staples

**Labels:** `idea`, `shopping`
**Priority:** Low
**State:** Triage

### Opportunity
When the user checks off "flour, 1kg" in their shopping list, the app could know they now have flour. Combined with ticket #7 (menu → shopping aggregation), this closes the loop: the shopping list could subtract what's already in the pantry.

### Current State
- `lib/models/pantry/pantry_item.dart` exists.
- `lib/models/unified/unified_shopping_item.dart` exists.
- Zero connection between checking off shopping and pantry contents.

### Proposed Improvement
On shopping-item check-off, add the same item (with quantity) to the user's pantry. Prompt-on-first-use ("Track pantry from shopping? You'll see what you already have when planning.") so we don't surprise users. Pair with #7 to subtract pantry stock from generated shopping lists.

### Effort vs Impact
Medium / low individually, but multiplies the value of #7. Schedule after #7.

---

## 14. Bulk block / unblock users

**Labels:** `idea`, `social`
**Priority:** Low
**State:** Triage

### Opportunity
`lib/services/unified/operations/friends_management_operations.dart:307,348` — `blockUser(String userId)` and `unblockUser(String userId)` are singular. Users wanting to clean up a blocklist of 5 people from a long-ago group must do it one tap at a time.

### Current State
- Block list view shows users with individual remove buttons.
- No multi-select.

### Proposed Improvement
Add multi-select mode to the block-list view with "Unblock selected" action. Backend: `blockUsers(List<String>)` / `unblockUsers(List<String>)` using a batched Firestore write.

### Effort vs Impact
Small / low. Niche but cheap.

---

## 15. Bulk operations on tag management (delete, merge, rename across recipes)

**Labels:** `tech-debt`, `tagging`
**Priority:** Medium
**State:** Triage

### Opportunity
`lib/views/personal_tags_view.dart` renders tags with edit/delete one-by-one. Users who realise they've created "vegan", "Vegan", and "VEGAN" as separate tags can't merge them. Users wanting to clean up 20 stale tags can't bulk-delete.

### Current State
- Tag list, one row per tag, one action per row.
- No selection mode.
- No merge operation in `lib/services/tagging/tagging_service.dart`.

### Proposed Improvement
Add multi-select to the tag management view. Actions: Delete, Rename (single only — rename one across all recipes), Merge (pick two tags → all recipes tagged A are also tagged B, then delete A). All operations need to update the `RecipePersonalTag` lists across affected recipes in a single batch.

### Effort vs Impact
Medium / medium. Merge is the tricky one — needs a careful service-level operation that updates many recipes atomically.

---

## 16. Copy-week-to-week + bulk move on menu plan

**Labels:** `idea`, `menu`
**Priority:** Medium
**State:** Triage

### Opportunity
Power users plan their week and want to clone it as the starting point for next week, or move "this Wednesday's dinner" to Thursday with one drag. `lib/services/menu/weekly_menu_plan_service.dart` supports neither.

### Current State
- `addEntry()` (line 192) — single (day, slot, recipe) tuple.
- No `copyWeek`, no bulk-move operation.
- View: recipe-per-day cards; no multi-select, no drag-between-days.

### Proposed Improvement
- "Copy this week to next" action in the weekly menu overflow.
- Long-press a menu entry → selection mode → "Move to…" with day/slot picker.
- Drag-to-reorder between days (Flutter `Draggable` + `DragTarget`).

### Effort vs Impact
Medium / medium. UI-heavy.

---

## 17. Multi-select removal of group members

**Labels:** `idea`, `social`
**Priority:** Low
**State:** Triage

### Opportunity
`lib/views/social/group_detail/group_members_list.dart:60-78` lets owners remove members one at a time. Cleaning up a group of 20 stale members is tedious.

### Current State
- Per-member remove button only.
- No multi-select.

### Proposed Improvement
Long-press to enter selection mode → "Remove selected" action. Service-side: existing single-remove can be looped client-side, or add a batched endpoint if removal triggers Cloud Function side-effects (audit logs, notifications).

### Effort vs Impact
Small / low.

---

## 18. Add a recipe to multiple menu days/slots in one action

**Labels:** `idea`, `recipe`, `menu`
**Priority:** Medium
**State:** Triage

### Opportunity
From the recipe detail view, "Add to menu" today picks one day + one slot. Users batch-cooking the same recipe across Mon/Wed/Fri naturally expect a multi-select day picker.

### Current State
- `addEntry()` in `weekly_menu_plan_service.dart:192` is single-tuple.
- Recipe-detail "Add to menu" picker is single day + single slot.

### Proposed Improvement
Multi-select day/slot picker. On confirm, fan out `addEntry()` calls (or add a batched `addEntries(List<MenuEntry>)` service method). Pair with the per-recipe context in the recipe detail and with the recipe-list bulk-add (ticket #1).

### Effort vs Impact
Small-medium / medium.

---

## 19. Filter view: "All recipes shared by friend X"

**Labels:** `idea`, `social`
**Priority:** Low
**State:** Triage

### Opportunity
`lib/models/shared_recipe.dart` carries `sharedByUserId` but there's no view that filters the user's library to "everything shared by this friend". Users return to a friend's profile expecting to see their contributions.

### Current State
- Shared recipes display in the global feed without a per-friend filter.
- Friend profile view (if any) doesn't list their shared recipes.

### Proposed Improvement
Add a "Recipes shared by you" section on the friend profile, querying shared-content where `sharedByUserId == friendId` and the current user is a recipient. Same view scaffold can be reused for groups (ticket would be a follow-up).

### Effort vs Impact
Small / low. One query + one view.

---

## 20. Bulk friend-add / contact-book import

**Labels:** `idea`, `social`
**Priority:** Low
**State:** Triage

### Opportunity
`lib/viewmodels/friends_viewmodel.dart:179` `sendFriendRequest(String userId, …)` is singular. There's no flow for "import my contacts and add the matching Butlery users". A new user with 30 contacts on the app must search and add one by one.

### Current State
- No contact-permission integration.
- No bulk friend-add UI.
- Singular request path only.

### Proposed Improvement
Phone-contact-permission flow (gated, clearly explained, optional). Hash phone numbers client-side and check against a server-side index of registered users (mind GDPR — see `firebase-backend-security` agent for review). Present matches with checkboxes. Confirm → loop `sendFriendRequest` server-side via a batched callable function, or client-side loop with progress UI.

### Effort vs Impact
Medium-large / low-medium. Contact-permission UX, hashing pipeline, GDPR review, and a batched server endpoint to avoid hammering the per-request rate limit. Low priority until growth is bottlenecked by friend-graph density.

---

## Reference index

Quick-scan list with priority + area, ordered by recommended sequencing.

| # | Title | Labels | Priority |
|---|---|---|---|
| 1 | Wire bulk tag / menu / share / export on recipe-list selection mode | tech-debt, recipe | High |
| 2 | Add recipe photo gallery viewer | idea, recipe | High |
| 7 | Auto-aggregate shopping list from weekly menu | idea, menu, shopping | High |
| 3 | Accept multi-share from OS share sheet | idea, import | Medium |
| 4 | Allow multiple URLs / index pages in URL import | idea, import, parsing | Medium |
| 5 | Multiple photos per cook snap | idea, social, recipe | Medium |
| 6 | Bulk dismiss + mark-all-read on notifications | idea, social, account | Medium |
| 8 | Per-step images on recipe instructions | idea, recipe | Medium |
| 9 | Persist source URL on video-imported recipes | tech-debt, recipe, import | Medium |
| 10 | Allow images in recipe comments | idea, social, recipe | Medium |
| 15 | Bulk operations on tag management | tech-debt, tagging | Medium |
| 16 | Copy-week-to-week + bulk move on menu plan | idea, menu | Medium |
| 18 | Add a recipe to multiple menu days in one action | idea, recipe, menu | Medium |
| 11 | Multi-recipe paste in text import | idea, import, parsing | Low |
| 12 | Recipe-to-recipe relations | idea, recipe | Low |
| 13 | Auto-add checked shopping items to pantry | idea, shopping | Low |
| 14 | Bulk block / unblock | idea, social | Low |
| 17 | Multi-select removal of group members | idea, social | Low |
| 19 | "Recipes shared by friend X" filter view | idea, social | Low |
| 20 | Bulk friend-add / contact-book import | idea, social | Low |
