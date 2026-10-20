# cloud-functions-specialist — chapter: ci-wiring

- **Prove endpoint config, never reason about it:** `npm run
  test:deploy-manifest` imports the ENTRY POINT (the only way the global call
  runs), pinning region, numeric `maxInstances` and the cascades'
  `concurrency === 1`. An unset v2 option is a sentinel OBJECT, not null
  (`== null` is FALSE) — check `typeof x === "number"`. Vacuity is in the
  `gcfv2` FILTER: guard the filtered COUNT per caller, keep presence AND value
  pins, and make a by-NAME pin fail rather than skip on a missing export.
- **No global option reaches EVERY export, and never TALLY endpoints.**
  `onUserDeleted` is gcfv1 (own `.region().runWith()`) and others pin their own
  region — grep `\.region(|region: "` and exclude every hit from an "every
  function" claim, rather than trusting a roster written here.

### CI / test wiring / ops
- **A cross-language pinned literal has a POINTER on each side, and MOVING one
  half breaks the other's repair instruction** — the drift comment tells the
  next reader where the twin lives (`log-safe-conversation-id.test.ts` ⇄
  `test/unit/core/utils/log_sanitizer_test.dart`), so a suite split updates
  BOTH files in one commit, and a new hand-rolled suite carries its OWN
  `run`/`failed`/`check`/exit harness plus its `test:*` line or it runs
  nowhere. Never write how MANY places pin the value: the Dart side pins the
  same masked literal in more than one test.
- Post-deploy smoke: `firebase functions:list --json` + grep stable names.
  `deploy` exiting 0 does not prove callability; a run concluding `failure`
  does not prove the DEPLOY step failed.
- **An ops script's top-level `catch` that prints `err.message` re-leaks what the
  module excluded** — a batch `update` NOT_FOUND names the whole doc path
  (emulator: `no entity to update ... name: "<uid>_<date>"`), so a uid-keyed doc id
  lands in the Actions log. Convert every Firestore throw at its SITE (query AND
  `commit`) to a code-only error; a probe-only wrapper leaves the commit path raw.
- **A step whose `if:` names only a step OUTCOME is DEAD after a failure** —
  GitHub ANDs an implicit `success()`. Write `always() && (...)`.
- **A guard READING files outside `functions/src` is asleep unless the workflow
  `paths:` reach them** — derive the list from what the guard OPENS and assert
  it against BOTH the `push` and `pull_request` blocks; fixing one is the
  half-miss. A hand-rolled `paths:` parser fails CLOSED. Assert PER GUARD — a
  sibling scenario's derived assertion covers only ITS inputs — and reach the
  ORCHESTRATOR assembling the output, not just the helper directory.
  `assertGuardTriggersCoverItsDartInputs` takes lib/ paths only; a docs or
  `firestore.rules` input needs its own `paths:` entry and assertion. Two guards
  in two languages must never cite EACH OTHER for a case neither covers: a
  TEXT scan sees the token, the behavioural test sees named keys, and a rename
  escapes both — name the residual, never describe it as covered.
- **A source-scanning erasure guard counts READERS as writers.**
  `discoverUserSubcollectionWriters` (`account-deletion-cascade.test.ts`) flags any
  `.collection(users).doc(x).collection("y")` chain, and `reset-analytics-prune.test.ts`
  flags any `.collection("analytics").doc(<variable>)` outside `reviewedVariableChains`.
  A new export reader of an erased path reddens both: add the name to
  `COVERED_BY_OWN_STEP` (which seeds and runs the real deleter) and spell analytics parents
  as literals. Never reshape the chain so the regex misses it.
- **Count a probe's FAIL lines from a FILE, never a pipe**: once a failure message is
  large (an `assertEqual` over thousands of rows) a piped `ts-node` run came back
  truncated while the same run redirected to a file was complete. A no-uid-in-logs test
  patches `process.stdout/stderr.write`; patching `console.*` captured nothing from
  `firebase-functions/logger`.
- **A guard on how CI names a project must parse every spelling the CLI and actions accept** — `--project`, `-P`, `firebase use`, and action `projectId:`/`project_id:` inputs; a guard reading one spelling passes the others.
