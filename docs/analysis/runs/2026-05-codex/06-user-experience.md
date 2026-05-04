USER EXPERIENCE & PLATFORM ANALYSIS -- PHASE 1 FINDINGS
=========================================================
Analysis Date: 2026-05-04
Analyst: Claude (Opus 4.7)
Platforms: Android, iOS, Web, macOS, Windows

OVERALL UX SCORE: 70/100

  1. Design System & Visual Consistency:    11/15
  2. Accessibility (WCAG 2.1 AA):           10/18
  3. User Flows & Navigation:               9/12
  4. Internationalization & Localization:    11/18
  5. Platform Compliance:                    11/15
  6. App Store Readiness:                    8/12
  7. Responsive Design & Adaptability:       10/10

STATUS: Needs Improvement

CRITICAL issues: 1 found
HIGH issues:     7 found
MEDIUM issues:   9 found
LOW issues:      4 found

## 1) Design System & Visual Consistency (11/15)
Theme centralization is strong: Material 3 is enabled and component themes are wired through `ThemeData` (`lib/theme/app_theme.dart:42-76`). The color/text systems are also centralized (`lib/theme/app_colors.dart:189-260`, `lib/theme/app_text_styles.dart:38-126`). Consistency drops in edge flows where inline styles and non-scale spacing are still present.

### MEDIUM
- **Inline text styling bypasses TextTheme in production UI**
  - File:line: `lib/main.dart:388-390`, `lib/main.dart:397-400`, `lib/main.dart:974-977`, `lib/widgets/menu/menu_content_widgets.dart:292-299`
  - User impact: Typography drift between screens and less predictable scaling behavior.
  - Current vs expected: Current code mixes `TextStyle(...)` literals with themed styles; expected is consistent `theme.textTheme`/`AppTextStyles` usage for UI copy.
  - Effort: 4-6 hours.

- **Android is forced to use Cupertino page transitions**
  - File:line: `lib/theme/app_theme.dart:87-91`
  - User impact: Android navigation motion feels non-Material and inconsistent with platform expectations.
  - Current vs expected: Current transition builder maps both Android and iOS to `CupertinoPageTransitionsBuilder`; expected is Material transitions on Android and Cupertino on iOS.
  - Effort: 2-4 hours.

### LOW
- **Spacing scale exceptions are still used in live UI**
  - File:line: `lib/theme/app_dimensions.dart:32-37`, `lib/theme/app_dimensions.dart:62-71`, `lib/views/veckomeny_view.dart:301`
  - User impact: Minor rhythm inconsistency.
  - Current vs expected: Current system keeps extra values (6, 10, 14) and uses ad-hoc 10/6 paddings; expected is tighter use of the primary spacing scale.
  - Effort: 2-3 hours.

Quick wins:
- Replace highest-visibility inline text styles in error/loading/menu headers first.
- Restore Material transitions on Android while retaining Cupertino on iOS.
- Normalize a few recurring off-scale paddings in navigation toggles.

## 2) Accessibility (WCAG 2.1 AA) (10/18)
The codebase has broad accessibility scaffolding: many `Semantics` wrappers and focus grouping (`lib/views/mina_recept_view.dart:460`, `lib/widgets/common/navigation/adaptive_navigation.dart:104-119`). Reduced-motion handling is implemented at utility level (`lib/core/utils/reduced_motion.dart:29-57`, `lib/core/utils/animation_utils.dart:16-24`). Two blockers remain: aggressive text-scale clamping and undersized tap targets.

### HIGH
- **Text scaling is clamped to 1.3x in key UI surfaces**
  - File:line: `lib/core/utils/accessibility_utils.dart:12-18`, `lib/widgets/common/navigation/adaptive_navigation.dart:450-454`, `lib/widgets/common/badges/unified_badge.dart:202-207`
  - User impact: Users needing 200% text scaling can get reduced readability and potential WCAG 1.4.4 failures.
  - Current vs expected: Current max scale factor is `1.3`; expected behavior is to support large accessibility text scaling without global cap on primary navigation/content labels.
  - Effort: 1-2 days (requires targeted overflow hardening).

