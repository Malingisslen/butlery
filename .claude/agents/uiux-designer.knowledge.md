# uiux-designer — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every UI task and **APPEND** to it when it discovers a
new pattern, decides a new design rule, or is corrected by the user.

## How to update this file

- **Append-only** — never delete entries; supersede with a newer dated entry.
- **Date every entry** — `### YYYY-MM-DD — short title`.
- **Be terse** — 1–3 sentences plus a code/value excerpt where it helps.
- **One concept per entry** — easier to supersede later.

---

## Design language (mockup-driven)

**Square everywhere, never rounded.** Badges, buttons, FABs, cards — all
square corners. Don't introduce `borderRadius` unless replacing a clearly
broken rounded element with a square one.

**Page background**: white (`cardWhite`), not cream, for content surfaces.
Cream (`#E8E2D6`) is for the bottom navigation bar and a few accent
surfaces. Don't realign the cream scale to mockup values — leave as-is.

**Recipe-detail-specific:**
- Recipe titles render lowercase via `.toLowerCase()` on detail page.
- Hero buttons: solid cream squares with green icons — keep.
- "Lagat idag" chip stays in the metadata row even though it's not in the
  mockup; it's useful information.
- No-image recipe state: dark green gradient (`forestGreen` →
  `forestGreenDark`) with illustration. Do NOT show a generic placeholder.
- Collapsed `SliverAppBar`: white/surface background (Material default).

## Color system

Primary palette (do not invent new colors — extend from these):

| Token | Value | Use |
|---|---|---|
| `forestGreen` | brand green | Primary accents, success states |
| `forestGreenDark` | darker green | Gradients, pressed states |
| `greenMuted` | desaturated green | Bottom-nav inactive icons |
| `greenDark` | dark green | Bottom-nav active icons |
| `rust` | warm rust | Underlines, decorative borders, accent strokes |
| `cardWhite` | white | Page backgrounds, content cards |
| `cream-dark` | `#E8E2D6` | Bottom nav background |
| `warning` | `#D4A03C` | Warnings (warm gold, not amber) |
| `success` | alias to `forestGreen` (`#4A7C59`) | Success states |

**Text colors** — use pure grays, NOT blue-gray tints:
`#1A1A1A` / `#666666` / `#999999`.

**Rating badge** stays green pill (NOT the gold from the mockup).

## Component conventions

- **Recipe card**: 64×64 image, 4px green left border, 3px rust bottom border.
- **Add-recipe grid**: diagonal color pattern (rust-green / green-rust).
- **Search box**: ONE component with green+rust border treatment. Merge
  duplicate implementations rather than maintain two.
- **Buttons**: 48px min-height for mobile touch ergonomics — keep even
  though it's larger than the mockup.

## Allergen badges

- **UNKNOWN status** is intentionally hidden. Only render `FREE` and
  `CONTAINS` badges. Do NOT add an "unknown" pill back without explicit
  approval.

## Bottom navigation

- **Background**: cream-dark (`#E8E2D6`), same everywhere — no per-view
  override even on detail screens.
- **Inactive icons**: `greenMuted`. **Active icons**: `greenDark`. Active
  underline: `rust`.
- **All detail views** must include the bottom nav, not just the recipe
  detail.
- **Navigation behavior** from a detail view: `pushNamed` (stack-based);
  Back returns to the detail page. Do NOT replace.

## Microcopy & locale

- App UI is **Swedish** — keep tone friendly, action-oriented, encouraging.
- All comments in code stay English; only user-facing strings are Swedish.
- Empty states should guide; error states should help recovery.

## Accessibility floor

- 48dp touch targets (already enforced via button min-height).
- 4.5:1 contrast for body text.
- `Semantics` on every interactive element.
- Focus order matches reading order.
- Test with TalkBack/VoiceOver before declaring an accessibility task done.

## Modern Flutter syntax

- `withValues(alpha: 0.8)` — NOT `withOpacity(0.8)` (deprecated).
- Theme values via `Theme.of(context)` / `context.butleryColors` — never
  hardcode hex in widgets.

---

## Discovered patterns

*Append new dated entries below as the agent learns them.*

### 2026-04-25 — initial seed
Knowledge file created from accumulated UI decisions in `MEMORY.md`
(2026-02-17 mockup-driven block) and the existing agent description.
Future entries should record genuinely new design decisions, not
re-derivations of what's already here.

### 2026-04-29 — a11y audit-driven sweep pattern (BUT-739, follow-up to BUT-697)

**Trigger:** Closing residual unwrapped tap targets surfaced by
`tools/audit_unwrapped_tap_targets.dart` after the BUT-697 chunk-1..8
sweep. Audit flagged 24 candidates; 13 were real wraps, 11 were
systematic false positives (heuristic limit — not bugs in the audit).

