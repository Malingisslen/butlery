---
paths:
  - "design/**"
  - "lib/theme/**"
  - "lib/widgets/common/icons/**"
  - "tools/design_theme.dart"
  - "tools/generate_butlery_icons.dart"
---

# Design system

The design system is `design/` (moved in from Malingisslen/butlery-design-system,
BUT-2202). It is the source of truth; `design/NULAGE.md` says where it stands.

- **A colour, type or token change** is made in `design/tokens.json` (and
  `design/tools/app-theme-map.json` for a new member), then
  `dart run tools/design_theme.dart` regenerates `design/lib/theme/` and writes the
  formatted copies to `lib/theme/`. Commit both. Never edit `app_colors.dart`,
  `app_colors_dark.dart` or `app_text_styles.dart` by hand: the Design system workflow
  runs `--check` and goes red.
- **A new glyph** is added to `design/icons.json` and drawn as
  `design/assets/icons/<name>.svg`, then `dart run tools/generate_butlery_icons.dart`
  and `dart format lib/widgets/common/icons/butlery_icons.dart`.
- `design/lib/theme/*.dart` stay unformatted and outside the analyzer: the Block 289
  freeze hashes those bytes.
- The design tools are Node scripts run from `design/`
  (`cd design && node tools/...`). After changing any file under `design/`, run
  `node tools/gen-manifest.mjs` there, or the Fas 0 gate fails on the manifest.
- **Mockups** are built from `design/mockup-kit/` (README there). After a token, glyph
  or component change, run `dart run tools/mockup_kit.dart`; CI runs `--check`.

## Sketches stay alive

`design/screen-register.json` ties every `lib/views/**/*_view.dart` to its sketch frames
(`design/sketch-frames.json`) and a sketch-against-app image in `design/skiss-mot-app/`.
`test/architecture/screen_register_test.dart` fails a view without a row, and the count of
`ej-bedömd` rows only shrinks.

- **A new view** gets its row in the same PR, with frames and an image rendered by the
  golden harness (never hand-drawn). It cannot arrive as `ej-bedömd`.
- **A PR touching a view** puts a sketch-against-app image in its description on the line
  `Skiss mot app:` (or `ej berörd` with a reason); Malin approves the image before merge.
- **A decision that changes a view** updates the sketch or sets the row to `ersatt` /
  `avviker-beslutad`, and the decision log (`design/beslutslogg.md`) names the frames.

## The top of a screen

One rule per kind of view. A view does not pick its own bar, colour, title size or rule
line; it picks the kind, and the shared component draws it (`ButleryPage`,
`ButleryTopBar`). Decided by Malin 2026-10-11/12: Hem has no bar, every subpage has the
light bar (B-56), the tab bar shows on every page reached from a tab (B-54).

| Kind of view | Top | Carried by |
|---|---|---|
| Hem | No bar. Only the heading "Dina recept · N" in the page. | page heading, never a bar |
| Main tab (Meny, Inköp, Mer) | Root bar: paper, 26/700 title, optional second line, at most two actions, tabs directly under as underlined text tabs | `ButleryPage.rot` |
| Subpage (anything reached from a tab) | Light bar: back arrow named "Tillbaka till X", 14/700 title, at most two actions, then the 2 px ink rule | `ButleryPage.undersida` |
| Form (recipe editor, family member, new group) | The subpage bar, no tab bar, Spara in the footer, never in the bar | `ButleryPage.undersida(showTabBar: false)` |
| Selection mode | The same bar changes content, never height: "Avbryt" replaces the arrow, "N valda" replaces the title | one shared selection bar |
| Media page (recipe with photo) | Arrow and actions as round buttons over the photo, title under it. Without a photo the same buttons sit bare on paper | `RecipeHeroButton` row |
| Focus mode (cooking, onboarding, sign-in, guest) | No `ButleryTopBar`. Cooking keeps its ink band; onboarding and sign-in at most one text action on the right | the view's own focus surface |

- A new view starts from this table. A bar that fits none of the rows is a question for
  Malin, not a new variant.
- `titleStyle`, `backgroundColor` and `foregroundColor` on `ButleryTopBar` are not for
  views. A view that needs one has found a missing row.
- The inventory behind the table is in `/mnt/project-files/topfalt/` (2026-10-12).
