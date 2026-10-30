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
BUT-2202). It is the source of truth, together with the golden views in `test/` and the guard tests
in `test/architecture/`; nothing else describes how a view should look.

- **A colour, type or token change** is made in `design/tokens.json` (and
  `design/tools/app-theme-map.json` for a new member), then
  `dart run tools/design_theme.dart` regenerates `design/lib/theme/` and writes the
  formatted copies to `lib/theme/`. Commit both. Never edit `app_colors.dart`,
  `app_colors_dark.dart` or `app_text_styles.dart` by hand: the Design system workflow
  runs `--check` and goes red.
- **A new glyph** is added to `design/icons.json` and drawn as
  `design/assets/icons/<name>.svg`, then `dart run tools/generate_butlery_icons.dart`
  and `dart format lib/widgets/common/icons/butlery_icons.dart`.
- `design/lib/theme/*.dart` stay unformatted and outside the analyzer.
- The design tools are Node scripts run from `design/`
  (`cd design && node tools/...`); the Design system workflow runs the same checks.
- **Mockups** are built from `design/mockup-kit/` (README there). After a token, glyph
  or component change, run `dart run tools/mockup_kit.dart`; CI runs `--check`.

## The top of a screen

One rule per kind of view. A view does not pick its own bar, colour, title size or rule
line; it picks the kind, and the shared component draws it (`ButleryPage`,
`ButleryTopBar`). Decided by Malin 2026-10-11/12: Hem has no bar, every subpage has the
light bar (B-60), the tab bar shows on every page reached from a tab (B-54).

| Kind of view | Top | Carried by |
|---|---|---|
| Hem | No bar. Only the heading "Dina recept · N" in the page. | page heading, never a bar |
| Main tab (Meny, Inköp, Mer) | Root bar: paper, 26/700 title, optional second line, at most two actions, tabs directly under as underlined text tabs | `ButleryPage.rot` |
| Subpage (anything reached from a tab) | Light bar: back arrow named "Tillbaka till X", 14/700 title, at most two actions, then the saffron dash with a hairline, close under the title (drawn by the bar, `accentRule`) | `ButleryPage.undersida` |
| Form (recipe editor, family member, new group) | The subpage bar, no tab bar, Spara in the footer, never in the bar | `ButleryPage.undersida(showTabBar: false)` |
| Selection mode | The same bar changes content, never height: "Avbryt" replaces the arrow, "N valda" replaces the title | `ButleryCancelSelectionButton` as the bar's `leading`; the selection bar is still built per view |
| Media page (recipe with photo) | Arrow and actions as round buttons over the photo, title under it. Without a photo the same buttons sit bare on paper | `RecipeHeroButton` row |
| Focus mode (cooking, onboarding, sign-in, guest) | No `ButleryTopBar`. Cooking keeps its ink band; onboarding and sign-in at most one text action on the right | the view's own focus surface |

- A new view starts from this table. A bar that fits none of the rows is a question for
  Malin, not a new variant.
- The rule is on by default for every `ButleryTopBar.undersida`. A modal bar (the photo
  viewer) or a main-tab bar built with `implyBack: false` passes `accentRule: false`.
- `titleStyle`, `backgroundColor` and `foregroundColor` on `ButleryTopBar` are not for
  views. A view that needs one has found a missing row. The one sanctioned `titleStyle` is
  `ButleryTopBar.selectionCountStyle`, for the count while a list is in selection mode.
- `test/architecture/top_bar_choice_test.dart` lists the files that still construct
  `ButleryTopBar` themselves. The list only shrinks: a new view uses `ButleryPage`.

## Primary button colour by place

Decided by Malin (megagenomgången, B-158): saffron (`HeroButton`) opens a flow; dark green
(`FormButton`) is the primary on forms and account pages.
`test/architecture/primary_button_by_place_test.dart` pins where saffron may be drawn.

- **Exception, Malin 2026-10-28:** the Inköp add button and its empty-state button stay
  saffron (`HeroButton`) as drawn, because a list is neither a form nor an account page.
  They are pinned as `_shoppingButtons` in that test.
