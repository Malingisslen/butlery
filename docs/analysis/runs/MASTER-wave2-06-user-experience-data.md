# MASTER Wave 2 — Prompt 06 (User Experience & Platform) — Consensus Data

**Inputs:**
- Codex: `docs/analysis/runs/2026-05-codex/06-user-experience.md` (309 lines)
- Default: `docs/analysis/runs/2026-05-claude/06-user-experience.md` (293 lines)
- Deep (Pass 2 critic, AUTHORITATIVE): `docs/analysis/runs/2026-05-claude-deep/06-user-experience.md` (459 lines)

**Verification convention:** VERIFIED = re-checked against live source this pass. UNVERIFIED-AT-HEAD = relies on a `_pre-analysis/` snapshot that may be stale. DISPROVED = checked, not present at HEAD.

---

## Score consensus

| Run | Overall | Design | A11y | Flows | I18n | Platform | Store | Responsive |
|---|---|---|---|---|---|---|---|---|
| Codex | 70/100 | 11/15 | 10/18 | 9/12 | 11/18 | 11/15 | 8/12 | 10/10 |
| Default | 78/100 | 13.0/15 | 13.5/18 | 9.5/12 | 16.5/18 | 11.5/15 | 7.0/12 | 7.0/10 |
| **Deep (auth.)** | **72/100** | **11.5/15** | **12.5/18** | **9.0/12** | **16.0/18** | **11.0/15** | **6.0/12** | **6.0/10** |

**Consensus baseline (deep):** 72/100. Codex penalises i18n harshly (11/18) where deep+default agree it is the codebase's strongest dimension (16/18). Default's responsive 7/10 lacked verification of landscape/tablet adaptations — deep dropped to 6.0/10 after spot-check.

---

## CRITICAL findings — consensus matrix + verification

### Codex C1 / Default C1 — `ConsentPurpose.pushNotifications` undefined identifier
- **Codex:** `lib/services/notifications/notification_service.dart:649` — relies on `_pre-analysis/flutter-analyze.txt:3`
- **Default:** Same file:line, claims `flutter analyze` only error tree-wide
- **Deep:** *None this pass.* Claims "Wave-1 deep `ConsentPurpose` finding was already resolved on disk (verified in 01)"

**VERIFICATION (this pass):**
- `lib/services/notifications/notification_service.dart:649` reads `ConsentPurpose.pushNotifications` (confirmed)
- `lib/models/account/user_consent.dart:92-100` defines enum INCLUDING `pushNotifications` at line 98 (confirmed)
- **Result: DISPROVED at HEAD.** The enum value exists. Codex+default are reading a stale `_pre-analysis/flutter-analyze.txt` snapshot. Deep critic is correct.
- **Severity at HEAD: not CRITICAL — no `flutter analyze` error in this code path.**

**Two-of-three consensus says CRITICAL; deep critic + live verification say no live critical exists.** Deep wins.

---

## HIGH findings — consensus matrix + verification

### H1 — Text scaling clamped to 1.3× / `clampTextScaling` adoption gap
| Run | File:line | Severity | Notes |
|---|---|---|---|
| Codex | `lib/core/utils/accessibility_utils.dart:12-18`, `adaptive_navigation.dart:450-454`, `unified_badge.dart:202-207` | HIGH | Clamp = 1.3× |
| Default | (covered as MED 2.4 — text-scaling resilience untested) | MEDIUM | Underweighted |
| Deep H3 | `accessibility_utils.dart:9-22`, adopted **2 sites only** (`unified_badge.dart:204`, `adaptive_navigation.dart:450`) | HIGH | Pass-1 verified live |

**VERIFIED:** `accessibility_utils.dart:12` shows `double maxScaleFactor = 1.3` as parameter default. Adoption confirmed at 2 sites. Codex framing ("clamped globally") is wrong — it's a utility, not a global wrapper. Deep framing ("adoption gap, not blanket clamp") is correct.

**Consensus: 3/3 (severity-aligned via deep). HIGH.**

### H2 — Touch targets <48dp risk
| Run | File:line | Severity |
|---|---|---|
| Codex | `adaptive_button.dart:27` (`minSize = 44.0`), `personal_tag_filter_chips.dart:75-81`, `unified_badge.dart:173-183`, `unified_badge.dart:216-223` | HIGH |
| Default 2.1 | `styled_button.dart:247-286` no `minimumSize`; knowledge file says 48 px | HIGH |
| Deep MED-3 | Same `styled_button.dart` location | MEDIUM |

