# BUTLERY CODE QUALITY & ARCHITECTURE ANALYSIS — PHASE 1 FINDINGS

```
Analysis Date: 2026-02-26
Analyst: Claude (Opus 4.6) — 4 parallel investigation agents
Codebase: 1,044 non-generated .dart files in lib/, ~564k LOC (hand-written)
Flutter analyze: 1 warning (outstanding)

OVERALL SCORE: 68.5/100

+-- D1  Architecture Compliance:        14 /20
+-- D2  File Size & Complexity:         10 /15
+-- D3  Deduplication & Infrastructure: 10 /15
+-- D4  Error Handling & Resilience:    10 /15
+-- D5  Documentation Health:            6 /10
+-- D6  Code Readability:                7 /10
+-- D7  Production Readiness:          7.5 /10
+-- D8  Deprecated API & Tech Debt:      4 /5

STATUS: Needs Work (strong foundation, targeted fixes required)

CRITICAL ISSUES: 3 found
HIGH PRIORITY:   14 found
MEDIUM PRIORITY: 20 found
LOW PRIORITY:    18 found
```

---

## Top 10 Issues Quick Reference

| # | Sev | Issue | Location | Effort | Impact |
|---|-----|-------|----------|--------|--------|
| 1 | CRIT | View imports concrete Firebase repository | `personal_tags_view.dart:20` | 1h | Architecture |
| 2 | CRIT | FeedbackService bypasses repository layer (Firestore+Storage direct) | `feedback_service.dart:58,76` | 4h | Architecture |
| 3 | CRIT | MessagingService bypasses repository for poll ops | `messaging_service.dart:555,613` | 3h | Architecture |
| 4 | HIGH | 385 hard-coded Firestore collection name strings across 79 files | `repositories/`, `services/` | 2d | Maintainability |
| 5 | HIGH | PII (userIds, emails) logged to production Crashlytics | 80+ AppLogger calls | 1d | GDPR |
| 6 | HIGH | 8 model files bypass SerializationUtils (raw data['field'] casting) | `audit_log.dart`, `friend_category.dart`, etc. | 4h | Resilience |
| 7 | HIGH | ACCEPTED_LARGE_FILES.md severely stale (33 listed vs 118 actual) | `docs/architecture/` | 2h | Governance |
| 8 | HIGH | 5 ViewModels import cloud_firestore for Timestamp type leakage | `base_shared_content_viewmodel.dart`, etc. | 3h | Architecture |
| 9 | HIGH | ~15 silent catch-and-return-null in import/extraction services | `import_manager.dart`, etc. | 4h | User experience |
| 10 | HIGH | `runZonedGuarded` is a no-op — async errors bypass Crashlytics | `main.dart:152-165` | 1h | Reliability |

---

## Dimension 1: Architecture Compliance (14/20)

### Summary
The MVVM+Repository architecture is well-defined and largely followed. However, the repository boundary is significantly porous: 60 service files import Firebase packages, 3 services bypass repositories entirely, and 5 ViewModels import `cloud_firestore`. Data source discipline (UserService vs PermissionService) is excellent with zero mixing violations.

### CRITICAL

**C1.1: View imports concrete Firebase repository implementation**
- `lib/views/personal_tags_view.dart:20` — `import 'package:butlery/repositories/firebase/firebase_shared_personal_tag_repository.dart';`
- Double violation: view bypasses service layer AND imports concrete (not interface) repository.
- **Fix**: Route through PersonalTagService; remove direct repository access. **Effort**: 1h

**C1.2: FeedbackService uses FirebaseFirestore.instance and FirebaseStorage.instance directly**
- `lib/services/feedback/feedback_service.dart:58` — `await FirebaseFirestore.instance.collection('feedback').add(entry.toMap());`
- `lib/services/feedback/feedback_service.dart:76` — `FirebaseStorage.instance.ref().child('feedback/$userId/$timestamp.png');`
- Bypasses repository pattern, security validation, and audit logging entirely.
- **Fix**: Create FeedbackRepository, inject into FeedbackService. **Effort**: 4h

**C1.3: MessagingService uses FirebaseFirestore.instance for poll operations**
- `lib/services/messaging_service.dart:555` — `final firestore = FirebaseFirestore.instance;`
- `lib/services/messaging_service.dart:613` — `final firestore = FirebaseFirestore.instance;`
- Service already has `_messagingRepository` injected but bypasses it for poll voting/closing.
- **Fix**: Add poll operations to MessagingRepository. **Effort**: 3h

### HIGH

**H1.1: 5 ViewModels import cloud_firestore for Timestamp type**
- `lib/viewmodels/shared_content/base_shared_content_viewmodel.dart:30`
- `lib/viewmodels/shared_content/shared_menu_viewmodel.dart:32`
- `lib/viewmodels/shared_content/shared_shopping_viewmodel.dart:33`
- `lib/viewmodels/shared_content/shared_recipe_viewmodel.dart:32`
- `lib/viewmodels/menu/menu_social_manager.dart:3`
- Firebase `Timestamp` type leaks into ViewModel layer. Models should expose `DateTime` instead.
- **Fix**: Convert Timestamp → DateTime at model/service boundary. **Effort**: 3h

