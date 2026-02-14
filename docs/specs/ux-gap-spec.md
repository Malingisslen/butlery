# UX Gap Analysis Spec — Beta Launch

**Date:** 2026-02-13
**Source:** Systematic analysis of 350+ backend operations vs frontend coverage + industry benchmarking
**Scope:** All items approved for beta implementation, organized in 3 phases

---

## Phase 1: Core Gaps (Backend exists, needs frontend)

### 1.1 Notification Preferences View
**Gap:** NotificationService.updatePreferences() + updateTopicSubscriptions() exist. No UI.
**Decision:** Category toggles + quiet hours
**Spec:**
- New view: `NotificationPreferencesView` accessible from profile menu
- 4-6 category switches: Social, Messages, Shopping, Menus, System
- Quiet hours: time range picker (start + end time)
- Save button persists to NotificationService.updatePreferences()

### 1.2 Conversation Pin, Archive & Swipe Gestures
**Gap:** pinConversation() and archiveConversation() backend exists. Only mute wired in UI.
**Decision:** Full: pin + archive + swipe gestures
**Spec:**
- Swipe-left on conversation item: archive
- Swipe-right on conversation item: pin
- Long-press menu: pin, archive, mute (existing), delete (existing)
- Pinned conversations: sticky section at top of list
- Archived conversations: collapsible section at bottom, or separate "Archived" view

### 1.3 Recipe Collaboration Enable Toggle
**Gap:** enableCollaborativeEditing() exists, 95% backend complete, zero frontend entry points. Realtime editing module has commented-out Firestore writes. Member management is stub.
**Decision:** Same UX pattern as shopping list collaboration
**Spec:**
- "Enable collaboration" action in recipe detail more-menu
- Triggers enableCollaborativeEditing() which converts personal -> collaborative recipe
- **NOTE:** Before exposing this, realtime editing module needs Firestore writes uncommented and member management stubs completed
- Presence indicators + conflict resolution UI deferred until backend stubs are completed
- Phase 1 scope: just the toggle button + basic member display. Full collab UX is Phase 2+.

### 1.4 Shopping List Conversion (Both Directions)
**Gap:** convertPersonalToCollaborative() and convertCollaborativeToPersonal() exist. No UI.
**Decision:** Both directions, same pattern as recipe collab
**Spec:**
- Action in shopping list settings/header: "Convert to collaborative" / "Convert to personal"
- Personal -> collaborative: friend picker dialog for initial members
- Collaborative -> personal: confirmation dialog (warns collaborators lose access)
- Same toggle UX pattern as recipe collaboration (1.3)

### 1.5 Menu Comments & Ratings (Saved Menus Only)
**Gap:** addMenuComment(), rateMenu(), toggleCommentLike() built. Zero menu UI.
**Decision:** Full social on saved menus only (not live generation view)
**Spec:**
- Add comment section + star rating to saved menu detail view (VeckomenyView when viewing a saved/shared menu)
- Match recipe detail comment/rating pattern
- NOT shown during menu generation or on the prompt input view
- Only appears when viewing a previously saved or shared menu

### 1.6 Favorites Quick Filter
**Gap:** Explicitly TODO in mina_recept_view.dart (switch case does nothing).
**Decision:** Boolean isFavorite field on Recipe model
**Spec:**
- Add `isFavorite` boolean to Recipe model + Firestore serialization
- Heart/star icon toggle on recipe cards in list view
- Quick filter chip "Favoriter" in MinaReceptView filter bar
- Implement the TODO case in mina_recept_view.dart
- Persist via Firestore user's recipe document
- Real-time sync across devices

