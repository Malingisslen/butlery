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
