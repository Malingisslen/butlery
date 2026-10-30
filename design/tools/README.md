# design/tools

The Node generators behind `lib/theme/`. Run from `design/`:

| Script | What it does |
|---|---|
| `gen-app-theme.mjs`, `gen-app-theme-dark.mjs` | Write the raw colour and type files to `design/lib/theme/`; `dart run tools/design_theme.dart` (repo root) drives them and writes the formatted copies to the app. |
| `gen-flutter.mjs`, `gen-css.mjs` | Token output for Flutter and CSS; `--check` fails on drift. |
| `test-generated.mjs`, `test-generated-dark.mjs` | The generation contracts. |
| `check-app-theme.mjs` | Checks `app-theme-map.json` against the tokens. |
| `tools/generate_brand_assets.dart` (repo root) | `dart run` it. Writes every launcher icon, splash image, store icon and web icon from `design/brand-mark.json`; `test/architecture/brand_mark_single_source_test.dart` fails on drift. |
| `gen-lab-icons.mjs`, `apply-lab-export.mjs` | Design lab helpers (`mockup-kit/README.md`). |