- **Multiple interactive targets risk dropping below 48x48dp**
  - File:line: `lib/widgets/common/buttons/adaptive_button.dart:27`, `lib/widgets/common/buttons/adaptive_button.dart:54`, `lib/widgets/common/search_filter/personal_tag_filter_chips.dart:75-81`, `lib/widgets/common/badges/unified_badge.dart:173-183`, `lib/widgets/common/badges/unified_badge.dart:216-223`
  - User impact: Harder tapping for motor-impaired users; potential WCAG 2.5.5/2.1 AA usability failures.
  - Current vs expected: Current defaults include `44.0` min size and compact densities/small hit regions; expected is at least 48dp touch targets consistently.
  - Effort: 1 day.

### MEDIUM
- **Known personal-tag semantics labels are not represented as stable identifiers**
  - File:line: `docs/analysis/prompts/06_USER_EXPERIENCE_AND_PLATFORM.md:71`, `lib/views/recipe_detail/handlers/recipe_personal_tag_handler.dart:421-427`, `lib/widgets/common/search_filter/personal_tag_filter_chips.dart:172-177`, `lib/widgets/common/search_filter/personal_tag_filter_chips.dart:220-225`
  - User impact: Harder automation/screen-reader regression validation for the exact label hooks expected by the prompt.
  - Current vs expected: Current controls have semantic labels but not the expected stable label identifiers listed in prompt context.
  - Effort: 3-5 hours.

Quick wins:
- Remove/raise the 1.3 clamp on nav/badges and patch overflow locally.
- Raise adaptive min touch target to 48 and remove compact density on icon-only controls.
- Add stable semantic identifiers for the three known personal-tag surfaces.

## 3) User Flows & Navigation (9/12)
Primary flows are present and mostly efficient. Recipe creation is fast via quick capture (`lib/views/lagg_till_recept_view.dart:61-114`, `lib/views/quick_capture_view.dart:75-95`, `lib/views/quick_capture_view.dart:131-148`), and recipe search/navigation is direct (`lib/views/mina_recept_view.dart:473-476`, `lib/views/mina_recept_view.dart:650-657`). Error/loading/empty states are well represented (`lib/views/mina_recept_view.dart:896-928`, `lib/widgets/menu/menu_content_widgets.dart:135-167`, `lib/widgets/menu/menu_content_widgets.dart:375-419`).

### HIGH
- **Menu clear action is destructive without confirmation/undo**
  - File:line: `lib/views/veckomeny_view.dart:245-250`, `lib/views/veckomeny_view.dart:177-180`
  - User impact: Accidental data loss in a high-value planning flow.
  - Current vs expected: Current clear action immediately clears menu; expected is confirmation and/or undo parity with other destructive flows.
  - Effort: 2-4 hours.

### MEDIUM
- **“Minimal recipe” rules are inconsistent across creation paths**
  - File:line: `lib/views/quick_capture_view.dart:217-224`, `lib/viewmodels/recipe_form/recipe_form_state.dart:233-242`, `lib/viewmodels/recipe_form/recipe_form_state.dart:260-263`
  - User impact: Confusing validation expectations between quick capture and full/manual edit flows.
  - Current vs expected: Quick capture permits empty ingredients/instructions; manual/edit requires both non-empty.
  - Effort: 4-8 hours (policy + UX copy alignment).

### LOW
- **Onboarding is a long 5-page mandatory sequence for first completion**
  - File:line: `lib/views/onboarding/onboarding_view.dart:58`, `lib/views/onboarding/onboarding_view.dart:96-105`, `lib/main.dart:1133-1153`
  - User impact: Potential drop-off on first-run progression.
  - Current vs expected: Current flow enforces multi-step progression before home; expected is minimal-friction completion while preserving compliance.
  - Effort: 1-2 days.

Quick wins:
- Add confirmation to “clear menu” mirroring existing overwrite confirm patterns.
- Align quick-capture and full-form “minimum viable recipe” definition.
- Evaluate collapsing onboarding steps or progressive completion.

## 4) Internationalization & Localization (11/18)
Localization infrastructure is robust and active (`pubspec.yaml:13-15`, `pubspec.yaml:141`, `l10n.yaml:1-5`, `lib/main.dart:895-903`). Locale files are large and parity is high, but hardcoded strings and date/time formatting drift remain visible in user-facing surfaces.

