# Sprint Backlog

## Sprint: Household + Menu Voting — 2026-04-07

### Part 1: Household Model + Allergen Aggregation

- [x] **1A. Add `isHousehold` to FriendCategory** — `lib/models/friend_category.dart`: field + serialization. (BUT-256)
- [x] **1B. Create HouseholdService** — `lib/services/household_service.dart`: allergen aggregation. (BUT-256)
- [x] **1C. Wire MenuGenerator for household allergens** — `lib/viewmodels/menu/menu_generator.dart`: async method. (BUT-256)
- [x] **1D. Add toggleHousehold operation** — `lib/services/unified/operations/friend_categories_operations.dart`. (BUT-256)
- [x] **1E. Register HouseholdService in DI** — `lib/core/di/modules/social_module.dart`. (BUT-256)
- [x] **1F. Household l10n strings** — Both ARB files. (BUT-256)

### Part 2: Menu Voting Backend

- [x] **2A. Create MenuSlotVote model** — `lib/models/realtime/menu_slot_vote.dart`. (BUT-239)
- [x] **2B. Create MenuVotingRepository interface** — `lib/repositories/interfaces/menu_voting_repository.dart`. (BUT-239)
- [x] **2C. Create FirebaseMenuVotingRepository** — `lib/repositories/firebase/firebase_menu_voting_repository.dart`. (BUT-239)
- [x] **2D. Create MenuVotingService** — `lib/services/menu_voting_service.dart`. (BUT-239)
- [x] **2E. Register voting in DI** — `lib/core/di/modules/collaboration_module.dart`. (BUT-239)
- [x] **2F. Voting l10n strings** — Both ARB files. (BUT-239)

### Part 3: ViewModels + UI

- [ ] **3A. Household toggle in group detail** — VM + header widget. (BUT-256)
- [ ] **3B. Household allergen toggle in menu generation** — MenuViewModel. (BUT-256)
- [ ] **3C. Create MenuVotingViewModel** — `lib/viewmodels/menu_voting_viewmodel.dart`. (BUT-239)
- [ ] **3D. Create vote card widget** — `lib/widgets/menu/menu_vote_card.dart`. (BUT-239)
- [ ] **3E. Create suggest-alternative sheet** — `lib/widgets/menu/suggest_alternative_sheet.dart`. (BUT-239)
- [ ] **3F. Wire voting into realtime menu view** — Menu slot button + vote card. (BUT-239)

### Post-Sprint

- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Sprint Bug Cleanup + Loading Polish (completed 2026-04-07)

### Agent A: debugger — Close Stale Bugs

- [x] **A1. Verify and close 5 stale bug tickets** — BUT-292, BUT-293, BUT-294, BUT-295, BUT-296 all closed in Linear.

### Agent C: performance-optimizer — Loading Polish

- [x] **C1. Shimmer sweep on skeleton screens** — Already existed in `skeleton_components.dart`. No changes needed. (BUT-244)
- [x] **C2. Animated offline banner** — `status_indicators.dart`: AnimatedSwitcher + SizeTransition + "back online" confirmation. (BUT-244)

### Post-Sprint

- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Sprint Share & Discover (completed 2026-04-07)

### Agent A: Social Discovery

- [x] **A1. Add shareable public recipe collection** — PublicProfileView + PublicProfileViewModel, deep link /profile route, share button on friend profile, fetchPublicUserRecipes repository method. (BUT-219)

### Agent B: Recipe Intelligence

- [x] **B1. Enhance collection health dashboard** — Completeness stats in RecipeQueryViewModel, distribution bar + quick-fix entry points in CollectionStatsView. (BUT-242)

### Agent C: Social Polish

- [x] **C1. Enrich friend cards with subtitle** — `friends_list_cards.dart`: bio or last-active fallback. (BUT-272)
- [x] **C2. Fix shared-with-me empty state** — `shared_with_me_view.dart`: explain sharing + "Dela ett recept" CTA. (BUT-271)

### Post-Sprint

- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Previous Sprints

### Sprint: Tech Debt + UX Polish (completed 2026-04-07)

- [x] A1 Drift codegen verified (BUT-289)
- [x] A2 offline test mocks fixed (BUT-288)
- [x] B1 tablet recipe detail layout (BUT-253)
- [x] B2 cooking identity profile (BUT-218)
- [x] B3 shopping check-off animations (BUT-212)

### Sprint: Smart Import + Menu Intelligence (completed 2026-04-06)

- [x] A1 Schema.org extraction (BUT-208)
- [x] A2 duplicate detection merge (BUT-241)
- [x] A3 import progress timer (BUT-247)
- [x] B1 weighted menu generation (BUT-204)
- [x] B2 smart menu swap (BUT-270)
