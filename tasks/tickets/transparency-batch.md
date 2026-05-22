# Linear Ticket Drafts — Transparency, Consistency & Cost Audit (2026-05-22)

> Paste-ready ticket bodies. Linear MCP was not connected when these were prepared, so they have not been created in Linear yet. Each section is one ticket. Separator `---` marks ticket boundaries.

Findings from the third audit sweep — gaps where the app does things without showing them, behaves inconsistently between similar surfaces, hides existing features, or burns operational cost. Organised into five themes.

---

# Theme 1 — Privacy & visibility transparency

## 1. Warn users that cook snaps inherit recipe visibility (public recipe = public photo)

**Labels:** `idea`, `social`, `recipe`
**Priority:** High
**State:** Triage

### Finding
`lib/models/cook_snap.dart` has no visibility field. Cook snaps are visible to everyone who can see the parent recipe. If the parent recipe is public, the snap is public. The user is **never told this** at capture time.

### Proposed Improvement
- Before saving a cook snap, show inline visibility text under the photo preview: "This photo will be visible to: <who>" (drawn from the parent recipe's share scope).
- Add a per-snap visibility override (start with: same-as-recipe / only-me) — same field as the recipe but capped at parent visibility.

### Effort vs Impact
Small / high. Single message + optional override field. Prevents the worst-case "I posted a kitchen-fail picture, now my coworker saw it" scenario.

---

## 2. Surface that actions broadcast to friends' activity feeds

**Labels:** `idea`, `social`, `account`
**Priority:** High
**State:** Triage

### Finding
`lib/models/social/activity_event.dart` includes events `cooked`, `shared`, `addedIngredient`, `startedCooking`, `pinged`. These post automatically to friends' feeds. Users are not told this is happening, and there's no per-event-type opt-out.

### Proposed Improvement
- One-time onboarding hint the first time an activity event is created: "<action> appears in your friends' feed. You can change this in Settings."
- Settings → Privacy → "Activity in friends' feed": per-event-type toggles (cooked, shared, added ingredient, started cooking, pinged) defaulting to on but discoverable.

### Effort vs Impact
Small / high.

---

## 3. Show visibility on recipe cards (lock / world / friends icon)

**Labels:** `idea`, `recipe`
**Priority:** High
**State:** Triage

### Finding
`lib/models/recipe_unified.dart:167` carries a single `isPublic` bool. Recipe cards in `mina_recept_view.dart` render no visibility indicator — users have to open the detail view to learn whether a recipe is shared.

### Proposed Improvement
- Add a small icon overlay on the recipe card corner: lock (private) / friends-with-tick (shared) / globe (public).
- On the detail view, show a short label under the title: "Private" / "Shared with 3 friends" / "Public".

### Effort vs Impact
Small / medium-high. Pure UI; data is already there.

---

## 4. Toggle for "show my last-active / online status"

**Labels:** `idea`, `social`, `settings`
**Priority:** Medium
**State:** Triage

### Finding
`lib/models/user_profile.dart:39` exposes `lastActiveAt` and `isOnline`. `friend_request_card.dart:71-87` renders them. There's no opt-out — users can't be invisible.

### Proposed Improvement
Settings → Privacy → "Show online status" toggle. When off, the field is omitted from profile reads (or always returns null) and the green dot disappears on friends' views.

### Effort vs Impact
Small / medium.

---

## 5. Label comment visibility on the composer

**Labels:** `idea`, `social`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
`lib/models/recipe_comment.dart:44` carries `sharedWithUserIds`. The comment composer doesn't tell the author who will see the comment — they assume "the recipe owner" when often it's also everyone the recipe is shared with.

### Proposed Improvement
Show a small "Visible to: Anna, Per, Maria" line under the comment composer (truncated at 3 names + "and N others"). Tap → full list.

### Effort vs Impact
Small / medium.

---

## 6. Retroactively hide blocked users' content

**Labels:** `bug`, `social`
**Priority:** Medium
**State:** Triage

### Finding
`lib/models/block_record.dart` — when user A blocks user B, B's existing comments on A's recipes stay visible. Blocking should mean "I don't want to see this person", retroactively.

### Proposed Improvement
- Query-side filter: when reading comments/feed/snaps, exclude items whose `authorId ∈ blockedUserIds`.
- Consider doing the same for cook snaps on shared recipes.

### Effort vs Impact
Small / medium. Repository-level filter applied uniformly.

---

## 7. Show analytics event list under "analytics consent"

**Labels:** `idea`, `account`, `analytics`
**Priority:** Low
**State:** Triage

### Finding
`lib/services/analytics_service.dart` checks the abstract `ConsentPurpose.analytics` flag, but the consent UI never shows what events are actually logged. Users consent to a category without seeing the actual telemetry.

### Proposed Improvement
Consent management view gets a per-purpose "What we log" expansion that lists representative event names + their fields. Pulled from `analytics_events.dart` constants so it stays in sync.

### Effort vs Impact
Small / low. GDPR-aligned transparency win.

---

# Theme 2 — LLM transparency

## 8. Persist source artefacts on imported recipes (OCR text, source HTML)

**Labels:** `idea`, `import`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
- After photo import, raw OCR text is not stored on the saved recipe (`recipe_unified.dart` has no `ocrText` / `sourceArtefact`).
- After URL import, the parsed HTML is discarded (`import_manager.dart:250` keeps only the parsed structured recipe).
- Users can't audit what the LLM saw, and a re-extraction requires re-photographing or re-fetching.

### Proposed Improvement
Add an optional `sourceArtefact: { type, data, retrievedAt }` to the recipe model. Store the OCR text or the cleaned HTML. Surface as "View source" affordance in the recipe overflow menu. Allow "Re-extract from source" to rerun parsing without re-importing.

### Effort vs Impact
Medium / medium. Storage cost goes up slightly per imported recipe; auditability and re-extraction get unlocked. Pair with uxgap-batch #9 (source URL).

---

## 9. Show ingredient parse confidence in the import UI

**Labels:** `idea`, `import`, `parsing`
**Priority:** Medium
**State:** Triage

### Finding
`lib/models/parsing/parsed_ingredient.dart:27` defines `ParseConfidence { high, medium, low }` per ingredient, but `assisted_import_dialog.dart:338-344` only renders the parsed name. Users can't see "the parser is unsure about this one — please check".

### Proposed Improvement
Render a confidence pill next to each ingredient in the assisted dialog (green/amber/grey dot). Low-confidence items get auto-focused or sorted first. Show the original line on long-press / expand.

### Effort vs Impact
Small / medium. Data is already there.

---

## 10. Carry OCR confidence into the assisted import dialog

**Labels:** `tech-debt`, `import`, `parsing`
**Priority:** Medium
**State:** Triage

### Finding
`photo_import_viewmodel.dart:370-374` exposes a confidence badge (green/orange/red, 0-100%) during the OCR preview step. Once the user enters the assisted dialog (`text_line_selector.dart`), confidence is dropped. Users get a strong signal then lose it.

### Proposed Improvement
Plumb the per-line OCR confidence through to the line selector. Render the same colour scheme. Combine with #9 so the user sees both OCR confidence and parse confidence per line.

### Effort vs Impact
Small / medium.

---

## 11. Distinguish AI-suggested content from user-entered content

**Labels:** `idea`, `import`, `parsing`
**Priority:** Medium
**State:** Triage

### Finding
- AI-detected lines in `text_line_selector.dart:85-90` are highlighted in green/blue but never explicitly labelled as AI suggestions.
- If/when tagging suggestions are introduced during import, `RecipePersonalTag` has no flag distinguishing AI-applied from user-applied tags.
- Users can't tell what was AI vs. their own input.

### Proposed Improvement
- Add an "AI suggested" tag (visual chip + a11y label) to highlighted lines.
- Add `appliedBy: { user, ai }` to `RecipePersonalTag` so we can show provenance and let users bulk-strip AI suggestions.

### Effort vs Impact
Small (lines) / medium (tags). Foundational for AI literacy as more LLM features land.

---

## 12. Explain what changed when scaling portions

**Labels:** `idea`, `recipe`
**Priority:** Low
**State:** Triage

### Finding
`portion_scaler.dart` scales ingredient quantities when the user changes portions. The UI shows new numbers with no diff and no handling-of-edge-cases visible. "1 pinch salt" scaled 4× — does it stay 1 pinch? Drop? Become "4 pinches"?

### Proposed Improvement
After scaling, briefly show a "Scaled from N portions" banner with an "Undo / View changes" affordance. View changes opens a diff panel showing original ↔ scaled per ingredient. Flag non-scalable items ("pinch", "to taste") explicitly.

### Effort vs Impact
Small / low.

---

## 13. Surface a "Re-extract from source" affordance

**Labels:** `idea`, `import`, `recipe`
**Priority:** Low (blocked on #8)
**State:** Triage

### Finding
Once a recipe is saved, there's no path to re-run extraction over the original source. If the extraction was poor, users must re-import from scratch.

### Proposed Improvement
With #8 landed (source artefact persisted), add "Re-extract from source" to the recipe overflow menu. Useful when prompt improvements ship and you want to upgrade existing recipes.

### Effort vs Impact
Small / low.

---

# Theme 3 — Consistency

## 14. Establish and enforce a single icon convention for favourite / primary / saved

**Labels:** `tech-debt`, `settings`
**Priority:** Medium
**State:** Triage

### Finding
Three different icons are used for adjacent concepts with no clear distinction:
- `Icons.favorite` / `favorite_border` — recipe favourites, comment likes (`recipe_detail_view.dart:335`, `comment_item_widget.dart:97`, `recipe_card.dart:346`)
- `Icons.star` / `star_outline` — primary image badge (`image_grid_widgets.dart:156`, `primary_badge.dart:28`)
- `Icons.bookmark` — saved-as-template (`shopping_app_bar.dart:246`, `shopping_list_header.dart:302`)

Colour usage also drifts — comment likes use `colorScheme.error` (red), recipe favourites use theme default.

### Proposed Improvement
Document and apply a convention: heart = personal preference (favourite / like), star = system designation (primary, featured), bookmark = template / saved-for-later. Add a `lib/widgets/common/icons.dart` (or extend AdaptiveIcons) with named getters and ban direct `Icons.favorite` references via a lint or codemod.

### Effort vs Impact
Medium / medium. Touches many call sites but mechanical; future-proofs the design system.

---

## 15. Define long-press semantics across views

**Labels:** `tech-debt`, `settings`
**Priority:** Medium
**State:** Triage

### Finding
Long-press currently means:
- Enter selection mode — `recipe_card_widget.dart:71`
- Open options sheet — `personal_tag_widgets.dart:110-111`
- Show ingredient substitutions — `cooking_mode_view.dart:266-267`
- **Pre-fill a timer** — `cooking_mode_view.dart:202-207` (the timer affordance specifically; see also discoverability #25)
- Open message action menu — `conversations_list_view.dart:312`

A single gesture means five different things depending on what kind of list/card you're in.

### Proposed Improvement
Pick one of two conventions and apply it everywhere:
- Option A: long-press = "select this for multi-action". Other secondary actions go to a visible "…" / overflow.
- Option B: long-press = "open contextual menu". Multi-select uses a header button or swipe-to-select.

Option A is more consistent with platform conventions (e.g. iOS Photos, Android Gmail). Move the cooking-step long-press timer to a tap on a (newly-visible) timer icon.

### Effort vs Impact
Medium / medium-high. Reduces a class of discoverability bugs.

---

## 16. Standardise destructive-action confirmation patterns

**Labels:** `tech-debt`, `settings`
**Priority:** Medium
**State:** Triage

### Finding
Same severity (a destructive single-item action) uses three different patterns:
- Dialog confirmation: recipe swipe-delete (`recipe_card_widget.dart:131-142`), pantry item (`pantry_item_card.dart:30`), tag delete (`personal_tag_dialogs.dart:206`).
- Snackbar undo (no dialog): bulk recipe delete (`recipe_delete_manager.dart:94`).
- Nothing (instant): shopping item swipe-to-claim (`collaborative_shopping_items.dart:435-444`), comment delete (after a small confirm dialog), most others.

### Proposed Improvement
Codify a rule:
- Reversible action (snackbar / soft-delete in place): snackbar undo, no dialog.
- Hard-destructive: confirm dialog AND snackbar undo (or soft-delete via robustness-batch #9).
- Light action (claim, mark complete): no friction.

Apply uniformly. Many of the robustness-batch tickets will inherit this rule.

### Effort vs Impact
Small (writing the rule) / medium (applying it). Strong UX-coherence return.

---

## 17. Consolidate loading-indicator usage

**Labels:** `tech-debt`, `settings`
**Priority:** Low
**State:** Triage

### Finding
Loading state uses one of: `CircularProgressIndicator`, `LoadingVariant.skeletonRecipeList/Card`, or `LoadingVariant.peaAnimation` (`state_widget.dart:51-84`). The pea animation is described as the new default but spinners persist in many views.

### Proposed Improvement
Decide per-context: spinner for short waits (<300ms perceived), skeletons for list/detail loads, pea animation for full-screen first-load. Codify in a wrapper widget and migrate offenders.

### Effort vs Impact
Small / low.

---

## 18. Standardise date/time formatting

**Labels:** `tech-debt`, `settings`
**Priority:** Low
**State:** Triage

### Finding
- `TimeAgoFormatter.compact()` ("2d ago") — `cook_snap_gallery.dart:196`
- `TimeAgoFormatter.standard()` ("2 days ago") — `recipe_comment.dart:162`
- `DateFormat.yMMMd().add_Hm()` ("May 22, 2026 3:45 PM") — `group_info_card.dart:31`

The same semantic concept (when did this happen?) renders three different ways in the same app.

### Proposed Improvement
One context-aware formatter: compact in tight UI (cards, headers), standard in body text, absolute date for items >7 days old. Codify in a single helper and migrate.

### Effort vs Impact
Small / low.

---

## 19. Standardise primary-action placement (FAB vs app-bar vs bottom-bar)

**Labels:** `tech-debt`, `settings`
**Priority:** Low
**State:** Triage

### Finding
"Add" / "Create" lives in:
- FAB — recipe detail (`recipe_detail_view.dart:193-196`), shopping (`unified_shopping_view.dart:107-108`), conditionally in menu (`veckomeny_view.dart:200`), friends tab 2 only (`friends_list_view.dart:318-319`).
- App-bar — tag detail.
- Nowhere — some views require entering an edit mode first.

### Proposed Improvement
FAB = primary create-action for the current list. App-bar overflow = secondary actions. Apply consistently. Friends list should show "Add friend" FAB across all tabs, not just tab 2.

### Effort vs Impact
Small / low.

---

## 20. Localise route names (currently Swedish-only)

**Labels:** `tech-debt`, `settings`
**Priority:** Low
**State:** Triage

### Finding
Route file names and route constants are Swedish (`lagg_till_recept_view.dart`, `redigeraRecept`, `receptDetalj`, `importera_fran_arkiv_view.dart`). If app expands to English-locale users, these create a jarring code-vs-UI mismatch and complicate deep links / analytics.

### Proposed Improvement
Rename route constants to English (`addRecipe`, `editRecipe`, `recipeDetail`, `importFromArchive`). Keep file names Swedish-equivalent or rename — pick one. Keep the user-facing l10n strings as they are.

### Effort vs Impact
Medium / low. Mechanical rename, but touches many files.

---

# Theme 4 — Discoverability

## 21. Wire backup_service or remove the dead code

**Labels:** `tech-debt`, `account`
**Priority:** High
**State:** Triage

### Finding
`lib/services/backup_service.dart` implements `exportToFile()` (Android/iOS file export, web returns "not supported"). **No view in the app references it.** The feature is built but invisible.

### Proposed Improvement
Decide:
- (a) Wire it into Settings → Account → "Back up my recipes" with appropriate UX (file picker, share sheet on mobile).
- (b) Delete the service and any related code as confirmed dead code.

(a) is preferred — users have asked for non-GDPR backup historically. But pick one within the ticket — don't leave it dead.

### Effort vs Impact
Small (delete) / medium (wire). Either resolution is better than leaving it dead.

---

## 22. Surface keyboard shortcuts in an in-app help dialog

**Labels:** `idea`, `settings`
**Priority:** Medium
**State:** Triage

### Finding
`lib/core/keyboard/app_shortcuts.dart:77-121` registers: Esc (close), Backspace (back), Cmd/Ctrl+K (search), Cmd/Ctrl+1/2/3 (tab switch), Cmd/Ctrl+Enter (submit). **Nothing in the UI tells the user these exist.**

### Proposed Improvement
- Add `?` (shift+/) shortcut → opens a help dialog listing all bindings.
- Footer link "Keyboard shortcuts" in the Settings → Help section.
- Discover-on-first-use: a one-time toast on web/desktop ("Tip: press ? to see keyboard shortcuts").

### Effort vs Impact
Small / medium.

---

## 23. Promote "Create Copy" to a first-class action

**Labels:** `idea`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
`recipe_detail_view.dart:405-414` — "Create Copy" (recipe duplication, used for forks of shared recipes) is buried in the overflow menu. Forking is a primary use case for shared recipes.

### Proposed Improvement
On shared recipes the user doesn't own, surface "Save a copy" as a primary action in the app-bar (next to the share icon). On owned recipes, keep it in the overflow as a secondary "Duplicate" action.

### Effort vs Impact
Small / medium.

---

## 24. Surface global ingredient search on the home screen

**Labels:** `idea`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
`ingredient_search_view.dart` is a powerful match-by-pantry view, but the home/recipe-list screen has no search bar. Discoverable only via Cmd+K (web) or by knowing the route.

### Proposed Improvement
Add a search field at the top of the recipe list (or as a prominent app-bar action with a clear icon + label). Tapping opens the global search with options: by name, by ingredient, by tag.

### Effort vs Impact
Small / high. Single biggest discoverability win for power features.

---

## 25. Add discoverability hints for gesture-based features

**Labels:** `idea`, `recipe`, `social`, `shopping`
**Priority:** Medium
**State:** Triage

### Finding
Three valuable gestures with zero UI hint:
- Long-press cooking step → timer (`cooking_mode_view.dart:202-207`).
- Swipe recipe card → edit/delete (`recipe_card_widget.dart:128-167`).
- Swipe shopping item → claim (`collaborative_shopping_items.dart`).

Users have to find these by accident.

### Proposed Improvement
- First-use coachmark per gesture, dismissable, never shown again per device.
- Visible secondary affordance for each gesture (e.g. tap an icon to do the same thing), so users who don't discover the gesture can still reach the feature.
- Optional: gentle horizontal "peek" animation on first item in a list, hinting that swiping is possible.

Pair with #15 (long-press standardisation) — if long-press becomes "select", the cooking-step timer needs a visible button instead.

### Effort vs Impact
Medium / medium-high.

---

## 26. Surface allergen / dietary preferences contextually

**Labels:** `idea`, `settings`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
`settings_hub_view.dart:35-40` — Allergen & dietary preferences are buried in Settings → Food. They affect recipe card display and search ranking, but there's no link to them from the recipe list, filters, or import flow.

### Proposed Improvement
- On the recipe list filter sheet, add "Edit my allergens" / "Edit my diet" links that deep-link into the preferences screens.
- On recipe import, if the recipe contains allergens the user hasn't configured, surface a non-blocking banner: "We can flag allergens for you — set them up in 30 seconds."

### Effort vs Impact
Small / medium.

---

## 27. Add an in-app help / FAQ entry point from outside Settings

**Labels:** `idea`, `settings`
**Priority:** Low
**State:** Triage

### Finding
`settings_hub_view.dart:70-73` — FAQ is in Settings → About → FAQ (3 taps deep). No first-class help affordance on home, no "?" icon, no contact-support shortcut.

### Proposed Improvement
- Add a top-bar "?" icon on key screens (home, recipe detail) opening a context-aware help sheet (FAQ entries filtered by current view).
- Add "Contact support" as a primary action from the help sheet.

### Effort vs Impact
Small / low.

---

# Theme 5 — Cost & performance

## 28. Compress images client-side before upload

**Labels:** `performance`, `import`, `recipe`
**Priority:** High
**State:** Triage

### Finding
`lib/services/image_picker_service.dart:313` — picker takes images at up to 2400×2400 with `compressQuality: 90`, producing 2–4MB files. OCR-side resizes to 2048px JPEG@85 (`ocr_extraction_service.dart:665-730`) but **only after upload**. Every recipe photo burns 2–3MB of upload bandwidth unnecessarily.

### Proposed Improvement
- In `ImagePickerService`, pre-resize to ~1600×1600 max (still well above OCR needs) and re-encode at JPEG@80 before returning bytes.
- Keep a separate higher-resolution path for heirloom-source images if quality matters there.
- Measure: log mean upload size before/after.

### Effort vs Impact
Small / high. Direct user-visible improvement (faster imports on mobile data) AND direct cost reduction (Firebase Storage egress + downstream OCR).

---

## 29. Adopt prompt caching on LLM calls

**Labels:** `performance`, `backend`, `parsing`
**Priority:** High
**State:** Triage

### Finding
`functions/src/llm/structure-recipe.ts` and `functions/src/llm/ocr-recipe-image.ts` send the full system prompt + extraction instructions on every call. Gemini supports cached system prompts at ~25% of input-token cost, so the per-call savings are real.

### Proposed Improvement
- Refactor the LLM call sites to use Gemini's `cachedContents` API for the stable parts of the prompt (system instructions, extraction schema, examples).
- Validate the cache survives the desired TTL (the Cloud Function may need warming or a persistent cache key strategy).
- Measure cost-per-import before/after.

Per CLAUDE.md: "When LLMs are necessary — optimize: prompt caching, smaller models where sufficient, batching". This is the textbook application.

### Effort vs Impact
Medium / high. Single change, recurring cost benefit on every import.

---

## 30. Switch open-ended `.snapshots()` listeners on static-ish data to cached `.get()` or polling

**Labels:** `performance`, `tagging`
**Priority:** Medium
**State:** Triage

### Finding
`lib/repositories/firebase/firebase_personal_tag_repository.dart:93-97` — `watchAllSorted()` uses `.snapshots()`. Personal tags rarely change during a session, but every Firestore listener costs an ongoing read budget. Across many users this multiplies.

### Proposed Improvement
- Use `.get()` on view-mount + manual invalidation on mutation (tag CRUD already goes through the same repository — invalidate cache there).
- If real-time freshness is desired for collaborative tag scenarios, keep `.snapshots()` but rate-limit. Rare static data doesn't need a live listener.

### Effort vs Impact
Small / medium.

---

## 31. Document and audit listener disposal across services

**Labels:** `bug`, `performance`, `backend`
**Priority:** Medium
**State:** Triage

### Finding
`lib/repositories/firebase/firebase_menu_collaboration_repository.dart:266` uses manual `.listen()` without an obvious unsubscribe path. Repeated screen navigations may stack listeners — a real memory + cost leak.

### Proposed Improvement
- Audit all `.listen()` and `.snapshots().listen(...)` call sites for matching `.cancel()` in a `dispose()` or equivalent.
- Add a lint rule (or a custom analyzer pass) flagging `StreamSubscription` assignments without disposal.
- Fix offenders.

### Effort vs Impact
Medium / medium. Hidden cost compounds with user base growth.

---

## Reference index

| # | Title | Theme | Labels | Priority |
|---|---|---|---|---|
| 1 | Warn that cook snaps inherit recipe visibility | Privacy | idea, social, recipe | High |
| 2 | Surface that actions broadcast to friends' feeds | Privacy | idea, social, account | High |
| 3 | Visibility indicator on recipe cards | Privacy | idea, recipe | High |
| 4 | Toggle for online / last-active visibility | Privacy | idea, social, settings | Medium |
| 5 | Label comment visibility on composer | Privacy | idea, social, recipe | Medium |
| 6 | Retroactively hide blocked users' content | Privacy | bug, social | Medium |
| 7 | Show analytics event list under consent | Privacy | idea, account, analytics | Low |
| 8 | Persist source artefacts (OCR / HTML) on recipes | LLM | idea, import, recipe | Medium |
| 9 | Show ingredient parse confidence in import UI | LLM | idea, import, parsing | Medium |
| 10 | Carry OCR confidence into assisted import dialog | LLM | tech-debt, import, parsing | Medium |
| 11 | Distinguish AI-suggested from user-entered content | LLM | idea, import, parsing | Medium |
| 12 | Explain what changed when scaling portions | LLM | idea, recipe | Low |
| 13 | "Re-extract from source" affordance | LLM | idea, import, recipe | Low |
| 14 | One icon convention for favourite/primary/saved | Consistency | tech-debt, settings | Medium |
| 15 | Define long-press semantics across views | Consistency | tech-debt, settings | Medium |
| 16 | Standardise destructive-action confirmation | Consistency | tech-debt, settings | Medium |
| 17 | Consolidate loading-indicator usage | Consistency | tech-debt, settings | Low |
| 18 | Standardise date/time formatting | Consistency | tech-debt, settings | Low |
| 19 | Standardise primary-action placement | Consistency | tech-debt, settings | Low |
| 20 | Localise route names (Swedish → English) | Consistency | tech-debt, settings | Low |
| 21 | Wire backup_service or remove dead code | Discoverability | tech-debt, account | High |
| 22 | Surface keyboard shortcuts in help dialog | Discoverability | idea, settings | Medium |
| 23 | Promote "Create Copy" to a first-class action | Discoverability | idea, recipe | Medium |
| 24 | Surface global ingredient search on home | Discoverability | idea, recipe | Medium |
| 25 | Discoverability hints for gestures | Discoverability | idea, recipe, social, shopping | Medium |
| 26 | Surface allergen/dietary prefs contextually | Discoverability | idea, settings, recipe | Medium |
| 27 | First-class help / FAQ entry point | Discoverability | idea, settings | Low |
| 28 | Compress images client-side before upload | Cost | performance, import, recipe | High |
| 29 | Adopt prompt caching on LLM calls | Cost | performance, backend, parsing | High |
| 30 | Cached `.get()` instead of `.snapshots()` for static data | Cost | performance, tagging | Medium |
| 31 | Audit and document listener disposal | Cost | bug, performance, backend | Medium |

---

## What's good (audit notes — not gaps)

The cost lens also surfaced things that are already done right and should not be re-ticketed:

- **Cloud Functions pinned to `europe-west1`** — `functions/src/index.ts:25`.
- **OCR result caching with SHA-256 keys + 24h expiry** — `ocr_extraction_service.dart:217-236`.
- **`whereIn` batching used correctly** — `firebase_personal_tag_repository.dart:131-145`.
- **Cursor pagination on recipe list** — `firebase_recipe_repository.dart` (`loadMoreRecipes`).
- **Image caching via `CachedNetworkImage`** with LRU eviction — `optimized_image_loader.dart`.
- **Tag generator is deterministic** (Phase 1–5 are rule-based, no LLM call) — `tag_generator.dart:166-300`.
- **Consent infrastructure exists** with 7 purpose granularity — `user_consent.dart`.
- **GDPR data export** is one-click and well-built — `data_export_view.dart`.
- **Search-visibility toggles** present and correct (`isSearchable`, `allowEmailSearch`) — `user_profile.dart:33-34`, `user_profile_edit_view.dart:629-645`.

---

## Cross-batch dependency notes

- **#15 (long-press standardisation)** affects how #25 (cooking-step timer hint) should land — the timer might move from long-press to a visible button.
- **#8 (persist source artefacts)** unlocks #13 (re-extract) and complements uxgap-batch #9 (source URL).
- **#11 (AI provenance)** could share the "history" view scaffold with robustness-batch #19 (sync-conflict history).
- **#28 (image pre-compression)** reduces costs that #29 (prompt caching) also reduces — both ship together for maximum compound effect.
