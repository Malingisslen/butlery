# Phase 2b: Low-Usage Utilities & Helpers Analysis
**Generated**: 2025-11-13
**Focus**: Utilities and helper files with 1-3 dependents
**Objective**: Identify consolidation opportunities, unnecessary abstractions, and inlining candidates

---

## Executive Summary

### Analysis Scope
- **Total utilities analyzed**: 13 low-usage utility/helper files
- **Total LOC analyzed**: ~4,950 lines
- **Files with 1 dependent**: 8 files (62%)
- **Files with 2 dependents**: 2 files (15%)
- **Files with 3 dependents**: 3 files (23%)

### Recommendations Summary
- **Files to KEEP (Well-justified)**: 6 files (~3,100 LOC)
- **Files to MERGE**: 4 files (~930 LOC) into 1 consolidated file
- **Files to INLINE**: 3 files (~170 LOC)
- **Total potential LOC reduction**: ~544 LOC (12% reduction)
- **Estimated total effort**: 6.5 hours

### High-Impact Actions
1. **INLINE** small helper files (170 LOC saved, 1.5 hrs)
2. **MERGE** ingredient processing utilities (improved maintainability, 3 hrs)
3. **KEEP** core infrastructure utilities (retry, connectivity, parsing)

---

## Analysis Table

| File Path | LOC | Usage | Dependents | Recommendation | Rationale | Effort (hrs) |
|-----------|-----|-------|------------|----------------|-----------|--------------|
| lib/core/utils/retry_helper.dart | 435 | 1 | offline_sync_manager | KEEP | Critical infrastructure, reusable | N/A |
| lib/core/utils/connectivity_check.dart | 494 | 3 | 3 services | KEEP | Production DNS failover, tested | N/A |
| lib/utils/social_content_features.dart | 322 | 1 | share_dialog_vm | INLINE | Single usage, tightly coupled | 2.0 |
| lib/utils/text/ingredient_normalizer.dart | 315 | 1 | ingredient_processor | MERGE | Part of MODUL1 pipeline | 1.5 |
| lib/utils/text/ingredient_preprocessor.dart | 330 | 1 | ingredient_processor | MERGE | Part of MODUL1 pipeline | 1.5 |
| lib/utils/text/ingredient_parser.dart | 792 | 3 | 3 files | KEEP | Core v2.0 engine, well-doc'd | N/A |
| lib/utils/text/unit_converter.dart | 283 | 3 | 3 files | KEEP | Swedish-American conversion | N/A |
| lib/utils/text/shopping_list_generator.dart | 357 | 1 | recipe_shopping_handler | MERGE | Related to MODUL1 | - |
| lib/utils/recipe_scraper.dart | 194 | 2 | 2 import strategies | KEEP | International recipe import | N/A |
| lib/services/social/helpers/activity_cache_helper.dart | 62 | 1 | activity_service | INLINE | Simple cache logic | 0.5 |
| lib/services/.../realtime_diagnostics_helper.dart | 49 | 1 | realtime_recipe_ops | INLINE | Simple status aggregation | 0.5 |
| lib/services/.../recipe_permission_helper.dart | 404 | 3 | 3 services | KEEP | Complex permission logic | N/A |
| lib/widgets/permissions/edit_mode_ui_helper.dart | 59 | 1 | collaborative_permissions | INLINE | Simple UI mapping | 0.5 |

