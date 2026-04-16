# User Experience & Platform Analysis

**Prompt 06 of 06** | Consolidates: UX/UI Analysis (10 dims), Internationalization (8 dims), Platform Analysis (8 dims)

---

## Mission

Analyst: **Claude (Opus 4.7)**

Deliver a world-class user experience across all platforms. This prompt audits the full
surface area of what users see, touch, and interact with: design consistency, accessibility,
internationalization, platform compliance, and app store readiness.

**Scope boundaries** -- topics owned by other prompts (do not duplicate):
- Performance metrics and frame rates --> 04_PERFORMANCE_AND_SCALABILITY
- Security rules, auth, GDPR compliance --> 02_SECURITY_AND_COMPLIANCE
- Test coverage and CI/CD pipelines --> 03_INFRASTRUCTURE_AND_OPERATIONS

---

## Two-Phase Approach

### Phase 1: Investigation and Documentation (current task)

No code changes. No design changes. Investigate and record findings only.

For every issue found, document:
- File path and line number
- Severity: CRITICAL / HIGH / MEDIUM / LOW
- User impact description
- Effort estimate (hours or days)

### Phase 2: Improvement Plan (after Phase 1 completes)

Analyze all findings together. Prioritize by user impact, effort, and platform risk.
Group related improvements. Produce a sequenced remediation roadmap.

Phase 2 is a separate step that begins only after Phase 1 is 100% complete.

---

## Known Project Context

```
Project:             Butlery (Swedish recipe and meal planning app)
Framework:           Flutter / Dart
Architecture:        MVVM + Repository (Views -> ViewModels -> Services -> Repositories -> Firebase)
Primary language:    Swedish (sv)
Secondary language:  English (en)
Target platforms:    Android, iOS, Web, macOS, Windows
Package name:        com.example.butlery (PLACEHOLDER -- must change before store submission)

Responsive design:   Phase 3 complete (10 Tier 1 views)
Responsive pattern:  Center + ConstrainedBox with responsive max width
Content widths:      Narrow (500-600px), Medium (700-800px), Wide (900-1200px)

Social features:     Complete (friends, sharing, comments, ratings, groups)
GDPR:                Phase 1 complete (Articles 7, 15, 17, 30)
FCM Notifications:   Complete (Cloud Functions)

Key UI areas:
  - Recipe form (lib/views/recipe_form/)
  - Recipe detail view
  - Menu/calendar view (veckomeny_view.dart)
  - Shopping list views
  - Social/group views
  - Settings and profile
  - Personal tags management

Known Semantics labels: recipe_personal_tag_handler, personal_tag_filter_chips, personal_tags_view

Generated file exclusions (skip during analysis):
  - *.g.dart
  - *.freezed.dart
  - app_localizations*.dart
```

---

## Dimensions (7 total, weights sum to 100)

### 1. Design System and Visual Consistency -- 15 points

**Goal:** Every screen follows a unified design language.

Investigate:

**1.1 Theme compliance**
- ThemeData usage: verify all colors reference ColorScheme (primary, secondary, tertiary, error, surface)
- TextTheme usage: verify text styles reference theme.textTheme instead of inline TextStyle
- Find hardcoded colors (`Color(0x...)`, `Colors.red`, etc.) that should use theme tokens
- Dark mode: verify ColorScheme works in both light and dark brightness

**1.2 Component library**
- Inventory reusable widgets in lib/widgets/
- Find duplicate widget implementations across views (should be consolidated)
- Check widget parameterization (flexible props vs hardcoded values)
- Verify component APIs are consistent (similar widgets have similar parameter names)

**1.3 Typography**
- Font weight consistency (headings, body, captions use expected weights)
- Font size progression (clear heading hierarchy: display > headline > title > body > label)
- Line height and letter spacing consistency across similar text roles
- Hardcoded font sizes that bypass TextTheme

**1.4 Spacing and padding system**
- Identify magic number spacing (should use consistent multiples: 4, 8, 12, 16, 24, 32)
- Padding and margin consistency across similar components
- Whitespace usage: breathing room, visual hierarchy, information density

**1.5 Visual polish**
- Shadow and elevation consistency (Material elevation system)
- Border radius consistency (same radius for same component types)
- Opacity usage (withValues(alpha:) not withOpacity)
- Iconography: consistent icon set, sizes, and visual weight

**Output:** List of design inconsistencies with file:line references. Component variations
that should be unified. Hardcoded values that should use design tokens.

---

### 2. Accessibility (WCAG 2.1 AA) -- 18 points