**H1.2: ProfileViewModel imports firebase_auth for User type**
- `lib/viewmodels/profile/profile_viewmodel.dart:8` — exposes `User?` at line 43
- **Fix**: Use domain-level user type or expose through AuthService. **Effort**: 2h

**H1.3: Views import firebase_auth for MFA types**
- `lib/views/auth/mfa_challenge_dialog.dart:2`
- `lib/views/settings/mfa_settings_view.dart:2`
- MFA is inherently Firebase-specific, but views should not import Firebase packages.
- **Fix**: Create MFA abstractions in auth service layer. **Effort**: 4h

**H1.4: FirebaseSyncManager falls back to FirebaseFirestore.instance**
- `lib/services/unified/modules/firebase_sync_manager.dart:212` — `final firestoreInstance = firestore ?? FirebaseFirestore.instance;`
- **Fix**: Remove fallback, require injection. **Effort**: 30m

**H1.5: 60 service files import Firebase packages directly**
- Many import `cloud_firestore` for types like `DocumentSnapshot`, `QuerySnapshot`, `Timestamp`.
- While some are justified (auth_service, monitoring), most represent porous repository boundary.
- **Fix**: Systematic migration to domain types at service boundary. **Effort**: 2-3d

**H1.6: notification_repository.dart misplaced in services/ directory**
- `lib/services/notifications/notification_repository.dart` — Repository class in services directory.
- **Fix**: Move to `lib/repositories/`. **Effort**: 30m

### MEDIUM

**M1.1: Views import repository interfaces (2 files)**
- `lib/views/personal_tags_view.dart:19` — imports `recipe_repository.dart` interface
- `lib/views/settings/allergen_preferences_view.dart:6` — same
- Views should only access services, not repositories (even interfaces).
- **Fix**: Route through appropriate services. **Effort**: 2h

**M1.2: 5 ViewModels import repository implementations/interfaces**
- `lib/viewmodels/group_content_viewmodel.dart:5`
- `lib/viewmodels/personal_tag_viewmodel.dart:13`
- `lib/viewmodels/menu/menu_storage.dart:8`
- `lib/viewmodels/recipe_form/recipe_collaborative_manager.dart:15`
- `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:15`
- **Fix**: Route through services. **Effort**: 4h

**M1.3: Direct service instantiation in ViewModels (3 files)**
- `lib/viewmodels/user_profile_viewmodel.dart:44` — `ImageUploadService()` fallback
- `lib/viewmodels/recipe_form/recipe_image_manager.dart:80` — same
- `lib/viewmodels/recipe_form/image_management/xfile_upload_handler.dart:31` — same
- **Fix**: Remove fallback, require DI injection. **Effort**: 1h

**M1.4: FirebaseAuth.instance in DI module**
- `lib/core/di/modules/social_module.dart:124` — `auth: FirebaseAuth.instance`
- DI modules are the expected place, but should use AuthRepository abstraction.
- **Fix**: Inject through existing auth repository. **Effort**: 30m

### LOW

**L1.1: Unified service sub-module naming inconsistency**
- `UnifiedRecipeService`: `.personal`, `.social`, `.realtime`
- `UnifiedShoppingService`: `.personal`, `.collaborative`, `.share` (different naming)
- `UnifiedMenuService`: `.collaborative` only (missing sub-modules)
- **Fix**: Standardize naming convention. **Effort**: 2h

**L1.2: Data source discipline is excellent**
- All files importing both UserService and PermissionService use them correctly.
- No mixing violations found.

**L1.3: setState in ViewModels — false alarm**
- `realtime_menu_viewmodel.dart` and `realtime_menu_state.dart` use `ChangeNotifier` with `notifyListeners()` correctly.
- No actual `setState()` (Flutter widget) calls found. No migration needed.

---

## Dimension 2: File Size & Complexity (10/15)

### Summary
The 500-line discipline shows evidence of prior refactoring (28 files, 8,233 lines reduced). However, 3 files >1,000 lines are not in the accepted list, and the governance document (ACCEPTED_LARGE_FILES.md) is severely stale. Functions are generally well-decomposed with manageable complexity.

### HIGH

**H2.1: personal_tags_view.dart — 1,324 lines, NOT in accepted list**
- Largest non-generated file. Contains 18 methods with repetitive dialog patterns.
- **Decomposition**: Extract `PersonalTagDialogs` (~400 lines) + `PersonalTagWidgets` (~300 lines) → core view ~500 lines.
- **Effort**: 4h

**H2.2: personal_tag_service.dart — 1,117 lines, NOT in accepted list**
- 40+ methods covering tag CRUD, group CRUD, rule evaluation, sharing.
- **Decomposition**: `PersonalTagCrudService` (~350) + `PersonalTagRuleEvaluator` (~350) + `PersonalTagSharingService` (~150).
- **Effort**: 6h

