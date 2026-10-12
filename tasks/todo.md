# Adminpanelen v17: ny ram, samma flikar (2026-10-12)

Malin chose "Ny ram, samma flikar" on the card in the thread "Mer och undersidorna"
(2026-10-12 09.34). Sketch: `design/skiss-mot-app/17-admin.png`, frame
`del_3_sok_och_skalbevis#29`. The panel is web-only and admin-only. Router tier: single
(Software Architect, Product Manager); no sensitive domain, no data, rules or auth change.

No architecture-changing unknowns. Assumptions: the six tabs and their data stay; Moderering
is not added; the statistic tiles show what the Feedback tab already holds (new, in progress,
resolved among the loaded reports), not new queries.

## Shared parts (one place each, every tab uses them)

- `AdminTopBar`: dark bar with "Butlery Admin", the six tabs as text with an underline on the
  selected one, and the signed-in e-mail with a sign-out button on the right. Replaces
  `AdminRail` in `admin_shell.dart`. Scrolls sideways when narrow.
- `AdminTabHeader`: the title and the tab's own actions (refresh, export) as a light header
  row. Replaces the per-tab `ButleryTopBar.undersida` in feedback, metrics, ops log and
  parsing so there is one dark bar, not two.
- `AdminStatCard`: restyled to the sketch tile (rule above, overline label, big value). Every
  tab's tiles change with it.
- Feedback rows: a table row per report with the existing detail and status control.

## Verification

Analyze, the admin tests (`test/widget/views/admin`, `test/unit/viewmodels/admin`,
`test/widget/admin`), a rendered image of the Feedback tab at web width for the PR, and the
design-state hosts for the admin screens.

## Summary for Malin

The admin panel gets the sketch's look: a dark bar across the top with the tabs, four
summary tiles, and feedback as a table where you click a row to open it. The six tabs and
what they show stay as they are. The "Moderering" tab from the sketch is not added.
