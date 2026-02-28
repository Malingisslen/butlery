# User Experience & Platform Analysis -- Phase 1 Findings

```
USER EXPERIENCE & PLATFORM ANALYSIS -- PHASE 1 FINDINGS
=========================================================
Analysis Date: 2026-02-26
Analyst: Claude (Opus 4.6)
Codebase: Butlery (Swedish recipe & meal planning app)
Platforms: Android, iOS, Web, macOS, Windows

OVERALL UX SCORE: 70/100

  1. Design System & Visual Consistency:    12/15
  2. Accessibility (WCAG 2.1 AA):            9/18
  3. User Flows & Navigation:               10/12
  4. Internationalization & Localization:    15/18
  5. Platform Compliance:                    11/15
  6. App Store Readiness:                     5/12
  7. Responsive Design & Adaptability:        8/10

STATUS: Acceptable

CRITICAL issues: 2 found
HIGH issues:     7 found
MEDIUM issues:   13 found
LOW issues:      10 found

CHANGE FROM PREVIOUS ANALYSIS (2026-02-10):
  Score: 62 -> 70 (+8 points)
  Primary driver: I18n externalization (5/18 -> 15/18)
  Secondary: Design system Colors.* cleanup (11/15 -> 12/15)
```

---

## Cross-Reference Notes

- Security/GDPR (Prompt 02): Full GDPR consent UI exists -- not duplicated here.
- Infrastructure (Prompt 03, 57/100): CI/CD, testing strategy -- not duplicated here.
- Performance (Prompt 04): Frame rates and rendering -- not duplicated here.
- Package name `com.example.butlery` flagged in Prompt 03; reinforced here as app store blocker.

---

## 1. Design System & Visual Consistency -- 12/15

The design system is well-structured with centralized color, typography, spacing, and component theme definitions. Material 3 is enabled with proper ColorScheme for both light and dark modes. Significant progress on `Colors.*` cleanup since the Feb 10 analysis.

### Strengths

- **Centralized theme system**: `lib/theme/app_theme.dart` orchestrates ThemeData with Material 3 (`useMaterial3: true`), proper ColorScheme, TextTheme, and 16 component themes.
- **Comprehensive color system**: `lib/theme/app_colors.dart` (293 lines) defines semantic brand colors (forestGreen, rust, cream), status colors (success, warning, error), full light ColorScheme, and M3-compliant dark ColorScheme via `ColorScheme.fromSeed`.
- **Typography system**: `lib/theme/app_text_styles.dart` provides dual-font system (Josefin Sans headers, Space Grotesk body) with 40+ semantic text styles and a complete `createTextTheme()`.
- **Spacing system**: `lib/theme/app_dimensions.dart` provides systematic spacing scale (Xs=4, Sm=8, Md=16, Lg=24, Xl=32, Xxl=48) with responsive helpers.
- **Component themes**: Organized in `lib/theme/components/` (button_themes.dart, feedback_themes.dart, input_themes.dart, navigation_themes.dart).
- **Zero `.withOpacity()` usage**: Fully migrated to `.withValues(alpha:)`.
- **Dynamic Color support**: `DynamicColorBuilder` in main.dart for Material You on Android 12+.
- **81% reduction in `Colors.*`**: Down from 1,879 (Feb 10) to 361 total (158 in views, 203 in widgets).

### Issues

