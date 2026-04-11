# Sprint Backlog

## Sprint: Calendar Weekly Menu — Phase 1 — 2026-04-11

**Slot model:** 3 slots only — `MealSlot { lunch, middag, ovrigt }`. Frukost removed; breakfast/dessert/mellanmål/fika/snack all map to `ovrigt`. Lunch and middag are single-recipe per cell. **Övrigt is multi-recipe per day** (stacked entries, user can keep adding via "+ lägg till" inside the cell).

### Step 0: HTML Preview (before any Flutter code)

- [x] **S0. HTML preview** — `docs/design/previews/weekly-menu-plan-preview.html` with 3-column grid (lunch/middag/övrigt), prompt + toggle in header, multi-entry övrigt cell on tisdag, single-entry on onsdag, overflow tray, empty state in Frame 2. Approved 2026-04-11. Delete after implementation. (BUT-211)

### Agent A: firebase-backend-security — Data layer

- [x] **S1. Create WeeklyMenuPlan model + enums + mapper + ISO week utils** — new `lib/models/menu/weekly_menu_plan.dart`: `MealSlot { lunch, middag, ovrigt }` enum with Swedish display labels + `isMulti` getter (true for ovrigt only), `DayOfWeek` enum, `WeeklyMenuPlanEntry { day, slot, recipeId, recipeTitle, recipeImageUrl? }`, `WeeklyMenuPlan { id, userId, weekStartDate, entries, createdAt, updatedAt }` with `toFirestore`/`fromMap` using `lib/core/utils/serialization_utils.dart`. Helper getters on `WeeklyMenuPlan`: `entryAt(day, slot)` (single, returns first match), `entriesAt(day, slot)` (list, used for ovrigt). New `lib/services/menu/meal_slot_mapper.dart`: pure `MealSlot mapMealTypeToSlot(String)` — frukost/breakfast/dessert/mellanmål/fika/snack/snacks → ovrigt, lunch → lunch, middag/dinner → middag, default → middag. New `lib/core/utils/iso_week_utils.dart`: `weekStartOf(DateTime)`, `isoWeekNumber(DateTime)`, `weekIdFor(userId, DateTime)`. Add `weeklyMenuPlans` constant to `lib/core/constants/firestore_collections.dart`. (BUT-211)

- [x] **S2. Create WeeklyMenuPlanRepository interface + Firebase impl + security rules** — `lib/repositories/interfaces/weekly_menu_plan_repository.dart`: `fetchForWeek`, `save`, `deleteAllByUser`. `lib/repositories/firebase/firebase_weekly_menu_plan_repository.dart`: extend `BaseFirebaseRepository<WeeklyMenuPlan>` with `PermissionValidationMixin`, deterministic doc ID `userId_YYYY-WW`, upsert on save. Update `firestore.rules` with owner-scoped read/write for `weeklyMenuPlans/{docId}`. (BUT-211)

- [x] **S3. Create WeeklyMenuPlanService with distribution** — `lib/services/menu/weekly_menu_plan_service.dart` extends `BaseService`. Methods: `getWeek(date)`, `distributeFromGeneratedMenu(generated, weekStart, {existing, now})` returns `(WeeklyMenuPlan, List<Recipe> overflow)` — for lunch/middag walks anchor→sun skipping occupied, for ovrigt walks anchor→sun adding one per day (no skip), overflow when out of days. `addEntry(plan, day, slot, recipe)` (always adds; ovrigt allows multiple per day, lunch/middag replace), `moveEntry`, `removeEntry(entryId)`, `clearWeek`, `save`. Use `executeServiceOperation` for all public async methods. (BUT-211)

- [x] **S4. Register in DI** — `lib/core/di/modules/content_module.dart`: register `WeeklyMenuPlanRepository` as interface + `WeeklyMenuPlanService` (lazy singletons). `lib/core/di/modules/ui_module.dart`: register `WeeklyMenuPlanViewModel` as factory. Verify dependency order. (BUT-211)

### Agent B: flutter-developer + uiux-designer — Presentation layer

- [x] **S5. Create WeeklyMenuPlanViewModel** — `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart` extends `BaseViewModel`: state `{currentWeekStart, entriesByDaySlot, hasOfflineChanges}`, methods `loadWeek`, `previousWeek`, `nextWeek`, `assignRecipe`, `moveEntry` (guard self-drop), `removeEntry`, `fillPlaceholders`, `clearWeek`. Use `executeAsyncVoid` for persistence. Guard async gaps with `if (isDisposed) return`. (BUT-211)

- [x] **S6. Create CalendarWeeklyMenuWidget with all five UI states** — new `lib/widgets/menu/calendar_weekly_menu_widget.dart` (embeddable, not a page — `BaseScaffold` not used). State builder for loading (pea animation) / error (contextual error engine + retry) / empty (centered illustration + bouncing arrow up + "Skapa en veckomeny från prompten ovan" hint) / offline (animated banner) / success (week-nav header, overflow tray when non-empty, 7 day-rows × 3-column grid: lunch / middag / övrigt). Lunch/middag cells render single-recipe (empty=plus icon, assigned=image+title). Övrigt cell renders **stacked entries** (mini chip per recipe) + "+ lägg till" affordance. Reuse `menu_recipe_selection_dialog.dart` for picking. Theme tokens only — zero hardcoded values. (BUT-211)

- [x] **S7. Add drag-and-drop between slots** — `LongPressDraggable<WeeklyMenuPlanEntry>` on assigned cells, `DragTarget` on all slots. On accept → `viewModel.moveEntry` (swap if occupied). Haptic feedback on pickup + drop. Theme accent border on drop targets while dragging. (BUT-211)

