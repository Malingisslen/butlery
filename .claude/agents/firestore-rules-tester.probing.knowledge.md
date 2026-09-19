# firestore-rules-tester — chapter: probing

## Actor conventions

```ts
const OWNER_UID = "owner-uid";
const OTHER_UID = "stranger-uid";
const ADMIN_UID = "admin-uid";
```

- Authenticated:   `env.authenticatedContext(uid)`
- Unauthenticated: `env.unauthenticatedContext()`
- Admin grant:     write to `/admins/{uid}` via `env.withSecurityRulesDisabled(...)` during setup.

  **But that seam DELETES the suite from `rules-coverage-report.js`, silently.** Its
  discovery reads `/\bPROJECT_ID\s*=\s*["']…["']/` and `/projectId:\s*["']…["']/`, and
  `PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "…"` matches neither, so the suite's whole
  coverage slice is never fetched and never unioned — measured 2026-09-04: FOUR suites
  (conversations, chat-groups, poll-votes, cook-snaps-and-message-mod) are invisible, i.e.
  every suite that has adopted the seam. It inflates the untested-block count and can fail
  the NEW-block gate on a block those suites do cover. Adding the seam therefore owes a
  literal the discovery can still see (keep `projectId: "…"` at the
  `initializeTestEnvironment` call, or export the default as its own string const).
  **That split then has its OWN failure mode: every OTHER consumer of the id must resolve it
  the SAME way.** A suite that honours `PROBE_PROJECT_ID` at `initializeTestEnvironment` but
  interpolates the BARE literal into `clearFirestore()` empties a different namespace from
  the one under test, so the run silently loses its isolation — an earlier allow's write
  survives and turns a later create-deny into an update-deny, which is the exact
  mis-attribution the limb-pair mutant exists to catch. Grep every use of the id constant
  when you add the seam; `blocks-rules.test.ts` resolves it at BOTH sites today (measured
  2026-09-09), so it may be probed with `PROBE_PROJECT_ID` set. Assert the mutator's match
  count is 1 and diff the mutant against the original before trusting the run. **A probe
  project id must be lowercase with NO underscores** — an uppercase letter (a `createdAt`-derived
  id) or an `_` (a mutant name like `c_age` interpolated raw) makes the run emit NO test lines at all, which greps for `FAIL` as cleanly as a green suite; require
  a `passed` line before reading any probe result. A suite that ships WITHOUT the two env
  hooks has to be probed through a throwaway `sed`-derived copy under
  `functions/src/__tests__/`, deleted in the same call — workable, but add the hooks when
  you touch the file. **Substituting `RULES_PATH` in that copy orphans the `import * as path`
  line, and `noUnusedLocals` then aborts ts-node on TS6133 before any test runs** — an exit
  that greps for `FAIL` exactly like a green suite. Delete the import in the same `sed`, and
  require a `N/N passed` line before reading any probe result. **A mutant that breaks the
  rules file's SYNTAX is the same failure one layer down**: deleting `x is string` from
  `(x is string && x.size() <= N)` leaves `(&& …)`, so the emulator rejects the whole ruleset
  and the run again emits no verdict line — take the `&&` with the arm (BUT-2079).
- **A probe script written through a heredoc or `node -e` inherits the SHELL's escaping, and
  the collapse is silent**: `"function\\s+"` came back as `function\s+` inside a JS *string*
  literal, i.e. the pattern `functions+`, which matched nothing and read as "the rule is gone"
  — the same decay the Dart guard's own comment warns about, arriving through bash instead.
  Build patterns from REGEX LITERALS (`/…/.source` with a placeholder to substitute), never
  from backslashes inside a quoted string, and print the CAPTURE plus how many other copies of
  the number the file holds before believing a match (BUT-1971, 2026-08-31).