**Workflow that worked:**
1. Run audit script first — produces a fixed list of `file:line  WidgetType` candidates.
2. Triage each: read 30 lines around the line number. Decide real-vs-false-positive.
3. Apply the canonical pattern only to real candidates:
   ```dart
   Semantics(
     label: context.l10n.a11y<Key>,
     button: true,
     // toggled: <bool>   for expand/collapse
     // selected: <bool>  for radio-style pickers
     child: InkWell(...) /* or GestureDetector(...) */,
   )
   ```
4. Add localized keys to **both** `app_sv.arb` and `app_en.arb`,
   matching the existing `a11y*` style and placeholders.
5. Run `flutter gen-l10n` once after all keys are added.
6. Per-chunk widget test in `test/widget/widgets/chunkN_semantics_a11y_test.dart`
   covers the most user-facing wraps that don't need ViewModel scaffolding
   (e.g. PollMessageWidget). Heavy-scaffolded views (recipe detail,
   conversations list, shopping list) are guarded by the audit script
   plus production behavior — don't force a full provider stack into
   the test for marginal coverage.

**False-positive heuristics — the audit script naturally over-reports these:**
- `Semantics(...)` is **inside** the `InkWell`/`GestureDetector` body, not above it (e.g. `cooking_session_card.dart`, `family_presence_bar.dart`).
- The widget is **conditionally** wrapped: `semanticLabel == null ? bare : Semantics(...)` (e.g. `debounced_button.dart`, `social_builder_components.socialCard`, `lagg_till_recept_view._AddRecipeButton`).
- The tap target's only purpose is **keyboard dismissal** (`onTap: () => FocusScope.of(context).unfocus()`) — no semantic meaning to convey (e.g. `import_via_url_view.dart`, `smart_import_view.dart`).
- The widget is a **disabled placeholder** (`onTap: null`) for a future feature (e.g. `substitution_bottom_sheet.dart`).
- Parent `Semantics` lives **>10 lines** above the tap target — heuristic proximity window misses it (e.g. `recipe_card.dart`, `main_view_header.dart`, `shopping_item_tiles.dart`).

**Don't try to drive the audit count to zero.** The remaining ~12
findings on a fully-cleaned tree are stable false positives. Lowering
the heuristic threshold or expanding the proximity window risks
masking real regressions.

**Special case — class-level fixes propagate.** `_HeroButton` in
`recipe_detail_view.dart` is a private widget reused for back-button +
menu icons. Some callers wrapped it in `Semantics`, others didn't (the
back button at AppBar.leading had only a `Tooltip`). Fix at the class
itself (wrap the build output with `Semantics(button: true)`) — this
covers all callers and is testable as a unit.

### 2026-06-29 — Family consent UX: two-tier GDPR pattern review (Min familj)

**Pattern:** For children's sensitive-data consent the approved pattern is:
- Tier 1 (Art. 6, guardian, required) = green left-border card, "krävs" badge, green checkbox, only shown when `_isMinor` is true.
- Tier 2 (Art. 9, allergen health data, optional) = amber/warning left-border card, "valfritt" badge, amber checkbox when checked, prominent "känsliga hälsouppgifter" note ABOVE the checkbox, allergen chips only visible once consent is ON, always rendered regardless of age band.
- Consent-given info (edit mode) renders BELOW the allergen card, before the save button — the "Samtycke givet" banner + one-tap withdraw link.
- Withdraw link only shows when `hasAllergenConsent` is true (the guardian-consent banner is always shown in edit mode when `guardianConsent != null`).

**Bug found (2026-06-29):** The allergen card's `_consentHeader` renders the "valfritt" badge with `color: AppColors.textLight` instead of `color: AppColors.warning` (amber). Mockup uses `--text-muted` for the optional pill but the consent card title uses `color:var(--leather)` (warm brown for health), making the allergen section title visually distinct from green. Implementation uses `AppTextStyles.titleSmall` for both consent headers — the allergen card title does not adopt the amber/warning color to match the mockup's `.consent-title.health { color: var(--leather) }`.

**Also noted:** The `CheckboxListTile` for both consent cards renders a full-width hit area that includes the label text — this is correct for touch target ≥48dp.

### 2026-04-29 — Color literal centralization (BUT-690)

**Pattern:** When `theme_constants.dart` / `brand_colors.dart` carry
`Color(0x...)` hex literals, lift the literal to `lib/theme/app_colors.dart`
as a primary token, then have the original file `static const Color X = AppColors.tokenX;`.
Preserves the public API surface (`BrandColors.youtube` / `ThemeConstants.blackOverlay20`)
while eliminating duplicate hex literals — `app_colors.dart` becomes the
single source of truth.

**Don't migrate** the `ButleryColors` ThemeExtension — its values look
duplicated in light mode but the extension's purpose is the
**dark-mode pair** for every token. The light values must stay `const`
for ThemeExtension construction; AppColors aliases (e.g. `forestGreen`)
are non-const inside the extension class. Comments next to each line
document the AppColors equivalence — that's the right boundary.

