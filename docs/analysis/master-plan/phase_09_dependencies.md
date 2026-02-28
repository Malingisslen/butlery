# Phase 9: Dependencies & Tech Debt (~5 days)

EOL packages, version upgrades, deprecated code removal, documentation updates.

---

## P9-01 — Migrate sqlcipher_flutter_libs (EOL) [HIGH]

**Source**: R05:dim2, R01:H8.1
**Files**: `pubspec.yaml:41`
**Fix**: Package is officially EOL (0.7.0+eol is a no-op stub). Migrate to sqlite3 v3.x (same author). Requires data migration, encryption key handling, cross-platform testing.
**Effort**: 2-4d

---

## P9-02 — Replace flutter_jailbreak_detection (abandoned) [HIGH]

**Source**: R05:dim2
**Files**: `pubspec.yaml`
**Fix**: Last update Jan 2023, trivially bypassed by Frida. Replace with freeRASP.
**Effort**: 4-6h

---

## P9-03 — Upgrade image_cropper (3 major behind) [HIGH]

**Source**: R05:dim2, R01:M8.2
**Files**: `pubspec.yaml:57`
**Fix**: 8.1.0 → 11.0.0. Android/iOS config changes, API refactor.
**Effort**: 4-6h

---

## P9-04 — Remove deprecated personal_tag_manager_dialog.dart [LOW]

**Source**: R01:L2.1
**Files**: `lib/widgets/tagging/personal_tag_manager_dialog.dart` (892 lines)
**Fix**: Marked `@Deprecated`. Dead code — remove entirely.
**Effort**: 30 min

---

## P9-05 — Remove ~2,000 lines of deprecated backward-compatibility code [MED]

**Source**: R01:M8.1
**Files**: `recipe_backward_compatibility_mixin.dart` (269 lines), `social_recipe_service.dart:428,485`, `activity_feed_item.dart`, 14 more (26 `@Deprecated` annotations total)
**Fix**: Schedule removal sprint. Pre-production means no backward compatibility needed.
**Effort**: 1d

---

## P9-06 — Upgrade device_info_plus (1 major behind) [MED]

**Source**: R05:dim2
**Fix**: 11.5.0 → 12.3.0. Removed `serialNumber`; Android Gradle Plugin 8.12.1+ required.
**Effort**: 1-2h

---

## P9-07 — Upgrade csv (1 major behind) [MED]

**Source**: R05:dim2
**Fix**: 6.0.0 → 7.1.0. Complete API rewrite for dart:convert compatibility.
**Effort**: 2-3h

---

## P9-08 — Upgrade drift + drift_dev [MED]

**Source**: R05:dim7
**Fix**: 2.29.0 → 2.31.0. Auto-throws on DB downgrade attempts.
**Effort**: 1-2h

---

## P9-09 — Tier 1 drop-in upgrades [LOW]

**Source**: R05:dim7
**Fix**: algoliasearch 1.44→1.46.1, flutter_local_notifications 20.0→20.1, get_it 9.2.0→9.2.1, uuid 4.5.2→4.5.3.
**Effort**: 30 min total

---

## P9-10 — Remove flutter_cache_manager from direct deps [LOW]

**Source**: R05:dim4
**Files**: `pubspec.yaml`
**Fix**: Zero imports in lib/ — it's a transitive dep of cached_network_image.
**Effort**: 5 min

---

## P9-11 — Consolidate go_router vs Navigator [MED]

**Source**: R05:dim4, R06:3.1
**Files**: `pubspec.yaml`, `lib/core/navigation/app_router.dart`, 137 files with `Navigator` calls
**Fix**: go_router has 1 import; Navigator has 478 calls in 137 files. Either fully adopt go_router or remove it.
**Effort**: 2-4h (remove) or 2-4 weeks (full adoption)

---

## P9-12 — Decompose personal_tags_view.dart (1,324 lines) [HIGH]

**Source**: R01:H2.1
**Fix**: Extract `PersonalTagDialogs` (~400 lines) + `PersonalTagWidgets` (~300 lines) → core view ~500 lines.
**Effort**: 4h

---

## P9-13 — Decompose personal_tag_service.dart (1,117 lines) [HIGH]

**Source**: R01:H2.2
**Fix**: Split into `PersonalTagCrudService` (~350) + `PersonalTagRuleEvaluator` (~350) + `PersonalTagSharingService` (~150).
**Effort**: 6h

---

## P9-14 — Decompose personal_tag_rule.dart (1,018 lines) [HIGH]

**Source**: R01:H2.3
**Fix**: Extract `condition_type.dart` (~170) + `condition_operator.dart` (~140) + `rule_condition.dart` (~380) → main ~330 lines.
**Effort**: 3h

---

## P9-15 — Update stale architecture documentation [HIGH]

**Source**: R01:H5.1, R01:H5.2, R01:H5.3, R01:H5.4
**Files**: `docs/architecture/ACCEPTED_LARGE_FILES.md`, ADR-001, ADR-003, ADR-004, ADR-005
**Fix**: (1) ACCEPTED_LARGE_FILES lists 33 files; actual is 118 (85 undocumented, 3 >1,000 lines). (2) Update ADR-001 file counts, ADR-004 (7→9 modules), ADR-005 metrics. Fix 3 broken doc references in ADR-003.
**Effort**: 4h

---

## P9-16 — Resolve old TODO/FIXME comments [MED]

**Source**: R01:M5.2
**Files**: `social_module.dart:195,254,260` (3 FIXMEs, Nov 2025), `universal_share_dialog_viewmodel.dart:368`, `app_router.dart:238`, `menu_storage.dart:281`, `startup_optimization_manager.dart:17,390,405,415,421`
**Fix**: Triage 11 items — implement, remove, or convert to tracked issues.
**Effort**: 2h

---

## P9-17 — Remove friends_service_stubs.dart [LOW]

**Source**: R01:L3.3
**Files**: `lib/services/unified/friends/friends_service_stubs.dart:21-33`
**Fix**: 3 empty stub classes — dead code.
**Effort**: 10 min

---

## P9-18 — recipe_image_manager.dart facade claim is misleading [MED]

**Source**: R01:M2.3
**Files**: `lib/viewmodels/recipe/managers/recipe_image_manager.dart`
**Fix**: Accepted at 1,317 lines as "uses facade pattern" but actually a single class with 30+ methods. Extract `ImageUploadManager`, `ImageCacheManager`, `ImageCompressionManager`.
**Effort**: 8h

---

## P9-19 — CI artifact updates [LOW]

**Source**: R03:F1-3, R03:F1-4
**Files**: `test.yml:52,136`, `e2e_tests.yml`, `architecture-validation.yml`
**Fix**: (1) Update `actions/upload-artifact@v3` → v4. (2) Standardize artifact retention (currently 30/7/90 days across workflows).
**Effort**: 30 min

---

## P9-20 — Extract common Duration constants [LOW]

**Source**: R01:M6.2
**Fix**: 238 hard-coded Duration values across 118 files. Extract common ones (e.g., 300ms debounce) to constants.
**Effort**: 4h

---

## P9-21 — Move Python site-packages out of lib/ [LOW]

**Source**: R02:C-16
**Files**: `lib/site-packages/`
**Fix**: Python packages do not belong in Flutter's lib/ directory. Move to project root or scripts/.
**Effort**: 5 min
