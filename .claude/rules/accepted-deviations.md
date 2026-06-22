# Accepted Deviations

Known, deliberate deviations from otherwise-applicable rules. **Review agents
(code-reviewer, firebase-backend-security, testing-specialist, firestore-rules-tester,
uiux-designer, performance-optimizer) MUST consult this list before filing a finding** —
do not re-flag anything listed here. These are decided; reopening one needs a new decision,
not a review comment.

Append-only. Supersede an entry with a newer dated entry; never silently delete.
Format per entry: **what it deviates from** — the deviation — **Why:** rationale — date.

---

### [Firebase] Pure-equality Firestore queries need no composite index
Multi-field **equality** filters do not require a composite index — Firestore's automatic
single-field indexes merge equality constraints. Only `orderBy` or range (`<`, `>`, `!=`,
`in` + sort) combinations need a composite.
**Why:** A reviewer once flagged a missing composite index on an equality-only query as a
Critical; it was a false positive. Don't flag missing composites unless an `orderBy`/range is
involved. (See memory `reference_firestore_equality_index.md`.) — 2026-06-22

### [Code Quality] Files >500 lines listed in ACCEPTED_LARGE_FILES.md
The 500-line limit (CLAUDE.md rule #2) is waived for every file enumerated in
`docs/architecture/ACCEPTED_LARGE_FILES.md`, each with a per-file rationale.
**Why:** Some files are cohesive facades or generated/config and splitting them would hurt
clarity. Don't propose refactoring a large file without first reading its rationale there;
don't file "exceeds 500 lines" findings for listed files. — 2026-06-22

### [UI/UX] Deliberate departures from the mockup
The following intentionally differ from the design mockup — do **not** file
"doesn't match mockup" findings for them:
- **Rating badge** is a green pill, not the gold from the mockup.
- **"Lagat idag" chip** stays in the recipe metadata row even though it's absent from the mockup (it's useful).
- **UNKNOWN allergen status** is intentionally hidden — only FREE and CONTAINS badges render.
- **Cream color scale** is left as-is, intentionally not realigned to mockup values.

**Why:** Each was a considered product/UX call recorded in project memory ("UI/UX Design
Preferences"). The mockup is a reference, not a contract, on these points. — 2026-06-22
