# Google Play Data Safety form — submission staging

**Status (2026-04-26):** PENDING USER ACTION. The runbook with copy-paste-ready
answers is complete (`docs/ops/play-data-safety-runbook.md`); the actual
form must be filed via the Play Console UI by an account with **App
content** edit rights — agents cannot reach Play Console.

This directory is the destination for:

- The screenshot of the submitted form (proof of submission).
- Any archived form payloads exported from Play Console.
- Future Data Safety form revisions (one screenshot per re-submission).

## Filing workflow

1. **Open the runbook.** `docs/ops/play-data-safety-runbook.md` is the
   authoritative answer set. Sections 1–4 map 1:1 to the four Play
   Console steps. Read top-to-bottom before opening Play Console.
2. **Sign in to Play Console.** [https://play.google.com/console](https://play.google.com/console)
   → Select **Butlery** → **App content** → **Data safety** → **Manage**.
3. **Work through the four Play Console steps in order**, copy-pasting
   answers from the runbook. Save as draft after each step (the runbook
   §0 calls this out).
4. **Verify Section 5 of the runbook (verification checklist)** before
   submitting. The most common rejections are listed in §7.
5. **Submit.** Play Console will return a "Submitted for review" state;
   re-review takes minutes to hours, not days.
6. **Capture proof.** Take a full-page screenshot of the submitted form's
   summary view and save it to:
   ```
   docs/store-submission/play-data-safety/2026-04-26-submitted.png
   ```
   (or substitute the actual submission date — keep the
   `YYYY-MM-DD-submitted.png` naming so the file sorts chronologically).
7. **Update the runbook §8 (Submission History) row** with the date,
   submitter, form version, and outcome. Append a "## Filing status"
   note at the bottom of the runbook (already pre-stubbed) flipping
   `Pending user action` → `Submitted YYYY-MM-DD`.
8. **Mark BUT-646 → Done in Linear** with a link to the screenshot path.

## Screenshot file naming

Format: `YYYY-MM-DD-submitted.png` (date the form was submitted, not
when it was approved). One screenshot per submission; if Play returns
the form for revisions, capture the re-submission separately as
`YYYY-MM-DD-resubmitted.png` with a runbook §8 history entry pointing
to the rejection reason.

## Why this directory exists separately from `docs/ops/`

- `docs/ops/play-data-safety-runbook.md` is the **source of truth** —
  the answer set, maintained alongside code changes that affect
  data collection (new SDK, new analytics event, etc.).
- `docs/store-submission/play-data-safety/` is the **filing artefact**
  — proof that the answers in the runbook were actually submitted, on
  a specific date, with a specific outcome.

Re-reads should hit the runbook first; this directory is for audit
trail only.

## Related

- `docs/ops/play-data-safety-runbook.md` — answer set + verification
  checklist + submission history.
- `docs/store-submission/STORE_SUBMISSION_CHECKLIST.md` — top-level
  store-submission tracker; includes the row for this filing.
- `BUT-561` — runbook authoring (Done).
- `BUT-646` — form filing (this work; awaiting user action).
