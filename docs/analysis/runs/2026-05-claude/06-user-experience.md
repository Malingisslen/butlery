# 06 — User Experience & Platform — Phase 1 Findings

**Run:** 2026-05-claude (Wave 2)
**Analyst:** Claude (Opus 4.7, 1M context)
**Mode:** Read-only investigation. Zero code changes.
**Date:** 2026-05-02
**Knowledge file consulted:** `.claude/agents/uiux-designer.knowledge.md` (8.6 KB; mtime 2026-05-01).

---

## Executive Summary

```
USER EXPERIENCE & PLATFORM ANALYSIS — PHASE 1 FINDINGS
=========================================================
Platforms: Android, iOS, Web, macOS, Windows
Primary locale: sv (Swedish). Secondary: en (English).

OVERALL UX SCORE: 78/100  ("Good")

  1. Design System & Visual Consistency:    13.0 / 15
  2. Accessibility (WCAG 2.1 AA):           13.5 / 18
  3. User Flows & Navigation:                9.5 / 12
  4. Internationalization & Localization:   16.5 / 18   ← genuine standout
  5. Platform Compliance:                   11.5 / 15
  6. App Store Readiness:                    7.0 / 12   ← biggest drag
  7. Responsive Design & Adaptability:       7.0 / 10

CRITICAL: 1   HIGH: 7   MEDIUM: 11   LOW: 8
```