### HIGH
- **User-facing hardcoded strings still exist in critical UI**
  - File:line inventory:
    - `lib/main.dart:369`, `lib/main.dart:388`, `lib/main.dart:411`, `lib/main.dart:843`
    - `lib/core/router/app_router.dart:435`, `lib/core/router/app_router.dart:445`, `lib/core/router/app_router.dart:453`
    - `lib/views/mina_recept_view.dart:440`, `lib/views/veckomeny_view.dart:191`
    - `lib/views/importera_fran_arkiv_view.dart:229`, `lib/views/importera_fran_arkiv_view.dart:243`, `lib/views/importera_fran_arkiv_view.dart:257`
    - `lib/widgets/common/social_components/invitation_lists.dart:119`, `lib/widgets/common/social_components/invitation_lists.dart:149`
  - User impact: Localization gaps and inconsistent language when locale changes.
  - Current vs expected: Current UI contains literal Swedish/English strings in runtime widgets/routes; expected is AppLocalizations-backed strings for user-visible copy.
  - Effort: 1 day.

### MEDIUM
- **Duplicate top-level ARB keys create ambiguous source-of-truth values**
  - File:line: `lib/l10n/app_sv.arb:649`, `lib/l10n/app_sv.arb:8393`, `lib/l10n/app_sv.arb:1633`, `lib/l10n/app_sv.arb:4629`, `lib/l10n/app_en.arb:649`, `lib/l10n/app_en.arb:8393`, `lib/l10n/app_en.arb:1633`, `lib/l10n/app_en.arb:4629`
  - User impact: Translation drift risk and tooling ambiguity.
  - Current vs expected: Current files duplicate `recipePrint` and `authLogIn`; expected is one canonical key per message.
  - Effort: 2-3 hours.

- **Date/time formatting is partly hardcoded and not locale-aware**
  - File:line: `lib/views/recipe_detail/recipe_detail_actions.dart:170-179`, `lib/widgets/messaging/components/message_status_widget.dart:82-92`, `lib/widgets/recipe/comment_item_widgets.dart:152-162`, `lib/views/settings/mfa_settings_view.dart:454-458`, `lib/views/settings/notification_preferences_view.dart:508-511`, `lib/services/share_service.dart:341-343`
  - User impact: Inconsistent temporal formatting across locales and contexts.
  - Current vs expected: Current code mixes manual `day/month`, `Xm/Xh`, forced `sv` date names, and manual ISO-like strings; expected is centralized locale-aware formatting.
  - Effort: 1-2 days.

Quick wins:
- Externalize the hardcoded strings listed above.
- Remove duplicated ARB keys and keep one canonical message each.
- Route all relative/date formatting through shared locale-aware formatters.

## 5) Platform Compliance (11/15)
Adaptive component infrastructure is good: platform-aware dialogs, date pickers, switches, and buttons exist (`lib/core/dialogs/dialog_factory.dart:17-24`, `lib/widgets/common/input/adaptive_date_picker.dart:31-33`, `lib/widgets/common/input/adaptive_switch.dart:40-41`, `lib/widgets/common/buttons/adaptive_button.dart:92-100`). Material 3 is enabled (`lib/theme/app_theme.dart:42`) and iOS system font fallback exists (`lib/theme/app_text_styles.dart:27-35`). Main HIG gap is navigation chrome parity on iOS.

### MEDIUM
- **iOS navigation uses Material AppBar broadly (no CupertinoNavigationBar usage)**
  - File:line examples: `lib/views/quick_capture_view.dart:53`, `lib/views/personal_tags_view.dart:151`, `lib/views/ingredient_search/ingredient_search_view.dart:59`
  - User impact: iOS shell feels less native in many screens.
  - Current vs expected: Current app bars are mostly Material `AppBar`; expected is stronger Cupertino nav treatment on iOS for high-frequency flows.
  - Effort: 2-4 days.

- **Platform motion parity is skewed by Cupertino transitions on Android**
  - File:line: `lib/theme/app_theme.dart:87-91`
  - User impact: Android motion language feels iOS-like instead of Material.
  - Current vs expected: Current route transitions use Cupertino on both platforms; expected is per-platform transition fidelity.
  - Effort: 2-4 hours.