**H2.3: personal_tag_rule.dart — 1,018 lines, NOT in accepted list**
- 3 enums with extensions + RuleCondition (380 lines) + PersonalTagRule.
- **Decomposition**: `condition_type.dart` (~170) + `condition_operator.dart` (~140) + `rule_condition.dart` (~380) → main file ~330 lines.
- **Effort**: 3h

### MEDIUM

**M2.1: recipe_unified.dart grew 39% beyond documented size**
- Accepted at 845 lines, now 1,174 lines. Contains 6 classes.
- Should trigger re-evaluation and possible extraction of serialization helpers.
- **Effort**: 3h

**M2.2: 7 additional files >500 lines not in accepted list**
- `personal_recipe_module.dart` (952), `personal_tag_manager_dialog.dart` (892 — deprecated!), `tag_phase1_base.dart` (838), `personal_tag_rule_dialog.dart` (816), `tag_result.dart` (814), `recipe_detail_content.dart` (749), `personal_tag_viewmodel.dart` (735)
- **Fix**: Add to accepted list with rationale, or decompose. **Effort**: 1h per file assessment

**M2.3: recipe_image_manager.dart — accepted but facade claim is misleading**
- Accepted at 1,317 lines as "uses facade pattern with 5 sub-managers"
- Actually a single class with 30+ methods; sub-managers not extracted as separate classes.
- **Fix**: Actually extract the sub-managers. **Effort**: 8h

### LOW

**L2.1: Deprecated personal_tag_manager_dialog.dart still in codebase (892 lines)**
- Marked `@Deprecated('Use PersonalTagsView instead')` at line 20.
- Dead code that should be removed entirely.
- **Effort**: 30m

**L2.2: Complexity in RuleCondition.evaluate() is well-structured**
- 12-branch switch dispatch to dedicated methods. Acceptable pattern.

**L2.3: Repetitive dialog patterns inflate view file sizes**
- `personal_tags_view.dart` has 4 nearly identical dialog methods (~80 lines each).
- A shared `_showTagEditDialog()` helper could reduce duplication.
- **Effort**: 2h

---

## Dimension 3: Code Deduplication & Infrastructure (10/15)

### Summary
Infrastructure adoption is strong overall: BaseService at 92% (counting justified ChangeNotifier exceptions), SerializationUtils at ~84% (not the claimed 100%). The main gaps are 8 model files with raw Firestore data casting, scattered collection name strings, and 3 ViewModels manually managing loading state.

### HIGH

**H3.1: 8 model files bypass SerializationUtils with raw data['field'] casting**
True adoption is ~84% (42/50), not the claimed 100%.
- `lib/models/audit_log.dart:67-73` — 7 fields with raw `as String` casting
- `lib/models/friend_category.dart:238-249` — raw casting for all fields
- `lib/models/messaging/conversation_participant.dart:89-100` — raw casting
- `lib/models/messaging/conversation_membership.dart:92-100` — raw casting for 8 fields
- `lib/models/shared_content.dart:69-82` — uses `.orEmpty()` but not SerializationUtils
- `lib/models/notification_batch.dart:28-43` — raw casting
- `lib/models/realtime/realtime_menu_factory.dart:80-107` — raw casting
- **Risk**: `as String` on null Firestore data throws TypeError at runtime.
- **Fix**: Migrate each to SerializationUtils.safe* methods. **Effort**: 4h total

**H3.2: Inconsistent null-coalescing — 33 `?? ''` vs 37 `.orEmpty()` in models**
- 14 model files use raw `?? ''` pattern instead of the project's `.orEmpty()` extension.
- **Fix**: Batch replace in model files. **Effort**: 1h

### MEDIUM

**M3.1: 8 plain service classes without BaseService or ErrorHandlingMixin**
- `PermissionCacheService`, `FeatureFlagService`, `DeviceIntegrityService`, `FirebasePerformanceService`, `AppMonitoringService`, `FieldEncryptionService`, `FCMService`, `TagResolutionService`, `YouTubeTranscriptService`
- Most are utility/infrastructure services (justified). However, `YouTubeTranscriptService`, `FCMService`, and `FieldEncryptionService` perform substantive operations.
- **Fix**: Add ErrorHandlingMixin to the 3 substantive services. **Effort**: 2h

**M3.2: Firestore collection names as scattered string literals (385 occurrences, 79 files)**
- `'recipes'`, `'users'`, `'menus'`, `'friends'`, `'messages'`, etc.
- No `FirestoreCollections` constant class exists.
- Worst: `conversation_participant_module.dart` (33), `collaborative_recipe_repository.dart` (28)
- **Fix**: Create `FirestoreCollections` constants class, batch replace. **Effort**: 2d

