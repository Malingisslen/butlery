# Sprint Backlog

## Sprint: Social Activity Feed — Phase 1 — 2026-04-10

### Step 1: Model + Constants

- [x] **S1. Create ActivityEvent model + FirestoreCollections constant** — new `lib/models/social/activity_event.dart`: ActivityEventType enum (cooked, shared), model with id/actorId/actorDisplayName/type/recipeId/recipeTitle/extraData/createdAt, toFirestore/fromMap. Add `activityEvents` to `lib/core/constants/firestore_collections.dart`. (BUT-339)

### Step 2: Repository

- [x] **S2. Create ActivityEventRepository interface + Firebase implementation** — `lib/repositories/interfaces/activity_event_repository.dart`: addEvent, fetchFriendActivity, getEventsByUser, deleteAllByUser. `lib/repositories/firebase/firebase_activity_event_repository.dart`: BaseFirebaseRepository<ActivityEvent>, batched whereIn queries in chunks of 10. (BUT-339)

### Step 3: Service

- [x] **S3. Create ActivityFeedService** — `lib/services/social/activity_feed_service.dart`: emitEvent (fire-and-forget), fetchFeed (gets friend IDs, passes to repo). (BUT-339)

### Step 4: DI Registration

- [x] **S4. Register in DI modules** — `social_module.dart`: ActivityEventRepository + ActivityFeedService in configure(). `ui_module.dart`: ActivityFeedViewModel as factory. (BUT-339)

### Step 5: ViewModel

- [x] **S5. Create ActivityFeedViewModel** — `lib/viewmodels/social/activity_feed_viewmodel.dart`: ChangeNotifier + StateNotifierMixin + AsyncOperationMixin, loadFeed/loadMore/refresh/setFilter/filteredEvents. (BUT-339)

### Step 6: Feed Tab UI

- [x] **S6. Create FeedTab widget** — `lib/views/social/friends_list/feed_tab.dart`: static build pattern, LoadingStateBuilder, activity cards with color-coded borders, filter chips, date separators, empty state. (BUT-339)

### Step 7: Tab Integration

- [x] **S7. Integrate feed tab into FriendsListView** — `lib/views/social/friends_list_view.dart`: tabs 3→4, insert Flöde at index 0, shift indices, MultiProvider, loadFeed on init. (BUT-339)

### Step 8: Emission Points

- [x] **S8. Emit activity events from CookSnap + Share** — `lib/services/cook_snap_service.dart`: emit cooked after upload. `lib/services/unified/operations/modules/recipe_sharing_manager.dart`: emit shared after notifications. (BUT-339)

### Step 9: GDPR

- [x] **S9. Add GDPR deletion + export for activity events** — `content_deletion_operations.dart`: deleteActivityEvents. `data_export_service.dart`: export activity events. (BUT-339)

### Step 10: Localization

- [x] **S10. Add l10n strings** — `app_sv.arb` + `app_en.arb`: socialFeed, feedEmpty, feedEmptyDescription, feedInviteFriends, feedFilterAll, feedFilterCooked, feedFilterShared, feedActionCooked, feedActionShared, feedTimeToday, feedTimeYesterday, feedTimeDaysAgo. (BUT-339)

### Post-Sprint Steps
- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket state (BUT-339 → Done)

---

## What this means in plain language

- A new "Flöde" tab appears first on your friends screen
- When a friend posts a cooking photo or shares a recipe, it appears in your feed
- Only explicitly social actions show up — private things stay private
- You can filter by type and tap any recipe to open it
- Feed starts empty, fills up as people use the app
- Account deletion removes all activity events too
- Risk: Low — new feature, easy to remove

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