### LOW
- **Android dynamic color (Material You) is not wired**
  - File:line: `lib/theme/app_theme.dart:43`, `lib/theme/app_colors.dart:189-228`
  - User impact: Less native personalization on Android 12+.
  - Current vs expected: Current theme uses static app-defined schemes; expected is optional dynamic color adaptation with fallback.
  - Effort: 1-2 days.

Quick wins:
- Start with Cupertino navigation parity on a small set of top iOS routes.
- Restore per-platform route transitions.
- Add optional Material You support behind a feature flag.

## 6) App Store Readiness (8/12)
Store prep artifacts and runbooks exist and are structured (`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:1-27`, `store_assets/README.md:26-33`). Bundle/package IDs are production-like (`android/app/build.gradle.kts:34`, `ios/Runner.xcodeproj/project.pbxproj:377`), and iOS privacy manifest exists (`ios/Runner/PrivacyInfo.xcprivacy:13-17`, `ios/Runner/PrivacyInfo.xcprivacy:99-234`). Release readiness is still blocked by one compile error and metadata/submission gaps.

### CRITICAL
- **Current build has an undefined symbol in notifications consent path**
  - File:line: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`, `lib/services/notifications/notification_service.dart:649`
  - User impact: Shipping risk; can block release pipelines and store submission readiness.
  - Current vs expected: `flutter analyze` reports undefined `ConsentPurpose`; expected is clean analysis for release branch.
  - Effort: 0.5 day.

### HIGH
- **Swedish iOS subtitle exceeds Apple 30-char limit**
  - File:line: `store_assets/README.md:29`, `store_assets/metadata/sv-SE/subtitle.txt:1`
  - User impact: App Store metadata validation failure risk.
  - Current vs expected: Subtitle text exceeds documented iOS subtitle limit; expected is <=30 chars.
  - Effort: 15-30 minutes.

- **Store image assets are not prepared yet (screenshots/feature graphic)**
  - File:line: `store_assets/README.md:19-21`, `store_assets/screenshots/README.md:1-21`
  - User impact: Submission blocking for both stores once filing starts.
  - Current vs expected: Repo contains screenshot guidelines but no prepared screenshot asset set.
  - Effort: 1-2 days.

- **Console-side filings are still pending manual action**
  - File:line: `docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:21-26`, `docs/store-submission/play-data-safety/README.md:3-6`
  - User impact: Store review cannot proceed until owner-side console filings are completed.
  - Current vs expected: Data Safety/App Privacy/age rating/COPPA/reviewer notes marked pending.
  - Effort: 0.5-1 day owner time.

Quick wins:
- Fix the analyze blocker first.
- Shorten sv-SE subtitle to compliant length.
- Capture/store screenshots and create feature graphic before first filing window.

## 7) Responsive Design & Adaptability (10/10)
Responsive implementation is strong and widespread. The project uses breakpoint utilities and consistent `Center + ConstrainedBox` composition across major views (`lib/core/responsive/breakpoints.dart:49-63`, `lib/views/quick_capture_view.dart:57-65`, `lib/views/veckomeny_view.dart:319-327`, `lib/views/unified_shopping_view.dart:154-162`, `lib/views/recipe_detail_view.dart:580-588`). Safe-area handling is also broadly present (`lib/main.dart:919-923`).

### MEDIUM
- **Minor responsive polish gaps from local hardcoded micro-spacing**
  - File:line: `lib/views/veckomeny_view.dart:301`, `lib/widgets/menu/calendar_weekly_menu_widget.dart:340`, `lib/views/lagg_till_recept_view.dart:93`
  - User impact: Small visual inconsistencies across breakpoints.
  - Current vs expected: Most layout is tokenized/responsive, but isolated literal spacing still appears.
  - Effort: 2-4 hours.

### LOW
- **No explicit foldable/hinge-aware layout adaptation found**
  - File:line: `lib/core/responsive/breakpoints.dart:106-123`, `lib/views/veckomeny_view.dart:319-327`
  - User impact: Possible suboptimal UX on dual-screen/foldable devices.
  - Current vs expected: Breakpoint-based adaptation exists, but no explicit foldable display-feature handling.
  - Effort: 1-2 days.

Quick wins:
- Sweep remaining hardcoded micro-spacing in top-priority views.
- Add foldable-specific layout handling only if target-device analytics justify it.

## Accessibility Audit (WCAG 2.1 AA Checklist)
| Criterion | Status | Evidence |
|---|---|---|
| 2.1 Color contrast | PASS | Contrast targets documented in theme tokens and focus guidance (`lib/theme/app_colors.dart:60-69`, `lib/theme/app_theme.dart:79-84`). |
| 2.2 Screen reader support | FAIL | Broad semantics usage exists, but known personal-tag label hooks are not represented as expected stable identifiers (`docs/analysis/prompts/06_USER_EXPERIENCE_AND_PLATFORM.md:71`, `lib/widgets/common/search_filter/personal_tag_filter_chips.dart:172-177`). |
| 2.3 Touch targets | FAIL | 44dp adaptive button defaults and compact/icon-only controls risk undersized hit areas (`lib/widgets/common/buttons/adaptive_button.dart:27`, `lib/widgets/common/search_filter/personal_tag_filter_chips.dart:75-81`). |
| 2.4 Focus management | PASS | Global keyboard shortcuts + focus root + focus traversal groups are present (`lib/main.dart:913-919`, `lib/views/mina_recept_view.dart:460`). |
| 2.5 Text scaling | FAIL | Global clamp to 1.3x on nav/badge surfaces (`lib/core/utils/accessibility_utils.dart:12-18`, `lib/widgets/common/navigation/adaptive_navigation.dart:450-454`). |
| 2.6 Motion | PASS | Reduced-motion utilities and runtime checks are implemented (`lib/core/utils/reduced_motion.dart:29-57`, `lib/core/utils/animation_utils.dart:16-24`). |
| 2.7 Semantic structure | PASS | Header semantics are present in multiple UI sections (`lib/widgets/menu/menu_content_widgets.dart:220`, `lib/views/recipe_detail/recipe_detail_content.dart:110`). |

## I18n Readiness
- **Total hardcoded user-facing strings (audited):** 14 high-confidence runtime instances listed in section 4 (`lib/main.dart:369`, `lib/core/router/app_router.dart:435`, `lib/views/veckomeny_view.dart:191`, `lib/widgets/common/social_components/invitation_lists.dart:119`, etc.).
- **% externalized (approx):** 99.6% using 3,798 unique locale keys vs 14 audited hardcoded UI strings (`lib/l10n/app_sv.arb:1`, `lib/l10n/app_en.arb:1`).
- **ARB coverage per locale:** 3,798 unique non-metadata keys in both sv/en; key parity is effectively 100% with 0 missing keys between locales (`lib/l10n/app_sv.arb:1`, `lib/l10n/app_en.arb:1`), but duplicate top-level keys exist (`lib/l10n/app_sv.arb:649`, `lib/l10n/app_sv.arb:8393`).
- **RTL readiness (pattern audit):** 100% for audited directional-pattern checks; code favors directional APIs in sampled UI (`lib/views/mina_recept_view.dart:745`, `lib/views/mina_recept_view.dart:755`, `lib/views/skriv_sjalv_recept_view.dart:331`).
- **Formatting compliance (locale-aware):** ~25% in audited formatter helpers (2 locale-aware vs 6 manual/mixed) based on `lib/core/utils/time_ago_formatter.dart:11-21`, `lib/viewmodels/shared_content/shared_shopping_viewmodel.dart:337-348` vs manual formatters in `lib/views/recipe_detail/recipe_detail_actions.dart:170-179`, `lib/widgets/messaging/components/message_status_widget.dart:82-92`, `lib/views/settings/mfa_settings_view.dart:454-458`, `lib/views/settings/notification_preferences_view.dart:508-511`, `lib/services/share_service.dart:341-343`.

## Platform Compliance Matrix
| Feature | iOS HIG requirement | Material requirement | Current state |
|---|---|---|---|
| Navigation chrome | Prefer Cupertino-style nav | Material AppBar/TopAppBar | Mostly Material `AppBar` even on iOS (`lib/views/quick_capture_view.dart:53`, `lib/views/personal_tags_view.dart:151`). |
| Dialogs | Native alert behavior | Material dialogs | Adaptive dialog factory implemented (`lib/core/dialogs/dialog_factory.dart:23`, `lib/core/dialogs/dialog_factory.dart:39-43`). |
| Inputs (switch/date/buttons) | Cupertino variants | Material variants | Adaptive components implemented (`lib/widgets/common/input/adaptive_switch.dart:40-41`, `lib/widgets/common/input/adaptive_date_picker.dart:31-33`, `lib/widgets/common/buttons/adaptive_button.dart:92-100`). |
| Typography | System font acceptable | Themed text system | iOS uses system font fallback while Android/web use custom families (`lib/theme/app_text_styles.dart:27-35`, `pubspec.yaml:155-171`). |
| Navigation transitions | iOS-style transitions on iOS | Material transitions on Android | Both Android and iOS forced to Cupertino transitions (`lib/theme/app_theme.dart:87-91`). |
| Safe areas | Respect notch/home indicator | Respect system insets | Broad SafeArea adoption (`lib/main.dart:919-923`, `lib/views/quick_capture_view.dart:56`). |
| Notifications | iOS permission flow | Android channels required | Android channel initialization present (`lib/services/notifications/fcm_service.dart:230-271`); iOS permissions requested in same service (`lib/services/notifications/fcm_service.dart:290-303`). |
| Web/desktop keyboard access | N/A | Keyboard accessible interactions | Global shortcut map wired (`lib/core/keyboard/app_shortcuts.dart:3-15`, `lib/main.dart:913-919`). |

## App Store Checklist
| Requirement | Google Play status | Apple App Store status |
|---|---|---|
| Unique package/bundle ID | PASS (`android/app/build.gradle.kts:34`) | PASS (`ios/Runner.xcodeproj/project.pbxproj:377`) |
| Metadata files present | PASS (`store_assets/metadata/en-US/title.txt:1`) | PASS (`store_assets/metadata/sv-SE/title.txt:1`) |
| Metadata length compliance | PASS in sampled Android fields (`store_assets/README.md:30`) | FAIL: sv subtitle exceeds 30-char limit (`store_assets/README.md:29`, `store_assets/metadata/sv-SE/subtitle.txt:1`) |
| Screenshots prepared | FAIL (`store_assets/screenshots/README.md:1-21`) | FAIL (`store_assets/screenshots/README.md:1-13`) |
| Feature graphic prepared | FAIL (no repo asset under store assets; only guidance files `store_assets/README.md:19-21`) | N/A |
| Privacy policy accessible in-app | PASS (`lib/views/legal/privacy_policy_view.dart:45-55`, `lib/views/legal/privacy_policy_view.dart:83`) | PASS (`lib/views/legal/privacy_policy_view.dart:45-55`, `lib/views/legal/privacy_policy_view.dart:83`) |
| Privacy manifest | N/A | PASS (`ios/Runner/PrivacyInfo.xcprivacy:13-17`, `ios/Runner/PrivacyInfo.xcprivacy:99-234`) |
| Data safety / privacy console filing | FAIL (pending user action) (`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:21`) | FAIL (pending user action) (`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:22`) |
| Age rating questionnaire | FAIL (pending user action) (`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:24`) | FAIL (pending user action) (`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:23`) |
| Reviewer notes/demo account | FAIL (pending user action) (`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:26`) | FAIL (pending user action) (`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:26`) |
| Build static analysis clean | FAIL (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`) | FAIL (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`) |

## Responsive Design Assessment
| View | Responsive yes/no | Pattern used | Issues |
|---|---|---|---|
| `MinaReceptView` | Yes | `Center + ConstrainedBox`, responsive grid/list (`lib/views/mina_recept_view.dart:796`, `lib/views/mina_recept_view.dart:950-963`) | Minor local spacing drift only. |
| `VeckomenyView` | Yes | `Center + ConstrainedBox`, breakpoint width tiers (`lib/views/veckomeny_view.dart:319-327`) | Local magic padding in mode toggle (`lib/views/veckomeny_view.dart:301`). |
| `UnifiedShoppingView` | Yes | `Center + ConstrainedBox` with breakpoint widths (`lib/views/unified_shopping_view.dart:154-162`) | No major issues found. |
| `RecipeDetailView` | Yes | Mobile/tablet split + constrained content (`lib/views/recipe_detail_view.dart:550-556`, `lib/views/recipe_detail_view.dart:580-588`) | No major issues found. |
| `QuickCaptureView` | Yes | `Center + ConstrainedBox` (`lib/views/quick_capture_view.dart:57-65`) | No major issues found. |
| `SkrivSjalvReceptView` | Yes | Constrained body and save overlay (`lib/views/skriv_sjalv_recept_view.dart:610-617`) | Minor hardcoded micro-spacing remains (`lib/views/skriv_sjalv_recept_view.dart:691`). |
| `EditRecipeView` | Yes | `Center + ConstrainedBox` (`lib/views/edit_recipe_view.dart:145-153`) | No major issues found. |
| `PersonalTagsView` | Yes | `Center + ConstrainedBox` (`lib/views/personal_tags_view.dart:254-262`) | No major issues found. |
| `ConsentManagementView` | Yes | `Center + ConstrainedBox` (`lib/views/account/consent_management_view.dart:37-45`) | No major issues found. |
| `OnboardingView` | Yes | Centered constrained wizard container (`lib/views/onboarding/onboarding_view.dart:87-90`) | Fixed max width 700 is acceptable but not foldable-specific. |

## Improvement Roadmap
### Sprint 1 (submission blockers, WCAG critical failures, broken flows)
- Fix notification consent compile blocker (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`, `lib/services/notifications/notification_service.dart:649`).
- Remove/raise 1.3 text-scaling clamp in nav/badge paths and patch resulting overflows (`lib/core/utils/accessibility_utils.dart:12-18`, `lib/widgets/common/navigation/adaptive_navigation.dart:450-454`).
- Enforce 48dp minimum touch targets in adaptive/compact icon controls (`lib/widgets/common/buttons/adaptive_button.dart:27`, `lib/widgets/common/search_filter/personal_tag_filter_chips.dart:75-81`).
- Add clear-menu confirmation/undo path (`lib/views/veckomeny_view.dart:245-250`).
- Fix sv-SE subtitle length (`store_assets/README.md:29`, `store_assets/metadata/sv-SE/subtitle.txt:1`).

