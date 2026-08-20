# BUT-1693 — Let a household member share their allergen list (Part 2 of BUT-1663)

## Context

Butlery's weekly menu filters recipes on the household's aggregated allergen preferences.
An adult member's own allergen list lives in `users/{uid}/settings/preferences`, which
`firestore.rules:548-549` makes owner-read-only. So for **every household member except the
signed-in user**, `profile.allergenPreferences` is always `null` — not a declaration, a
structural read denial (`lib/models/profile_lookup.dart:16-24`).

Part 1 (`f36e3db35`, 2026-07-26) made the app honest about that: unreadable members get a
four-allergen safety floor (gluten, mjölk, nötter, jordnötter), the roster reports itself
incomplete, and — since BUT-1685 (this session) — the menu says so on screen. But the floor
is still a guess: it misses egg and shellfish, and it needlessly narrows the menu for a
household where nobody has those four.

Part 2 replaces the guess with the real list, for members who choose to share it.

**This is Art. 9 health data.** A full stakeholder panel ran before this plan
(Legal Counsel, Privacy/DPO, Security Architect, Product Manager, Database Administrator,
plus a Codebase Archaeologist). All five roles returned **approve-with-conditions**; nobody
blocked. Their conditions are folded in below as acceptance criteria.

## Decisions Malin took (2026-08-11)

| # | Question | Her answer |
|---|---|---|
| 1 | What can be shared | **Allergens AND dietary choices in one toggle** (not allergens-only) |
| 2 | Who sees it when the household changes | **Everyone in the household, including anyone who joins later** — the copy must say so before the toggle is flipped |
| 3 | Per-person storage reopens the 2026-06-28 minimisation override | **Confirmed, eyes open** — record it as a dated ADR |
| 4 | Legal paperwork vs build order | **Papers first.** No code until the DPIA addendum and the policy text exist |

**Consequence of answer 1, stated plainly because it is a real cost:** the menu's dietary
filter treats a tracked diet as a *hard requirement*. If one member shares "vegansk", every
recipe that is not vegan leaves the household's menu. That is why Part 1's safety floor
deliberately carries allergens only (`docs/architecture/ACCEPTED_DEVIATIONS.md`, BUT-1663
entry). Sharing is opt-in and per person, so nobody gets this without choosing it — but the
consent copy must name it, and the ADR records that the trade was chosen knowingly.

---

## Phase 0 — The papers (gate: nothing below starts until Malin approves these)

Per answer 4. Four documents, drafted for her review; none is legal advice, and the DPIA
addendum is written to be handed to a real reviewer.

1. **`docs/legal/dpia-household-allergen-sharing.md`** — an addendum to the existing
   family-rating DPIA scope: new processing activity (adult-to-adult Art. 9 disclosure
   inside a household), lawful basis (Art. 9(2)(a) explicit consent), data categories,
   recipients, retention, revocation, risk table, and the residual risks this plan accepts.
2. **Consent copy** — the toggle's title, subtitle, and the explain-then-confirm
   dialog. Must clear the bar this repo already set for allergen consent in ADR-0003:
   standalone, not pre-ticked, versioned, timestamped, one-tap revocable. Must state (a)
   that allergens *and* dietary choices are shared, (b) that everyone in the household sees
   it **including anyone who joins later**, (c) that dietary choices narrow the whole
   household's menu, (d) how to take it back. Authored in Swedish, but every string ships as
   an ARB key in **both** `lib/l10n/app_sv.arb` and `lib/l10n/app_en.arb` with matching
   `@key` descriptions, then `flutter gen-l10n`.
3. **Privacy-policy clause (SV + EN)** — a new recipient/disclosure category. Follows the
   pooled-ratings precedent of amending the bundled policy, not just a doc draft.
4. **`docs/org/adr/ADR-0005-household-allergen-sharing.md`** — records Malin's four answers
   above with their reasoning, so no future reviewer re-litigates them, and supersedes the
   premise that the 2026-06-28 minimisation override rested on.

---

## Design (built after the gate)