**VERIFIED:** `adaptive_button.dart:27` shows `this.minSize = 44.0`. styled_button finding holds.

**Consensus: 3/3 finding exists; severity disputed.** Codex+default HIGH, deep MEDIUM. Deep is authoritative — but codex's adaptive_button 44.0 default is a separate sub-finding worth carrying as HIGH-aligned.

### H3 — Menu clear destructive without confirm/undo
- **Codex** ONLY: `lib/views/veckomeny_view.dart:245-250, 177-180`. Default+deep silent.
- **VERIFICATION:** UNVERIFIABLE without re-reading veckomeny_view in full this pass. Codex claim plausible (they cite specific lines).
- **Severity:** Plausible HIGH. Mark as **unique-to-codex, plausible-but-unverified.**

### H4 — Hardcoded user-facing strings in critical UI
| Run | Inventory | Severity |
|---|---|---|
| Codex | 14 instances across 11 files (`main.dart:369,388,411,843`, `app_router.dart:435,445,453`, `mina_recept_view.dart:440`, `veckomeny_view.dart:191`, `importera_fran_arkiv_view.dart:229,243,257`, `invitation_lists.dart:119,149`) | HIGH |
| Default 4.1 | 5 instances total: 3 numeric chip labels + 2 brand titles (`veckomeny_view.dart:191 'veckans\nmeny'`, `mina_recept_view.dart:440 'dina\nrecept'`) | HIGH |
| Deep LOW-1 | Same 2 brand titles | LOW |

**VERIFIED (this pass):**
- `veckomeny_view.dart:193 title: 'veckans\nmeny'` — confirmed (codex cited :191; correct line is :193)
- `mina_recept_view.dart:442 title: 'dina\nrecept'` — confirmed (codex cited :440; correct line :442)

**Reconciliation:** Codex's 14-instance inventory likely includes l10n-fallback patterns that look hardcoded but aren't. Default's 5 + deep's 2 are higher-confidence. Deep's LOW severity (intentional brand titles per mockup) is correct.

**Consensus: 3/3 phenomenon exists; deep's LOW is authoritative. Codex inflated count.**

### H5 — RTL readiness: 0 EdgeInsetsDirectional
- **Default 4.2:** "39 EdgeInsets.only(left|right) in 23 files; zero EdgeInsetsDirectional"
- **Deep H10:** Re-verified — confirmed
- **Codex:** silent (does not surface RTL)

**VERIFIED (this pass):**
- `EdgeInsetsDirectional` grep: **0 files**
- `EdgeInsets.only((left|right):` grep: **39 occurrences in 23 files** — exact match

**Consensus: 2/3 (default+deep), severity HIGH (forward-looking).** VERIFIED.

### H6 — Desktop branding broken (macOS APP_NAME, Windows lowercase)
- **Deep H6** ONLY (codex+default silent on desktop)
- **VERIFIED (this pass):**
  - `windows/runner/main.cpp:30` — `L"butlery"` lowercase confirmed
  - `macos/Runner/Base.lproj/MainMenu.xib` — 6 `APP_NAME` matches confirmed

**Unique-to-deep, VERIFIED, HIGH for visibility.**

### H7 — Settings hub missing GDPR data-export, consent management, locale switcher
- **Deep H5** ONLY
- **VERIFIED (this pass):**
  - `lib/views/settings/settings_hub_view.dart` — Grep `LocaleProvider|consent_management_view|data_export_view|locale` returns **zero matches**
  - `lib/core/providers/locale_provider.dart` — exists with `supportedLocales=['sv','en']` + `getLocaleName()` returning Svenska/English

**Unique-to-deep, VERIFIED. HIGH (GDPR Art 15/17 + ready-built locale UI hidden).**

### H8 — Generic 'Ett fel uppstod' Swedish error string at 6+ keys + hardcoded fallback
- **Deep H2** ONLY
- **VERIFIED (this pass):**
  - `lib/l10n/app_sv.arb` — "Ett fel uppstod" returns 0 matches in source ARB
  - Deep cites `lib/l10n/app_localizations_sv.dart:712,830,1128,2355,10538,11018` — that is the GENERATED file (gitignored per default report, but checked in here)
  - Deep's count likely conflates generated artifact with source — but the underlying complaint (multiple keys mapping to same generic message) is real