### Sprint 2 (accessibility gaps, i18n infrastructure, platform compliance)
- Externalize remaining hardcoded user-facing strings (section 4 inventory).
- Resolve duplicated ARB top-level keys and re-validate locale generation (`lib/l10n/app_sv.arb:649`, `lib/l10n/app_sv.arb:8393`).
- Standardize date/time formatting through shared locale-aware formatter utilities (`lib/core/utils/time_ago_formatter.dart:11-21`).
- Improve iOS navigation parity on top routes while keeping adaptive controls (`lib/views/quick_capture_view.dart:53`, `lib/views/personal_tags_view.dart:151`).

### Sprint 3 (design consistency, responsive remaining views, polish)
- Replace remaining inline text styles with theme/text tokens (`lib/main.dart:388-390`, `lib/widgets/menu/menu_content_widgets.dart:292-299`).
- Normalize micro-spacing literals in high-traffic screens (`lib/views/veckomeny_view.dart:301`).
- Align Android transitions with Material while preserving iOS-native motion (`lib/theme/app_theme.dart:87-91`).

### Backlog (nice-to-have improvements, advanced platform features)
- Add foldable/hinge-aware responsive behavior if device analytics justify it (`lib/core/responsive/breakpoints.dart:106-123`).
- Expand web hover/context affordances beyond isolated widgets (`lib/widgets/common/emoji_reaction_picker.dart:89-91`).
- Add optional Android dynamic color support (`lib/theme/app_colors.dart:189-228`).

## Deferred to Prompt 03 (Infrastructure & Testing)
- The known `flutter test --coverage` hang in `test/views/helpers/infrastructure_integration_test.dart` is acknowledged as a testing-infrastructure finding and intentionally not scored in this UX prompt scope (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31512`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525-31529`).