### Which "household"? — `households/{householdId}`, not the friend category

This repo has **two live household concepts**, and both the DBA and the Security Architect
flagged the risk of building a third:

- `FriendCategory.isHousehold` — owner-scoped, **asymmetric**, what
  `HouseholdService.getHousehold()` uses today (`lib/services/household_service.dart:84-92`).
- `households/{householdId}` — a real collection with `memberUserIds` + `memberPermissions`,
  **symmetric**, already carrying Art. 9 allergen data for non-account family members
  (`diner_profiles`, `firestore.rules:967-983`) behind the existing `isHouseholdMember(hid)`
  helper (`firestore.rules:296-301`).

**Decision: scope the share to `households/{householdId}`.** The deciding argument is
symmetry, not cost: a share is a statement *by* a member, so that member must be able to
name a household they belong to and write to it. A friend category is owned by one person
and the other members cannot see or write it. `households/{hid}` is also the identity under
which this app already shares allergen data between household members, so the rule helper,
the membership model and the review precedent all exist.

**Known divergence, deliberately not fixed here:** `HouseholdService` still aggregates over
the friend-category roster. A member listed there but absent from `households/{hid}` simply
has no readable share and keeps the floor — safe by construction. Unifying the two rosters
changes which people the allergen union covers; that is its own safety decision and gets its
own ticket, not a silent ride-along.

### Data

New top-level collection, one document per (household, member):

```
household_allergen_shares/{householdId}_{uid}
  householdId: string
  userId: string
  trackedAllergens: string[]
  trackedDietary: string[]
  includeUnknownInMenu: bool      // AND-folded by the aggregate, so it can only tighten
  consentGranted: true            // explicit; absent/false is never treated as consent
  consentVersion: string
  consentGrantedAt: timestamp
  updatedAt: timestamp
```

No display name, no avatar — the household never renders "Anna: mjölk", only the union
(PM condition). Data minimisation is the reason; the union display already exists.

### Rules (`firestore.rules`)

- **read**: `isHouseholdMember(householdId)` — one bounded `get()`, the same idiom as
  `diner_profiles`. Membership is re-derived live on every read, so removing someone from
  the household cuts their access immediately with zero extra writes.
- **create/update**: `isOwner(userId)` **and** the writer is a member of the named household
  **and** `consentGranted == true` **and** the doc id equals `{householdId}_{userId}`. The
  household check on the *writer* closes the leak the Security Architect found: without it,
  a user could point their share at a stranger's household id.
- **delete**: `isOwner(userId)` and **nothing else** — no membership conjunct, no household
  admin. The first draft of this plan allowed an admin "for member removal"; the code is
  owner-only, and condition 4 below settles removal as a server-side sweep instead. Letting
  an admin erase another member's Art. 9 record from a client is a widening nothing in this
  feature asks for, and it would also let a household delete the evidence of a consent it
  did not give.
- Never `public_profiles` — that doc is world-readable to authenticated users and its rules
  explicitly deny `allergenPreferences` today (`firestore.rules:623-626, 636-638`).

### Repository layer (no Firestore in the service)

`HouseholdService` touches no Firestore today and must not start. A new repository owns
every read and write of the collection, modelled on
`lib/repositories/firebase/firebase_diner_profile_repository.dart`:

