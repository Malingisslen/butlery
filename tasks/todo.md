# Sprint Backlog

## Sprint: icon-convention enforcement (BUT-1213 enforce half) — 2026-06-08 (iter-134) `[Tier A]`

**Step 0:** FITS. BUT-944 follow-up. Frontier-iteration pick: the one genuinely-clean shippable
thing from the iter-133 steer. Enforcement half is Tier A tooling (no design decision); the colour
half stays for Malin → BUT-1213 parks In Review.

### Agent A: icon convention guard + missed migrations (BUT-1213)
- [x] **A1. Fix 3 concept sites BUT-944 missed** `[Tier A]` — `shopping_sharing_status_dialog.dart` + `shopping_list_card.dart` (template `Icons.bookmark` → `AdaptiveIcons.savedTemplate`), `edit_actions_panel.dart` ("set primary" `Icons.star_outline` → `AdaptiveIcons.primaryOutline`). analyze clean; 73/73 widget tests pass. (BUT-1213)
- [x] **A2. CI guard `tools/check_icon_convention.sh`** `[Tier A]` — hard-fails on raw `Icons.favorite*`/`Icons.bookmark*` in lib/views|lib/widgets (regex `Icons\.(favorite|bookmark)(_[a-z]+)*\b`, excl adaptive_icon.dart). Star deliberately un-gated (overloaded: rating/sort/dietary/permission). Proven exit 1 on violation, 0 clean. Wired into `architecture-validation.yml`. (BUT-1213)

### Deferred (BUT-1213 colour half — needs Malin)
Colour rule for favourite/like (red vs theme-default) — stays open; BUT-1213 → In Review.

### Post-Sprint Steps
- [x] analyze + format clean; code-reviewer + testing-specialist LGTM
- [ ] Commit, push; BUT-1213 → In Review + notify

---
## ARCHIVED — iter-133 (BUT-1216 foundation filed; frontier) · iter-132 (BUT-925 groomed) · iter-131 (BUT-906 In Review) · iter-130 (BUT-901 In Review)