- **A parallel session can edit the suite MID-REVIEW** — this file went 30 -> 32 tests between
  the first run and the report, so a quoted total and a "no test covers X" claim both age
  inside one review. Re-`Read` the test file and re-`ls -l` it before quoting any count, and
  never carry a probe's pass total from an earlier run into the write-up. **The session
  scratchpad is SHARED with parallel agents too**: a generic `mut.js` was overwritten between
  two rounds by another agent's mutator, the rebuild threw, and the rest of the call ran on the
  PREVIOUS round's mutant file, printing a plausible 4/5 against stale rules. Give every probe
  file a unique name, `rm -f` the mutant path before rebuilding, abort the call when the
  mutator fails, and grep the mutant for the CURRENT rule's new literal before reading a result
  (2026-09-14).
- A standalone probe script must live UNDER `functions/src/` — from the OS temp dir,
  `npx ts-node` resolves neither `@firebase/rules-unit-testing` nor the tsconfig and dies
  on TS2307/implicit-any. Delete it in the SAME Bash call that created it (`trap ... EXIT
  INT TERM`); watch an earlier `cd functions` in that call — a later `rm
  functions/src/...` can silently miss.
  **`resource\.data\.` also matches the TAIL of `request.resource.data.`**, so a pre-state
  mutation silently counts the create limb too — anchor on `&& resource.data`. When one
  collection's shape is shared repo-wide (`memberPermissions[uid] in ['edit','admin']`
  appears three times), slice the block by `indexOf('match /<collection>')` and mutate
  inside the slice rather than widening the pattern.
  **The same slice is mandatory in a SHIPPED cross-language guard, where the consequence is
  worse than in a probe: an unanchored needle stays green FOREVER instead of measuring the
  wrong bytes once.** A rules test pinning a Cloud Function's cap by
  `rulesText.includes(".get('contributorUserIds', []).size() <= 200")` matched THREE times —
  once in `group_weekly_menu_plans`, twice in `unified_shared_shopping_lists` — so the group
  cap could move to 150 (with its Dart twin, keeping the Dart guard green) while the needle
  went on matching the shopping-list copy, which is exactly the drift the guard exists to
  catch. Count the needle's occurrences over the WHOLE file before shipping any substring
  pin, assert the count inside the slice is 1, and note that a needle unique TODAY (the
  `editTrail` twin) is anchored by luck, not construction. A raw `includes()` is also
  COMMENT-BLIND, unlike the Dart guard beside it which strips `//` first — measured:
  commenting the cap out leaves the pin green (BUT-1971, 2026-08-31).
  **Certify such a pin with FOUR text-only mutants, no emulator needed — the guard is pure
  string work, so replicate its own slicer over a mutated buffer in `node`**: (1) change the
  cap INSIDE the block → must fire; (2) same for the sibling cap, separately, or one anchor
  covers for the other; (3) comment the cap out → must fire; (4) change the copies OUTSIDE
  the block → must NOT fire. Print the WHOLE-FILE needle count beside the in-slice count:
  the whole-file number is what tells you whether the slice was load-bearing at all
  (measured: contributor needle 3 whole-file / 1 in-slice, trail needle 1 / 1 — so the trail
  pin is anchored by luck and only the slice makes that safe to stop worrying about).
  **A cross-language guard anchored on a rules FUNCTION NAME is safe by construction and
  needs no slice** — `groupMenuContributorsWithinCap` cannot match the shopping list's inline
  copy, whereas the literal can. Prefer the name anchor when the rule offers one.
