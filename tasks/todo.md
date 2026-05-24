# Sprint Backlog

## Sprint: iter-53 — BUT-704 ARB @key descriptions — STEP 0 RESCOPE — 2026-05-24 (Sun)

Theme: Ticket original premise stale. Plan-fil FÖRST per discipline.

### Step 0 — premise verification (significant rescope)

- Ticket claims ARB files have **no** `@key` metadata. Verified 2026-05-24:
  - `lib/l10n/app_en.arb`: 3868 keys, **854 @meta blocks**, **750 placeholders metadata blocks** out of 753 placeholder-strings.
  - `lib/l10n/app_sv.arb`: matching counts.
- The "no metadata" framing is wrong — coverage is ~22% across all keys but **99.6% for placeholder-strings specifically** (which is where translator-context matters most).
- **Only 3 placeholder-strings lack `@meta` placeholders blocks:**
  - `menuVoteWinner`: `Winner: {recipeName}` (string placeholder)
  - `menuVoteCount`: `{count, plural, =0{No votes} =1{1 vote} other{{count} votes}}` (plural with int)
  - `errorShareCapReached`: `Recipe is already shared with the maximum number of users ({max})` (int) — **note**: my iter-40 (sv added @meta inline, en didn't — see commit `14806f107`). Fix is: add the missing `@errorShareCapReached` block to `app_en.arb` (parallel structure to sv).

### Design choices

- Fix the 3 missing-meta cases. That closes the load-bearing gap (translators-without-context-for-placeholders).
- Don't backfill descriptions for the 3014 non-placeholder strings without @meta — that's the 2-day scope the ticket originally projected. Close BUT-704 noting actual remaining gap is the description coverage, not placeholder typing.
- File BUT-XXX follow-up for "full description coverage" if/when translation work actually starts.

### Ship this sprint

- [ ] **A1. BUT-704 partial** — Add 3 missing `@meta` placeholder blocks in both ARB files (sv+en parallel structure).
- [ ] **A2. `flutter gen-l10n`** — regenerate to validate JSON structure.
- [ ] **A3. File follow-up** — BUT-XXX for "full description-coverage backfill across remaining ~3000 keys" (deferred until translation starts).

### Acceptance

- [ ] `Found 0 placeholder strings without @meta` (the check script returns clean).
- [ ] `flutter gen-l10n` succeeds + `flutter analyze` clean.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Stäng BUT-704 i Linear → Done with "premise rescoped per Step 0" comment

---

## Archived iter-52 (commit `623896697`) — 2026-05-24 (Sun)

BUT-891 CPI assertion update. 5 sites across 3 test files migrated from `find.byType(CircularProgressIndicator)` → `LoadingIndicator` (with "tolerate raw CPI legacy" pattern in shared helpers). iOS-platform-coupling latent bug closed. +51 / -35. BUT-891 → Done.