**M3.3: 3 ViewModels manually manage _isLoading instead of AsyncOperationMixin**
- `lib/viewmodels/chat_viewmodel.dart:27`
- `lib/viewmodels/group_detail_viewmodel.dart:61`
- `lib/viewmodels/personal_tag_viewmodel.dart:32`
- **Fix**: Migrate to StateNotifierMixin + AsyncOperationMixin. **Effort**: 3h

**M3.4: FirebaseFirestore.instance in 4 service files (repeated from D1)**
- `feedback_service.dart:58`, `messaging_service.dart:555,613`, `firebase_sync_manager.dart:212`

### LOW

**L3.1: BaseService pre-flight checks are stubs**
- `lib/core/base/base_service.dart:298-313` — `_isNetworkAvailable()` and `_hasPermission()` return `true` always.
- Functional but misleading. **Effort**: 2h to implement or remove.

**L3.2: CircuitBreaker has minimal adoption (4 files)**
- Exists at `lib/core/circuit_breaker.dart` but only used by parsing/upload services.
- Core Firestore operations don't use it.
- **Fix**: Evaluate whether Firestore ops need circuit breaking. **Effort**: 4h

**L3.3: Friends service stubs are dead code**
- `lib/services/unified/friends/friends_service_stubs.dart:21-33` — 3 empty stub classes.
- **Fix**: Remove. **Effort**: 10m

### Infrastructure Adoption Summary

| Infrastructure | Target | Current | Rate | Gap |
|---|---|---|---|---|
| BaseService | 66 services | 38 direct + 13 ChangeNotifier | 92% (justified) | 8 plain classes |
| BaseFirebaseRepository | ~28 Firebase repos | 21 | ~75% | 7 holdouts |
| SerializationUtils | 50 model factories | 42 | **84%** (not 100%) | 8 raw casting |
| ErrorHandlingMixin | All services | 51+ | ~77% | 8 infra services |
| AsyncOperationMixin | ViewModels | ~25/28 | ~89% | 3 manual _isLoading |
| CircuitBreaker | Firebase ops | 4 files | Very low | Not core-adopted |

---

## Dimension 4: Error Handling & Resilience (10/15)

### Summary
The error handling infrastructure is genuinely excellent — comprehensive mixins, retry logic, DNS resilience, circuit breaker. However, adoption gaps in import/extraction services (~15 silent failures) and ~15 localized error strings that leak raw exception text to users prevent a higher score.

### HIGH

**H4.1: ~15 silent catch-and-return-null patterns in import/extraction services**
- `lib/services/import/import_manager.dart:58-59, 67-68, 76-77` — 3 methods return `null` silently
- `lib/services/content_detector_service.dart:361-362` — returns `false` silently
- `lib/services/import/url_import_strategy.dart:42-43, 68-69` — returns null/false silently
- `lib/services/extraction/site_parsers/arla_recipe_parser.dart:68-69` — returns null
- `lib/services/extraction/site_parsers/ica_recipe_parser.dart:86-87` — returns null
- `lib/services/import/youtube/youtube_transcript_service.dart:90-91, 164-165, 206-207, 294-295, 309-310` — 5 silent blocks
- **Risk**: Users get no feedback when recipe import fails.
- **Fix**: Log errors and return Result type or throw typed exceptions. **Effort**: 4h

**H4.2: ~20 catch-and-log-only blocks in services**
- `lib/services/auth_service.dart:178-180` — `forceSignOut` catches and logs only
- `lib/services/messaging_service.dart:297-300` — `markConversationAsRead` logs only
- `lib/services/deep_link_service.dart:350-352, 365-367, 421-423` — deep link errors caught-and-logged
- **Fix**: Add user notification for user-facing operations. **Effort**: 3h

**H4.3: ~15 error messages leak raw exception text to users**
- `lib/l10n/app_sv.arb:408` — `"Kunde inte lämna gruppen: {error}"`
- `lib/l10n/app_sv.arb:434` — `"Kunde inte radera konversation: {error}"`
- `lib/l10n/app_sv.arb:466` — `"Kunde inte radera konto: {error}"`
- `lib/l10n/app_sv.arb:1448` — `"Kunde inte skapa lista: {error}"`
- Plus ~10 more with raw `{error}` parameter.
- **Fix**: Map errors to user-friendly categories. **Effort**: 3h

### MEDIUM

**M4.1: TextFormField widgets without validators**
- `lib/widgets/import/assisted_import_dialog.dart:239-298` — 4 fields (title, description, portions, time) have no validators
- `lib/widgets/social/groups/edit_group_dialog.dart:164` — description field lacks validator
- **Fix**: Add validators using ValidationUtils. **Effort**: 2h

**M4.2: `double.parse()` / `int.parse()` without try-catch (4 locations)**
- `lib/widgets/common/input/shopping_item_dialog.dart:324` — `double.parse()` on user input
- `lib/core/mixins/json_serializable_mixin.dart:283, 299` — `int.parse()`, `double.parse()` in deserialization
- `lib/widgets/tagging/personal_tag_color_picker.dart:44` — `int.parse(colorStr, radix: 16)`
- **Fix**: Replace with `tryParse` or wrap in try-catch. **Effort**: 1h