- **Proving a "comment-only" rules diff is mechanical, not eyeballable**: recover every
  previously-staged revision with `git cat-file --batch-all-objects --batch-check`, strip
  `//` comments (only after grepping for `://` first) AND blank lines AND `\r`, then
  compare md5s — print the surviving line count alongside the md5 so "identical" is
  visibly non-vacuous. Cross-check with `git diff -U0 | grep '^[+-]' | grep -v
  '^[+-][[:space:]]*//'` coming back empty; the two methods fail differently (md5 catches
  reordering, the line filter catches a `//` inside a string literal). **The md5 is valid
  only WITHIN one run: it fingerprints the strip pipeline as much as the bytes** — two
  correct pipelines over the same 1382 surviving lines printed different digests in two
  reviews of one diff (CR stripped before vs. after the comment strip). Compare digests only
  against one you computed in the same call; the SURVIVING LINE COUNT is the figure that
  travels between entries. Size-filter object
  recovery on the file's real CRLF byte size, not an LF-era guess, or the sweep silently
  returns only ancient revisions and reads as "no prior version exists."
  **Run the strip over EVERY file in the STAGED set, not the files the brief names** — a
  "two-file comment fix" arrived touching four (two Cloud Functions doc-comments rode along),
  and a `/** … */` doc block needs its own `sed` arm beside the `//` one or the TS files
  compare as changed. A `://` inside a string literal truncates identically in both
  revisions, so it does not invalidate the md5 pair — grep for it and say which lines it hit.
  **Re-run the affected suite anyway.** A comment cannot change CEL evaluation, so the run
  is not owed for behaviour — but it is the only check on the one thing a comment edit CAN
  break: a ruleset that no longer compiles.
  **"Does any guard key on this COMMENT?" is enumerable, not arguable**: `grep -rl
  "firestore\.rules"` over `test/ lib/ functions/ .github/ .claude/hooks` yields every
  consumer, and each text consumer owes a NAMED mechanism — the two Dart drift guards strip
  comments in `setUpAll` BEFORE any assertion and anchor on `match` paths and `function`
  names; `rules-coverage-report.js` blanks comments to spaces character-for-character
  (offsets preserved) and diffs block PATHS. Three concurring reviewers are not that answer.
  **A RED on the owed re-run is not evidence about the diff until emulator state is
  excluded** — see the persistence bullet below: measured 2026-09-16, one suite went 19/19,
  then 17/19 on bytes differing by ONE comment, then 19/19 again after clearing the
  namespace. Attributing that red to the comment is the available wrong answer.
- **A mutant built by PREFIXING a CEL predicate is not the mutant you wrote — `&&` binds
  tighter than `||`.** `return false && !exists(X) || Y` collapses to `Y`, so an intended
  "deny always" silently became "delete the leading fail-open disjunct" and killed a
  different 8 tests (measured on `notBlockedByAnyoneHere`, BUT-1917). Replace the WHOLE
  predicate body when you want an unconditional verdict, and read the kill SET against what
  you predicted — a kill count you did not expect is the precedence showing itself, not a
  surprising suite. The accidental mutant was worth keeping under an accurate name: prefixing
  is a cheap way to reach "make this limb fail closed", which is often the edit a deviation
  entry records as REJECTED and which therefore wants a pinned kill set of its own.
- **A deny-always mutant on a whole gate is what grades its ALLOW tests, including the
  pinned-green "known gap" ones** — they are fail-closed controls only if they die when the
  gate stops permitting anything. It grades the ungated verbs at the same time: on `poll_votes`
  it killed all 12 allows through the gate and left the READ and DELETE tests green, which is
  the measurement behind "read and delete are deliberately not block-gated". Run it once per
  gate before writing that a verb is ungated.
- **A mutation probe that reddens NOTHING is often the most valuable result — it means a
  COMMENT is wrong, not the code.** Run both the "the forbidden edit" probe (tests the
  comment's claim) and the "delete the conjunct" probe (tests whether the test is
  load-bearing at all) — a comment can be stale about an old rule shape while the current
  code is fine.

### Emulator, harness & CI gotchas
- The emulator PERSISTS DATA ACROSS `npm run` invocations — suffix create-allow doc ids
  with a per-run token, or a second local run silently becomes update-not-create and
  fails wrong. CI is unaffected (fresh emulator per job); "fails locally, green in CI"
  means clear-and-retry, not a regression. **A DETERMINISTIC id is the same hazard WITHIN
  one run**: `direct_<a>_<b>` is a pure function of its two uids, so any two fixtures
  naming that pair ARE one document and the later seeder silently overwrites the earlier —
  turning an ALLOW control into a deny while its DENY twin stays green and pins nothing.
  Give a new fixture DEDICATED uids and grep every path in the file before calling it
  isolated (BUT-1831). **The same persistence makes an "absent document" fixture a claim
  about every test that ran BEFORE it, and the vacuity is total: in a file with no per-test
  clear, an earlier test's seed means the case never reaches the absent branch and passes
  with the null arm DELETED** (measured on `user_moderation` UM8, BUT-2046). Seed absence
  positively — `withSecurityRulesDisabled` DELETE, not "no test wrote it" — and grade it
  with a null-arm mutant, which must kill that test alone.
  **The FINGERPRINT of this artefact is that the failures land on exactly the client
  CREATE-ALLOW tests**, because a surviving doc turns the create into an UPDATE, and these
  collections commonly carry `allow update: if false`. Measured 2026-09-16 on
  `audit-logs-rules.test.ts`: `teardown()` calls `env.cleanup()`, which disposes the ENV,
  not the data. Before
  blaming the diff, probe one create-allow doc id and clear.