| # | Severity | Issue | Location | Impact | Effort |
|---|----------|-------|----------|--------|--------|
| 1.1 | HIGH | **361 `Colors.*` references remain** (158 in 36 view files, 203 in 75 widget files). Down from 1,879 but still bypass theme system. ~27 are `Colors.transparent` (benign). | `lib/views/` (36 files), `lib/widgets/` (75 files) | Dark mode broken for these elements; inconsistent visual appearance | 2-3 days |
| 1.2 | MEDIUM | **14 hardcoded `Color(0x...)` outside app_colors.dart** across 6 files: illustration SVG colors, personal tag color picker, social formatters, theme constants, brand colors | `lib/widgets/common/illustrations/vegetable_illustration.dart`, `lib/widgets/tagging/personal_tag_color_picker.dart`, `lib/theme/theme_constants.dart`, `lib/theme/brand_colors.dart`, `lib/widgets/common/social_components/social_formatters.dart`, `lib/theme/butlery_colors_extension.dart` | Most are legitimate (illustration, color picker palettes); theme_constants and brand_colors should reference AppColors | 2 hours |
| 1.3 | MEDIUM | Dark mode described as "not in scope for redesign" but ColorScheme.fromSeed dark mode exists -- inconsistency between comment and implementation | `lib/theme/app_colors.dart` | Developer confusion about dark mode support status | 30 min |
| 1.4 | LOW | Border radius constants set to 0.0 (square design per mockup) creates misleading names like `borderRadius8 = 0.0` | `lib/theme/app_dimensions.dart` | Developer confusion -- names suggest rounding but value is 0 | 1 hour |

### Quick Wins

- Audit remaining `Colors.white` / `Colors.black` usages (most common pattern) and replace with `AppColors.cardWhite` / `AppColors.textDark`.
- Move `Color(0x...)` from `theme_constants.dart` and `brand_colors.dart` into `AppColors`.
- Clarify dark mode status in code comments.

---

## 2. Accessibility (WCAG 2.1 AA) -- 9/18

Accessibility infrastructure exists but systematic coverage is incomplete. Improvements since Feb 10 include PopScope adoption (8 files) for unsaved-changes protection and slight Semantics growth.

### Strengths

- **Reduced motion support**: `AnimationUtils.shouldAnimate()` in `lib/core/utils/animation_utils.dart` checks `MediaQuery.disableAnimations`. Used in 8 files including route transitions, skeleton components, animated lists, and typing indicators.
- **Semantics on key widgets**: ~56 `Semantics(` usages across ~27 code files (excluding generated l10n files), including recipe cards, message bubbles, navigation, image widgets, tag selectors, badges, and avatar widgets.
- **ExcludeSemantics**: Properly used in dietary/allergen status badges to prevent redundant announcements.
- **Semantic labels on navigation**: `AdaptiveNavigationItem` has `semanticLabel` property with fallback to `label`.
- **Touch target constant**: `AppDimensions.minTouchTarget = 48.0` defined and used in responsive button heights.
- **SafeArea usage**: 49 occurrences across 40 files -- good coverage for notch/gesture bar handling.
- **PopScope adoption**: 8 files now use `PopScope` for unsaved-changes protection (was 0 in Feb 10).

### Issues