**M4.3: ~30 silent catch blocks with comments (error suppression pattern)**
- Clustered in extraction services (multi-strategy fallback): `recipe_site_content_extractor.dart`, `instagram_content_extractor.dart`
- Partially justified but prevents error aggregation and debugging.
- **Fix**: Log at debug level even when suppressing. **Effort**: 2h

### LOW

**L4.1: `.then()` without `.catchError()` (2 instances)**
- `lib/services/feature_flags/feature_flag_service.dart:177`
- `lib/services/parsing/recipe_parser_service.dart:431`
- Low risk. **Effort**: 15m

**L4.2: Only 2 genuinely empty catch blocks**
- `lib/services/extraction/web_scraper.dart:59` — cleanup code
- `lib/services/monitoring/app_monitoring_service.dart:187` — trace stop
- Both are in cleanup contexts. Acceptable.

**L4.3: Error handling infrastructure is comprehensive (positive)**
- `ErrorHandlingMixin`: 607 lines with DNS-aware classification, retry with exponential backoff
- `FirebaseServiceMixin`: 818 lines with DNS resilience, batch operations, transactions
- `CircuitBreaker`: 154 lines, proper open/half-open/closed states
- `AsyncOperationMixin`: 454 lines with debouncing, throttling, caching
- `int.tryParse` / `double.tryParse` is the dominant pattern (~45 tryParse vs ~12 parse)

---

## Dimension 5: Documentation Health (6/10)

### Summary
The ADR system is well-structured but metrics are severely stale — the codebase has nearly doubled since docs were written. ACCEPTED_LARGE_FILES.md is the most critical gap (33 listed vs 118 actual). ~40 Swedish comments violate the English-only rule.

### HIGH

**H5.1: ADR-004 claims 7 DI modules; actual count is 9**
- `docs/adr/ADR-004-seven-domain-modules.md` — Missing `search_module.dart` and `tagging_module.dart`.
- **Fix**: Update ADR with 2 new modules. **Effort**: 30m

**H5.2: ACCEPTED_LARGE_FILES.md severely stale**
- Lists 33 files; actual count is 118 files >500 lines.
- 85 files not documented, including 3 files >1,000 lines.
- Last updated December 2025.
- **Fix**: Full audit and update. **Effort**: 2h

**H5.3: ADR-005 metrics completely outdated**
- Claims 669 files, ~12 >500 lines; reality is 1,052 files, 118 >500 lines.
- Referenced "largest file" (`firebase_ratings_repository.dart`) doesn't exist.
- **Fix**: Update with current metrics. **Effort**: 1h

**H5.4: ADR-001 file counts stale**
- Claims 60 views, 60 VMs, 150 services, 30 repos; reality is 101/98/276/90.
- **Fix**: Update counts. **Effort**: 30m

### MEDIUM

**M5.1: 3 broken document references in ADRs**
- `ADR-003:197` → `../architecture/FIREBASE_INTEGRATION.md` — does not exist
- `ADR-003:255` → `../../docs/ultimate/MASTERPLAN.md#007` — does not exist
- `ADR-004:299` → `DI_SYSTEM.md` — does not exist
- **Fix**: Remove or update references. **Effort**: 15m

**M5.2: 11 TODO/FIXME comments (4 are 3+ months old)**
- `lib/core/di/modules/social_module.dart:195,254,260` — 3 FIXMEs from Nov 2025 (3+ months)
- `lib/viewmodels/universal_share_dialog_viewmodel.dart:368` — FIXME from Nov 2025
- `lib/core/router/app_router.dart:238` — TODO from Dec 2025 (2 months)
- `lib/viewmodels/menu/menu_storage.dart:281` — TODO from Dec 2025
- `lib/services/performance/startup_optimization_manager.dart:17,390,405,415,421` — 5 TODOs from Feb 2026 (recent)
- **Fix**: Triage and resolve or convert to tracked issues. **Effort**: 2h

**M5.3: ~40 Swedish prose comments in application code**
Violates CLAUDE.md rule "All comments in English."
- `lib/viewmodels/recipe_list_viewmodel.dart:496-534` — 7 consecutive Swedish comments
- `lib/core/form/form_fields_manager.dart:152,328,333`
- `lib/services/user_service.dart:324,329` — "NYTT: Skapa base user document..."
- `lib/viewmodels/collaborative_status_viewmodel.dart:90,317,391`
- Plus ~25 more across various files.
- **Fix**: Translate to English. **Effort**: 2h

**M5.4: 4 section dividers violating CLAUDE.md rule**
- `lib/models/parsing/parsing_correction.dart:31,45,62` — `// === Context === `, etc.
- `lib/models/tagging/ingredient_data.dart:78` — `// --- New fields ---`
- **Fix**: Remove dividers. **Effort**: 15m