**Don't migrate** per-context literals like SVG palettes
(`vegetable_illustration.dart`) or user color picker palettes
(`personal_tag_color_picker.dart`). These are decorative palettes
intentionally divorced from the brand color system.

### 2026-07-04 — Butlery-betyget pooled pill review (Increment E2, `recipe_card.dart`)

**Trigger:** Reviewing the new green community pill + demoted personal/family
pill against the approved `docs/design/previews/butlery-betyget-pill-preview.html`
("green + slate" pairing).

**Check for a dedicated decorative token before reusing a status token for a
star glyph.** `_buildPooledPill` colors its star with `context.butleryColors.warning`
(`#D4A03C`, the semantic warning/banner token). The app already has
`butleryColors.starGold` (`#FBBF24` light / `#FFD54F` dark) used by every other
star-rating glyph (`star_rating_row.dart`, `recipe_detail_metadata.dart`,
`cooking_session_card.dart`). Reusing `warning` for decoration conflates two
unrelated tokens and produces a second, slightly different gold in the same
visual family. Rule going forward: grep for an existing decorative token
(`starGold`, etc.) before defaulting to the nearest semantic-status color.

**"Demote to neutral" needs matching visual weight, not just a color swap.**
The approved mockup's slate personal pill is a *light, thin-bordered,
near-white* pill (`rgba(44,44,44,.06)` fill + border) — deliberately quiet so
the green community pill reads as the one flagship number. The shipped
demoted pill instead keeps the same *solid filled* treatment as the
non-demoted green pill, just swapped to `butleryColors.neutral`
(`#9CA3AF`, a fairly saturated mid-gray). Contrast is fine (≈6.8:1 vs
`onSurface` text, passes AA), but two solid-fill pills of similar darkness
compete for attention more than the mockup's filled-vs-outlined pairing
intended. When "demoting" a pill to signal secondary importance, prefer
matching the mockup's *fill treatment* (outlined/light vs filled), not just
recoloring within the same filled style.

**Mixed star glyphs read as different weights.** The pooled pill uses a
Material `Icons.star` (via `Icon`); the sibling personal rating pill
(`_buildRatingPill`) uses a literal `'★'` character inlined in the
`Text`. They can now render in the same `Wrap` row for the first time —
worth normalizing to one glyph approach when pills that show stars sit next
to each other.

**What was correct:** square corners (no `borderRadius` introduced anywhere
in this diff), Swedish butler-voice copy (`butleryBetygCount` / Swedish
"betyg", `a11yButleryBetygPill` "Butlery-betyget {rating}, {count} röster" —
no exclamation), and the semantics label wiring.

### 2026-07-04 — Butlery-betyget detail-page pills review (Increment 6b, `recipe_detail_metadata.dart`)

**Trigger:** Reviewing the two labelled pooled pills added to the recipe-detail
metadata (`_buildPooledSection` / `_buildCommunityPill` / `_buildHouseholdPill`)
against the card's E2 treatment and the approved preview.

**The demoted-pill treatment is now shared across card + detail — that's the
canonical "quiet secondary pill" pattern.** Both `recipe_card.dart`
(`_buildFamilyRatingPill(demoted: true)`, `_buildRatingPill(demoted:)`) and the
detail household pill use: transparent fill + `Border.all(cs.outlineVariant)` +
`cs.onSurfaceVariant` text/star. Prefer this over a filled neutral-gray pill or
the preview's literal light-theme `rgba` tokens — the `onSurfaceVariant` /
`outlineVariant` roles carry defined dark-theme variants, so it stays AA-safe in
both themes; a filled neutral pill fails AA in dark mode. Reuse these two roles
when "demoting" any pill to secondary weight. This session's detail pills got the
`starGold` decorative star right too (not the `warning` token that the E2 card
pill got wrong).

**Caption-case: decide brand-lowercase vs uppercase once.** `_buildLabelledPill`
renders the ARB literal verbatim (`letterSpacing: 0.5`, `w600`, no
`.toUpperCase()`), so "butlery-betyget" / "alla i ditt kök" show lowercase even
when a design note says "uppercase caption." For the brand name lowercase is
defensible (recipe titles render lowercase by design); the descriptor caption is
the ambiguous one. When a labelled-pill caption is added, don't assume uppercase —
match the ARB literal's case to the intended treatment explicitly.

**Watch overstated fallback labels.** The household pill's value is
`familyAverage ?? averageRating ?? recipe.rating`, but the caption + a11y label
("alla i ditt kök" / "Ditt köks betyg") assert a whole-household verdict. Only
`familyAverage` literally is that; the fallbacks are the per-copy aggregate (may
include non-household raters) or the user's own single star. A caption that
narrates provenance should hold across all its data fallbacks, or be softened.