**Goal:** Usable by all users. WCAG 2.1 Level AA compliance.

Investigate:

**2.1 Color contrast**
- Text contrast: 4.5:1 ratio for normal text, 3:1 for large text (18sp+ or 14sp+ bold)
- Interactive element contrast: 3:1 minimum against adjacent colors
- Disabled state contrast: perceivable but clearly disabled
- Placeholder text and hint text contrast
- Error message visibility

**2.2 Screen reader support**
- Semantics widgets on all interactive elements
- Meaningful labels (not "button 1" or "icon")
- Image descriptions via Semantics(label:)
- Navigation announcements for screen changes
- Form field labels and hints announced correctly
- Verify known labels: recipe_personal_tag_handler, personal_tag_filter_chips, personal_tags_view

**2.3 Touch targets**
- Minimum 48x48 dp for all interactive elements (Material guideline)
- Minimum 8dp spacing between adjacent touch targets
- Slider thumb sizes, checkbox/radio sizes, icon button sizes

**2.4 Focus management**
- Keyboard navigation: visible focus indicators on all focusable elements
- Tab order follows logical reading order
- All actions reachable via keyboard (web/desktop targets)
- Focus not trapped in dialogs or modals without escape

**2.5 Text scaling**
- App handles 200% font size without text overflow or clipping
- Layouts adapt to larger text (no fixed-height containers that truncate)
- Scrollable content areas accommodate enlarged text

**2.6 Motion**
- Respects MediaQuery.disableAnimations / reduced motion preferences
- Autoplay animations can be paused or disabled
- Animation durations appropriate (not too fast to follow)

**2.7 Semantic structure**
- Heading hierarchy (logical nesting of header semantics)
- Landmark regions (navigation, main content, complementary)

**Output:** WCAG compliance checklist with pass/fail per criterion. Specific violations
with file:line references.

---

### 3. User Flows and Navigation -- 12 points

**Goal:** Intuitive navigation. Minimal steps for core tasks.

Investigate:

**3.1 Core user journey step counts**

Map each flow and count required user actions:
- Recipe creation (target: under 5 taps to minimal viable recipe)
- Recipe search and discovery (search, filter, select)
- Menu planning (add recipe to weekly plan)
- Shopping list generation (from menu or recipe)
- Social sharing (share recipe with friend/group)
- User onboarding (first-time experience)

For each flow, identify friction points: unnecessary confirmations, redundant data entry,
unclear next steps.

**3.2 Error recovery**
- Can user go back from any screen?
- Undo support for destructive actions (delete recipe, remove item)
- Unsaved changes warning when navigating away from forms
- Retry mechanism for failed network operations

**3.3 Loading states**
- All async operations show loading indicators
- Skeleton screens or shimmer effects for content loading (preferred over plain spinners)
- Progress indicators for multi-step or long operations
- Loading state cancellation (user can abandon long operations)

**3.4 Empty states**
- Every list/collection has a meaningful empty state
- Empty states provide actionable guidance ("Add your first recipe")
- Empty states are visually appealing, not just plain text

**3.5 Error states**
- User-friendly error messages (no technical jargon, no "Error occurred")
- Error messages suggest resolution steps
- Inline form validation with clear, specific messages
- Network error handling with retry option

**3.6 Navigation patterns**
- Bottom navigation clarity (labels, icons, active state)
- Back button behavior (consistent, predictable)
- Deep link handling (share URLs resolve correctly)
- Drawer or side navigation organization

**Output:** User journey maps with step counts. Friction points identified. Missing loading/empty/error
states with file references.

---

### 4. Internationalization and Localization -- 18 points

**Goal:** App ready for multi-language deployment with zero hardcoded user-facing strings.

Investigate:

**4.1 Hardcoded strings audit**

Search for all user-facing strings not using AppLocalizations:
```
Patterns to find:
- Text('Hardcoded string')
- title: 'Hardcoded'
- hintText: 'Enter value'
- labelText: 'Field name'
- errorText: 'Error message'
- tooltip: 'Tooltip text'
- SnackBar(content: Text('Message'))
```
Categorize each string:
- CRITICAL: button text, error messages, dialog titles, form labels, navigation titles, empty states
- HIGH: placeholder text, tooltips, confirmation messages, validation messages
- MEDIUM: help text, instructions, feature descriptions, onboarding
- LOW: log messages, debug strings (not user-facing, exclude from i18n scope)

Count total hardcoded strings and distribution across files.

**4.2 ARB file quality**