### LOW

**L5.1: ~35 lines of commented-out code across 7 files**
- `lib/services/deep_link_service.dart:322-335` — 14 lines of bit.ly code
- Plus 6 other files with 1-8 lines each.
- Very low for a 1,052-file codebase.
- **Fix**: Remove. **Effort**: 30m

**L5.2: butlery_parser_spec.md is 5,500 lines in Swedish**
- While potentially useful as a product spec, unusual for an English-standard codebase.

### Markdown File Health

| File | Status | Reason |
|------|--------|--------|
| `docs/adr/ADR-001` | **UPDATE** | File counts stale (60→101 views, etc.) |
| `docs/adr/ADR-002` | KEEP | Patterns still accurate |
| `docs/adr/ADR-003` | **UPDATE** | 2 broken doc references |
| `docs/adr/ADR-004` | **UPDATE** | Claims 7 modules, actually 9 |
| `docs/adr/ADR-005` | **UPDATE** | Metrics completely stale |
| `docs/architecture/ACCEPTED_LARGE_FILES.md` | **UPDATE** | 33 listed vs 118 actual |
| `docs/architecture/FIREBASE_*_DECISION.md` (2) | KEEP | Valid exclusion decisions |
| `docs/performance/FIREBASE_PERFORMANCE_GUIDE.md` | KEEP | Production guide |
| `docs/security/*.md` (2) | KEEP | Active security docs |
| `docs/design/*.md` (2) | KEEP | Active design specs |
| `docs/parser/*.md` (2) | KEEP | Parser reference docs |
| `docs/tagging/tagging_system.md` | KEEP | Active SSOT for tagging |
| `docs/testing/MANUAL_TEST_LOG.md` | KEEP | Active (updated 2026-02-25) |
| `docs/analysis/prompts/*.md` (7) | KEEP | Active analysis framework |

---

## Dimension 6: Code Readability (7/10)

### Summary
Excellent lint compliance (1 warning across 1,052 files), full `withValues()` migration, and good naming conventions. The main concerns are 385 hard-coded Firestore collection strings, 238 scattered Duration values, and a god object in PersonalTagService (38 public methods).

### HIGH

**H6.1: 385 hard-coded Firestore collection name strings across 79 files**
- No `FirestoreCollections` or `CollectionPaths` constant class exists.
- Worst: `conversation_participant_module.dart` (33), `collaborative_recipe_repository.dart` (28), `firebase_shared_shopping_repository.dart` (26)
- **Risk**: Typo writes to wrong collection silently. Name changes require 79-file find-replace.
- **Fix**: Create centralized constants. **Effort**: 2d

### MEDIUM

**M6.1: God object — PersonalTagService has 38 public Future methods**
- `lib/services/tagging/personal_tag_service.dart` — 1,117 lines
- Also: `firebase_recipe_repository.dart` (28 methods), `unified_recipe_service.dart` (28 methods, documented facade)
- **Fix**: Decompose into focused sub-services. **Effort**: 6h (overlaps with D2)

**M6.2: 238 hard-coded Duration values across 118 files**
- 115 `Duration(milliseconds: ...)` + 123 `Duration(seconds: ...)`
- `Duration(milliseconds: 300)` repeated in multiple debounce contexts.
- Some centralized in `theme_constants.dart` / `app_dimensions.dart`, but many are not.
- **Fix**: Extract common durations to constants. **Effort**: 4h

**M6.3: Mixed-language naming (Swedish view names)**
- `mina_recept_view.dart`, `skriv_sjalv_recept_view.dart`, `importera_fran_arkiv_view.dart`
- Internally consistent (filename matches class) but creates mixed-language friction.
- **Fix**: Consider but likely keep for UX team alignment. **Effort**: N/A

### LOW

**L6.1: Minor abbreviated variable names (~19 occurrences)**
- `ctx` instead of `context` in 6 files, `val` in forEach callbacks
- `lib/services/menu_service.dart:118` — `num` shadows Dart type
- **Fix**: Rename in next touch. **Effort**: 30m

**L6.2: Outstanding lint compliance**
- Single warning: `lib/services/parsing/recipe_parser_service.dart:213` — `unnecessary_non_null_assertion`
- 1 warning across 1,052 files is exceptional.

**L6.3: Zero withOpacity() usage — 451 correct withValues() usages**
- Full compliance with deprecated-API migration. Excellent.

**L6.4: No redundant doc comments**
- Zero matches for `/// Gets the`, `/// Returns the`, `/// Sets the` restating method names.
- Good WHY-not-WHAT discipline.

---

## Dimension 7: Production Readiness (7.5/10)

### Summary
Strong production fundamentals: secrets managed via flutter_dotenv, comprehensive .gitignore, zero print() in executable code, App Check enabled, Crashlytics configured, SSL pinning implemented. Main concerns are PII in production logs (GDPR risk) and a non-functional runZonedGuarded pattern.