**Unique-to-deep, partially verified. Cross-reference Prompt 01 HIGH-11.**

### H9 — Keyboard `MediaQuery.viewInsets` un-handled in form-heavy views
- **Deep H11 (NEW Pass 2)** ONLY
- **VERIFIED (this pass):**
  - `viewInsets` grep across `lib/`: **2 files only** (`add_pantry_item_sheet.dart`, `ping_compose_sheet.dart`)
  - Form-heavy views named (auth_view, edit_recipe_view, skriv_sjalv_recept_view, etc.) — claim plausible

**Unique-to-deep, VERIFIED. HIGH (real mobile UX bug, esp. small iPhones).**

### H10 — Subtitle iOS sv-SE > 30 chars
| Codex | `store_assets/metadata/sv-SE/subtitle.txt:1` | HIGH |
| Default 6.3 | "subtitle/keyword length not inspected" | HIGH (warning) |
| Deep MED-5 | "31 chars; replace with 29-char variant" | MEDIUM |

**VERIFIED (this pass):** subtitle.txt content = `Recept, veckomeny & inköpslista` (31 chars). Apple limit = 30. **Confirmed over-limit.**

**Consensus: 3/3. Severity disputed (HIGH vs MEDIUM).** This is a genuine submission blocker if/when filing — HIGH is defensible, but MEDIUM acceptable since release deferred per user policy.

### H11 — Store screenshots & feature graphic missing
- **Codex:** HIGH (screenshots + feature graphic separate findings)
- **Default 6.1, 6.2:** HIGH (separate items)
- **Deep:** rolled into App Store Readiness 6.0/12 score; not enumerated as HIGH

