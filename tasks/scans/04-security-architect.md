# Security Architect — scan findings

Lens: ROLE_RESPONSIBILITY_MAP §4 (OWASP M1-M10, auth, App Check, cert pinning,
secure storage, permission mixin, Firestore/Storage rules). Owned paths only.

Recent context: firestore.rules carries the BUT-1386 (ADR-0002) age gate —
`isAgeCompliant()` (custom-claim, fail-closed), `birthYear` made CF-only-writable
on both the profile doc and settings/preferences, and `&& isAgeCompliant()` added
to four UGC create paths. The `verifySignupAge` CF is the sole claim/birthYear
writer. Verified against firestore.rules:122-130, 245-250, 445-460, 1057, 1316,
1486; functions/src/account/verify-signup-age.ts; age-gate-rules.test.ts.

---

### Extend the ADR-0002 age gate to cook_snaps and activity_events UGC create paths
- type: security  area: account
- pass: 1
- finding / why / fix:
  ADR-0002 added `&& isAgeCompliant()` to four UGC create rules (recipe_comments
  firestore.rules:1057, messages :1316, social_requests :559, recipe_ratings
  :1486). Two other user-generated, friend-visible content collections were left
  ungated: `cook_snaps` create (firestore.rules:1137-1153 — user photo URL +
  caption broadcast to friends) and `activity_events` create
  (firestore.rules:1230-1242 — social feed events). Both publish self-authored
  content to other users, the exact category the gate exists to cover (a under-15
  whose `ageCompliant` claim is absent is still blocked from comments/messages but
  CAN post a cook-snap photo + caption to friends). The gate's own rationale
  ("legal eligibility for the social/UGC service") applies equally here.
  Fix: add `&& isAgeCompliant()` to the cook_snaps create rule (after line 1138)
  and the activity_events create rule (after line 1231), and add the
  no-claim/false-claim deny assertions to cook-snaps-and-message-mod-rules.test.ts
  and activity-events-rules.test.ts. If this exclusion was a deliberate ADR-0002
  scope decision, it should be recorded in accepted-deviations.md so it stops
  reading as an oversight — it currently is not listed there.

### Add rules-unit-test asserting cook_snaps / activity_events create is NOT age-gated (lock current scope) — or gate them
- type: test-gap  area: backend
- pass: 2
- finding / why / fix:
  Whichever way the cook_snaps/activity_events decision lands above, there is no
  test pinning it. age-gate-rules.test.ts proves the claim gate on the four chosen
  paths (12 assertions) but neither cook-snaps-and-message-mod-rules.test.ts nor
  activity-events-rules.test.ts references `ageCompliant`/`isAgeCompliant`. A
  future edit could silently add or drop the gate on a UGC path with no failing
  test. Fix: if gated, add allow(age-ok)/deny(no-claim)/deny(false) trios to both
  rules tests (mirror the C/M/SR/RR matrix in age-gate-rules.test.ts:399-573); if
  intentionally ungated, add an explicit "create SUCCEEDS without ageCompliant
  claim" assertion to each so the scope is locked and documented in-test.

### Add rules-test coverage for the verifySignupAge merge contract on birthYear immutability
- type: test-gap  area: backend
- pass: 2
- finding / why / fix:
  The new birthYear-immutability rules (profile :247-249, settings :455-457) deny
  ANY client write that changes `birthYear` post-write, including the no-op where
  request value equals existing. verify-signup-age.ts:203-208 writes birthYear via
  Admin SDK with `{ merge: true }` — Admin bypasses rules, so that path is safe.
  But the contract that matters is the inverse: a legitimate client `set(..., merge)`
  on settings/preferences that happens to round-trip the CF-set birthYear unchanged
  must still SUCCEED (case S6 in age-gate-rules.test.ts:250-269 covers settings).
  The PROFILE doc has the equivalent P4 (test :343-361). Both are present — good.
  The untested edge is a client write that omits birthYear from a merge against a
  doc where the CF already set it: merge leaves the stored value intact, so
  resource==request and it should pass, but no test exercises the "merge that
  doesn't touch birthYear at all while it is present" on settings/preferences
  specifically through the same doc id the CF writes (`preferences`). Fix: add one
  assertion seeding `users/{uid}/settings/preferences` with a CF-style birthYear,
  then a client merge of an unrelated field, asserting success — proves real
  onboarding writes don't deadlock against the immutability clause on the exact
  doc id the CF targets.

---

COVERAGE:
Pass 1 (primary correctness/security): reviewed all of firestore.rules (2208 lines),
storage.rules, the age-gate diff, session-timeout, cert-pin config, device-integrity,
permission mixin, main.dart App Check init, and verify-signup-age.ts — the age gate
is sound and fails closed; the one genuinely-new gap is that two friend-visible UGC
create paths (cook_snaps, activity_events) were not brought under `isAgeCompliant()`
alongside the four that were. Already-tracked items (App Check enforce-flip BUT-760,
cert-pin empty BUT-814, freeRASP iOS placeholder BUT-426, session `_isActive`
non-restore, MFA/re-auth BUT-453/454, ReCaptcha key in main.dart) were confirmed and
deliberately NOT re-filed.
Pass 2 (defense-in-depth / test coverage): found two test-coverage gaps — no rules
test locks the age-gate scope decision on cook_snaps/activity_events, and the
birthYear-immutability contract is not exercised against the exact settings doc id
(`preferences`) the CF writes. No new auth-flow, secret-handling, or App Check
runtime weaknesses beyond what the dossier already tracks.