Check localization infrastructure:
- flutter_localizations in pubspec.yaml
- l10n.yaml configuration file
- ARB files in lib/l10n/ (app_sv.arb, app_en.arb)
- Generated localization classes (app_localizations.dart)
- AppLocalizations usage patterns in views

Assess ARB file completeness:
- String count per locale
- Coverage percentage (translated vs total)
- Metadata quality (@key descriptions for translator context)
- Consistency between language files (same keys present in all)

**4.3 Pluralization**
- Find plural string patterns: `${count} recipes`, `count == 1 ? 'recipe' : 'recipes'`
- Check for ICU message format usage in ARB files
- Zero-count handling ("0 recipes" vs "No recipes")
- Languages with complex plural rules (Russian: zero/one/few/many, Arabic: six forms)

**4.4 Date, time, and number formatting**
- Find non-locale-aware date formatting: DateTime.toString(), manual formatting
- Verify DateFormat usage includes locale parameter
- Number formatting: locale-specific decimal separators (1,000 vs 1.000 vs 1 000)
- Currency formatting: hardcoded currency symbols
- Time formatting: 12-hour vs 24-hour based on locale
- Relative time strings ("2 hours ago", "Yesterday")

**4.5 RTL readiness**
- Hardcoded EdgeInsets.only(left:) / EdgeInsets.only(right:) instead of EdgeInsetsDirectional
- Hardcoded Alignment.centerLeft/Right instead of AlignmentDirectional.centerStart/End
- TextAlign.left/right instead of TextAlign.start/end
- Directional icons that need flipping (arrows, back buttons)

**4.6 Cultural sensitivity**
- Food images and examples (appropriate for international audience)
- Measurement units (metric vs imperial, cups vs ml)
- Color cultural meanings (red, white, green vary by culture)
- Placeholder/example data (names, addresses locale-appropriate)

**4.7 Text overflow handling**
- Translated strings may be 30-50% longer than Swedish/English
- Verify layouts handle longer text without overflow or clipping
- Check that fixed-width containers accommodate translation expansion

**Output:** Hardcoded string inventory with file:line and category. I18n readiness score
(percentage of strings externalized). ARB file quality assessment. Formatting issue count.
RTL readiness score.

---

### 5. Platform Compliance -- 15 points

**Goal:** Native feel on each platform. Guideline compliance for iOS HIG and Material Design.

Investigate:

**5.1 iOS Human Interface Guidelines**
- Navigation: CupertinoNavigationBar vs Material AppBar on iOS
- Components: CupertinoSwitch, CupertinoAlertDialog, CupertinoDatePicker usage on iOS
- System font: SF Pro (system font) vs custom font on iOS
- Safe area: proper SafeArea handling for notch, Dynamic Island, home indicator
- iOS gestures: swipe-to-go-back, pull-to-refresh native feel
- iOS features: Share Sheet integration, Dark Mode, Dynamic Type support

Search patterns:
```
Platform.isIOS
Cupertino
CupertinoNavigationBar
CupertinoSwitch
SafeArea
```

**5.2 Android Material Design**
- Material 3 adoption: useMaterial3 in ThemeData, ColorScheme.fromSeed
- Component compliance: FAB placement, BottomNavigationBar, AppBar elevation
- Material You / dynamic color support (Android 12+)
- Navigation: back button handling, drawer, system gestures
- Android features: notification channels (required Android 8+), adaptive icons

**5.3 Platform-adaptive widgets**
- Identify Material-only widgets used on both platforms (should be adaptive)
- Check for platform branching: Platform.isIOS ? CupertinoX : MaterialX
- Document which components use adaptive patterns vs fixed Material

**5.4 Platform gestures**
- Swipe-to-dismiss (iOS and Android)
- Pull-to-refresh implementation
- Long press context menus
- System gesture conflicts (back swipe on iOS, navigation gestures on Android)

**5.5 System integration**
- Share sheet (iOS) / share intent (Android)
- Camera and photo picker integration
- File picker behavior
- Notification handling: platform-specific display patterns

**5.6 Feature parity**
- Create matrix: Feature x Platform (Android, iOS, Web, macOS, Windows)
- Document intentional differences vs gaps
- Identify features available on only some platforms

**Output:** iOS HIG compliance score. Material Design compliance score. Platform-adaptive
widget audit. Feature parity matrix. Platform-specific issues with file references.

---

### 6. App Store Readiness -- 12 points

**Goal:** Zero submission blockers. Optimized store listings.

Investigate:

