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
