# Sprint Backlog

## Sprint: iter-56 — BUT-898 cooking-mode title fontScale — 2026-05-24 (Sun)

Theme: Trivial WCAG 1.4.4 bug fix. Plan-fil FÖRST per discipline.

### Step 0 — premise verification

- `lib/views/cooking_mode_view.dart:143` — title uses `AppTextStyles.headerTitle.copyWith(color: ..., letterSpacing: 1)`. No fontSize multiplier.
- Lines 560, 586 — body content multiplies `AppTextStyles.X.fontSize! * vm.fontScale`. Pattern confirmed.
- Bug real: 1.25× user font-scale → step text scales, title doesn't. WCAG violation.

### Design choices

- Apply the same `fontSize! * vm.fontScale` multiplier to the title. Pattern is established.
- `AppTextStyles.headerTitle` must have `fontSize` (assume non-null per the body sites; verify).
- Test: hard to widget-test without spinning up the whole cooking-mode VM; covered by existing visual smoke + the body sites' pattern is the implicit pin.

### Ship this sprint

- [ ] **A1. BUT-898** — Apply `fontSize: AppTextStyles.headerTitle.fontSize! * vm.fontScale` in title's copyWith.

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] Title scales 1× / 1.25× / 1.5× along with body text.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Stäng BUT-898 i Linear → Done

---

## Archived iter-55 (commit `1249b01f6`) — 2026-05-24 (Sun)

BUT-899 unit-converter negative-quantity consistency. 8 thresholds + 1 new test (9 sub-cases). +88 / -36. BUT-899 → Done.