### HIGH

**H7.1: PII (User IDs, emails) logged to production Crashlytics**
- 80+ `AppLogger` calls output raw `$userId` values.
- `lib/services/unified/operations/friends_invitations_operations.dart:145` — logs actual email
- `lib/viewmodels/realtime/participant_tracker.dart:129` — logs displayName
- `AppLogger.debug()` is gated behind `assert()` (safe), but `.info()`, `.warning()`, `.error()`, `.success()` execute in release and forward to Crashlytics.
- **GDPR Article 5(1)(c)** (data minimization) risk.
- **Fix**: Sanitize or hash PII before logging. **Effort**: 1d

**H7.2: runZonedGuarded is a no-op**
- `lib/main.dart:152-162` — `runApp()` is called OUTSIDE the guarded zone.
- Async errors during app lifecycle are NOT caught by Crashlytics on mobile.
- **Fix**: Move `runApp()` inside the guarded zone. **Effort**: 1h

### MEDIUM

**M7.1: Email logged in clear text**
- `lib/services/unified/operations/friends_invitations_operations.dart:145` — `'Email invitation sent to $email'`
- **Fix**: Remove or hash email from log. **Effort**: 15m

**M7.2: 4 FIXME comments indicating incomplete implementations in DI**
- `lib/core/di/modules/social_module.dart:195,254,260` — wired into DI but implementations missing
- `lib/viewmodels/universal_share_dialog_viewmodel.dart:368`
- **Fix**: Implement or document as intentionally deferred. **Effort**: 4h

**M7.3: Version still at 1.0.0+1**
- `pubspec.yaml:4` — No semantic versioning despite extensive development.
- **Fix**: Establish versioning scheme before release. **Effort**: 30m

### LOW

**L7.1: .env files in build/ directory (expected Flutter dotenv behavior)**
- Firebase API keys are public by design; security enforced by Firestore rules + App Check.

**L7.2: Only 4 @visibleForTesting annotations across codebase**
- Extensive mock infrastructure compensates.

### Dependency Health

| Package | Current | Latest | Risk | Action |
|---|---|---|---|---|
| sqlcipher_flutter_libs | 0.6.8 | 0.7.0+eol | **HIGH** | EOL — plan migration |
| image_cropper | 8.1.0 | 11.0.0 | **HIGH** | 3 major versions behind |
| csv | 6.0.0 | 7.1.0 | Medium | Major version, contained feature |
| device_info_plus | 11.5.0 | 12.3.0 | Medium | Major version |
| algoliasearch | 1.44.0 | 1.46.1 | Low | Patch update |
| drift | 2.29.0 | 2.31.0 | Low | Minor update |
| flutter_local_notifications | 20.0.0 | 20.1.0 | Low | Patch |
| get_it | 9.2.0 | 9.2.1 | Low | Patch |
| uuid | 4.5.2 | 4.5.3 | Low | Patch |

### Production Readiness Positives
- Zero `print()` in executable code (all 40 are in doc comments/examples)
- Zero `debugPrint()`
- `kDebugMode` guards: 35 occurrences across 6 core files
- Code obfuscation enabled (`--obfuscate --split-debug-info`)
- Firebase App Check enabled for production
- SSL Certificate Pinning implemented
- Session timeout with warning dialog
- Feature flags via Firebase Remote Config
- Multi-environment support (.env.development/.staging/.production)
- Memory pressure handling (didHaveMemoryPressure)
- Error boundaries (FlutterError.onError + PlatformDispatcher.onError)

---

## Dimension 8: Deprecated API & Technical Debt (4/5)

### Summary
Remarkably low technical debt for a 564k LOC codebase. Zero deprecated Flutter API usage, zero print() in executable code, and only 37 debt markers. Debt ratio of 0.11 items per 1,000 LOC is well below industry average (1-5/1k LOC).

### HIGH

**H8.1: sqlcipher_flutter_libs is EOL**
- `pubspec.yaml:41` — `sqlcipher_flutter_libs: ^0.6.4`
- Provides encrypted SQLite for Drift database. No more security patches.
- **Fix**: Plan migration to alternative encrypted storage. **Effort**: 2-3d

### MEDIUM

**M8.1: ~2,000 lines of deprecated backward-compatibility code**
- `lib/widgets/tagging/personal_tag_manager_dialog.dart:20` — 892 lines, `@Deprecated`
- `lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart` — 269 lines, 4 deprecated methods
- `lib/services/social_recipe_service.dart:428,485` — 2 deprecated methods
- `lib/models/social/activity_feed_item.dart` — 4 deprecated items
- Plus 14 more scattered across models, repositories, services, viewmodels.
- Total: 26 `@Deprecated` annotations.
- **Fix**: Schedule removal sprint. **Effort**: 1d

**M8.2: image_cropper 3 major versions behind (8→11)**
- `pubspec.yaml:57` — May miss platform fixes and compatibility improvements.
- **Fix**: Upgrade with API migration. **Effort**: 4h