| # | Severity | Issue | Location | Impact | Effort |
|---|----------|-------|----------|--------|--------|
| 2.1 | CRITICAL | **No Semantics on majority of interactive elements**: Many `InkWell`/`GestureDetector` widgets across `lib/widgets/` lack screen reader labels. Only ~56 `Semantics` in code vs hundreds of interactive elements. | `lib/widgets/` (many files) | Screen reader users cannot identify or activate many interactive elements | 3-5 days |
| 2.2 | HIGH | **Color contrast failures identified**: `AppColors.textLight` (#999999) on `AppColors.cream` (#F8F4E8) = **2.6:1** (FAIL, needs 4.5:1). `forestGreen` (#4A7C59) on `cream` = **4.3:1** (FAIL for normal text, needs 4.5:1). | `lib/theme/app_colors.dart:67,23,39` | Low-vision users cannot read light text on cream backgrounds | 1 day |
| 2.3 | HIGH | **No heading semantics hierarchy**: No `Semantics(header: true)` or heading-level annotations found in codebase | Entire codebase | Screen reader navigation by headings is impossible | 2 days |
| 2.4 | HIGH | **Form fields lack Semantics labels**: Custom widgets and tag filters have no explicit accessibility labels beyond Material defaults | `lib/widgets/common/input/`, `lib/widgets/tagging/` | Screen readers announce unclear or missing field descriptions | 2 days |
| 2.5 | MEDIUM | **No focus traversal configuration**: No `FocusTraversalGroup`, `FocusOrder`, or custom `FocusTraversalPolicy` found | Entire codebase | Keyboard/switch users may encounter illogical tab order | 2 days |
| 2.6 | MEDIUM | **No text scaling overflow testing evidence**: No `MediaQuery.textScaler` checks for 200% text | Various views | Large text users may see overflow/clipping | 2 days |
| 2.7 | LOW | **No landmark regions**: No `Semantics` with `namesRoute`, `scopesRoute`, or region annotations | Entire codebase | Screen reader users cannot jump between major page regions | 1 day |

### Contrast Ratio Analysis

| Color Pair | Hex Values | Ratio | WCAG AA Normal (4.5:1) | WCAG AA Large (3:1) |
|------------|-----------|-------|------------------------|---------------------|
| textDark on cream | #1A1A1A / #F8F4E8 | **16.5:1** | PASS | PASS |
| textMedium on cream | #666666 / #F8F4E8 | **5.2:1** | PASS | PASS |
| textLight on cream | #999999 / #F8F4E8 | **2.6:1** | **FAIL** | **FAIL** |
| textOnPrimary on forestGreen | #FFFFFF / #4A7C59 | **4.7:1** | PASS | PASS |
| forestGreen on cream | #4A7C59 / #F8F4E8 | **4.3:1** | **FAIL** | PASS |
| error on cardWhite | #C44536 / #FFFFFF | **4.6:1** | PASS | PASS |
| rust on cream | #8B5A3C / #F8F4E8 | **4.8:1** | PASS | PASS |

### WCAG 2.1 AA Compliance Checklist

| Criterion | Status | Notes |
|-----------|--------|-------|
| 1.1.1 Non-text Content | PARTIAL | Images have some Semantics labels; many decorative images lack `excludeFromSemantics` |
| 1.3.1 Info and Relationships | FAIL | No heading hierarchy, no landmark regions |
| 1.3.2 Meaningful Sequence | PASS | Linear layout, logical reading order |
| 1.3.4 Orientation | PASS | Both portrait and landscape supported |
| 1.4.1 Use of Color | PARTIAL | Status colors exist but no shape/icon alternatives verified for all states |
| 1.4.3 Contrast (Minimum) | PARTIAL | 2 of 7 key pairs fail: textLight on cream (2.6:1), forestGreen on cream (4.3:1) |
| 1.4.4 Resize Text | UNKNOWN | Not tested at 200% |
| 1.4.11 Non-text Contrast | UNKNOWN | Not verified for interactive elements |
| 2.1.1 Keyboard | PARTIAL | Standard Flutter focus works; no custom traversal |
| 2.3.3 Animation from Interactions | PASS | `AnimationUtils.shouldAnimate()` respects reduced motion (8 files) |
| 2.4.3 Focus Order | PARTIAL | Default order; no explicit management |
| 2.4.6 Headings and Labels | FAIL | No heading semantics |
| 4.1.2 Name, Role, Value | PARTIAL | ~56 Semantics but many gaps on interactive elements |

---

## 3. User Flows & Navigation -- 10/12

Navigation is well-structured with centralized routing, deferred module loading, adaptive navigation (bottom bar/rail/drawer), and comprehensive state handling. PopScope adoption addresses the previous unsaved-changes gap.

### Strengths

- **Centralized routing**: `lib/core/router/app_router.dart` handles all route generation with auth checks, type-safe arguments, error handling, and custom animations.
- **Deferred loading**: Three modules (extraction, social, messaging) use lazy loading for faster startup.
- **Adaptive navigation**: `AdaptiveNavigationScaffold` switches between BottomNavigationBar (mobile), NavigationRail (tablet), and extended rail (desktop).
- **Loading states**: Comprehensive coverage with CircularProgressIndicator, LinearProgressIndicator, skeleton components, and dedicated `LoadingStateBuilder`.
- **Empty states**: Dedicated `lib/widgets/common/state/empty_states.dart` with `EmptyStateScaffold` providing actionable guidance.
- **Error handling**: Error routes show user-friendly messages. Comprehensive state management via `StateWidget`.
- **Deep linking**: Configured for both Android (intent filters) and iOS (Universal Links) with `butlery://` and `https://butlery.app` schemes.
- **PopScope protection**: 8 files now use `PopScope` for form dirty-checking (`mina_recept_view.dart`, `user_profile_edit_view.dart`, `skriv_sjalv_recept_view.dart`, `veckomeny_view.dart`, `base_dialog.dart`, `edit_recipe_view.dart`, `image_picker_dialogs.dart`, `recipe_tagging_handler.dart`).

### Issues

| # | Severity | Issue | Location | Impact | Effort |
|---|----------|-------|----------|--------|--------|
| 3.1 | MEDIUM | **Navigator 1.0 (imperative)**: Uses `Navigator.pushNamed` instead of declarative routing (go_router). Only 1 file references GoRouter (deep_link_handler). | `lib/core/router/app_router.dart` | More complex deep linking, less predictable URL-based routing for web | 5+ days (major refactor) |
| 3.2 | LOW | **No undo for destructive actions**: No undo snackbar or undo mechanism for recipe deletion | Various action handlers | Users cannot recover from accidental deletions easily | 2 days |

### Core User Flow Step Counts

| Flow | Steps | Assessment |
|------|-------|------------|
| Recipe creation (manual) | Home -> "Lagg till" -> "Skriv sjalv" -> Fill form -> Save = 4-5 taps | Good |
| Recipe search | Search box -> Type query -> Select = 2-3 taps | Good |
| Recipe from URL | Home -> "Lagg till" -> "Fran sociala medier" -> Paste URL -> Extract -> Save = 5-6 taps | Acceptable |
| Menu planning | Navigate to Veckomeny -> Select day -> Add recipe = 3 taps | Good |
| Shopping list | Navigate to Inkopslista -> View/Add = 2 taps | Good |
| Social sharing | Recipe detail -> Share button -> Select friend/group -> Share = 3-4 taps | Good |

---

## 4. Internationalization & Localization -- 15/18

**Dramatic improvement since Feb 10.** The i18n migration is near-complete: 5,449 ARB keys with 2,973 `context.l10n` usages across 279 files. Hardcoded strings reduced from ~469 to ~21. The remaining gaps are RTL readiness and minor string stragglers.

### Strengths

- **Near-complete externalization**: 5,449 keys in `app_sv.arb`, 5,937 in `app_en.arb`. Coverage exceeds 99%.
- **Massive adoption**: 2,973 `context.l10n.*` usages across 279 files (was ~30 in 5 files).
- **Hardcoded strings nearly eliminated**: ~13 in views (5 files), ~8 in widgets (5 files). Down from 469 total.
- **ICU pluralization**: Multiple plural rules in ARB files for recipes, comments, friends, and other countable items.
- **Locale infrastructure**: `l10n.yaml` configured, `flutter_localizations` in pubspec, `LocaleProvider` for dynamic switching.
- **Two full locales**: Swedish (sv) and English (en) with near-parity key counts.
- **Tooltip localization**: Spot-checked tooltips show `context.l10n` usage (e.g., `photo_import_view.dart:468`).

### Issues

| # | Severity | Issue | Location | Impact | Effort |
|---|----------|-------|----------|--------|--------|
| 4.1 | MEDIUM | **~21 hardcoded user-facing strings remain** (~13 in views, ~8 in widgets): `animated_pressable.dart`, `debounced_button.dart`, `responsive_grid.dart`, `comment_debug_panel.dart`, `group_dialogs.dart` and a few view files | Various (10 files) | Minor gaps in translation coverage; mostly edge-case UI | 4 hours |
| 4.2 | MEDIUM | **RTL readiness ~60%**: 35 `EdgeInsetsDirectional` usages (22 files) vs 104 `EdgeInsets.only` (58 files). Not all `EdgeInsets.only` use left/right params, but a significant portion does. Also 9 `Alignment.centerLeft/Right` (6 files) and 2 `TextAlign.left/right` (2 files). | Various | RTL languages (Arabic, Hebrew) will have incorrect padding and alignment | 2 days |
| 4.3 | MEDIUM | **ARB key count mismatch**: sv has 5,449 keys, en has 5,937 (488 more in English). Either untranslated additions or key management drift. | `lib/l10n/app_sv.arb`, `app_en.arb` | Some strings may appear untranslated for Swedish users | 1 day |
| 4.4 | LOW | **No ARB metadata (@key descriptions)** for translator context | `lib/l10n/app_sv.arb`, `app_en.arb` | Translators lack context for ambiguous strings | 2 days |
| 4.5 | LOW | **iOS permission descriptions may still be Swedish-only** | `ios/Runner/Info.plist` | Non-Swedish iOS users see Swedish permission dialogs | 30 min per locale |

### I18n Readiness Score

| Metric | Feb 10 | Current | Change |
|--------|--------|---------|--------|
| ARB keys (sv/en) | 428/428 | 5,449/5,937 | +5,021/+5,509 |
| `context.l10n` usages | ~30 in 5 files | 2,973 in 279 files | +2,943 in +274 files |
| Hardcoded in views | ~263 in 59 files | ~13 in ~5 files | -250 in -54 files |
| Hardcoded in widgets | ~206 in 58 files | ~8 in ~5 files | -198 in -53 files |
| Externalization rate | ~48% | **~99.6%** | +51.6pp |
| Locales supported | 2 (sv, en) | 2 (sv, en) | -- |
| RTL readiness | LOW (~20%) | MEDIUM (~60%) | +40pp |
| EdgeInsetsDirectional | 23 in 16 files | 35 in 22 files | +12 in +6 files |

---

## 5. Platform Compliance -- 11/15

Good Material 3 adoption with adaptive widgets for iOS. Platform-specific handling exists across 11 Cupertino-aware files. No material changes since Feb 10.

### Strengths

- **Material 3**: `useMaterial3: true` in ThemeData. `ColorScheme.fromSeed`-compatible dark scheme.
- **Material You**: `DynamicColorBuilder` wraps MaterialApp for Android 12+ dynamic colors.
- **Adaptive widgets** (11 Cupertino-aware files):
  - `adaptive_button.dart` -- CupertinoButton on iOS
  - `adaptive_text_field.dart` -- CupertinoTextField on iOS
  - `adaptive_switch.dart` -- CupertinoSwitch on iOS
  - `adaptive_date_picker.dart` -- CupertinoDatePicker on iOS
  - `adaptive_activity_indicator.dart` -- CupertinoActivityIndicator on iOS
  - `adaptive_icon.dart` -- comprehensive SF Symbol mappings
  - `dialog_factory.dart` -- CupertinoAlertDialog on iOS
  - `loading_indicator.dart` -- platform-aware loading
- **Platform checks**: 5 files use `Platform.isIOS/isAndroid/isMacOS/isWindows/isLinux` for proper branching (FCM, backup, deep link, consent services).
- **CupertinoPageTransitionsBuilder**: Used for page transitions on both platforms.
- **Share intent handling**: Android intent filters for text/HTML/URL sharing. iOS Universal Links configured.
- **Deep linking**: Both `butlery://` custom scheme and `https://butlery.app` Universal Links.
- **Android config**: compileSdk 36, targetSdk 36, minSdk 24. R8/ProGuard enabled. Obfuscation + split debug info.
- **SafeArea**: 49 occurrences across 40 files.

### Issues

| # | Severity | Issue | Location | Impact | Effort |
|---|----------|-------|----------|--------|--------|
| 5.1 | MEDIUM | **No CupertinoNavigationBar**: All navigation uses Material AppBar. iOS users get Material-styled navigation bars. | Entire codebase | Non-native feel on iOS navigation | 3 days |
| 5.2 | MEDIUM | **Web/Desktop: No keyboard shortcuts**: No `Shortcuts`/`Actions` widgets for common operations (Ctrl+S, Ctrl+F, etc.) | Entire codebase | Desktop/web users cannot use keyboard shortcuts | 2 days |
| 5.3 | MEDIUM | **macOS entitlements minimal**: Only app-sandbox and user-selected file read. Missing network.client (needed for Firebase), camera, photos entitlements in Release build. | `macos/Runner/Release.entitlements` | macOS release build may fail Firebase/network calls | 2 hours |
| 5.4 | LOW | **Windows Runner.rc has placeholder metadata**: CompanyName "com.example", LegalCopyright "Copyright (C) 2025 com.example" | `windows/runner/Runner.rc:92-96` | Unprofessional metadata in Windows executable | 30 min |

### Platform Compliance Matrix

| Feature | iOS HIG | Material Design | Current State |
|---------|---------|-----------------|---------------|
| Navigation bar | CupertinoNavigationBar | AppBar | Material AppBar (both platforms) |
| Tab bar | CupertinoTabBar | BottomNavigationBar | Adaptive (BottomNav/NavigationRail) |
| Buttons | CupertinoButton | ElevatedButton etc. | Adaptive (adaptive_button.dart) |
| Text fields | CupertinoTextField | TextField | Adaptive (adaptive_text_field.dart) |
| Switches | CupertinoSwitch | Switch | Adaptive (adaptive_switch.dart) |
| Date pickers | CupertinoDatePicker | showDatePicker | Adaptive (adaptive_date_picker.dart) |
| Dialogs | CupertinoAlertDialog | AlertDialog | Adaptive (dialog_factory.dart) |
| Activity indicators | CupertinoActivityIndicator | CircularProgressIndicator | Adaptive |
| Icons | SF Symbols | Material Icons | Adaptive (adaptive_icon.dart) |
| Page transitions | CupertinoPageTransition | Material transition | CupertinoPageTransitionsBuilder (both) |
| Fonts | System (SF Pro) | Custom allowed | System fallback on iOS, custom on Android/web |
| Safe areas | Required | Required | Yes (49 SafeArea usages in 40 files) |

---

## 6. App Store Readiness -- 5/12

Multiple submission blockers remain unchanged since Feb 10. The app is functional but not ready for store submission.

### Issues

| # | Severity | Issue | Location | Impact | Effort |
|---|----------|-------|----------|--------|--------|
| 6.1 | CRITICAL | **Placeholder package name `com.example.butlery`** across all platforms (Android, iOS, macOS, Linux, Windows -- 11+ config files) | `android/app/build.gradle.kts`, `ios/Runner.xcodeproj/project.pbxproj`, `macos/Runner/Configs/AppInfo.xcconfig`, `linux/CMakeLists.txt`, `windows/runner/Runner.rc` | **Absolute submission blocker** for all app stores | 2 hours |
| 6.2 | HIGH | **Debug signing only**: No release signing configuration | Android/iOS build configs | Cannot create signed release builds for stores | 2 hours |
| 6.3 | HIGH | **No privacy policy URL** configured in app metadata | Not found in codebase | Required by both Google Play and Apple App Store | 1 hour |
| 6.4 | HIGH | **No app store metadata**: No screenshots, descriptions, feature graphics, keywords | Not in codebase | Required for both store listings | 2-3 days |
| 6.5 | MEDIUM | **No in-app review prompt**: No `in_app_review` package in pubspec.yaml | `pubspec.yaml` | Missed opportunity for organic ratings | 1 day |
| 6.6 | LOW | **App label lowercase "butlery"** in AndroidManifest and iOS Info.plist | Android/iOS configs | Should be "Butlery" (capitalized) for store display | 5 min |
| 6.7 | LOW | **macOS bundle identifier is com.example.butlery** | `macos/Runner/Configs/AppInfo.xcconfig:11` | Blocker for Mac App Store | Part of 6.1 |

### App Store Readiness Checklist

| Requirement | Google Play | Apple App Store |
|-------------|-------------|-----------------|
| Package/Bundle ID (not com.example) | FAIL | FAIL |
| Release signing | FAIL | FAIL (no provisioning profile) |
| Privacy policy URL | MISSING | MISSING |
| App description | MISSING | MISSING |
| Screenshots | MISSING | MISSING |
| App icon | Present (ic_launcher) | Present (AppIcon) |
| Target API level | PASS (targetSdk 36) | N/A |
| Content rating | NOT DONE | NOT DONE |
| Data safety / Privacy nutrition labels | NOT DONE | NOT DONE |
| GDPR consent | PASS (consent UI exists) | PASS |
| App Tracking Transparency | N/A | NOT NEEDED (no tracking) |
| TestFlight | N/A | NOT CONFIGURED |
| Crash-free rate | Firebase Crashlytics enabled | Firebase Crashlytics enabled |
| In-app review | NOT PRESENT | NOT PRESENT |

---

## 7. Responsive Design & Adaptability -- 8/10

Excellent responsive design infrastructure with comprehensive breakpoint system and widespread adoption. All views implement responsive patterns. No changes since Feb 10.

### Strengths

- **Breakpoint system**: `lib/core/responsive/breakpoints.dart` defines 6 breakpoints: mobile (<600), mobileLarge (600-768), tablet (768-1024), tabletLarge (1024-1280), desktop (1280-1920), desktopLarge (1920+).
- **ConstrainedBox adoption**: 39 occurrences across 34 view files -- near-universal max-width constraints.
- **Responsive dimensions**: `AppDimensions` provides responsive helper methods (`responsiveSpacing`, `responsivePadding`, `responsiveGridColumns`, `responsiveMaxContentWidth`, etc.).
- **Adaptive navigation**: Switches between BottomNavigationBar (mobile), NavigationRail (tablet), and extended rail/drawer (desktop).
- **Responsive grid**: `getGridColumnCount()` returns 1/2/3/4 columns for mobile/tablet/desktop/largeDesktop.
- **Content width tiers**: Max content width 800px (tablet), 1200px (desktop), 1400px (large desktop).
- **Form width constraint**: Max 600px for forms on larger screens.

### Issues

| # | Severity | Issue | Location | Impact | Effort |
|---|----------|-------|----------|--------|--------|
| 7.1 | MEDIUM | **No web-specific hover states**: No `MouseRegion` or `onHover` patterns beyond standard Material hover | Entire codebase | Web users lack visual hover feedback on custom widgets | 2 days |
| 7.2 | LOW | **No keyboard shortcuts for web/desktop** (same as 5.2) | Entire codebase | Power users on web/desktop cannot use keyboard shortcuts | 2 days |
| 7.3 | LOW | **Foldable device support not addressed**: No `MediaQuery.displayFeatures` usage | Entire codebase | Foldable devices may have content hidden by hinge | 1 day |

### Responsive Design Assessment

| View Category | Responsive | Pattern Used | Issues |
|---------------|------------|--------------|--------|
| MinaReceptView (home) | Yes | Center + ConstrainedBox | None |
| VeckomenyView (menu) | Yes | ConstrainedBox | None |
| UnifiedShoppingView | Yes | ConstrainedBox | None |
| RecipeDetailView | Yes | ConstrainedBox | None |
| SkrivSjalvReceptView (create) | Yes | ConstrainedBox | None |
| EditRecipeView | Yes | ConstrainedBox | None |
| AuthView | Yes | ConstrainedBox | None |
| Social views (8+) | Yes | ConstrainedBox | None |
| Messaging views | Yes | ConstrainedBox | None |
| Settings views | Yes | ConstrainedBox | None |
| Import views | Yes | ConstrainedBox | None |
| Personal tags views | Yes | SafeArea + ConstrainedBox | None |
| Cooking mode | Yes | SafeArea | None |

All views implement responsive patterns. Phase 3 responsive design is complete.

---

## Improvement Roadmap

### Sprint 1: Submission Blockers & Critical Accessibility (1-2 weeks)

1. **Change package name** from `com.example.butlery` to production identifier across all platforms (Android, iOS, macOS, Linux, Windows -- 11+ config files). [CRITICAL, 6.1]
2. **Configure release signing** for Android (keystore) and iOS (provisioning profile). [HIGH, 6.2]
3. **Add Semantics** to all InkWell/GestureDetector widgets -- prioritize navigation and primary actions. [CRITICAL, 2.1]
4. **Fix contrast failures**: Darken `textLight` (#999999 -> ~#767676 for 4.5:1) and adjust forestGreen on cream usage to large text only or darken. [HIGH, 2.2]
5. **Privacy policy URL**: Create and link in store metadata. [HIGH, 6.3]

### Sprint 2: Accessibility & Polish (2-3 weeks)

6. **Add heading semantics** (`Semantics(header: true)`) to section headers and view titles. [HIGH, 2.3]
7. **Form field Semantics**: Add labels to custom input widgets and tag filters. [HIGH, 2.4]
8. **Replace remaining `Colors.*`** with theme tokens: 361 references across 111 files. [HIGH, 1.1]
9. **Capitalize app name** in AndroidManifest and Info.plist. [LOW, 6.6]
10. **Fix macOS Release entitlements**: Add network.client for Firebase connectivity. [MEDIUM, 5.3]

### Sprint 3: I18n Completion & Store Preparation (2-3 weeks)

11. **Externalize final ~21 hardcoded strings** in views and widgets. [MEDIUM, 4.1]
12. **RTL cleanup**: Replace `EdgeInsets.only(left/right)` with `EdgeInsetsDirectional`, fix `Alignment.centerLeft/Right` and `TextAlign.left/right`. [MEDIUM, 4.2]
13. **Reconcile ARB key counts**: Identify 488 key difference between sv and en files. [MEDIUM, 4.3]
14. **App store metadata**: Screenshots, descriptions, feature graphics, keywords for both stores. [HIGH, 6.4]
15. **Add keyboard shortcuts** for web/desktop (save, search, navigate). [MEDIUM, 5.2]

### Backlog

16. Add web-specific hover states on custom widgets. [MEDIUM, 7.1]
17. Focus traversal configuration for keyboard navigation. [MEDIUM, 2.5]
18. Text scaling overflow testing at 200%. [MEDIUM, 2.6]
19. Add in-app review prompt (`in_app_review` package). [MEDIUM, 6.5]
20. ARB metadata for translator context. [LOW, 4.4]
21. Localize iOS permission descriptions. [LOW, 4.5]
22. Update Windows Runner.rc metadata. [LOW, 5.4]
23. Foldable device support. [LOW, 7.3]
24. Add undo snackbar for destructive actions. [LOW, 3.2]
25. Landmark regions for screen reader navigation. [LOW, 2.7]

---

## Score Change Summary

| Dimension | Feb 10 | Feb 26 | Delta | Key Driver |
|-----------|--------|--------|-------|------------|
| 1. Design System | 11/15 | **12/15** | +1 | `Colors.*` reduced 81% (1,879 -> 361) |
| 2. Accessibility | 8/18 | **9/18** | +1 | PopScope in 8 files, Semantics grew slightly, reduced motion in 8 files |
| 3. User Flows | 10/12 | **10/12** | 0 | PopScope improves dirty-check but no undo added |
| 4. I18n | 5/18 | **15/18** | +10 | 5,449 ARB keys, 2,973 usages, ~21 hardcoded strings remaining |
| 5. Platform | 11/15 | **11/15** | 0 | No material changes to adaptive widget count |
| 6. App Store | 5/12 | **5/12** | 0 | com.example.butlery still present, no store metadata |
| 7. Responsive | 8/10 | **8/10** | 0 | No web hover states; infrastructure still excellent |
| **TOTAL** | **62/100** | **70/100** | **+8** | Driven almost entirely by i18n externalization |

**Next biggest opportunities**: Accessibility (+9 possible with Semantics, contrast, headings) and App Store readiness (+7 possible with package rename, signing, metadata).