**6.1 Google Play readiness**
- App listing: title (50 char), short description (80 char), full description (4000 char)
- Screenshots: multiple sizes, feature graphic
- Privacy policy URL linked in Play Console
- Data Safety section completed (data types collected, purposes, sharing, security)
- Target API level compliance (current Play Store requirement)
- Package name: com.example.butlery is a PLACEHOLDER -- must be changed
- Content rating questionnaire completed
- Crash-free rate target: above 99%

**6.2 Apple App Store readiness**
- App metadata: name (30 char), subtitle (30 char), description, keywords (100 char)
- Screenshots for all required device sizes
- Privacy nutrition labels completed
- App Review Guidelines compliance (section 2.1 completeness, 2.3 metadata, 4.0 design, 5.1 privacy)
- TestFlight configuration for beta testing
- NSUserTrackingUsageDescription if tracking (App Tracking Transparency)

**6.3 Store listing optimization**
- Keyword research: primary and secondary keywords in title/subtitle
- Screenshot quality: show key features, captions, first screenshot most important
- App icon: recognizable at small size, stands out in category
- Feature graphic (Android): compelling, brand-consistent

**6.4 Compliance**
- Privacy policy: exists, accurate, covers Firebase/Analytics third-party data
- COPPA compliance (if children may use the app)
- GDPR consent (EU users): covered in prompt 02, but verify consent UI exists
- User data deletion process documented and functional

**6.5 Rating and review management**
- In-app review prompt: timing and frequency (not too aggressive)
- Review response process defined
- "What's New" section maintained for each release

**Output:** App store readiness checklist (Google Play and Apple App Store) with pass/fail
per item. Submission blockers identified. Store listing optimization recommendations.

---

### 7. Responsive Design and Adaptability -- 10 points

**Goal:** Excellent experience on every screen size and form factor.

Investigate:

**7.1 Responsive layout pattern**
- Verify Center + ConstrainedBox pattern used consistently across views
- Content width tiers: Narrow (500-600px), Medium (700-800px), Wide (900-1200px)
- Check which views implement responsive patterns vs fixed-width
- Phase 3 complete for 10 Tier 1 views -- verify remaining views

**7.2 Breakpoint handling**
- Phone: portrait and landscape (320px to 428px width)
- Tablet: portrait and landscape (768px+)
- Desktop/web: 1024px+
- Foldable devices: inner/outer screen adaptation

**7.3 Orientation**
- Portrait to landscape transitions: layout adapts, data preserved
- Landscape layout uses horizontal space effectively
- Keyboard does not obscure critical content in landscape

**7.4 Web-specific concerns**
- Scrollbar styling (custom or default)
- Hover states on interactive elements
- Keyboard shortcuts for common actions
- Right-click context menu handling
- Browser window resize handling (smooth, no layout breaks)

**7.5 Form factor adaptation**
- Small phone (320px): no horizontal overflow, text readable
- Large phone (414px+): content not too sparse
- Tablet: multi-column layouts or centered content, not just scaled-up phone
- Desktop: sidebar navigation, expanded layouts, keyboard-first interaction

**Output:** Responsive design assessment per view. Layout issues by screen size.
Missing responsive adaptations. Phase 3 completion verification.

---

## Investigation Process

### Stage 1: Visual and Design Audit

1. Audit ThemeData configuration (ColorScheme, TextTheme, component themes)
2. Search for hardcoded colors, font sizes, spacing values across lib/
3. Inventory reusable widgets in lib/widgets/
4. Check accessibility: Semantics widgets, contrast ratios, touch targets
5. Run `flutter analyze` for UI-specific warnings

Tools: Grep, Glob, Read. No Edit, no Write.

### Stage 2: Deep Investigation

6. Walk through core user journeys: recipe creation, search, menu planning, shopping list, sharing
7. Count steps for each flow, identify friction points
8. Audit loading states, empty states, error states across all views
9. Search for hardcoded user-facing strings (Text(), title:, hintText:, etc.)
10. Review ARB files for completeness and quality
11. Audit date/number/currency formatting patterns
12. Search for RTL layout issues (EdgeInsets, Alignment, TextAlign)
13. Review platform-specific code: Info.plist, AndroidManifest.xml, Platform.isIOS checks
14. Check app store metadata and configuration files
15. Verify responsive patterns across views

### Stage 3: Report Compilation

16. Score each of the 7 dimensions
17. Compile all findings with file:line references
18. Classify every issue by severity (CRITICAL / HIGH / MEDIUM / LOW)
19. Calculate overall score out of 100
20. Produce executive summary and improvement roadmap

---

## Output Format

### Executive Summary

