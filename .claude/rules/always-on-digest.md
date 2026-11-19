# Always-on digest of path-scoped rules

Cloud threads do not load rules that have `paths:`. These are the short versions;
the full rule file is the authority, so open it before acting on anything here.

## Accepted deviations (full: `accepted-deviations.md`, `docs/architecture/ACCEPTED_DEVIATIONS.md`)

- Before filing a review finding or proposing "cleanup" of safety, privacy, GDPR-export or
  allergen behaviour, grep the verdict file for the ticket or topic. A decided call is not
  re-proposed. A newer line marked SUPERSEDES wins over the one it names.
- A new deviation is appended to both files in the same edit.

## Design system (full: `design-system.md`)

- Never hand-edit `lib/theme/app_colors*.dart` or `app_text_styles.dart`: change
  `design/tokens.json`, run `dart run tools/design_theme.dart`, and stage both outputs.
- A new view picks a top-bar kind from the table in the full rule (`ButleryPage`); it
  never sets its own bar, title style or colours. No fit means ask Malin.
- Cloche looks and primary-button colour are decided per place; a new place is a
  question for Malin, not a new variant.
- Mockups start from `design/mockup-kit/`, never from today's views.