- [x] **S8. Veckomeny integration: Lista/Kalender toggle + auto-distribute on generation** — modify `lib/views/veckomeny_view.dart`. Add segmented "Lista │ Kalender" toggle (persisted via `SharedPreferences` key `veckomeny_view_mode`). Wire `WeeklyMenuPlanViewModel` via `MultiProvider`. When toggle = Lista, render existing list output unchanged. When toggle = Kalender, render `CalendarWeeklyMenuWidget` and after successful generation call `weeklyMenuPlanViewModel.applyGeneratedMenu(generated)`. If existing plan has entries, show overwrite confirmation dialog. (BUT-211)

### Agent C: flutter-developer — Integration & housekeeping

- [x] **S10. GDPR deletion + export** — `content_deletion_operations.dart`: `deleteWeeklyMenuPlans(userId)` with 500-op batch limit. `data_export_service.dart`: export under `weeklyMenuPlans` key. `app_sv.arb` + `app_en.arb`: `weeklyMenuToggleList`, `weeklyMenuToggleCalendar`, `weeklyMenuWeekLabel`, `mealSlotLunch`, `mealSlotMiddag`, `mealSlotOvrigt`, `weeklyMenuOvrigtAddMore` ("+ lägg till"), `weeklyMenuOverflowTitle` ("Recept som inte fick plats"), `weeklyMenuEmptyHint` ("Skapa en veckomeny från prompten ovan"), `weeklyMenuOverwriteConfirm` ("Detta ersätter din nuvarande planering. Fortsätt?"), `weeklyMenuLoadError`, `dayMon..daySun`. (BUT-211)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run `flutter test test/unit/viewmodels/menu/weekly_menu_plan_viewmodel_test.dart test/unit/repositories/firebase_weekly_menu_plan_repository_test.dart`
- [ ] Chrome end-to-end: empty → quick-fill → pick → drag → week nav → reload → offline → account deletion
- [ ] Commit, push, PR, merge
- [ ] Update Linear: BUT-211 → Done

---

## What this means in plain language

- A new "Kalender" view shows your week as a grid: 7 days across, 4 meal slots down (frukost, lunch, middag, snacks)
- You can tap an empty slot to add a recipe, or long-press and drag a recipe to move it to another day
- Quick-fill chips let you sketch the week: tap "3 middagar" and three empty dinner spaces appear, ready for you to pick recipes later
- The existing flat menu list stays exactly as it is — you can switch between "Lista" and "Kalender" on the veckomeny screen
- Your weekly plan saves automatically and reloads when you come back
- Account deletion removes your weekly plans along with everything else
- Risk: Low — the new calendar lives next to the existing menu without touching it. Worst case, we hide the toggle button and nothing else breaks.

---

## Archive: Sprint Skafferiet (Pantry) — 2026-04-10

- [x] A1-A3, B1, C1-C3, D1: Pantry model/repo/service/DI/VM, PantryView, "Laga med vad jag har" filter, navigation, GDPR/l10n/tests (BUT-349, BUT-205) — PR #143

---

## Archive: Sprint Social Activity Feed — Phase 1 (completed 2026-04-10)

- [x] S1-S10: ActivityEvent model, repository, service, DI, ViewModel, FeedTab UI, tab integration, emission points, GDPR, l10n (BUT-339)

---

## Archive: Sprint Consent Hardening (completed 2026-04-10)

- [x] A1: Consent change callback (BUT-356)
- [x] A2: FCM mid-session re-enable (BUT-356)
- [x] B1: ConsentService.checkSafely tests (BUT-357)

---

## Archive: Sprint Insights & Engagement (completed 2026-04-10)

- [x] A1: Cooking photos (BUT-338)
- [x] A2: Tag-based collection insights (BUT-350)
- [x] B1: Tag analytics heat map (BUT-223)
- [x] C1: Allergen EU FIC audit (BUT-354)
- [x] C2: Golden tests + coverage gates (BUT-214)

---

## Archive: Sprint Social Polish & Tech Debt (completed 2026-04-09)

- [x] A1: Fix share dialog dead end (BUT-342)
- [x] A2: Add reply shortcut on shared recipe cards (BUT-343)
- [x] A3: Improve comment engagement (BUT-305)
- [x] B1: Add search history + Algolia highlights (BUT-304)
- [x] B2: Handcraft warm dark color scheme (BUT-346)
- [x] C1: Accept or refactor 9 files exceeding 500-line limit (BUT-302)

---

## Archive: Previous Sprints

- Feature & Polish (2026-04-09): BUT-348, BUT-355, BUT-352, BUT-353
- Social & Stability Blitz (2026-04-08): BUT-345, BUT-341, BUT-314, BUT-323, BUT-337, BUT-324, BUT-300, BUT-301
- Tech Debt Consolidation (2026-04-08): BUT-303, BUT-306, BUT-299
- Bug Stability + Hardening H2 (2026-04-08): BUT-308, BUT-320, BUT-335, BUT-319, BUT-336, BUT-331, BUT-317, BUT-297, BUT-313, BUT-311, BUT-312, BUT-332, BUT-327
- Security Hardening (2026-04-08): BUT-334, BUT-315, BUT-310, BUT-325, BUT-326, BUT-330, BUT-316, BUT-333, BUT-318, BUT-329, BUT-328, BUT-321
- Household + Menu Voting (2026-04-08): BUT-256, BUT-239
- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