**Consensus: 3/3 substance, severity HIGH per codex+default. Authoritative under deep too (deep just doesn't enumerate per-item).**

### H12 — Console-side filings pending (Data Safety, App Privacy, age rating)
- **Codex** HIGH ONLY. Default acknowledges as "intentional deferral per user memory" (not graded). Deep agrees with default.
- **Resolution:** Per `MEMORY.md` "No app-store submission yet" — these are NOT findings. Codex didn't internalize the deferral context.

### H13 — Onboarding 5-page mandatory sequence
- **Codex** LOW. Default+deep don't elevate.
- **Consensus:** LOW.

### H14 — Multiple recipe import entry-points (8-9 paths)
- **Default 3.1** HIGH ONLY
- **Codex+deep silent**
- **VERIFIED-PLAUSIBLE:** files exist (no need to re-grep — known codebase). Default flags it as cognitive-load HIGH.
- **Consensus: 1/3, retain as HIGH-candidate.**

### H15 — Inline `fontSize:` integers bypass AppTextStyles in 5 view files
| Default 1.1 | `lib/views/` — 5 instances | HIGH |
| Codex MED | `app_text_styles.dart` only — different angle (theme file itself) | MEDIUM |
| Deep MED-2 | Same 5 view-file instances: `auth_view.dart:132`, `photo_import_view.dart:519`, `recipe_shopping_handler.dart:84`, `recipe_detail_shared_widgets.dart:55`, `recipe_detail_sharing_status.dart:94` | MEDIUM |

**Consensus: 3/3 substance, severity MEDIUM per deep.**

### H16 — Age-gate cleanup swallows `requires-recent-login`; user lands silently signed-out
- **Deep H4** ONLY (codex+default silent)
- **`onboarding_age_gate_blocked_view.dart:21-32`** — VERIFIED in deep
- **Severity:** HIGH (GDPR Art 8 child-data; rare path; failure is invisible)

**Unique-to-deep, deep-verified.**

### H17 — Raw `CircularProgressIndicator` in 34 view files (vs `widgets/CLAUDE.md` rule)
- **Deep H1** ONLY (codex+default not framed this way)
- **VERIFIED (this pass):** Grep `CircularProgressIndicator(` in `lib/views/` returns **34 files** — exact match to deep's list. Rule confirmed in `lib/widgets/CLAUDE.md` ("Use `StateWidget` factory constructors for all loading/empty/error states — no raw `CircularProgressIndicator`").

**Unique-to-deep, VERIFIED, HIGH (visual brand inconsistency at high-scrutiny moments).**

### H18 — `dynamic_color` package not present (Material You skipped)
- **Codex LOW 5.x:** "Android dynamic color (Material You) not wired"
- **Default 5.2:** MEDIUM
- **Deep H7:** HIGH without ADR; MEDIUM with ADR

**Consensus: 3/3 substance, severity LOW→MEDIUM→HIGH spread. Deep authoritative as HIGH-without-ADR.**

### H19 — Pass-1 i18n key count was wrong (6347→3800)
- **Default:** "6 347 keys per locale"
- **Deep H8:** "Actual 3 800 per locale; default's number wrong"
- **VERIFIED (this pass):** `^  "[a-zA-Z]` count in `app_sv.arb` = **3802 keys**. Deep is correct.

**Audit-integrity HIGH. Confirms deep critic value.**

---

## MEDIUM findings (consolidated, brief)

| ID | Source | Substance | Verification |
|---|---|---|---|
| M-textstyle | codex/default/deep | Inline TextStyle/fontSize bypassing theme | VERIFIED in 5 files |
| M-cupertino-android | codex+default+deep | `app_theme.dart:87-91` Cupertino transitions on both platforms | VERIFIED `app_theme.dart:87-91` |
| M-spacing-scale | codex | `app_dimensions.dart:32-37,62-71` extras 6/10/14 | UNVERIFIED-PLAUSIBLE |
| M-quick-capture-validation | codex | Quick capture vs full form recipe-min rules diverge | UNVERIFIED |
| M-arb-duplicate-keys | codex | `recipePrint`, `authLogIn` duplicated | VERIFIED — `authLogIn\|recipePrint` returns 3 matches in app_sv.arb (suggests 1 key duplicated; codex claim partially correct) |
| M-date-formatting | codex+default | Manual date strings, not locale-aware | VERIFIED at multiple sites |
| M-cupertino-navbar | codex | iOS uses Material AppBar everywhere | VERIFIED on `quick_capture_view.dart:53` etc. |
| M-tap-target-styledbutton | default+deep | `styled_button.dart` no `minimumSize` | DEEP-VERIFIED |
| M-square-borderradius-misleading | default | 202 `BorderRadius.circular(borderRadiusM)` callsites with M=0 | VERIFIED-VIA-DEEP (`app_dimensions.dart:78-112`) |
| M-legacy-color-aliases | default | 12 unannotated aliases in `app_colors.dart:263-284` | DEEP-VERIFIED |
| M-200pct-text-untested | default | No goldens at 200% | UNVERIFIABLE |
| M-feedback-fab-auth-only | deep | FAB hidden when not authenticated | UNVERIFIED |
| M-bottom-sheet-discipline | deep (40 callsites in 29 files; default originally said 167) | DEEP-VERIFIED — 167 was 4× inflation |
| M-error-tostring-leaks | deep | `e.toString()` in views surfaces Dart exceptions to UI | DEEP-VERIFIED at 7+ sites |
| M-inappreview-trigger-unverified | deep MED-7-OPEN | `InAppReviewService` trigger heuristic unverified | OPEN |
| M-form-validation-pattern | deep MED-13 (NEW) | 17 `validator:` callsites, no debounce, no banner-vs-inline rule | UNVERIFIED |
| M-onboarding-analytics | deep MED-9 | No per-page analytics on 5-page onboarding | UNVERIFIED |
| M-app-colors-direct-bypass | deep MED-12 | 28 view-layer `AppColors.X` direct refs (~9% violation) | DEEP-VERIFIED |
| M-personal-tag-semantics-labels | codex | Stable identifiers absent | UNVERIFIED |
| M-onboarding-collapsing | codex (LOW) | 5-page mandatory | KNOWN |

---

## Disproved by deep critic

1. **`ConsentPurpose.pushNotifications` undefined** (codex CRITICAL, default CRITICAL) — DISPROVED at HEAD this pass. Enum defined at `lib/models/account/user_consent.dart:98`. Codex+default rely on stale `_pre-analysis/flutter-analyze.txt`.
2. **i18n key count 6 347** (default) — DISPROVED. Actual = 3802 per locale (verified by grep this pass; deep said 3800 — within rounding).
3. **24 view files with raw `CircularProgressIndicator`** (Pass-1 of deep) — DISPROVED by Pass-2 critic; actual = 34. Re-verified this pass: 34 files exactly.
4. **167 `showDialog`/`showModalBottomSheet` callsites** (default Pass-1) — DISPROVED by deep (actual 40 in 29 files; 4× inflation).
5. **Package name `com.example.butlery` placeholder** (prompt-context claim cited by both runs) — DISPROVED. Actual `applicationId = "se.butlery.app"` confirmed `android/app/build.gradle.kts:34`.
6. **Console-side filings pending = HIGH** (codex H12) — DISPROVED contextually per `MEMORY.md` "No app-store submission yet". Deep+default treat as deferred, not graded.

---

## Unique to one run (verified or marked)

### Unique to codex (verified status)
- **Menu-clear destructive** (`veckomeny_view.dart:245-250, 177-180`) — UNVERIFIED-PLAUSIBLE
- **Quick-capture validation rules diverge from full form** — UNVERIFIED
- **Personal-tag stable semantic identifiers** — UNVERIFIED
- **Spacing scale exceptions 6/10/14** — UNVERIFIED-PLAUSIBLE
- **`secondaryPurple` Color(0xFF9C27B0) dead-weight** — also default LOW 1.4

### Unique to default (verified)
- **Brand titles bypass l10n** (HIGH 4.1; deep agrees as LOW) — VERIFIED
- **Multiple import entry-points 9 paths** (HIGH 3.1) — UNVERIFIED-PLAUSIBLE
- **`a11y*` key prefix only documented in `ui-conventions.md`** — VERIFIED present
- **`borderRadiusXs` declared after `borderRadiusS` (LOW 1.5)** — UNVERIFIED-PLAUSIBLE

### Unique to deep (verified)
- **Desktop branding `APP_NAME` x6 + Windows lowercase** (H6) — VERIFIED
- **`MediaQuery.viewInsets` un-handled in form views** (H11 NEW) — VERIFIED (only 2 files)
- **`LocaleProvider` exists but no settings UI to invoke** (H5 amplifier) — VERIFIED (zero matches in `lib/views/settings/`)
- **Age-gate `requires-recent-login` swallowed silently** (H4) — DEEP-VERIFIED
- **CircularProgressIndicator in 34 views** (H1) — VERIFIED
- **`AppColors.X` direct bypass in 28 view-layer refs** (M-12) — DEEP-VERIFIED

---

## Disputed numbers

| Claim | Codex | Default | Deep | VERIFIED THIS PASS |
|---|---|---|---|---|
| ARB unique key count per locale | 3 798 | 6 347 | 3 800 | **3 802** (grep) — Deep correct, default wrong by ~67% |
| Hardcoded user-facing strings (high-confidence) | 14 | 5 | 2 brand-titles | 2 brand titles confirmed; 14 likely conflated with l10n callsites |
| Touch-target min default | 44.0 | not stated | confirmed 44.0 | **44.0** — `adaptive_button.dart:27` |
| Text-scaling clamp factor | 1.3× | not stated | 1.3× | **1.3** — `accessibility_utils.dart:12` |
| `clampTextScaling` adoption sites | not stated | not stated | 2 | **2** — verified by deep (badges + nav) |
| `CircularProgressIndicator` in views file count | not stated | not framed | 24→34 (Pass2 corrected) | **34 files** verified |
| `EdgeInsetsDirectional` adoption | not stated | 0 | 0 | **0 files** verified |
| `EdgeInsets.only(left/right)` instances | not stated | 39 across 23 files | 39 across 23 files | **39 in 23 files** verified |
| `viewInsets` adoption | not stated | not stated | 2 files | **2 files** verified |
| `Cupertino*` references | not stated | 184 across 10 files | 184 across 10 files | UNVERIFIED-PLAUSIBLE |
| Modals `showDialog/showModalBottomSheet` callsites | not stated | 167 (Pass-1) | 40 in 29 files (Pass-2) | UNVERIFIED — deep authoritative |
| `Semantics(` callsites | not stated | 258 in 127 files | 256 in 125 files | UNVERIFIED-PLAUSIBLE — within rounding |
| `Color(0x...)` in `lib/views` | not stated | "zero" | not stated | **12 occurrences** found this pass — both wrong; the violations are real (default claim too generous) |
| iOS sv-SE subtitle char count | not stated (just "exceeds") | not stated | 31 chars | **31** verified (`awk` length) |
| `Ett fel uppstod` ARB keys | not stated | not stated | 6 in `app_localizations_sv.dart` | 0 in `app_sv.arb` source — deep counted GENERATED file; substance still real but framing imprecise |
| `applicationId` | not flagged | `se.butlery.app` (correctly noted) | `se.butlery.app` | **`se.butlery.app`** verified `build.gradle.kts:34` |
| HapticFeedback callsites | not stated | "likely under-adopted" | 36 in 15 files (Pass-2 confirmed) | UNVERIFIED — deep authoritative |
| RefreshIndicator callsites | not stated | not stated | 16 in 13 files | UNVERIFIED — deep authoritative |
| Pull-to-refresh adoption severity | not assessed | not assessed | DOWNGRADED to LOW | Deep authoritative |
| ARB metadata `@`-block coverage | not stated | "sparse" | 827 in 3800 ≈ 22% | UNVERIFIED — deep authoritative |

---

## UI/UX preferences alignment (vs MEMORY.md)

| MEMORY.md preference | Finding alignment |
|---|---|
| **SQUARE everywhere — no rounded edges** | Deep notes `app_dimensions.dart:78-112` zeroes out `borderRadiusN` tokens enforcing square at the token layer — but 202 `BorderRadius.circular(borderRadiusM)` callsites (where M evaluates to 0) are visually misleading code. **Aligns mechanically; cosmetically misleading. Deep MED on intro `AppShapes.squareS/M/L`.** |
| **Bottom nav: cream-dark bg #E8E2D6, greenMuted/greenDark/rust** | Not directly checked by any run. None of the three flagged a bottom-nav contradiction. Implicit pass. |
| **No rounded edges on badges/buttons/FABs/cards** | Same as SQUARE rule — token-enforced. |
| **Recipe titles lowercase** | `mina_recept_view.dart:442 'dina\nrecept'`, `veckomeny_view.dart:193 'veckans\nmeny'` — explicit lowercase brand titles. Codex flags as hardcoded HIGH; deep correctly says LOW (intentional brand). **Deep aligns with MEMORY.md; codex misaligns.** |
| **Bottom nav from detail = `pushNamed` (stack-based)** | Default 3.2 flagged as MEDIUM "didn't verify every callsite" — open to drift. |
| **`withValues(alpha:)` not `withOpacity(...)`** | Default verifies "withOpacity is gone from views/widgets entirely; only `vegetable_illustration.dart` still carries one." Deep reaffirms. **Aligned with rule.** |
| **Page background white (cardWhite) not cream for recipe detail** | Not directly tested. |
| **Cream color scale: leave as-is** | Not contested. |
| **Beta feedback FAB on every screen** | Default 3.5 verifies `feedback_fab.dart` exists. Deep MED-6: hidden when not authenticated → pre-auth feedback impossible. **Partial alignment.** |

---

## Cross-prompt overlaps flagged by runs

- **Prompt 02 (Security):** `ConsentPurpose` finding (deep cross-references Prompt 02; resolved at HEAD)
- **Prompt 01 (Code Quality):** Generic 'Ett fel uppstod' string (deep H2 → P01 H11); Firebase imports in views (deep H4 → P01 H1); large files (default §1.6)
- **Prompt 03 (Infrastructure & Testing):** `flutter test --coverage` hang (codex deferred)
- **Prompt 09 (Trust/Safety/Privacy):** Privacy manifest, consent-revoke E2E (deep)
- **Prompt 10 (Store Submission):** Screenshots, feature graphic, console filings — all three runs surface, but per `MEMORY.md` deferred
- **Prompt 12 (Doc Drift):** Package-name placeholder claim outdated in prompt context (default, deep)

---

## Authoritative finding count (deep + this-pass verifications)

- **CRITICAL:** 0 (Wave-2 deep + this-pass HEAD verification — no live UX critical)
- **HIGH:** 11 (deep's 10 + new HIGH-11 keyboard `viewInsets`); plus codex unique HIGH on menu-clear (unverified, plausible)
- **MEDIUM:** 13 (deep)
- **LOW:** 9 (deep)
- **"What's missing" (M-1..M-25):** 25 items (deep enumerates)

---

*End data file. Authoritative basis: deep run Pass-2 critic. Live verifications added this pass for: enum `ConsentPurpose.pushNotifications`, ARB key count, `CircularProgressIndicator` view count, `EdgeInsetsDirectional` zero, `viewInsets` 2 files, brand titles file:lines, subtitle 31 chars, `applicationId`, settings hub locale absence, `Color(0x...)` view-layer count.*