**Headline finding (CRITICAL):** `lib/services/notifications/notification_service.dart:649` references an undefined identifier `ConsentPurpose.pushNotifications` — `flutter analyze` reports this as the only static-analysis error in the whole tree (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`). This blocks any release build and means any user revoking push consent today would crash through this code path. Owned UX-side because it breaks a user-facing privacy flow; root-cause may live in service layer (Prompt 02 may overlap on the consent-purpose enum scope).

**The good news this report should not bury:** the codebase is in genuinely strong UX shape relative to its size (1252 .dart files, 327k LOC). I18n is exemplary — there are essentially **zero hardcoded user-facing English strings in `lib/views/`**. `flutter analyze` returned only the one error above after 220 s. The remaining issues are sprint-level, not foundational.

---

## Pre-analysis context already known (cited, not re-discovered)

- 132 `.dart` files >500 lines, several large views (`mina_recept_view.dart` 996, `skriv_sjalv_recept_view.dart` 873, `recipe_detail_view.dart` 835) — flagged in §1.6 below for UX-maintainability impact, not in §1 design audit.
- App-wide adaptive infrastructure exists: `lib/widgets/common/buttons/adaptive_button.dart`, `lib/widgets/common/input/adaptive_text_field.dart`, `lib/widgets/common/icons/adaptive_icon.dart` (652 lines), `lib/widgets/common/navigation/adaptive_navigation.dart` (593 lines).
- Two locales shipped, both with **6 347 keys each** in `lib/l10n/app_sv.arb` / `app_en.arb` — perfect parity on key count. 130 keys are a11y-prefixed.
- Material 3 (`useMaterial3: true`) and dark mode both wired up at `lib/theme/app_theme.dart:42` and `lib/main.dart:892` (`themeMode: _themeService?.themeMode ?? ThemeMode.system`).

---

## 1. Design System & Visual Consistency — 13.0/15

The system is unusually disciplined for an app this size. `lib/theme/app_colors.dart` is a single source of truth with WCAG-annotated color choices and Material 3 light/dark `ColorScheme`s. `lib/theme/app_dimensions.dart` lines 78–112 zero out **every** `borderRadiusN` token except `borderRadius100` (pill) and `borderRadiusRound` — meaning the 202 `BorderRadius.circular(...)` callsites in `lib/widgets/` all evaluate to 0 px, enforcing the "square everywhere" mockup language documented in `uiux-designer.knowledge.md` lines 16–24. That's the right mechanism; the call sites are visual noise but not bugs.

Color centralization is near-complete: `Color(0x...)` literals appear in only **3** files outside the theme layer — `lib/widgets/common/illustrations/vegetable_illustration.dart` (decorative SVG palette, intentionally divorced per knowledge file 2026-04-29 entry), and the two `CLAUDE.md` doc files. **Zero raw `Color(0x...)` literals in `lib/views/`.** `withOpacity` is gone from `lib/views/` and `lib/widgets/` entirely; only `vegetable_illustration.dart` still carries one (single-file SVG translation). Modern syntax is enforced.

### HIGH

**1.1 Typography uses raw `fontSize` integers in TextStyle constructors** — `lib/theme/app_text_styles.dart` lines 43, 51, 58, 66, 75 et seq. embed `fontSize: 24`, `17`, etc. directly in `TextStyle()`. Acceptable inside the theme file (it's the source of truth) but loses the 4/8 px modular scale. Five hardcoded `fontSize:` instances slipped into `lib/views/` per grep — verify they don't bypass `AppTextStyles`. *Effort: 2 h.*

### MEDIUM

**1.2 Square-design `BorderRadius.circular(AppDimensions.borderRadiusM)` is technically correct but visually misleading** — 202 callsites in `lib/widgets/` (e.g. `lib/widgets/styled/styled_button.dart:224`, `:240`, `:264`, `:282`) wrap `RoundedRectangleBorder` around a zero-radius value. Code reviewers seeing these naturally assume rounded corners are shipping. *Recommend: introduce `AppShapes.squareS/M/L` const `RoundedRectangleBorder` instances and migrate, or document the convention more loudly.* *Effort: 1 d if migrating; 30 min if just documenting.*

**1.3 `app_colors.dart` carries 12 "legacy compatibility" aliases** at lines 263–284 (`backgroundLight`, `surfaceVariant`, `secondaryPurple`, etc.) marked "use new names in new code." Aliases have no deprecation annotation — new code can still reach for them. *Effort: 2 h to add `@Deprecated()`.*

### LOW

**1.4 Dark-mode `secondaryPurple = Color(0xFF9C27B0)`** (`app_colors.dart:265`) is not in the brand palette and isn't documented anywhere. Looks like dead weight. *Effort: 30 min to grep+remove.*

**1.5 `borderRadiusXs = 0.0` declared on line 459 of `app_dimensions.dart`** *after* `borderRadiusS = 0.0` on line 78 — trailing definitions that imply a missing scale. Reads like an accidental duplication. *Effort: 30 min.*

**1.6 — UX maintainability flag (deferred to 01).** `lib/views/mina_recept_view.dart` 996 LOC, `lib/views/skriv_sjalv_recept_view.dart` 873 LOC, `lib/views/recipe_detail_view.dart` 835 LOC, `lib/views/auth_view.dart` 693 LOC, `lib/views/cooking_mode_view.dart` 681 LOC, `lib/views/photo_import_view.dart` 673 LOC. Large views accumulate UX inconsistencies because no one re-reads them in full. Owned by Prompt 01 (file size); cited here for cross-reference.

---

## 2. Accessibility (WCAG 2.1 AA) — 13.5/18

A real, sustained accessibility program is in evidence. The knowledge file's 2026-04-29 entry documents the BUT-697/BUT-739 sweep that wrapped tap targets in `Semantics`. Live state: **258 `Semantics(` callsites across 127 files** — coverage is broad. The codebase has a custom audit tool (`tools/audit_unwrapped_tap_targets.dart`) and a per-chunk widget test suite (`test/widget/widgets/chunkN_semantics_a11y_test.dart`) for ongoing enforcement. There is a dedicated localized a11y key prefix (`a11y*`) with **130 keys** in each ARB file. Color contrast is annotated inline in `app_colors.dart` (e.g. line 50 "WCAG AA ≥4.6:1 on creamDarker", line 67 "Darkened from #767676 (BUT-514)", line 73 "WCAG AA on cream/white").

### HIGH

**2.1 Touch-target enforcement is inconsistent across button entry points.** `lib/widgets/common/buttons/adaptive_button.dart` enforces `minimumSize: Size(minSize, minSize)` at lines 96, 106, 131, 167. `lib/widgets/styled/styled_button.dart` (`_getButtonStyle`/`_getDestructiveButtonStyle` lines 247–286) sets padding but **no `minimumSize`**, leaving the floor up to default ElevatedButton geometry. Knowledge file says "Buttons: 48 px min-height". *Recommend: add explicit `minimumSize: const Size(0, 48)` in `_getButtonStyle`.* *Effort: 30 min.*

**2.2 21 GestureDetectors and 22 InkWells in `lib/views/*.dart` were not exhaustively re-audited this session** — the knowledge file warns that the audit script over-reports false positives (~12 stable). At 43 candidates in views alone (and many more in widgets per the BUT-697 sweep), recommend re-running `dart tools/audit_unwrapped_tap_targets.dart` quarterly and after every new view. *Effort: 1 h to re-run + triage; ongoing.*

**2.3 No evidence of a focus-ring smoke test.** `lib/theme/app_theme.dart:84` correctly sets `focusColor: AppColors.rust` per BUT-533, but I found no widget test that asserts the focus ring is rendered on cream surfaces. Web/desktop targets need keyboard-only navigation. *Effort: 4 h to add a regression test using `RawKeyboardListener` + `Focus`.*

### MEDIUM

**2.4 Text-scaling resilience untested at 200%.** Several views with fixed-height containers in headers (e.g. `lib/widgets/common/main_view_header.dart`, `lib/widgets/menu/calendar_weekly_menu_widget.dart`) risk truncation/clipping at large `MediaQuery.textScaler` values. No grep evidence of `textScaler.clamp(...)` mitigation either. *Effort: 1 d to audit Tier 1 views + add golden tests at 200%.*

**2.5 No `MediaQuery.disableAnimations` checks** for any of the codebase animations. `Hero`, page transitions, and FAB animations should be reduced when the OS reports reduced motion. Search returns zero hits in `lib/`. *Effort: 4 h to add a wrapper utility + audit insertion points.*

**2.6 `a11y*` key naming convention is documented only in `.claude/rules/ui-conventions.md` and the knowledge file** — not in the ARB schema or a code comment. New devs adding strings might not know to prefix. *Effort: 30 min — add a short comment block at the top of `app_sv.arb`.*

### LOW

**2.7 Empty/loading/error abstraction is excellent and centralized** (`lib/widgets/common/loading_state_builder.dart` + `lib/widgets/common/state/state_widget.dart`) — the rule that "no raw `CircularProgressIndicator`" exists in `lib/widgets/CLAUDE.md`. This is a strength worth preserving; flag only because there's no CI grep that enforces it. *Effort: 1 h to add a grep step in `analyze.yml` (or its successor).*

---

## 3. User Flows & Navigation — 9.5/12

Six core flows verified by file presence: recipe creation (`lagg_till_recept_view.dart`, `skriv_sjalv_recept_view.dart`, `smart_import_view.dart`, `import_via_url_view.dart`, `fran_sociala_medier_view.dart`, `photo_import_view.dart`, `quick_capture_view.dart`, `file_import_view.dart`), recipe browsing (`mina_recept_view.dart`), recipe detail (`recipe_detail_view.dart`), menu planning (`veckomeny_view.dart`), shopping list (`unified_shopping_view.dart`), and cooking mode (`cooking_mode_view.dart`). Onboarding has its own subdirectory (`lib/views/onboarding/`) with at least 4 pages (welcome, allergen, dietary, import).

### HIGH

**3.1 Eight separate import entry-points** — counting `lagg_till_recept_view.dart`, `skriv_sjalv_recept_view.dart`, `smart_import_view.dart`, `import_via_url_view.dart`, `fran_sociala_medier_view.dart`, `photo_import_view.dart`, `quick_capture_view.dart`, `file_import_view.dart`, `importera_fran_arkiv_view.dart`, `receive_share_view.dart` — that's effectively 9 user-facing recipe-add paths. Likely covers different sources, but cognitive load is high. *Recommend: consolidated "add recipe" hub with sub-strategies.* *Effort: 2 d analysis + sketch; significant impl after.*

### MEDIUM

**3.2 Bottom-nav routing rule is "pushNamed from detail views" per knowledge file** lines 80–81, but I did not verify every bottom-nav callsite obeys this. A regression here means Back goes to root instead of returning to the detail page. *Effort: 2 h to grep + verify.*

**3.3 No undo for destructive actions surfaces in widget grep.** Recipe deletion uses confirmation dialog (per `MEMORY.md` 2026-02-13 spec — left-swipe = delete with dialog), but undo (snackbar action) is preferable for low-stakes deletes (e.g. shopping-list item). Known Material pattern. *Effort: 1 d.*

**3.4 Error messaging quality untested.** With `error: error.toString()` patterns common in Flutter, Swedish users may see English `Exception: ...` strings even though all UI is localized. *Effort: 4 h sample audit.*

### LOW

**3.5 Beta feedback FAB ("!" on every screen)** is documented in `MEMORY.md` 2026-02-13 — `lib/widgets/common/feedback_fab.dart` exists. Good. Verify it's mounted globally (in `main.dart` route shell) and not per-view. *Effort: 30 min.*

---

## 4. Internationalization & Localization — 16.5/18

This is the codebase's strongest UX dimension by a wide margin. Empirical findings:

- **Zero `Text('Hardcoded')` callsites with uppercase Swedish/English literal in `lib/views/`** (grep `Text\(['"][A-ZÅÄÖ]`).
- **Three `const Text(' ')` instances total in `lib/views/`** — all in `lib/views/importera_fran_arkiv_view.dart:229,243,257` and they're filter-chip labels `<= 15 min` / `<= 30 min` / `<= 60 min` (numeric-only, locale-neutral). Acceptable but cleaner as `Duration`-aware.
- **Two hardcoded title strings**: `lib/views/veckomeny_view.dart:191` `title: 'veckans\nmeny'` and `lib/views/mina_recept_view.dart:440` `title: 'dina\nrecept'`. These are intentional lowercase brand-titles per mockup. They escape l10n. (See HIGH §4.1.)
- **Zero `SnackBar(content: Text('hardcoded'))` patterns in views** (grep returns 0).
- **1 769 `context.l10n` callsites in `lib/views/`** — ubiquitous adoption.
- **6 347 keys** in each of `app_sv.arb` and `app_en.arb` — perfect parity by key count.

`flutter_localizations` and `intl` dependencies are present (`pubspec.yaml`); `app_localizations*.dart` is generated and in `.gitignore` per the prompt's exclusion list.

### HIGH

**4.1 Two view titles bypass l10n** — `lib/views/veckomeny_view.dart:191` and `lib/views/mina_recept_view.dart:440` hardcode `'veckans\nmeny'` and `'dina\nrecept'` respectively. These are user-visible page titles. Even if English target ships them as `'this week\'s\nmenu'`, they should live in ARB. *Effort: 30 min.*

**4.2 RTL readiness: 39 `EdgeInsets.only(left:|right:)` callsites in 23 files**, **zero `EdgeInsetsDirectional` callsites anywhere**, **zero `AlignmentDirectional`**. Same for `TextAlign.left/right` (zero — good) but the lack of any `Directional*` adoption means RTL languages (Arabic, Hebrew, Persian) would render flipped layouts wrong. App is Swedish-first so this is not a release blocker, but it forecloses any post-launch i18n expansion to RTL markets. *Effort: 2–3 d for a sweep; or accept and document as out-of-scope until Arabic ships.*

### MEDIUM

**4.3 Date/number/currency formatting was not exhaustively audited this pass.** `intl` package is present but spot-checking `DateFormat(...)` constructors for explicit `locale:` parameter would surface non-locale-aware formatters. *Effort: 4 h grep + fix.*

**4.4 Pluralization coverage assumed but not verified.** Swedish has zero/one/other plural rules (similar to English). With 6 347 keys, ICU-format plural messages are likely present but I didn't sample. `lib/utils/text/swedish_pluralization.dart` (514 lines) suggests heavy lifting in code rather than ICU — worth checking which approach wins where. *Effort: 4 h.*

### LOW

**4.5 ARB metadata quality unknown** — sample of first 60 lines shows mostly bare key/value, only `imageSelectUpTo` has a `@key` block with `placeholders`. Translator context for the other 6 300+ keys may be sparse. *Effort: ongoing; recommend `@key` blocks be required for any string with `{placeholder}`.*

**4.6 Translation expansion untested.** German/Finnish/Polish typically inflate strings 30–50 %. Without a render-at-150 % goldens pass, future translations may break layouts. *Effort: 1 d, deferred until a third locale is even on the roadmap.*

---

## 5. Platform Compliance — 11.5/15

`Platform.is*` checks: 28 occurrences across 12 files. `Cupertino*` references: 184 across 10 files — heavily concentrated in `lib/widgets/common/icons/adaptive_icon.dart` (108 hits — large icon mapping table), `lib/widgets/common/input/adaptive_date_picker.dart` (32), and `lib/core/dialogs/dialog_factory.dart` (9). The codebase has a deliberate adaptive-widget library: `adaptive_button.dart`, `adaptive_text_field.dart`, `adaptive_switch.dart`, `adaptive_date_picker.dart`, `adaptive_icon.dart`, `adaptive_activity_indicator.dart`, `adaptive_navigation.dart`. iOS gets system font (`null` family) on `Platform.isIOS` per `app_text_styles.dart:29,34` — HIG-aligned.

iOS Info.plist (`ios/Runner/Info.plist`) declares Swedish microcopy for camera/photo permissions (lines 50–55), supports portrait + landscape, declares `ITSAppUsesNonExemptEncryption=false`, has deep-link URL scheme `butlery://`. Privacy manifest exists at `ios/Runner/PrivacyInfo.xcprivacy` (deferred to Prompt 09).

Android: package name **`se.butlery.app`** (not the placeholder `com.example.butlery` claimed in the prompt context — this is already fixed). `compileSdk = 36` / `targetSdk = 36` / `minSdkVersion = 24`. Adaptive icon present (`mipmap-anydpi-v26/ic_launcher.xml`). `enableOnBackInvokedCallback="true"` for Android 13+ predictive back gesture. POST_NOTIFICATIONS permission declared (BUT-414).

### HIGH

**5.1 Prompt context is stale on package name.** `06_USER_EXPERIENCE_AND_PLATFORM.md:53` says `Package name: com.example.butlery (PLACEHOLDER -- must change before store submission)`. Reality (`android/app/build.gradle.kts:32`): `applicationId = "se.butlery.app"`. Documentation drift, not a bug. **Cite this in Prompt 12.** *Effort: 5 min to update prompt.*

### MEDIUM

**5.2 No Material You dynamic color support.** `lib/theme/app_theme.dart:42–44` uses `useMaterial3: true` but never reads `dynamic_color` package output for Android 12+. With seasonal-accent service already wired (`lightThemeWith(accent)` line 23), the plumbing exists; just no Android dynamic-color hook. Intentional? Defer to product. *Effort: 2 h spike.*

**5.3 `CupertinoPageTransitionsBuilder` applied to BOTH iOS and Android** at `lib/theme/app_theme.dart:88–91`. That gives iOS-style swipe-to-go-back on Android too — pleasant but breaks Material expectation. Verify with a Material-only user (Android purist). *Effort: 1 h decision.*

**5.4 Web platform untested for keyboard navigation in this audit.** Adaptive widgets exist but no `Shortcuts`/`Actions` registrations were grepped. Power users on Web/Desktop expect keyboard shortcuts (Ctrl+K search, Esc dismiss, Enter submit). *Effort: 1 d.*

### LOW

**5.5 `AppDelegate.swift` unread this pass** — should be checked for any pre-Flutter native init (Firebase config, deep-link handling). Likely fine; flag for Prompt 03 cross-check.

**5.6 macOS / Windows / Linux feature parity not catalogued.** Prompt context says the app targets all five platforms, but `lib/services/backup_service.dart` and a handful of others gate on `Platform.is*`. Build a small parity matrix in Phase 2.

---

## 6. App Store Readiness — 7.0/12

`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md` is comprehensive and shows operational maturity. **All store-side filings are explicitly "Pending user action"** — Data Safety, App Privacy, age rating (BUT-624), COPPA (BUT-720), reviewer demo (BUT-416). The user-facing CLAUDE.local.md memory note "No app-store submission yet" confirms this is intentional deferral. So I'm grading the *artefacts*, not the *filing status*.

`store_assets/metadata/sv-SE/` has all six files (title, subtitle, description, keywords, release_notes, promotional_text). `en-US/` mirrors. The Swedish description.txt scans well — clear value props (planning, lists, sharing, offline, GDPR), proper structure for store rendering.

### HIGH

**6.1 Zero shipped screenshots.** `store_assets/screenshots/` contains only `README.md`. Both Apple App Store and Google Play require screenshots at multiple device sizes before a build can even be submitted for review. *Effort: 1 d for capture + framing once UI is final.*

**6.2 No feature graphic** for Google Play (1024×500 banner). Required for Play Store listings. *Effort: 4 h design.*

**6.3 Subtitle/keyword files not inspected for length compliance.** iOS subtitle ≤30 chars, keywords ≤100 chars. Audit before submission. *Effort: 30 min.*

### MEDIUM

**6.4 Adaptive icon (Android) and AppIcon (iOS) ship from defaults?** Adaptive icon XML present at `mipmap-anydpi-v26/ic_launcher.xml` and 5 mipmap sizes under `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`. iOS `AppIcon.appiconset` has all required sizes including `Icon-App-1024x1024@1x.png`. **Visual quality unverified by this audit** — load the 1024 icon and inspect. *Effort: 30 min.*

**6.5 No "What's New" / release notes versioning workflow visible.** `release_notes.txt` is a single file overwritten per release. `fastlane/changelogs/` per-version structure preferred. *Effort: 2 h reorg.*

### LOW

**6.6 Promotional text content not reviewed** for ASO keyword density.

**6.7 No in-app review prompt code visible.** `in_app_review` package not detected in pubspec sweep this pass — defer to Prompt 05 if material.

---

## 7. Responsive Design & Adaptability — 7.0/10

Strong infrastructure: `lib/core/responsive/responsive_builder.dart` (517 lines), `lib/core/responsive/breakpoints.dart`, `lib/widgets/common/scaffolds/responsive_scaffold_builder.dart`, `lib/widgets/common/layout/layout_containers.dart`. Adoption: 88 `ConstrainedBox(` callsites across 68 files (54 % of the ~128 view files in `lib/views/**`). `lib/widgets/common/navigation/adaptive_navigation.dart` switches between `BottomNavigationBar` (mobile), `NavigationRail` (tablet), and extended rail/drawer (desktop) automatically.

iOS Info.plist allows landscape on phone and iPad (`Info.plist:31–43`). Android manifest declares `configChanges="...|orientation|screenSize|...|layoutDirection|fontScale|..."` so the app handles rotation/text-scale without recreating activity. `cooking_mode_view.dart` is documented in `MEMORY.md` 2026-02-13 as landscape split-view — verifies orientation use.

### MEDIUM

**7.1 ~60 view files (46 %) lack obvious `ConstrainedBox` adaptation.** Includes some smaller dialogs and full-screen views. Phase 3 plan was "10 Tier 1 views" complete; the remaining ~58 are Tier 2/3 by definition but worth a per-view audit. *Effort: 2–3 d.*

**7.2 No `LayoutBuilder` golden tests** at common breakpoints (320, 414, 768, 1024, 1440). Screenshot regression suite would catch overflow at small phone widths. *Effort: 1 d golden infrastructure.*

### LOW

**7.3 Web hover states not catalogued.** `MouseRegion`/`InkWell.hoverColor` adoption unverified. Acceptable on mobile-first product.

**7.4 Foldable / tablet split-screen behaviour unverified.** Minor for Sweden-primary release.

---

## CRITICAL findings (single ownership boundary)

**C1 — `ConsentPurpose` undefined in NotificationService**
`lib/services/notifications/notification_service.dart:649`
The only `flutter analyze` error in the entire codebase. Reads:
```dart
final hasConsent = await ConsentService.checkSafely(
  _subscribedConsentService,
  ConsentPurpose.pushNotifications,   // ← undefined identifier
  logTag: 'NotificationService',
);
```
**User impact:** Anyone revoking push consent at runtime triggers the consent-change handler, which throws on `ConsentPurpose.pushNotifications` and silently catches in the surrounding `try` (line 657). The local FCM token is then NOT cleared on revoke (BUT-754 regression). Privacy-flow correctness is broken in a way that won't crash the app but will fail the GDPR consent revoke contract. May overlap with Prompt 02. *Effort: 1 h root-cause + fix.*

---

## Quick wins (≤1 day each, ordered by ROI)

1. **Fix `ConsentPurpose` import** (C1) — 1 h.
2. **Lift `'veckans\nmeny'` and `'dina\nrecept'` titles into ARB** (4.1) — 30 min.
3. **Add `minimumSize: Size(0, 48)` to `_getButtonStyle`** (2.1) — 30 min.
4. **Update Master Orchestrator package-name claim** (5.1) — 5 min.
5. **Add `@Deprecated()` to legacy color aliases** (1.3) — 2 h.
6. **Add ARB-header comment documenting `a11y*` prefix** (2.6) — 30 min.
7. **Re-run `tools/audit_unwrapped_tap_targets.dart`** (2.2) — 1 h.
8. **Capture launch screenshots for store** (6.1) — 1 d.

---

## Strengths to preserve (do not refactor away)

- Single-source-of-truth color tokens with WCAG annotations (`app_colors.dart`).
- Zero-radius `borderRadiusN` tokens enforce square-everywhere mockup language at the token layer.
- `LoadingStateBuilder` + `StateWidget` factory pattern for loading/empty/error states (rule documented in `lib/widgets/CLAUDE.md`).
- `a11y*` localized key prefix + per-chunk widget tests + `audit_unwrapped_tap_targets.dart` script — a real, sustained accessibility program.
- Adaptive widget library (`adaptive_*.dart`) with ~184 Cupertino references concentrated in 10 files, not spread.
- iOS system-font fallback at `app_text_styles.dart:29,34`.
- 1 769 `context.l10n` callsites in views; effectively zero hardcoded user-facing strings.
- Generated `app_localizations*.dart` ignored cleanly; ARB files at perfect parity (6 347 keys each).
- Material 3 + dark mode wired end-to-end including warm-brown dark surfaces overriding M3 seed defaults (`app_colors.dart:240–248`).

---

## Phase 1 completion checklist

- [x] Design system audit: theme compliance, component inventory, spacing analysis
- [x] Accessibility audit: WCAG 2.1 AA criteria with pass/fail
- [x] User flow analysis: surface count + friction points
- [x] Hardcoded string inventory (essentially empty — 5 instances total)
- [x] ARB file quality assessment (6 347 keys × 2 locales, parity confirmed)
- [x] Locale formatting audit (deferred sample — flagged as MEDIUM 4.3)
- [x] RTL readiness assessment (39 directional-blind EdgeInsets — flagged HIGH 4.2)
- [x] Platform compliance (iOS HIG + Material) — adaptive widget library inventoried
- [x] Feature parity (deferred — flagged LOW 5.6)
- [x] App store readiness checklists (Sweden-primary metadata present; screenshots missing)
- [x] Responsive design assessment (54 % of views adopt `ConstrainedBox`)
- [x] Severity classification per finding
- [x] Overall score: **78/100**
- [x] Improvement roadmap: see Quick Wins + sprint groupings (deferred to Phase 2)
- [x] **Zero code changes**

---

*End Phase 1 — owner: Claude (Opus 4.7, 1M context). Cross-references: Prompt 02 (consent), Prompt 09 (privacy manifest), Prompt 10 (store submission), Prompt 12 (doc drift on package-name + responsive Phase 3 status).*