- **A fixture seeded inside `withSecurityRulesDisabled` is evaluated by NO limb, so any
  justification for its SHAPE that cites a future `hasOnly`/`hasRequiredFields` on that
  collection is false for that fixture.** Measured 2026-09-09 with one mutant file serving two
  suites: `blocks` create rewritten to `if false` reddens `blocks-rules.test.ts` W1 (a client
  create) while `recipe-comments-rules.test.ts`, whose `blocks` seed is rules-disabled, stays
  24/24 with the seed landing normally. Matching the producer is still the right default —
  nothing would ever tell you such a fixture had drifted — but say so from CONVENTION, not from
  a write-validation mechanism that cannot reach it. The shape does become load-bearing if a
  gate ever moves from `exists()` to a FIELD read, which is a read-side change, not a
  `hasOnly`; that is the direction to name if the justification needs a mechanism at all.
- Never import server-value sentinels (`serverTimestamp`, `increment`, `arrayUnion`,
  `deleteField`) from `firebase-admin/firestore` in a `*-rules.test.ts` — the test
  context is the CLIENT SDK; an admin sentinel throws before any rule runs, which also
  fails `assertFails` deny tests. Grep `from "firebase-admin/firestore"` across
  `__tests__/*-rules.test.ts` after any `firebase-admin` major bump.
- `count()` aggregate rule tests need the MODULAR `firebase/firestore` API
  (`getCountFromServer`, `collection`, `query`, `where`) — the compat API has no
  `.count()`.
- `{"error":{"code":500,"status":"UNKNOWN"}}` from `loadFirestoreRules` is emulator
  flake, not a rules syntax error — disprove it by PUTting the same ruleset to
  `/emulator/v1/projects/<pid>:securityRules` directly; a 200 with only WARNING
  severities means it compiles. Space probe runs one or two per shell call; a retry loop
  inside one call does not clear it.
- Clearing a project's emulator data from Bash needs the URL QUOTED (the parens glob-expand
  otherwise, exit 7) and an owner bearer, or the REST API answers 403 under the rules:
  `curl -X DELETE -H "Authorization: Bearer owner"
  "http://127.0.0.1:8080/emulator/v1/projects/<projectId>/databases/(default)/documents"` —
  measured 2026-09-16, HTTP 200, and a probed doc went 200 -> 404. The same quoting and
  header read a doc back, which is how you prove a stale fixture rather than assume one. A
  suite's own `clearFirestore()` is still the first choice where it has one; several do not.
- `test:rules:all` is not one atomic run — a Storage-emulator-dependent suite mid-chain
  hard-fails `ECONNREFUSED` without the Storage emulator up, aborting the `&&` chain so
  every later suite silently never executes. Check WHERE the chain stopped before
  reporting a pass count.
- Registering a new rules suite is FOUR mechanical steps, enforced by
  `functions/scripts/check-test-registration.js`: the `test:rules:<name>` script, an
  entry in `test:rules:all`, and the path in BOTH `paths:` blocks of
  `.github/workflows/firestore-rules.yml` (pull_request + push). Verify with `node
  scripts/check-test-registration.js` — and that checker RUNS IN CI
  (`.github/workflows/cloud-functions-unit.yml`), so the two missing `paths:` entries are a
  RED BUILD, not a soft warning. Run it on every new suite before reporting the suite green.