- `HouseholdAllergenShareRepository` (interface) +
  `firebase_household_allergen_share_repository.dart` extending the project's Firebase
  repository base **with `PermissionValidationMixin`** (CLAUDE.md rule #3), registered in the
  DI module alongside the other household repositories and resolved by interface.
- The model `HouseholdAllergenShare` parses every field through the project's safe
  serialization utilities — no raw map access — copying `lib/models/diner_profile.dart`.
- The atomic `WriteBatch` (below) lives **in the repository**, not in `UserService`.

### Read path — one query, not N gets

`HouseholdService._aggregatePreferences` currently does one profile lookup per member. It
gains **one** repository call, not one per member — internally a single
`where('householdId', isEqualTo: hid)`. Equality-only, so no composite index is needed
(accepted deviation, 2026-06-22). Then per member id: a share wins; no share falls back to
exactly today's behaviour.

**A failed query is not "nobody shares".** Offline, `permission-denied` or a timeout must
return an `unavailable` result, not an empty list — otherwise every member silently drops to
the floor *and the roster still reports itself complete*, which is the same
unreadable-looks-like-a-declaration bug `ProfileLookup` exists to prevent. On failure the
aggregate stays `degraded`, so BUT-1685's on-menu warning fires. There is a test for it.

**The trap this must not fall into** (Part 1's own commit message records that this bug
class was reintroduced three times inside one review cycle): a share document that exists
with an **empty** allergen list is a *declaration of no allergies* and must NOT trigger the
floor. Absent share = unknown = floor. Present-but-empty = known-empty. A missing
`consentGranted` reads as not-shared, never as shared-and-empty.

`HouseholdAllergenAggregate` gains `flooredMemberIds` — members resolved fine but not
sharing — so the UI can invite sharing without mislabelling a privacy choice as an outage.
The existing three roster states are untouched.

### Write path — atomic with the source edit

`UserService.updateAllergenPreferences` writes the private settings doc. When a share
exists, both documents move in **one `WriteBatch`**. Two sequential writes would open a
window where the household filters on a stale, narrower list — on this field that is a
safety bug, not an inconsistency. No Cloud Function in the write path (the repo's cost
principle; a CF would add propagation latency in the dangerous direction).

### The four-part registration ritual (Codebase Archaeologist)

A new collection is not done until all four land in the same change:

1. `firestore.rules` match block (+ rules tests) — a path with no match block is denied.
2. GDPR export leg.
3. Deletion-cascade step in `functions/src/account/request-account-deletion.ts` (tier 1,
   keyed `where('userId','==',uid)`) **plus** a `probeResidualData` leg.
4. `functions/src/admin/reset-user-data.ts` entry.

Plus a fifth trigger the DPO named: **leaving or being removed from the household deletes
the share**, not only the settings toggle.

### UI — design decision (Malin, 2026-08-12, from the directions preview)

**Direction A, whole.** A second `SwitchListTile` directly under the existing household-
allergen filter row, with a padlock icon. The TITLE says what you can do ("Dela mina
allergier med hushållet"); the SUBTITLE says what the household sees right now ("Hushållet
gissar just nu åt dig" / "Hushållets meny räknar med dina allergier"). Turning it ON opens
the approved consent copy as a DIALOG over the settings screen — not a bottom sheet, not its
own page. Turning it OFF has no dialog at all (Art. 7(3): withdrawing must never be harder
than giving) and states what happened. **With no household the row is hidden entirely** —
not shown disabled with an explanation.

Rejected with her, so they do not come back: the always-visible explanation card (B), the
state-first row that leads to its own page (C), and folding the toggle inside the existing
filter tile (D).

### UI

Settings — a new tile under the allergen screen, next to the existing household filter tile
whose confirm-dialog wiring it copies:

```
┌───────────────────────────────────────────────┐
│ Dela mina allergier med hushållet        [ ○] │
│ Hushållet ser en gemensam lista, aldrig vem   │
│ som har vad. Kan tas tillbaka när som helst.  │
└───────────────────────────────────────────────┘
        ↓ (turning ON opens the consent dialog)
┌───────────────────────────────────────────────┐
│ ⚠ Dela din allergilista                       │
│ Alla i hushållet — även den som går med       │
│ senare — får se ... [Phase 0 copy]            │
│                          [Avbryt]  [Dela]     │
└───────────────────────────────────────────────┘
```

Menu — the CTA goes where the cost is visible, and only for the signed-in user's own
un-shared state (no nagging other people):

```
⚠ Vi kunde inte läsa alla i hushållet ...        ← BUT-1685, unchanged
🔒 Dina egna allergier delas inte — menyn gissar. [Dela]
```

Behind `enable_household_allergen_sharing`, default **off**. Typed `AnalyticsEvents`
constants for share-on / share-off from day one (PM condition — this subsystem has already
shipped one untyped raw-string event).

Three UI mechanics the checklist requires and this plan commits to: the tile is a
`SwitchListTile` (self-labelling, so no `Semantics` wrapper needed) but the menu CTA's tap
target gets `Semantics(label: context.l10n.…, button: true)`; the new widget is added to
`docs/design/previews/_butlery-components.html`; and because it lands as a new file under
`lib/views/settings/widgets/`, `preview-gate.sh` needs
`~/.claude/state/preview-done-<basename>.marker`, stamped the legitimate way via `/preview`
— the ASCII above settles the structure, not the gate.

---

## Conditions carried out of the data-layer review (2026-08-12)

The security review of the foundation commit raised five things that are not
defects in it but MUST land with the commits that follow. Written down here because
they are the kind that get lost between commits:

1. **The rules cannot copy `diner_profiles` verbatim.** `allow read: if
   isHouseholdMember(resource.data.householdId)` dereferences `resource.data`, which
   is null for a document that does not exist — so it throws `permission-denied`
   rather than returning `exists == false`. That would break `getOwn`'s
   `if (!doc.exists) return null`, which is the commonest call in the feature and the
   one that keeps the floor on. The own-document read must be decided from the PATH
   (`shareId == householdId + '_' + request.auth.uid`). `fake_cloud_firestore` returns
   `exists == false` and will not catch this — it needs the emulator lane.
2. **Delete is owner-only, with no membership conjunct.** Gate delete on membership
   like `diner_profiles` does and a member who has been removed from the household can
   never erase their own Art. 9 data, while the household keeps reading it. DPIA §2 and
   R7 both promise erasure on removal.
3. **The rule must pin the path to the body** — `shareId == request.resource.data
   .householdId + '_' + request.auth.uid` on create AND update — plus `consentGranted
   is bool`, an allowlist on `consentVersion`, and `consentGrantedAt` immutable across
   an update. The client already refuses all four; the server is what makes it true.
4. **Erasure and export wiring** (the four-part ritual): the deletion cascade's
   `deleteFamilyData` currently handles `households`, `diner_profiles` and
   `family_ratings` only — a sole-member teardown would orphan shares permanently, and
   the remaining-members branch would leave a deleted user's health data readable.
   `probeResidualData` takes one line (the collection carries `userId`). Leaving or
   being removed from a household needs a server-side sweep;
   `functions/src/family/purge-dormant-family-data.ts` already implements that shape.
5. **The atomic write needs a seam that does not exist yet.** DPIA R4 promises the
   settings edit and the share move together; `createBatch` is single-collection and the
   settings doc lives elsewhere, so the repository needs a method taking an
   externally-created `WriteBatch`. Until it exists, the model comment claiming
   same-batch writes describes code that is not there.

Also open, from the same review: the consent trail is a permission-check row today, not
a `consent_granted`/`consent_withdrawn` record with a version — the consent UI commit
lands the real one.

**Two more carried out of the final security read (2026-08-12), so they do not expire with
the session:**

6. **`getByHousehold`'s "returns empty when the caller is not a member" is a promise
   production will not keep.** `isMember` reads `households/{id}`, and that rule
   dereferences `resource.data`, so a non-member gets `permission-denied` rather than a
   false. The service commit must map that denial to ONE typed unavailability signal and
   treat it as "keep the floor", never as "nobody shared" — and the interface sentence has
   to be corrected in the same edit. Same applies to `getOwn`'s `FormatException`, which
   today escapes into whatever calls it.
7. **`getByHousehold` reads `households/{id}` twice** (once inside `isMember`, once for the
   roster) and the share query has no `.limit()`. Both are cheap to collapse once the code
   branches on the thrown denial instead of a bool.

**For the rules commit, beyond the five above:**
- Pin `consentGrantedAt == request.time` on CREATE. Without it a client backdates the
  Art. 7(1) evidence it is trusted to write.
- Derive WRITE access from the document-id suffix. The client's identity check only catches
  a body/path MISMATCH — a row written straight to `{hh}_{victimUid}` carrying the victim's
  own uid passes every client guard and is served as that member's declaration.
- `getByHousehold` issues a LIST query filtered on `householdId`, so a get-only rule will
  not serve it; and `update()` is a full-document `set()`, which is an UPDATE in rules terms.

**Carried out of the final integration read (2026-08-12):**

8. **The model names the wrong household concept as its future consumer.** `HouseholdService`
   aggregates over the FriendCategory household; `getByHousehold` takes an id from the
   `households/{uuid}` roster. The consumer ticket must resolve the `households` doc id
   first (`HouseholdRepository.getForUser` / `HouseholdRosterService`) — pass it a
   friend-category id and the query returns `[]`, the syntactically-perfect wrong-path read.
   It fails safe (the floor stays on) but the feature goes silently dark.
9. **The deletion cascade must include the collection in the SAME commit as the writer** —
   `childDocs` on the sole-member teardown, and a `householdId == hid && userId == uid`
   delete in the departing-member branch, BEFORE the membership scrub per that file's own
   retry-ordering note. The Dart roster filter HIDES a departed member's share; hiding is
   not erasure.
10. **`update()` never calls `validateUpdatePermission`** — the base hook is dead on every
    live path, and the re-point test asserts against the dead one. Either route `update()`
    through it or point the test at `update()`.
11. **`readAllSafe()` swallows the deliberate `UnsupportedError`** and returns `[]`, so
    "the caller finds out at the call site" is false for that entry point. And the
    single-document reads apply the consent filter but not the roster check.
12. **Two sources for one fact, once a consumer lands:** `household_roster_service.dart`
    already reads a member's allergens from `profile?.allergenPreferences`. Decide which
    wins when both are readable, in the consumer ticket, not per call site.

**Carried out of the service slice's reviews (2026-08-12), comment-accuracy only, no
behaviour — fix them in the next slice that touches these files:**

**Must land BEFORE the flag is ever flipped — added from the settings-slice reviews
(2026-08-12):**

D. **DPIA R4's atomic settings+share write.** The consent row snapshots the member's list at
   grant time and nothing re-writes it when they later edit their allergens. A share that
   lags its owner's edit UNDER-filters — they remove ägg and add nötter, the household keeps
   filtering ägg and misses nötter. The model itself calls that a safety defect rather than
   an inconsistency. This is the heavy one: build it or the flag stays off.
E. **DPIA R5's `consent_granted` / `consent_withdrawn` pair.** When building it, add
   `consent_withdrawn` to `CONSENT_OPERATIONS` in
   `functions/src/audit_logs/purge-expired.ts` — that list is exhaustive by enumeration for
   a server-side `in` filter, so an unlisted `consent_*` operation lands in the 180-day
   bucket and the Art. 7(1) trail is purged at six months, invisibly. 4 of the 10-value
   limit are used. `revoke()` deletes the
   document, and the document is the only carrier of `consentVersion` and `consentGrantedAt`
   — so today a withdrawal erases every trace that consent existed. Narrower than D (while a
   consent is live the document IS the record), but real.
F. **Move grant/withdraw onto a service.** The row calls the repositories directly while the
   read path already lives in `HouseholdService`; the consent construction, the
   `settingsMerged` refusal and the replace-on-`ValidationException` path are business rules
   only a widget test can currently reach.
G. **`mine.first`** silently decides which household sees a member's Art. 9 data when they
   belong to several — same `.first` question as the read path, now on the write path too.

**Must land BEFORE the flag is ever flipped** (both only become user-visible at that
moment, both fail safe until then):

A. `feature_flag_service.dart` — the switch comment says flipping it on early would "learn
   nothing". It would do more: with no rules block the denied query throws, so EVERY
   multi-member household falls to the floor with the incomplete-roster warning on the
   menu. State the real consequence before anyone can act on the comment.
B. `household_service.dart` — `othersOnRoster` counts members already known to be
   `missing`, whose shares this same batch discards. A household whose only other members
   are deleted accounts therefore degrades on an unreadable read that lost it nothing —
   the household-of-one carve-out, one step further out. Key it on
   `id != selfId && !missing.contains(id)`; `unresolved` must keep counting, since an
   unread profile leaves existence unknown.
C. `household_service.dart` — the two degraded-with-floor constructions are now
   byte-identical apart from their log line, in a file whose own `_floorOnly` comment says
   the floor is "kept in one place… two copies would drift". Extract one.

13. `household_service.dart` — "both callers gate on `hasHousehold`" is FALSE:
    `household_allergen_filter_tile.dart` calls `aggregateAllergenPreferences()`
    unconditionally on toggle-off, and the suite's own empty-roster test exercises the
    branch that comment calls unreachable. It matters for the new `othersOnRoster` line,
    because on that caller `memberIds` can come from `currentUserProfile?.uid` while
    `selfId` comes from `PermissionService` — if the two disagree mid-auth, a solo user's
    unreadable share read degrades them. Fail-safe direction only, and dark while the flag
    is off.
14. `unresolvedMemberIds`' doc says "Empty on the whole-aggregation-failed path" — now one
    of three such paths (add the unreadable-shares return and the empty-roster return).
15. The `sharesFuture` started before `Future.wait` would surface as an unhandled zone
    error if a throwing line were ever added ABOVE its `try`. Theoretical today; the
    comment is load-bearing for a second reason it does not state.
16. `HouseholdAllergenShare.toPreferences()` has no production caller — the aggregate
    unions field by field. Either the writer/UI slice uses it or the doc should stop
    calling it "the shape the household aggregate consumes".

**Settled since, so the rule can be written without hedging:** a re-grant is always a
`create` on a document that does not exist, because `revoke()` deletes and `create()` now
refuses an existing id. So `consentGrantedAt` CAN be pinned immutable across an update
without denying anyone their way back after a withdrawal — the case that would otherwise
have made a withdrawal irreversible.

## Verification

- `flutter test` on: `household_service_test` (shared member uses the real list; unshared
  keeps the floor; **shared-but-empty means no allergies, not floor**; a share for a member
  outside the household is ignored), the atomic dual-write, the settings toggle widget test,
  and `menu_household_allergen_test`.
- Rules tests via `firestore-rules-tester` against the emulator: non-member denied read;
  a removed member denied immediately with no projection rewrite; sharer-not-in-household
  denied write; missing/false `consentGranted` denied write; wrong `userId` denied write.
- Each new test mutation-verified — remove the load-bearing token, watch it redden, restore.
- `flutter analyze --fatal-infos` clean, and the toggle + dialog + menu CTA checked in a
  real browser before anything is called done.
- Commit gates: `code-reviewer`, `firebase-backend-security`, `firestore-rules-tester`,
  `cloud-functions-specialist`, `testing-specialist`, `integration-reviewer`. The reviewers
  stall past three files, so this ships as several commits (papers / rules + repository /
  service + UI / cascade + export), not one.
- The BUT-1663 floor entry gets a dated **superseding** addition in
  `docs/architecture/ACCEPTED_DEVIATIONS.md` **and** its mirror line in the always-on
  `.claude/rules/accepted-deviations.md`, in the same edit — the floor is now conditional on
  opt-in, and a session that only reads the mirror must not keep believing otherwise.
- The GDPR export leg is client-side, in `lib/services/account/export/` beside
  `preferences_export_manager.dart` — there is no Cloud Function export directory.
- Execution copy of this plan goes to `tasks/butlery-1693-household-share-plan.md`;
  `tasks/todo.md` belongs to the BUT-1819 session that is mid-execution in it.
- Expect `docs/onboarding/workflow-map.stale`; re-trace only the flows it names.
- Append the panel's review event to `docs/org/metrics/events.jsonl`.

## Open questions

Four were asked and answered by Malin before this plan was written — the decision table at
the top. They were the architecture-changing ones: what may be shared, who may read it, the
minimisation premise, and build order.

The fifth — whether a member's GDPR export includes the *other* members' shared allergen
lists — was answered on **2026-08-12: no.** The export carries the requester's own share and
consent record only. Their client can read the others live, and this repo's export precedent
says what the client can read the export may carry, but those precedents govern display
names and shopping rows; Art. 9 health data about another person is not the requester's
personal data and Art. 15 does not reach it. Recorded in the DPIA addendum (R8) and
ADR-0005 (D5).

**No architecture-changing unknowns remain.** Assumptions carried into the build: the
signed-in user has a `households/{householdId}` document (created by "Min familj"), and a
member listed in the friend-category household but absent from it simply has no readable
share and keeps the floor.

---

## Vad det här betyder, på svenska

Idag kan Butlery inte läsa någon annan vuxens allergier — de är privata. Därför gissar appen
fyra vanliga allergier för varje familjemedlem den inte kan läsa. Det skyddar mot fel sak:
den som är allergisk mot ägg eller skaldjur får inget skydd, och en familj utan de fyra får
en meny som krympts i onödan.

Efter det här kan var och en själv välja att dela sin lista med hushållet. Menyn slutar
gissa för dem som delat, och fortsätter vara försiktig för dem som inte har delat. Ingen
tvingas, och man kan ta tillbaka det när som helst.

Tre saker du redan bestämt är inbyggda: kostval delas i samma val som allergier (och då blir
hela familjens meny t.ex. vegansk om någon delar det — det står i rutan innan man klickar),
alla i hushållet ser det även om de går med senare, och pappersarbetet skrivs först.

Det du ser i appen är bara en gemensam lista — aldrig "Anna: mjölk". Det är medvetet.

## State at 2026-08-12, settings slice HELD (not committed)

Everything is written, green and staged. The commit is blocked by the review gate,
which is ledger-based: it records which reviewer agent Read which bytes. Four agents
were re-spawned after the last two fixes and all four died on the account session
limit (resets 23:10 Europe/Stockholm). Nothing was forged; no marker was hand-written
(the `.claude/state/*.marker` files are NOT what this gate reads).

To finish, in one step: re-run `code-reviewer`, `testing-specialist`,
`firebase-backend-security` and `integration-reviewer` over the final bytes, then

    git commit -F <scratchpad>/but1693-ui-msg.txt -- <the 23-path pathspec>

The pathspec is the BUT-1693 slice ONLY. The index also holds the parallel session's
firestore.rules, functions/src/messaging/*, tag_result.dart,
test/unit/security/rules_allowlist_drift_test.dart, both ACCEPTED_DEVIATIONS files and
tasks/todo.md — none of those may ride along.

Verified at hold time: 17 tests on the row, 254 green across settings and dialogs,
`dart analyze` clean, tree byte-identical to the index for every lib/ and test/ file,
no probe or mutant residue.

### Open follow-ups found by the reviews (none blocking this commit)

1. **Solo household shows the row.** `ensureForUser` creates a `households/{id}` for a
   one-person household, so the row can appear saying "Hushållet gissar just nu åt dig"
   when nobody is guessing. Fix: `if (household.memberUserIds.length < 2) return;` in
   `_resolve`, plus a test. Invisible today (flag OFF). — code-reviewer Medium 1
2. The two adjacent settings rows gate on two different "household" concepts
   (FriendCategory vs the `households` collection). Worth a sentence in the tile header.
3. `_grant` discards the merged profile it just fetched, so `UserService.allergenPreferences`
   keeps returning the defaults on the same screen. — integration Optional 6
4. Duplicate household resolution (tile vs `HouseholdService._sharedListsByMember`), both
   `.first` over an unordered query. One shared accessor. — integration Optional 4
5. An annex↔ARB code-point test, and a test for the replace branch's failure arm.
   — testing-specialist, non-blocking
6. The flag comment cites one grep for four gates; the export half is client-side under
   `lib/services/account/export/` and that grep cannot reach it. — security Low
