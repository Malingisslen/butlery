# tasks/todo.md

## 2026-07-16 parallel-sprint pile — status

**Shipped to main this session (each reviewed cold + fixed, tests green):**
- BUT-1611 — per-meal weekly-menu presence (rebuilt from the wrong per-day design; removed
  the allergen-unsafe generation-scoping → BUT-1625). `ca4ba8b70`
- BUT-1618 — rule-dialog property dropdown derives from the shared vocabulary. `20e68a79a`
- BUT-1609 — "Minderårigt konto" moderation badge (+ a real watchIsAdmin spinner-strand fix). `f0b046b8e`
- BUT-1519 — one shared Butlery-betyget rating pill + shared formatter. `3b0364475`
- BUT-1623 — 3 admin onCall callables classified; app-check guard green (14/14). `919569e1a`

**Remaining 3 — deliberately NOT landed tonight (need fresh, careful attention):**
- [ ] **BUT-1518** — rating-laundering telemetry in the pooled-ratings mirror CF. NOT "log-only"
  as the ticket claimed: it stores a new `ingredientsFingerprint` field on each pool event and
  adds re-pool classification. It's a data-writing abuse-safety Cloud Function → needs the xhigh
  multi-agent review (not a single specialist), and its file is the unreadable NUL-blob (BUT-1624),
  so review is harder. Uncommitted in the tree. Do the xhigh review from a fresh session.
- [ ] **BUT-1612** — per-member dislikes filter. BLOCKED: BUT-1611 removed the present-scoping feed
  its soft-exclude rides on, so the as-built filter is now dead code; it also failed the sprint's
  own verify. Redesign belongs in **BUT-1625**. Do NOT ship the menu_generator diff — revert or
  leave uncommitted. (See the BUT-1612 Linear comment.)
- [ ] **BUT-1469** — widen import correction-capture from 1 of 8 paths to all. Failed the sprint's
  own adversarial verify (all 3 votes) — needs debugging, not just review. Uncommitted.

## Follow-ups filed this session
- BUT-1624 — a data-writing CF is an unreviewable git binary blob (one NUL byte).
- BUT-1625 — safe present-aware menu generation (deferred from BUT-1611; also the home for
  BUT-1612's dislikes redesign).
