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

### [Privacy/GDPR] notification_delivery counterparty is exported, not anonymised (BUT-1450)
The GDPR data export (`DataExportService`) includes the `notification_delivery` records' raw
counterparty identifier (`senderId` / `targetUserId`) **without anonymisation or redaction**.
A blind Privacy/DPO + Legal panel recommended stripping the counterparty UID; that
recommendation was **consciously overridden by Malin**.
**Why:** Art. 15(4) is a case-by-case *balancing* test, not a blanket "redact all third parties"
rule. Mainstream exports (Facebook, Google) include the counterparty so the subject sees their
own interaction data as they experienced it; the human-readable notification is already in
`notification_history` (joined via `notificationId`). The only thing deliberately *not* exported
is bulk UID→name resolution (cost). Do **not** file a "third-party PII / must redact `senderId`"
finding against the notification-export path — it is a decided product+legal call. (The narrow
exception the panel flagged — a counterparty in a notification the user never saw — does not
apply: all exported notification categories are user-facing.) — 2026-06-30
