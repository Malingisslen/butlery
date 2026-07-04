# Scan — Role 11: Product Manager

Date: 2026-06-27
Scope: feature-portfolio completeness vs FEATURE_INVENTORY, onboarding funnel, analytics-event
instrumentation, feature-flag hygiene. Owned paths per ROLE_RESPONSIBILITY_MAP §11.
Method: every claim verified against code (file:line); inventory treated as documentation, not truth.

---

## NEW findings

### N1 — FEATURE_INVENTORY "Gaps worth ticketing / Tier 1" is stale: every flagged untested gap now has dedicated tests
The inventory (built 2026-06-21) lists four Tier-1 "safety/security/compliance, currently untested"
gaps. All four have since been covered by sprint work, but the doc still presents them as untested —
PM would prioritise tickets that are already done.

- **MFA (AUTH-11 / SET-05)** — claimed "no test on enrollment, unenrollment, or sign-in challenge".
  Covered: `test/unit/services/auth/auth_mfa_service_test.dart` (intent header: enrollment starts,
  sign-in resolution fires, error mapping), `test/unit/models/auth/mfa_types_test.dart`.
- **Account deletion client path (AUTH-14)** — claimed client-side path "has no dedicated test".
  Covered: `test/views/account_deletion_journey_test.dart` (group "Account deletion journey",
  3 testWidgets), `test/unit/services/account/account_deletion_service_test.dart`.
- **Allergen/dietary filtering (REC-03)** — claimed only VM-level coverage, "deserves dedicated
  assertions". Covered: `test/views/allergen_preferences_view_test.dart`,
  `test/widget/views/onboarding_allergen_page_test.dart`,
  `test/unit/services/tagging/allergen_mismatch_test.dart`, +5 more allergen test files.
- **Receive-share (IMP-06) & Instagram/TikTok extraction (IMP-07)** — claimed "no tests".
  Covered: `test/unit/services/import/incoming_share_service_test.dart`,
  `test/unit/core/bootstrap/incoming_share_handler_test.dart` (BUT-941 Stage 1, 2026-06-27),
  `test/unit/services/import/pipelines/instagram_pipeline_test.dart`,
  `test/unit/services/import/pipelines/tiktok_pipeline_test.dart`.

Consequence: the headline coverage numbers (80 Verified / 40 Partial / 17 Untested, all internally
consistent with the master index) are now under-counts of real coverage, and the entire "Tier 1 gaps
to ticket" list is obsolete. The inventory needs a refresh pass + recount, or it actively misdirects
product prioritisation toward already-solved gaps.
Evidence: `docs/FEATURE_INVENTORY.md` lines 13–37 (Coverage table + Tier-1 gaps); test files above.

---

## Verified-clean (no ticket)

- **Analytics dead-code:** every constant in `AnalyticsEvents` AND `AnalyticsUserProperties`
  (`lib/services/analytics/analytics_events.dart`) has ≥1 lib call-site. Zero declared-but-never-fired
  events. (BUT-436 territory — nothing new.)
- **North-Star instrumentation wired:** `cooking_session_started/completed`
  (recipe_events_tracker.dart), `menu_generated` (firebase_analytics_repository.dart),
  `recipe_shared` (recipe_events_tracker.dart) all fire. Onboarding funnel fully instrumented
  (started/page_viewed/resumed/abandoned/skipped/completed/recipes_seeded/menu_seeded/import_*).
- **Onboarding funnel — no dead-ends:** `onboarding_viewmodel.dart` (recently modified, re-read this
  scan) seeds recipes (BUT-926, awaited) + sample weekly menu & shopping list (BUT-930) so users land
  populated; age-gate mints claim at gate not completion (BUT-1386, fixes resume bug); completion
  bounded by 20s timeout returning false→error (BUT-33) — the dossier already notes the timeout has
  no retry loop, no new angle found.
- **Phase-3 dormant flags** (`enableFriendCategorySubcollection`, `enableReferenceSharedContent`,
  `enableServerRateLimiting`, `enableActivityVisibilityEnum`) confirmed 0 reads in lib/ + functions/src.
  Already a dossier watch-item — not re-filed.

## Dedup notes (verified, NOT re-filed)
- MENU-10 (`loadImportedMenuData` "stub returning null") — already implemented
  (menu_social_manager.dart:142–176); FEATURE_INVENTORY line 50 stale. **Already a dossier watch-item.**
- SET-12 (FAQ "hardcoded Swedish, not localized") — FaqView uses `context.l10n.faqQ1..5`/`faqA1..5`
  (faq_view.dart:32–49); inventory line 51 stale. **Already a dossier watch-item.**
- Unused analytics events / nav observer — BUT-436 / BUT-437 already exist.
- Phase-3 dormant flags — already a dossier watch-item.

COVERAGE: feature_flag_service.dart (all 25 flags, dormant set confirmed) · analytics_events.dart (all events + user-props checked for call-sites) · onboarding_viewmodel.dart (re-read, full funnel) · onboarding/ services dir · menu_social_manager.dart (MENU-10) · faq_view.dart (SET-12) · FEATURE_INVENTORY.md (header, coverage table, master index 137 rows, Tier-1 gaps) · cross-checked north-star event call-sites. 2 passes. NEW: 1.