### 1.7 Content Unsharing
**Gap:** removeContentFromGroups() / removeContentFromAllGroups() exist. No UI.
**Decision:** Both locations (shared-with-me view + recipe detail)
**Spec:**
- On shared content cards in SharedWithMeView: "Stop sharing" action in card menu
- On recipe detail view: show sharing status panel (who it's shared with) with per-friend/group revoke buttons
- Confirmation dialog before revoking
- Applies to recipes, menus, and shopping lists

### 1.8 Batch Retag All Recipes
**Gap:** retagUserRecipes() exists. Only per-recipe retag in UI.
**Decision:** Available in both allergen preferences + personal tags views, with progress indicator
**Spec:**
- AllergenPreferencesView: after saving changed allergen settings, show "Retag all recipes with new preferences" button
- PersonalTagsView: after modifying rules, offer "Apply updated rules to all recipes" button
- Both show progress dialog: "Retagging 47 of 123 recipes..."
- Uses retagUserRecipes() with progress callback

### 1.9 Menu Templates (Category Placeholders)
**Gap:** createMenuTemplate() / createMenuFromTemplate() exist. Template API unused.
**Decision:** Category placeholder templates ('3 dinners, 2 lunches')
**Spec:**
- "Save as template" option in menu save dialog
- Template stores structure only: category names + counts, NOT specific recipes
- "Load template" in VeckomenyDialogs alongside "Load saved menu"
- Creating from template pre-fills the AI prompt with the template pattern
- Template browser with user's saved templates
- Template name + description fields

### 1.10 Missing Delete UI (Comments, Ratings, Shopping Templates)
**Gap:** Backend delete methods exist for all three. No UI buttons.
**Decision:** Build all three
**Spec:**
- **Comments:** Delete button on own comments in recipe detail comment thread. Confirmation dialog.
- **Ratings:** "Remove my rating" option on recipe detail. Confirmation before removal. Update average display.
- **Shopping templates:** Delete button on each template in template management. Confirmation with template name.
- All use existing `CommonDialogActions.showDeleteConfirmation()` pattern

### 1.11 Shopping List Category Grouping
**Gap:** Items have category field in backend. No grouping UI.
**Decision:** High priority for beta
**Spec:**
- Collapsible category sections in shopping list: Produce, Dairy, Meat, Bakery, Frozen, Dry Goods, etc.
- Auto-categorize items based on ingredient knowledge from IngredientLookupService
- Sort items within categories
- Category headers with item count and completion progress
- Collapse/expand per category
- Items with unknown category go to "Ovrigt" (Other) section

### 1.12 Blocked Users List
**Gap:** blockUser()/unblockUser() exist inline. No list view for managing blocks.
**Decision:** Inside privacy settings
**Spec:**
- New section in a Privacy settings view (alongside consent management)
- Shows list of blocked users with "Unblock" button per user
- Calls getBlockedUsers() to populate list
- Unblock triggers unblockUser() with confirmation

### 1.13 Recipe List Swipe Gestures
**Gap:** No swipe gestures on recipe cards. New addition from interview.
**Decision:** Swipe-left to delete (with confirmation dialog), swipe-right to edit
**Spec:**
- Dismissible wrapper on recipe list cards
- Swipe left: reveals red delete background with trash icon -> confirmation dialog -> deleteRecipe()
- Swipe right: reveals green edit background with edit icon -> navigates to /editRecipe
- Smooth animation with background color reveal
- Partial swipe shows action preview

---

## Phase 2: New Features (Completely missing from codebase)

### 2.1 Onboarding Wizard
**Gap:** No first-time user experience. Login drops straight into app.
**Decision:** Standard: allergens + dietary + first recipe prompt. Two-step quick picks.
**Spec:**
- Triggers on first login (check `hasCompletedOnboarding` flag in user profile)
- Screen 1: Welcome + app introduction
- Screen 2: Quick allergen picks — top 8 common allergens as large toggle cards (gluten, dairy, nuts, eggs, soy, fish, shellfish, sesame). Tap to select.
- Screen 3: Quick dietary picks — vegetarian, vegan, pescetarian, etc. Same card UI.
- Screen 4: "Import your first recipe" — URL paste field + photo import button + "Skip for now"
- Link to full AllergenPreferencesView from quick picks for users who want more detail
- Save selections to UserService.updateAllergenPreferences()
- Set `hasCompletedOnboarding: true` on completion or skip

### 2.2 Cooking Mode (Landscape Split-View)
**Gap:** No dedicated cooking view. Instructions display as static list.
**Decision:** Landscape split-view with ingredients left, instructions right, wakelock
**Spec:**
- Entry point: "Start cooking" button on recipe detail view
- Auto-entry: rotating device to landscape while on recipe detail
- Forces landscape orientation on entry
- Layout: LEFT panel = ingredients list (scrollable, with portion-scaled quantities), RIGHT panel = instructions (scrollable, larger text)
- Wakelock: keep screen on always while in cooking mode (add wakelock_plus package)
- Exit: back button or rotate to portrait returns to recipe detail
- Clean, minimal UI — no navigation chrome, just the content
- Large readable text for kitchen-distance reading
- Portion scaler accessible from cooking mode (adjusts left panel)

### 2.3 Ingredient Substitutions Database
**Gap:** No substitution database or suggestions.
**Decision:** Static curated database with Swedish + American-to-Swedish substitutions. Local JSON + Firestore sync.
**Spec:**
- Ship with bundled JSON asset containing substitution data
- Sync updates from Firestore `ingredient_substitutions` collection when online
- Data model: `{ingredient: "agg", substitutions: [{name: "aquafaba", ratio: "3 msk per agg", notes: "For baking"}, ...]}`
- Include Swedish ingredient names + American-to-Swedish mapping (e.g., "all-purpose flour" -> "vetemjol")
- UI: on recipe detail or edit view, tap an ingredient to see available substitutions
- Filter substitutions by user's dietary preferences/allergens
- Start with top 100 most common substitutions

### 2.4 Beta Feedback System
**Gap:** No help center, FAQ, or feedback mechanism.
**Decision:** FAQ page + email link + beta FAB with screenshot + interaction log + feedback form
**Spec:**
- **FAQ View:** Static FAQ page accessible from profile menu. Common questions about the app.
- **Feedback FAB:** Floating "!" icon on EVERY screen (bottom-right, above bottom nav)
  - Tap captures: (1) screenshot of current screen, (2) last 20 user interactions (navigation path + button taps + device info), (3) opens feedback form
  - Form fields: category dropdown (Bug, Feature request, General), free-text description, optional email
  - Screenshot attached automatically (user can review/redact before sending)
  - Submit stores to Firestore `feedback` collection (screenshot in Firebase Storage) AND sends email notification via Cloud Function
- **Interaction logging service:** lightweight service tracking last 20 interactions (screen name, action type, timestamp). In-memory circular buffer, no persistence.

### 2.5 Shareable Personal Tags
**Gap:** Personal tags are private. No sharing mechanism.
**Decision:** Share both tag definition AND recipe list matching that tag
**Spec:**
- "Share tag" action on PersonalTagsView and TagDetailView
- Share dialog (reuse UniversalShareDialog) to pick friends/groups
- Recipient receives: tag definition (name, color, icon, rules) + list of recipes currently matching that tag
- Recipient can: import the tag to their own collection, browse the recipe list
- Imported tag gets the rules but applies to recipient's own recipes
- Recipe list is a snapshot at share time (not live-updating)

### 2.6 Comment Reactions (Emoji)
**Gap:** Only like/unlike on comments. No emoji reactions.
**Decision:** Build for beta
**Spec:**
- Quick emoji picker on recipe comments (long-press or reaction button)
- Default set: thumbs up, heart, fire, laughing, yum, thinking
- Multiple reactions per comment allowed
- Real-time sync of reactions
- Reaction count badges below comment
- ~19 hours estimated effort

### 2.7 Message Reactions (Emoji)
**Gap:** No emoji reactions on chat messages.
**Decision:** Build for beta
**Spec:**
- Quick emoji picker on chat messages (long-press)
- Same emoji set as comment reactions for consistency
- Multiple reactions per message
- Real-time sync
- Reaction badges below message bubble
- ~21 hours estimated effort

### 2.8 Chat Polls
**Gap:** No poll functionality in group conversations.
**Decision:** Build for beta
**Spec:**
- Create poll option in chat input (button or attachment menu)
- Poll types: single choice, multiple choice
- Question + 2-4 options
- Real-time vote tallying
- Deadline support (optional)
- Results visible to all group members
- Creator can close poll early
- ~29 hours estimated effort

---

## Phase 3: UX Polish & Platform Standards

### 3.1 Account Security Section
**Gap:** Change password and change email not available in-app. MFA settings exist separately.
**Decision:** Combined "Account Security" section with password + email + MFA
**Spec:**
- Consolidate into single "Account Security" view in profile menu
- Change password: current password + new password + confirm. Firebase Auth reauthenticate then updatePassword.
- Change email: current password + new email. Firebase Auth reauthenticate then verifyBeforeUpdateEmail.
- MFA settings: existing MfaSettingsView content embedded or linked
- All sensitive operations require reauthentication

### 3.2 Undo Delete (Snackbar Pattern)
**Gap:** No undo for destructive actions.
**Decision:** Build for beta
**Spec:**
- Soft delete pattern: mark as deleted, show undo snackbar for 5 seconds
- On undo: restore immediately
- On timeout: permanent delete
- Apply to: recipe delete, shopping item delete, comment delete
- Uses ScaffoldMessenger.showSnackBar with SnackBarAction

### 3.3 Duplicate Import Detection
**Gap:** No detection of duplicate recipe imports.
**Decision:** Build for beta
**Spec:**
- On URL import: check if source URL already exists in user's recipes
- On content import: simple title similarity check
- If duplicate detected: show dialog "You already have a recipe called 'X' from this source. Import anyway?"
- Options: View existing, Import as new, Cancel

### 3.4 Bulk Operations (Multi-Select)
**Gap:** No bulk operations in lists.
**Decision:** Build for beta
**Spec:**
- Long-press on recipe card enters multi-select mode
- Count display in app bar: "3 selected"
- Bulk action bar: Delete, Share, Add to shopping list
- "Select all" checkbox in action bar
- Cancel selection via back button or X
- Apply to recipe list primarily. Extend to shopping items if time permits.

### 3.5 Grid/List View Toggle
**Gap:** Only list view in recipe list. Grid component exists (responsive_grid.dart).
**Decision:** Build for beta
**Spec:**
- Toggle button in MinaReceptView app bar (grid/list icon)
- Grid mode: 2-column card grid with recipe image, title, quick badges
- List mode: current single-column detailed cards
- Persist preference via UserPreferences/PersistenceService
- Smooth transition between modes

### 3.6 Image Crop/Rotate Before Upload
**Gap:** No image editing before upload.
**Decision:** Build for beta
**Spec:**
- After image selection (camera or gallery), show crop/rotate editor
- Use image_cropper package
- Square crop for recipe thumbnails, free-form for full images
- Rotate 90-degree increments
- Apply before upload to Firebase Storage

---

## Deletions

### D1: Discovery Dashboard (Full Removal)
**Decision:** Remove entirely — "this is not a social network"
**Scope:**
- Delete: `DiscoveryDashboardView` + all sub-sections (trending, popular, recommendations, friend activity, recently shared)
- Delete: `DiscoveryDashboardViewModel`
- Delete: `RecommendationService` (in-memory only, no Firestore data)
- Delete: All discovery-related widgets in `lib/views/social/discovery_dashboard/`
- Keep: `activity_feed` Firestore collection (used by GDPR export/deletion)
- Keep: `SharedWithMeView` (separate, unchanged)
- Remove profile menu entry for discovery

### D2: Biometric/App Lock Backend Code
**Decision:** Delete dead code
**Scope:**
- Delete: `BiometricService` (`lib/services/auth/biometric_service.dart`)
- Delete: `AppLockService` (`lib/services/app_lock_service.dart`)
- Remove from DI registration
- Remove any initialization calls

---

## Deferred (Post-Beta)

| Feature | Reason |
|---------|--------|
| Cooking timers | Build cooking mode first, add timers later |
| Recipe print/PDF export | Users can screenshot or share-as-text |
| Nutritional information | Hard (3-4 weeks). Plan models post-beta, integrate Livsmedelsverket API later |
| Private recipe notes | Not critical for beta |
| In-app review prompt | Not needed for beta |
| Font size / accessibility settings | Respect OS settings for now |
| Social login (Google/Apple) | Post-beta, before production launch |
| Voice control for cooking | High complexity stretch |
| Barcode scanning | High complexity stretch |
| Meal prep scheduling | High complexity stretch |
| Gamification/challenges | Low priority |
| Video audio transcription | Post-beta |
| Home screen widgets | Post-beta |
| Recipe attribution/remixing | Post-beta |
| Smart shopping suggestions | Post-beta |
| Recently viewed recipes | Post-beta |
| Shopping list text import | Not needed |

---

## Collaboration Deep-Dive (Reference)

Recipe collaboration status discovered during analysis:
- **Backend:** 70% built. Models fully defined. Repositories fully implemented. Watching + presence tracking functional. Editing + member management have Firestore writes commented out.
- **Frontend:** Display-only banners. Zero interactive controls. No enable button, no invite dialog, no presence UI.
- **Before exposing collab toggle (1.3):** Uncomment Firestore writes in RealtimeEditingModule and CollaborationManagementModule. Complete member management stubs.
- **Collab shopping lists:** Fully working end-to-end (model to follow)
- **Collab menus:** More complete than recipes but partial

## Nutrition Analysis (Reference)

For post-beta planning:
- Current ingredient DB: ~2,230 items in Firestore, no nutrition fields
- Best data source: Livsmedelsverket open API (~2,100 Swedish foods, free)
- Existing parser already extracts (quantity, unit, name) from ingredient strings
- Hardest problem: volume-to-weight conversion (1 dl flour != 1 dl milk)
- Estimated effort: 3-4 weeks (2 weeks compressed with reduced scope)
- Approach: Add nutrition fields to IngredientData, new NutritionCalculationService, per-recipe cached computation