```
USER EXPERIENCE & PLATFORM ANALYSIS -- PHASE 1 FINDINGS
=========================================================
Analysis Date: [Date]
Analyst: Claude (Opus 4.7)
Platforms: Android, iOS, Web, macOS, Windows

OVERALL UX SCORE: X/100

  1. Design System & Visual Consistency:    X/15
  2. Accessibility (WCAG 2.1 AA):           X/18
  3. User Flows & Navigation:               X/12
  4. Internationalization & Localization:    X/18
  5. Platform Compliance:                    X/15
  6. App Store Readiness:                    X/12
  7. Responsive Design & Adaptability:       X/10

STATUS: [Excellent | Good | Needs Improvement | Critical Issues]

CRITICAL issues: X found
HIGH issues:     X found
MEDIUM issues:   X found
LOW issues:      X found
```

### Per-Dimension Report

For each dimension, provide: 2-3 sentence summary, then issues grouped by severity
(CRITICAL / HIGH / MEDIUM / LOW). Each issue includes: title, file:line, user impact,
current vs expected state, effort estimate. End with quick wins list.

### Specialized Sections

- **Accessibility audit:** WCAG 2.1 AA compliance checklist with pass/fail per criterion
- **I18n readiness:** total hardcoded strings, % externalized, ARB coverage per locale, RTL readiness %, formatting compliance %
- **Platform compliance matrix:** Feature rows (navigation, components, typography, gestures) x columns (iOS HIG requirement, Material Design requirement, current state)
- **App store checklist:** Requirement rows x columns (Google Play status, Apple App Store status)
- **Responsive design assessment:** View rows x columns (responsive yes/no, pattern used, issues)

### Improvement Roadmap

- **Sprint 1:** Submission blockers, WCAG critical failures, broken flows
- **Sprint 2:** Accessibility gaps, i18n infrastructure, platform compliance
- **Sprint 3:** Design consistency, responsive remaining views, polish
- **Backlog:** Nice-to-have improvements, advanced platform features

---

## Scoring Guide

| Score Range | Rating | Interpretation |
|-------------|--------|----------------|
| 90-100 | Excellent | Minor polish. Ready for prime time. |
| 75-89 | Good | Targeted improvements, no urgency. |
| 60-74 | Acceptable | Prioritized remediation within 2 sprints. |
| 40-59 | Needs Work | Significant remediation required. |
| 0-39 | Critical | UX fundamentals broken. Fix before feature work. |

### Per-Dimension Scoring Criteria

| Dimension | Top Tier (85%+) | Mid Tier (50-84%) | Low Tier (below 50%) |
|-----------|-----------------|--------------------|-----------------------|
| Design System (15) | Unified language, <5% hardcoded values | Mostly consistent, some variations | No system, ad-hoc styling |
| Accessibility (18) | WCAG 2.1 AA compliant, full Semantics | Most criteria pass, some gaps | Not considered, major barriers |
| User Flows (12) | Core tasks <5 steps, complete states | Reasonable flows, some gaps | Broken flows, no loading states |
| I18n (18) | Zero hardcoded strings, ARB complete, RTL ready | Most externalized, partial coverage | No infrastructure, all hardcoded |
| Platform (15) | Native feel, adaptive widgets, >90% compliant | Mostly compliant, some gaps | Guidelines ignored |
| App Store (12) | Zero blockers, optimized listings | Minor gaps, no blockers | Multiple blockers |
| Responsive (10) | All views responsive, web polish | Tier 1 done, gaps remain | No responsive design |

---

## Phase 1 Completion Checklist

Investigation and documentation only. No code or design changes.

- [ ] Design system audit: theme compliance, component inventory, spacing analysis
- [ ] Accessibility audit: WCAG 2.1 AA checklist with pass/fail per criterion
- [ ] User flow analysis: step counts for core tasks, friction points, missing states
- [ ] Hardcoded string inventory: file:line, string value, category for every instance
- [ ] ARB file quality assessment: coverage, consistency, metadata
- [ ] Locale formatting audit: date, number, currency, time patterns
- [ ] RTL readiness assessment
- [ ] Platform compliance: iOS HIG and Material Design scorecards
- [ ] Feature parity matrix across target platforms
- [ ] App store readiness checklists: Google Play and Apple App Store
- [ ] Responsive design assessment per view
- [ ] All issues classified by severity with effort estimates
- [ ] Overall score calculated (X/100)
- [ ] Improvement roadmap produced
- [ ] ZERO code changes made

**Phase 1 output:** Comprehensive UX and platform findings report.
**Phase 2 input:** Use this report to create the prioritized improvement plan.