### LOW

**L8.1: 4 section dividers (repeated from D5)**
- 2 files, 4 total occurrences. Trivial.

**L8.2: Discontinued transitive dependencies**
- `build_resolvers`, `build_runner_core` — dev-only, controlled by build_runner. Low risk.

### Technical Debt Summary

| Category | Count |
|---|---|
| @Deprecated annotations | 26 |
| FIXME comments | 4 |
| TODO comments | 7 |
| Deprecated Flutter/Dart APIs | **0** |
| print() in executable code | **0** |
| withOpacity() deprecated | **0** |
| Section dividers | 4 |
| EOL dependencies | 1 |
| Major-version-behind deps | 3 |
| Deprecated code ~lines | ~2,000 |

**Debt ratio**: 37 items / 564k LOC = **0.07 items per 1,000 LOC**
**Industry benchmark**: 1-5 items per 1,000 LOC
**Assessment**: Exceptionally clean — well below industry average.

---

## Metrics Table: Current vs Gold Standard

| Metric | Current | Gold Standard | Status |
|---|---|---|---|
| flutter analyze warnings | 1 | 0 | Near-perfect |
| Files >500 lines (non-generated) | 118 | 0 undocumented | 85 undocumented |
| Files >1000 lines (non-generated) | 5 | 0 undocumented | 3 undocumented |
| Direct Firebase instance in services | 4 call sites | 0 | Needs fix |
| setState in ViewModels | 0 | 0 | Clean |
| BaseService adoption | 92% | 100% | Strong |
| BaseFirebaseRepository adoption | ~75% | 100% | Gap |
| SerializationUtils adoption | ~84% | 100% | 8 models |
| ErrorHandlingMixin coverage | ~77% | 100% | Gap |
| TODO/FIXME count | 11 | <10 | Near target |
| Deprecated Flutter APIs | 0 | 0 | Perfect |
| withOpacity() usage | 0 | 0 | Perfect |
| Hard-coded collection names | 385 | 0 | Major gap |
| Hard-coded Duration values | 238 | <20 | Major gap |
| PII in logs | 80+ | 0 | GDPR risk |
| Debt ratio (items/1k LOC) | 0.07 | <1.0 | Excellent |

### Codebase Scale

| Metric | Value |
|---|---|
| Non-generated .dart files (lib/) | 1,044 |
| Total hand-written LOC | ~564,000 |
| Test files | 515 |
| Views | 101 |
| ViewModels | 98 |
| Services | 276 |
| Repositories | 90 |
| Models | 84 |
| Widgets | 265 |
| Core infrastructure | 92 |
| DI modules | 9 |

---

## Phase 2 Preparation

### Issue Counts by Severity

| Severity | Count | Est. Effort |
|---|---|---|
| Critical | 3 | 8h |
| High | 14 | ~6d |
| Medium | 20 | ~5d |
| Low | 18 | ~2d |
| **Total** | **55** | **~15d** |

### Recommended Sprint Grouping

**Sprint 1 — Critical Architecture Fixes (1 day)**
- Fix C1.1 (view→repo import), C1.2 (FeedbackService), C1.3 (MessagingService poll ops)
- Fix H7.2 (runZonedGuarded no-op)
- Remove deprecated personal_tag_manager_dialog.dart (L2.1)

**Sprint 2 — Repository Boundary Hardening (2 days)**
- Fix H1.1-H1.4 (Firebase imports in ViewModels/services)
- Move notification_repository.dart to correct directory
- Fix M1.1-M1.3 (view/VM → repository imports)
- Create FeedbackRepository

**Sprint 3 — Data Resilience (1 day)**
- Fix H3.1 (8 models with raw data casting → SerializationUtils)
- Fix H4.1 (15 silent catch-and-return-null)
- Fix M4.1-M4.2 (TextFormField validators, parse→tryParse)

**Sprint 4 — Constants & Governance (2 days)**
- Create FirestoreCollections constants (H6.1)
- Extract common Duration constants (M6.2)
- Update ACCEPTED_LARGE_FILES.md (H5.2)
- Update all stale ADRs (H5.1, H5.3, H5.4)

**Sprint 5 — Production Hardening (1 day)**
- Sanitize PII in logs (H7.1)
- Fix error message leakage (H4.3)
- Plan sqlcipher migration (H8.1)
- Translate Swedish comments (M5.3)

**Sprint 6 — File Size Reduction (2 days)**
- Decompose personal_tags_view.dart (H2.1)
- Decompose personal_tag_service.dart (H2.2)
- Decompose personal_tag_rule.dart (H2.3)
- Remove ~2,000 lines of deprecated code (M8.1)

### Next Steps
1. Review these findings with the development team
2. Prioritize sprints based on upcoming release timeline
3. Execute Sprint 1 (critical fixes) immediately
4. Schedule remaining sprints across 2-3 weeks
5. Re-run analysis after fixes to measure improvement
