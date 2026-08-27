# PLAN 2026-08-27 (andra passet) — BUT-1961 + BUT-1959/BUT-1914

Malin sa "ta tag i 1961 och 1959" efter att ha läst rapporten, där jag namngav en
rekommendation för var och en. Jag bygger enligt de rekommendationerna.

**BUT-1959 kan inte byggas ensam.** Den är LEVEL-halvan av samma vaktarm som BUT-1914 är
PATTERN-halvan av. BUT-1914 valdes i morgonens sprint men byggdes aldrig. Att bara göra
den ena lämnar armen halvfärdig och nästa läsare hittar två ärenden mot samma fem rader.
Båda byggs här.

Router: `single` för båda.
- BUT-1961: Data Analyst/BI, Performance, PM, Trust & Safety
- BUT-1959/1914: Data Analyst/BI, Performance, Trust & Safety

## Mätning gjord FÖRE bygget

Kommentaren i vaktarmen säger "Forty-odd non-`error` sites" och tillägger uttryckligen att
antalet varit fel två gånger i kommentarens historia. Mätt nu, på bara `$conversationId`
respektive `${conversationId}` i `lib/`:

| nivå | ställen |
| --- | --- |
| `.debug` | 14 |
| `.info` | 15 |
| `.success` | 11 |
| `.warning` | 1 |
| **summa** | **41** |

Med det bredare mönstret (även `${x.conversationId}` och `${convId}`) blir det 61 totalt,
varav **14 på `.error`** — alltså ställen som dagens arm SKA fånga men inte gör, eftersom
den bara ser den nakna identifieraren. Det är BUT-1914:s hål, och det är inte noll som
armens kommentar påstår ("zero instances today, checked").

VARNING: den siffran måste verifieras innan den blir ett påstående någonstans. Mönstret kan
matcha en redan maskerad form, eftersom `${conversationId.maskedConversationId}` innehåller
strängen `conversationId`. Räkna om med maskerade former exkluderade före något skrivs.

---

## BUT-1961 — skilj "finns inte" från "fick inget svar"

### Problemet

`getDocCacheFirst` (`base_firebase_repository.dart:373-383`) returnerar cache-träffen bara
`if (cached.exists)`. En vecka som är genuint TOM finns inte som dokument, så den faller
igenom till `.get(GetOptions(source: serverAndCache))` — som kastar offline. Efter BUT-1939
blir det `readFailed: true`, och vymodellen vägrar.

Följd: att planera en HELT NY vecka offline slutade fungera. En vecka man redan öppnat
fungerar (den ligger i cachen med `exists == true`).

### Riskerna, som avgör formen på lösningen

`getDocCacheFirst` är en DELAD hjälpare i basklassen. Att ändra dess semantik ändrar varje
repo som använder den. Första steget i bygget är att räkna anroparna — inte att anta att
det bara är veckomenyn.

Två former att välja mellan:
1. **Ny metod bredvid**, t.ex. `getDocCacheFirstOrAbsent`, som returnerar något som skiljer
   de tre utfallen (finns / finns inte / fick inget svar). Bara veckomenyns repo byter.
   Ingen befintlig anropare rör sig.
2. **Ändra `getDocCacheFirst`** att skilja fallen. Rör alla anropare.

Form 1 är nästan säkert rätt — men det är exakt den sortens val jag ska låta kritiken
väga, inte avgöra ensam i planen.

### Acceptanskriterier

1. `diff` — en genuint tom vecka offline ger INTE `readFailed`, och går att planera.
2. `diff` — en vecka som inte gick att LÄSA ger fortfarande `readFailed`, och vägran står.
   Detta är BUT-1939:s hela poäng och får inte tappas.
3. `diff` — antalet anropare av den ändrade hjälparen är RÄKNAT och skrivet i planen, och
   ingen befintlig anropare byter beteende oavsiktligt.
4. `diff` — båda fallen är mutationsprövade var för sig: en fixtur för "finns inte" och en
   för "svarade inte", och att ta bort skillnaden rödnar det ena utan det andra.
5. `diff` — den accepterade avvikelsen skrivs in i BÅDA avvikelsefilerna om utfallet blir
   att något medvetet lämnas.

- [ ] Räkna anroparna av `getDocCacheFirst` FÖRE någon ändring
- [ ] Konvenera kritiken; välj form 1 eller 2 på dess villkor
- [ ] Bygg + tester, mutationspröva båda riktningarna

---

## BUT-1959 + BUT-1914 — vaktarmen mot råa konversations-id

### Vad som byggs

**BUT-1914 (pattern):** armen matchar i dag bara den nakna identifieraren, så
`${message.conversationId}`, `${conversation.id}` och `${convId}` är osynliga. Widen —
snävt, så att `${recipe.id}` inte fångas.

**BUT-1959 (level):** armen täcker bara `AppLogger.error(`. Uid-armen bredvid täcker alla
nivåer. Ett `direct_`-id ÄR två råa uid, så asymmetrin har inget skrivet skäl — armens egen
kommentar säger att den "is not a policy anyone decided".

Malins beslut: bredda. Det kostar att loggställena måste maskeras först.

### Ordningen är hela arbetet

Att bredda armen utan att först maskera ställena gör bygget rött. Alltså:
1. Maskera de 41 ställena (`.maskedConversationId` finns redan).
2. Bredda armen.
3. Kör armen mot ett PLANTERAT brott och se den rödna — annars vet vi inte att den lever.

### Acceptanskriterier

1. `diff` — armen täcker alla `AppLogger.*`-nivåer, inte bara `.error`.
2. `diff` — armen fångar `${x.conversationId}` / `${convId}`, men INTE `${recipe.id}`.
3. `diff` — sviten är grön EFTER maskeringen, och armen rödnar mot ett planterat brott på
   en icke-error-nivå. Båda körningarna klistras in.
4. `diff` — armens kommentar beskriver den nya räckvidden, utan siffra som ruttnar. Den
   ärliga kvarvarande begränsningen (undantagsOBJEKTET till `recordError`, som inget
   `AppLogger`-mönster når) står kvar — det är BUT-1907.
5. `diff` — ingen maskering ändrar en loggs betydelse för den som felsöker: ett maskerat id
   ska fortfarande gå att korrelera inom samma session.

- [ ] Räkna om med maskerade former exkluderade
- [ ] Maskera, sedan bredda, sedan planterat brott
- [ ] Kontrollera att `maskedConversationId` finns och gör vad namnet säger

## Avvikelselogg (andra passet)

---

# ARKIV — sprinten 2026-08-27 (första passet), levererad

# PLAN 2026-08-27 — sprint (auto-select, N=7): poll-vote blocking at the rules level,
# shared-list attribution, GDPR analytics leftovers, week-overwrite rest, poll atomicity,
# a wedged group chat, and a log-PII guard that cannot see conversation ids

Selected via `/delivery:sprint-execute` (Phase 1, no `--pick`, no `malin` argument — the
Phase 3.6 decision queue does not run this pass). Linear MCP dropped its token twice during
this run; selection facts below come from the reads that succeeded plus a grep of current
`main`. **All Linear writes (transitions, start comments, close-out comments, follow-up
tickets) are batched to close-out** and are listed explicitly in "Linear writes owed" so
nothing is lost if the token expires again.

Backlog gathered: 100+ Backlog (paginated, `hasNextPage: true`) + 10 Todo + 0 In Progress +
0 Triage. Score = priority base (Urgent 100 / High 75 / Medium 50 / Low 25) + 20 for a
`bug`/`security` label. No ticket carried a due date, so the overdue and due-this-week
bonuses never fired.

## The state this sprint inherited

The 2026-08-23 sprint transitioned nine tickets to Todo and then failed to close them out —
that failure is itself filed as BUT-1932/1933/1935/1936. So Todo is **not** a list of open
work: three of its entries shipped days ago and were never transitioned. The Step-0 grep of
`main` below is what separates them, exactly as the skill's premise-check rule requires. The
`git log` scan alone would have caught these three, but it is not what decided them.

## Selection record

| Ticket | Disposition | Priority | Router tier | Plan mode | Panel |
| --- | --- | --- | --- | --- | --- |
| BUT-1917 blocked voters are not stopped by the rules | build | High | **full-panel** | yes | Security Architect, Trust & Safety, Privacy/DPO, Legal, DBA, Support, PM, QA, Software Architect, FinOps, Vendor |
| BUT-1939 three save-after-read sites can still overwrite a week | build | High | single | yes (priority <= 2) | Product Manager |
| BUT-1716 second shared-shopping repo stamps no attribution | build | High | single | yes (priority <= 2) | Data Analyst/BI, Performance, Trust & Safety |
| BUT-1800 deletion leaves two analytics collections behind | build | High | single | yes (priority <= 2) | Vendor/Procurement |
| BUT-1929 a deleted group chat wedges every future poll | build | Medium | single | no | Vendor/Procurement |
| BUT-1925 closing a poll is not atomic | build | Medium | single | no | Data Analyst/BI, Performance, Trust & Safety |
| BUT-1914 the log-PII guard cannot see `$conversationId` | build | Medium | single | no | Software Architect, Product Manager |

Router: `python tools/stakeholder_router.py --json <paths>`, run once per ticket rather than
once per batch, so a `full-panel` verdict cannot be smeared across tickets that did not earn
it. Only BUT-1917 came back `full-panel`, and only because it edits `firestore.rules`.

Panel policy is `park` (`shared-plugin.json` -> `delivery.router._panelPolicy`). The worker
here is this interactive session, which **can** spawn agents, so per the dispatch gate the
`single` critiques and the BUT-1917 panel are convened before the build — the
"cannot convene" fallback does not apply and must not be taken.

None of the seven carries a product choice. Each restores behaviour the code already claims
to have: blocking should block, a failed read should not overwrite, a delete should delete.
Disposition is therefore `build`, not `needs-approval`.

### Step-0 premise check — grep of current `main`, not `git log`

**Closed as obsolete (shipped, never transitioned):**

* **BUT-1928** — GONE. `lib/services/menu/weekly_menu_plan_service.dart:63-103`: `getWeek`
  now delegates to `readWeek`, returning `WeeklyMenuPlanRead(plan, readFailed)`. Both
  poll-close write paths check `read.readFailed` before writing. Shipped `453828fe9`.
* **BUT-1926** — GONE. `lib/services/messaging_service.dart:861-885`: an absent
  `BlockedUserFilter` now throws `PollCloseRefusedException(blockListUnknown)` instead of
  continuing, and a failed `requireBlockedIds()` throws the same. Fails closed. Shipped
  `453828fe9`.
* **BUT-1913** — GONE. Both tests now assert the exception's raw field (`resourceId`,
  `exception.resource`) instead of a rendered id shape. Shipped `cc997335f`.

**Verified still present (the seven above):**

* **BUT-1917** — `firestore.rules:2239-2249`. `poll_votes` create/update gate on
  `isAuthenticated()`, `request.auth.uid == voterId`, `inPollConversation()`, `pollIsOpen()`
  and `isValidVote()`. **No blocklist predicate exists on either limb.** The client half is
  already done (`_withoutBlockedBallots` at `messaging_service.dart:315-334` strips blocked
  voters from the rendered tally; `closePoll` refuses when the list cannot be resolved), so
  this is the server half only.
  WARNING — correction folded in: the first premise check reported that the rules comment
  "documents this gap as accepted/deferred". Read directly, it does not. The commentary at
  `firestore.rules:2162-2225` documents two *different* poll-vote gaps — BUT-1838's
  `memberSince` cut-off and BUT-1832's metadata-map-without-`poll` row — and both of those
  are in `.claude/rules/accepted-deviations.md`. The blocklist gap is in neither. Do not
  close this ticket by citing those entries; that is the exact error the BUT-1732 entry
  records having made.
* **BUT-1939** — all three sites still call the unsafe `getWeek`:
  `onboarding_viewmodel.dart:514` (save at `:561`), `menu_placement_viewmodel.dart:120`
  (save at `:245`), `weekly_menu_plan_viewmodel.dart:161` (saves at 219/258/283/299/327/352).
  **Dependency resolved — the guard is not inert.** `getDocCacheFirst`
  (`base_firebase_repository.dart:373-383`) wraps only the *cache* read in try/catch; its
  final `return await docRef.get(GetOptions(source: Source.serverAndCache))` is unguarded and
  throws when the server is unreachable with no cache. So `readFailed: true` really is minted
  in the offline case the guard was built for. The contradicting comment is
  `firebase_weekly_menu_plan_repository.dart:92-94`, which claims the read "returns null ...
  rather than letting a server read stall/throw" — false, and struck as part of this ticket
  per code-style ("a wrong comment gets STRUCK, not reworded").
* **BUT-1716** — `firebase_shared_shopping_repository.dart` writes no attribution in
  `addItem` (373-393), `addItemsBatch` (402-436), `updateItem` (505-521), `toggleItemBought`
  (558-588) or `removeItem` (529-548). The sibling BUT-1697 fixed,
  `shopping_item_operations_module.dart:65-109`, stamps `lastActivityByUserId` and
  `lastActivityByDisplayName` on every item write. DI-registered at
  `social_module.dart:371`, so this is a live second write path, not dead code.
* **BUT-1800** — `account-deletion-cascade.ts` erases
  `analytics/feature_retention/users/{uid}_{date}` (BUT-1789, lines 458-484 / 1030-1063) and
  nothing else under `analytics`. Still uncovered, both uid-bearing:
  `analytics/retention/events/{uid}_d{day}` (written `track-retention.ts:165-176`) and
  `analytics/lapsed_users/events/{autoId}` carrying a `userId` field (written
  `detect-lapsed-users.ts:256-267`).
* **BUT-1929** — `functions/src/groups/ensure-category-chat.ts`: the early return at 330-339
  fires whenever `toAdd` and `toRemove` are both empty and returns the stale `conversationId`
  from line 300; the deleted-conversation guard is at 393-398, *inside* `runTransaction`, so
  the steady-state path never reaches it. The only deleted-conversation test
  (`ensure-category-chat.test.ts:599`) also adds `"latecomer"` to the roster, so it exercises
  the transaction path and never the early return.
  Second half: `chat_group_error_mapper.dart:45-55` reads `details['reason']` but matches only
  `'group-too-small'`, so this failure renders as `genericFallback` — while the Swedish string
  already exists, unused, at `app_sv.arb:3465` (`messagingGroupNoLongerExists`:
  "Denna grupp finns inte langre").
* **BUT-1925** — `messaging_service.dart:811-937`: pre-read at 818-830 is the only guard, the
  plan write lands at 890-919, and `isClosed` flips afterwards at 924.
  `message_mutation_module.dart:475-497` checks `pollMap['creatorId'] != closerId` and then
  does a plain `update()` — no transaction, no compare-and-set on `isClosed`.
* **BUT-1914** — `architecture_test.dart:504-506`: the conversationId arm is
  `AppLogger\.error\([^;]*(\$conversationId\b|\$\{conversationId\})` — scoped to `.error(`
  only, and bare-identifier only. The uid arm at 449-451 covers all `AppLogger.\w+` levels.
  So `${message.conversationId}` at `.info`/`.warning`/`.debug` is invisible, and a `direct_`
  id is two raw uids.

### Not selected, with the reason recorded

* **BUT-1921** (`Low`, tech-debt) — **premise refuted, nothing to build.** The observed
  failure (`sh: line 2: [: .github/workflows/test.yml: binary operator expected`) is real,
  but a sweep of `.claude/hooks/*.sh`, `tools/*.sh`, `lefthook.yml`, `.github/workflows/` and
  `scripts/` found no unquoted `[ $VAR ... ]` that could produce it: the secret-scan test at
  `lefthook.yml:26` is correctly quoted (`[ -z "$files" ]`), and every remaining bare-`$var`
  single-bracket test is numeric. A prior recorded investigation
  (`.claude/state/sprint-patches/batch-5-20260823-184335.json`) reproduced the error only
  against a deliberately-unquoted control script and found no twin in history via
  `git log -S`. Stays open as an investigation; building a fix would be building against a
  cause nobody has located.
* **BUT-1944** (`High`, tech-debt) — **deferred, and the sprint is the wrong place for it.**
  Measured: `testing-specialist.knowledge.md` is 1339 lines / 113630 chars against a
  `knowledge.sizeLimit` of 800, so the ticket's headline is true. But the file's own
  pre-authorised split trigger is *~250000 chars*, not the line limit, and the janitor's
  auto-distillation fires at 2x (1600 lines) — neither is reached. `knowledge-freshness.mjs`
  warns to stderr and explicitly "never blocks; fails open", so nothing is being silently
  enforced either. Decisive reason: the file **is modified in the working tree right now** by
  this repo's own reviewer agents, and every commit in this sprint invokes
  `testing-specialist`. Restructuring a shared file while concurrent agents write to it is
  precisely what the ticket's own last section says not to do. It belongs in a session that
  runs no gates.
* `need-malin` and `deferred`-labelled tickets were left unselected regardless of score —
  decision-queue and long-hold material, not this pass's target.

## Tasks

### BUT-1939 — a failed week read can still overwrite the week [Tier A] [build]

Acceptance criteria:
1. `diff` — all three save-after-read call sites read through `readWeek`/`readOrBuildWeek`
   and refuse to save when `readFailed` is true; the five display-only callers are untouched.
2. `diff` — `onboarding_viewmodel.dart`'s idempotency comment no longer claims immunity it
   does not have, or the claim becomes true.
3. `diff` — the false comment at `firebase_weekly_menu_plan_repository.dart:92-94` is struck,
   not reworded.
4. `diff` — a test proves a failed read does **not** result in a save, for at least the
   onboarding path.

- [ ] Trace the three sites and the five display-only callers before editing
- [ ] Convert the three; leave `slot_picker_dialog.dart:95` alone (display-only, no save)
- [ ] Strike the false repository comment
- [ ] Tests

### BUT-1716 — the second shared-list write path stamps nobody [Tier A] [build]

Acceptance criteria:
1. `diff` — `addItem`, `addItemsBatch`, `updateItem`, `toggleItemBought` and `removeItem` in
   `firebase_shared_shopping_repository.dart` stamp the same attribution fields, with the
   same names, as `shopping_item_operations_module.dart`.
2. `diff` — the field names match the sibling exactly (`lastActivityByUserId`,
   `lastActivityByDisplayName`), verified by reading both, not by memory.
3. `diff` — `firestore.rules` is checked in the same edit for a `hasOnly` allowlist that
   would deny the new fields (lessons digest, BUT-1482), and a rules test covers it if one
   applies.
4. `diff` — a test asserts the stamp on at least one write per method family.

- [ ] Read both repositories side by side; list the exact field names
- [ ] Check `firestore.rules` for the shared-list item validator BEFORE writing code
- [ ] Implement + tests

### BUT-1800 — account deletion leaves two analytics collections behind [Tier C] [build]

Acceptance criteria:
1. `diff` — the cascade erases `analytics/retention/events/{uid}_d{day}` and
   `analytics/lapsed_users/events` rows carrying the deleted `userId`.
2. `diff` — the sweep declines rather than truncates above a cap, matching the existing
   BUT-1822 roster-sweep shape, and reports incompleteness rather than a false success.
3. `diff` — no raw uid reaches a log on the new path.
4. `diff` — tests cover both collections, including the "nothing to delete" case.

- [ ] Read `account-deletion-cascade.ts` and mirror the `deleteFeatureRetentionFlags` shape
- [ ] Check whether either collection's id shape needs a query rather than a doc delete
- [ ] Implement + tests

### BUT-1929 — a deleted group chat wedges every future poll [Tier C] [build]

Acceptance criteria:
1. `diff` — the steady-state early return can no longer hand back a conversation id that
   does not exist.
2. `diff` — if the chosen fix throws `failed-precondition`, it carries a `details['reason']`
   that `ChatGroupErrorMapper` matches; if it self-heals, no error surfaces at all.
3. `diff` — the user-visible string is the existing Swedish
   `messagingGroupNoLongerExists`, not `genericFallback`.
4. `diff` — a test combines an **unchanged** roster with a deleted conversation and asserts
   the caller never receives the dead id.

- [ ] Decide self-heal vs hoisted check; the ticket argues self-heal costs nothing extra
- [ ] Weigh the extra `get()` on the steady-state path if the hoisted check wins
- [ ] Implement + the missing test case

### BUT-1925 — closing a poll is not atomic [Tier A] [build]

Acceptance criteria:
1. `diff` — a retry after a partial failure cannot place the same recipe in a second slot.
2. `diff` — the `isClosed` check and the write that depends on it happen in one atomic
   operation, or the ordering is inverted so the failure mode is a closed poll with no meal
   (visible and recoverable) rather than a duplicate.
3. `diff` — the doc comment describes what the code does, with no claim about a re-check
   that does not exist.
4. `diff` — a test drives the double-fire.

- [ ] Choose transaction vs inverted ordering; the ticket calls the transaction the real answer
- [ ] Implement + test

### BUT-1914 — the log-PII guard cannot see a conversation id [Tier A] [build]

Acceptance criteria:
1. `diff` — the conversationId arm covers every `AppLogger.*` level, not only `.error(`.
2. `diff` — it catches non-bare expressions (`${message.conversationId}`, `${conversation.id}`,
   `${convId}`) or the arm's comment states precisely what it still cannot see, with no
   "every/no/only" the regex does not earn.
3. `diff` — the guard is proven both ways: a planted violation reddens it, and the current
   tree passes. A dormant assertion protects nothing (lessons digest, BUT-1931).
4. `diff` — any existing violation the widened arm now catches is fixed, not allowlisted.

- [ ] Widen the arm; run it against a planted violation FIRST
- [ ] Fix whatever it newly catches
- [ ] Correct the arm's comment to the new truth

### BUT-1917 — blocking is not enforced on poll votes at the rules level [Tier C] [build -> In Review]

**Convene the full panel before building** (dispatch-gate rule: this session can spawn
agents, so the "cannot convene" fallback is unavailable). Panel: Security Architect,
Trust & Safety, Privacy/DPO, Legal, DBA, Support, PM, QA, Software Architect, FinOps, Vendor.

Acceptance criteria:
1. `diff` — a blocked user's `poll_votes` create/update is denied by `firestore.rules`, not
   only filtered client-side.
2. `diff` — the cost of any added `get()` on the vote path is stated and weighed; the repo's
   cost principle makes an unbounded per-vote read a real objection, not a nit.
3. `diff` — `poll-votes-rules.test.ts` gains allow **and** deny cases against the emulator.
4. `diff` — the change does not silently alter the two gaps the surrounding comment records
   as accepted (BUT-1838 `memberSince`, BUT-1832 metadata-without-`poll`); if it touches
   either, that is called out rather than folded in.

- [ ] Convene the panel; fold every must-have into the criteria above before coding
- [ ] Establish where the blocklist lives and whether a rule can even read it per-vote
- [ ] Implement + rules tests
- [ ] Parks In Review regardless of grades (panel policy `park`)

## Phase 1.4 — panel conditions, folded in (BINDING)

Seven critiques convened before any code: a four-seat blind panel on BUT-1917 (Security
Architect; Trust & Safety + Support; Privacy/DPO + Legal; DBA + FinOps + Software Architect)
and three single-role reviews covering the other six. Every must-have below is binding and
overrides the acceptance criteria above where they conflict. Two of my own criteria were
wrong and are corrected here rather than left standing.

### Corrections to the criteria written at selection

* **BUT-1800, criterion 2 was WRONG.** It demanded "the sweep declines rather than truncates
  above a cap, matching the existing BUT-1822 roster-sweep shape". That shape belongs to
  **collectionGroup** sweeps, where rows sit under arbitrarily many parents. Both collections
  here hang off a single fixed parent doc, exactly like `feature_retention` — so the correct
  model is `deleteFeatureRetentionFlags` (`account-deletion-cascade.ts:1057-1064`):
  uncapped single-collection `where('userId','==',uid)` -> `batchDeleteAll` -> `return true`.
  Importing the capped decline machinery here would be cargo-culting a control built for a
  different query shape.
* **BUT-1914, criterion 1 was WRONG.** It demanded the arm cover "every `AppLogger.*` level".
  The arm's own comment records that the `.error`-only scope "is not a policy anyone decided",
  and widening it IS that decision. Split: ship the **pattern** widen only; the **level** widen
  goes to Malin. See below.
* **BUT-1716, criterion 2 was WRONG.** It said to match `lastActivityByUserId` /
  `lastActivityByDisplayName` "exactly". Those are the sibling's **list-document** stamp; this
  repository writes the **item subcollection**, whose fields are `addedByUserId`,
  `addedByDisplayName`, `lastModifiedByUserId`, `purchasedByUserId`. Copying the list-level
  pair down to item level would invent fields with no rules precedent and no reader.

### BUT-1917 — the panel split, and how it was resolved

Two seats contradicted each other on whether this is an integrity bug or confidentiality
hygiene. Resolved by measurement rather than by preferring a seat:

`closePoll` (`messaging_service.dart:861-888`) refuses only when the block list is
UNRESOLVABLE. When it resolves, it strips ballots via `requireBlockedIds()` — the **closer's
own** list — and the plan write runs only when `resolvablePoll.creatorId == currentUserId`,
so the list consulted is always the **creator's**. Therefore: A blocks B, C creates the poll,
C closes it — B is absent from C's list, B's ballot counts, and B's recipe lands in A's plan.
Trust & Safety is right; the DBA seat conflated fail-closed-on-unresolvable with
fail-closed-on-third-party-block. The code's own comment at `messaging_service.dart:850-855`
names this exact harm and the guard below it closes only one route to it.

**The consequence is the important part: the rules fix does NOT close that hole.** The only
expressible predicate is `blocks/{senderId}_{voterId}`, which fires only when the CREATOR
blocked the voter. A third party's block is invisible to rules — they cannot iterate
`participantIds` (`firestore.rules:215`). So this ticket ships confidentiality for the
creator-voter pair, and the integrity half is filed separately rather than scope-crept in.

Binding conditions:
1. Predicate keyed on the message's immutable `senderId` (`cannotModify` at
   `firestore.rules:2110-2116`), never `metadata.poll.creatorId`, which a sender can rewrite —
   a client-controlled field is not a security input.
2. Derive `senderId` from the ALREADY-CACHED `pollMessage()`. Target exactly 3 distinct
   document access calls (from 2 today); the 10-call cap is not approached. Do not add a
   second `get()` at a different path.
3. `create` and `update` limbs ONLY. **Not** `read`, **not** `delete`, and **not** inside
   `inPollConversation()` — all three limbs call it, and the Art. 15 export reads a vote row
   through the client `read` limb (`firebase_data_export_repository.dart:475-490`). Landing it
   there would drop a blocked user's own vote from their data export, and fail SILENTLY: the
   repo's catch sets `poll_votes_error_code`, so the bundle would claim a read failure rather
   than show an omission. `delete`'s single conjunct `uid == voterId` is load-bearing for
   Art. 17 and stays.
4. Prove the two pinned deviations in this same rule block are unmoved — BUT-1832's
   metadata-without-`poll` ALLOW and BUT-1838's absent `memberSince`. Paste the emulator run.
   This change does NOT perform BUT-1832's owed presence-test repair and must not be read as
   having done so.
5. Rules tests both limbs, both ways, plus one proving the REVERSE-direction block doc does
   not deny — so the direction is pinned by a test, not by a comment.
6. The client swallows the resulting `PERMISSION_DENIED` and shows the same non-committal
   outcome as success. No text revealing a block relationship.
7. Keep `_filterBlocked` and `_stripBlockedBallots`. Three surfaces cover three DIFFERENT
   populations and directions; the rule is forward-only and says nothing about votes cast
   before the block, so the display filter is the only retroactive cover. Say so in the commit
   body so a later cleanup does not read the rule as superseding them.
8. New entry in BOTH deviation files recording the one-directional semantics, whose blocklist
   is read, and that the denial is an accepted inference channel — justified because `blocks`
   doc ids are the deterministic composite and `firestore.rules:2399-2404` already lets the
   BLOCKED party read their own row, plus three existing `isNotBlockedBy()` gates leak the
   same inference.
9. Order the `exists()` LAST in both `&&` chains so CEL short-circuits.
10. Cost was measured, not asserted: ~$0.0005/month at current scale. Record it so the
    CLAUDE.md cost principle is not used to re-litigate this.

### BUT-1939

1. `menu_placement_viewmodel.confirm()` and the `weekly_menu_plan_viewmodel` save paths call
   `setError()` with a specific Swedish message on a `readFailed` refusal — a bare early
   return falls through to the generic `errorUnexpected` string, which misdescribes a
   retryable failure.
2. The copy tells the user to retry.
3. Onboarding keeps its existing silent-swallow shape (it is fire-and-forget at
   `onboarding_viewmodel.dart:382` and gates no navigation), but gains a log/analytics signal
   so the refusal is not invisible.

### BUT-1716

1. Stamp the ITEM-level fields the rules and model already define, not the list-level pair.
2. **Verified, and it enlarges the ticket:** `firestore.rules:844-858` requires
   `addedByUserId == request.auth.uid` on create and `lastModifiedByUserId == request.auth.uid`
   on update. On an update `request.resource.data` is the MERGED document, and
   `toggleItemBought` (`:566-570`) writes only `bought`, `purchasedByUserId`, `purchasedAt` —
   so the merged doc keeps whoever last touched the item, and a second member ticking it off
   should be DENIED. This is the BUT-1826 class ("rules require fields the writer never
   sends"), not a missing-attribution nit. CONFIRM against the emulator before writing the
   fix; if it holds, rewrite the ticket premise first.
3. No `hasOnly` allowlist exists on this block, so the BUT-1482 fail-closed hazard does not
   apply — verified at `firestore.rules:844-858`, not assumed.
4. A display-name field ships with its backfill owner (`on-profile-updated.ts`) named in the
   same edit, or the gap is filed. A name copy with no backfill owner is the BUT-1798
   "two copies of one fact drifted" failure.

### BUT-1925

1. Replace the non-atomic pre-read with a transactional test-and-set of `isClosed` on the
   message document, run BEFORE the plan write. Scoped to ONE document — no cross-collection
   span is needed and none is possible without refactoring three service boundaries.
2. Wrap the group-plan read-modify-write (`readOrBuildWeek` -> `addEntry` -> `save`) in its own
   transaction: the deterministic `{groupId}_{week}` id makes CREATION idempotent, never the
   APPEND, so concurrent closes can drop an entry.
3. Leave the DM-path plan write and `shareMenuWithFriends` outside any transaction — already
   best-effort by design.

### BUT-1929

1. Hoist the conversation-exists check above the `toAdd.length === 0 && toRemove.length === 0`
   early return.
2. **Both** throw sites carry `{ reason: 'conversation-deleted' }` — the EXISTING
   in-transaction throw at `ensure-category-chat.ts:393-398` has no `details.reason` at all
   today, so even when it fires it renders as `genericFallback`. That is a second bug beside
   the hole, and a fix that gives the reason only to the new site leaves it live.
3. Mapper gains the case beside `'group-too-small'`.
4. **No ARB edit and no `flutter gen-l10n` run.** `messagingGroupNoLongerExists` already
   exists at `app_sv.arb:3465` / `app_en.arb:3459` and is already compiled into
   `app_localizations_sv.dart:5030`. It is dead code, not a missing string.

### BUT-1914 — scope cut by the panel

1. Ship the PATTERN widen only, tightly scoped to `conversationId` / `conversation.id` /
   `convId`, never a generic `.id` match that would catch `${recipe.id}`.
2. **Do NOT widen from `.error`-only to all log levels.** The arm's comment states that scope
   "is not a policy anyone decided"; widening it IS the decision, and it belongs to Malin.
   Filed as its own ticket. -> listed under "Needs you".
3. Run the widened regex against the full file set and paste the violation count before
   committing — never assert what a check would say.
4. Keep the honest caveat that this regex catches the LOG SITE, not the exception-object
   channel `recordError` uses, which no `AppLogger.error(` pattern reaches at any level.

### BUT-1800

1. Mirror `deleteFeatureRetentionFlags` exactly: uncapped single-collection query on `userId`,
   `batchDeleteAll`, `return true`. Not the capped collectionGroup decline shape.
2. Residual `count()` probe for both collections so `gdprCompliant` stays accurate.
3. No TTL for either — both are uid-bearing, and TTL is the anonymous-aggregate tool. Checked:
   neither collides on a collectionGroup id the way `feature_retention/users` collides with the
   top-level `users` collection, and no `ttl:true` entry covers them.
4. `analytics/lapsed_users/events/{autoId}` has auto ids, so it needs a query on `userId`, not
   a doc-id delete. A bare equality filter needs no composite index.
5. No aggregate sibling exists under either parent, so there is nothing to preserve the way
   BUT-1789 preserved `daily/{date}`.

## Needs you (Tier D)

None this pass — no ticket in the selection needs console, deploy, store or secret access.

## Linear writes owed (batched — the token expired twice mid-run)

- Close as obsolete, citing the resolving commit: **BUT-1928** (`453828fe9`),
  **BUT-1926** (`453828fe9`), **BUT-1913** (`cc997335f`).
- Comment and leave open: **BUT-1921** (premise refuted; sweep found no unquoted test — root
  cause still unfound), **BUT-1944** (deferred with the measurement + the concurrency reason).
- Transition the seven selected to In Progress at start, then per tier at close-out.
- File follow-ups for every deferred sub-scope found during the build, **before** the commit.

## Deviation log

- [discovery] BUT-1917: the panel SPLIT on whether this is integrity or confidentiality.
  Measured `closePoll` directly — it strips ballots using the CLOSER's list, and only the
  creator's close writes a plan, so a THIRD party's block never applies. Trust & Safety was
  right, the DBA seat was wrong, and the rules fix cannot close the integrity half. Building
  the rules half; filing the integrity half separately rather than widening scope.
- [deviation] BUT-1914: plan said "cover every AppLogger.* level". The Software Architect
  blocked that — the arm's own comment records the `.error`-only scope as an UNDECIDED policy.
  Shipping the pattern widen only; the level widen goes to Malin as its own ticket.
- [deviation] BUT-1716: plan said to stamp `lastActivityBy*` "exactly" like the sibling. Wrong
  — those are LIST-document fields; this repository writes the ITEM subcollection. Worse, the
  rules already REQUIRE `addedByUserId`/`lastModifiedByUserId` on this path, so the ticket is
  probably a broken write path, not a missing stamp. Needs emulator confirmation before code.
- [deviation] BUT-1800: plan said to mirror the capped decline-above-cap sweep. Wrong shape —
  that control belongs to collectionGroup queries. Mirrored `deleteFeatureRetentionFlags`
  instead, on the reviewer's evidence.
- [discovery] BUT-1800: TWO reviewers independently found a THIRD uid-bearing analytics
  collection, `analytics/notifications/effectiveness`, which my comment claimed did not exist.
  Struck the numeral rather than re-counting; filing the collection as its own ticket.
- [discovery] BUT-1800: my new residual-probe leg was UNTESTED — deleting all 33 lines left
  130/130 green. Added a per-parent clean/dirty scenario and mutation-proved it (132/134).
- [discovery] BUT-1800: the cascade-step REGISTRATION was unpinned — deleting the tier-1 line
  left every unit test green because they `require()` the deleter directly. Added
  `feature_retention` and `retention_analytics` to the smoke list and proved it reds.
- [needs-human] BUT-1929: no self-heal. A deleted group conversation now reports itself
  clearly instead of wedging silently, but the pointer stays sticky and the user's only exit
  is a support path that does not exist. Raised by integration-reviewer; own ticket.
- [deviation] My own error: ran `git checkout --` on a file carrying uncommitted work while
  restoring a mutation probe, and lost the BUT-1800 registration edits. Restored by hand and
  re-verified. The repo rule says never run destructive git on a dirty tree; mutation probes
  now restore from a scratchpad backup only.
- [discovery] BUT-1939: two of my first-draft tests passed VACUOUSLY under the mutation probe
  (the onboarding one because no recipe persisted, so the walk returned before `save`; the
  weekly one because the removed entry did not exist, so the mutator short-circuited).
  Strengthened both; all five refusal tests now redden on the probe.

---

# ARCHIVE — previous sprint plan (2026-08-23), superseded

# PLAN 2026-08-23 — sprint (auto-select, N=8): poll fail-opens, plan-overwrite bug,
# blocking-rule gap, feedback-FAB accessibility, GDPR cascade gaps, golden-test blindness

Selected automatically via `/delivery:sprint-execute` (Phase 1, no `--pick`, no `malin`
argument — Phase 3.6 decision queue does not run this pass). Linear MCP confirmed
connected (`list_issues` succeeded). Backlog gathered: 178 Backlog + 9 Todo + 0 In Progress
+ 0 Triage = 187 candidates, minus 2 `onboarding-reserved` (excluded per rule, never
scored) = 185 scored.

Score = priority base (Urgent 100/High 75/Medium 50/Low 25) + 20 if `bug`/`security`
labeled. No ticket carried a due date, so the overdue/due-this-week bonuses never fired.
`deferred`- and `need-malin`-labeled tickets were left unselected (decision-queue /
long-hold material, not this pass's build target) even where they scored high.

## Selection record

| Ticket | Disposition | Priority | Router tier | Plan mode | Owning panel (if full-panel) |
| --- | --- | --- | --- | --- | --- |
| BUT-1928 a failed plan read silently overwrites the week | build | Urgent | single | yes (priority≤2) | Product Manager |
| BUT-1926 two fail-open holes in the poll/blocklist path | build | High | single | yes (priority≤2) | Product Manager |
| BUT-1917 blocking is not enforced by the rules on poll_votes | build | High | **full-panel** | yes | Security Architect, Trust & Safety, Privacy/DPO, Legal, Software Architect, PM, DBA, Perf, FinOps, Support |
| BUT-1837 Feedback-FAB semantics node covers the whole screen | build | High | single | yes (priority≤2) | Information Architect, Monetization |
| BUT-1716 second shared-shopping repo stamps no attribution | build | High | **full-panel** | yes | Security Architect, Privacy/DPO, Trust & Safety, DBA, Legal, PM, Software Architect, Perf, FinOps, Vendor |
| BUT-1800 account deletion misses two analytics collections | build | High | **full-panel** | yes | (same panel as BUT-1716 — same batch, same router call) |
| BUT-1931 golden tests cannot fail — the comparator's error is swallowed | build | High | single | yes (priority≤2) | Software Architect, PM |
| BUT-1929 a deleted group conversation wedges every future poll | build | Medium | single | no | Vendor/Procurement |
| BUT-1913 two BUT-1872 tests hang on an id shape nothing creates | build | Low | single | no | QA/Test Engineer |

Router: `python tools/stakeholder_router.py --json <paths>`, run once per batch's file set.
Panel policy is `park` (`shared-plugin.json` → `delivery.router._panelPolicy`): a
full-panel ticket still enters the sprint and still builds — it parks in In Review instead
of auto-closing at ship, and the specialist commit-gate reviewers (unconditional on every
commit) are the backstop regardless of whether the panel convenes. None of the three
full-panel tickets carry a product choice — they restore documented-intended behaviour
(blocking should block; deletion should delete) — so disposition stays `build`, not
`needsApproval`; the heavier review is a process control, not a founder sign-off gate.

### Step-0 premise check (grep of current `main`, not `git log`)

* **BUT-1928** — `WeeklyMenuPlanService.getWeek` (`weekly_menu_plan_service.dart:46-67`)
  wraps the fetch in `executeServiceOperation`, which returns null on error; both the inner
  and outer `??` fall through to `WeeklyMenuPlan.empty(...)`, same deterministic id `save`
  upserts by. `GroupWeeklyMenuPlanService.getOrBuildWeek` (`:61-76`) does the identical
  collapse — `getWeek` returns null on error, `getOrBuildWeek` cannot tell that from "no
  plan yet". **Premise holds**, confirmed by direct read, not by trusting the ticket.
* **BUT-1926** — `messaging_service.dart:294-301`'s catch block for
  `getConversationMessages` reads exactly `return messages;` — the raw, unfiltered list —
  discarding both the BUT-544 author filter (`visible`) and the BUT-1909 ballot strip
  computed one line above it. `closePoll`'s block-filter resolution at `:786` uses
  `ServiceLocator.tryGet<BlockedUserFilter>()`, confirmed. **Premise holds.**
* **BUT-1917** — `firestore.rules`'s `poll_votes` `allow create` (`:2148+`) has no clause
  referencing the message author's block list; the only membership check is
  `inPollConversation()`. `firebase_block_repository.dart`'s `getBlockedUserIds()` queries
  `where('blockerId', isEqualTo: uid)` — no compound-key doc a rule could `exists()`-check
  today. **Premise holds**, and the "where does the list live for rules to read it" question
  the ticket names as undecided is real — that is why this batch requires plan mode.
* **BUT-1837** — `feedback_fab.dart:64-92` and the `Stack` mount at
  `butlery_app.dart:769-777` are unchanged since the ticket's 2026-08-13 measurement.
  **Premise holds** (reproduced only on web per the ticket; device verification is the
  ticket's own open item, carried into acceptance as a `run` criterion).
* **BUT-1716** — `grep -c lastActivityBy firebase_shared_shopping_repository.dart` → 0.
  **Premise holds.**
* **BUT-1800** — `grep -n "retention/events\|lapsed_users/events" account-deletion-cascade.ts`
  → no matches. **Premise holds.**
* **BUT-1931** — `golden_helper.dart:107-109` sets `FlutterError.onError = (_) {};`
  immediately before `expectLater`, which is exactly where `matchesGoldenFile`'s own
  comparator error would land. **Premise holds.**
* **BUT-1929** — not independently re-derived beyond the ticket's own measurement (it
  already names its own repro + fix shape); no contradicting code found in
  `ensure-category-chat.ts`.
* **BUT-1913** — test-only; not independently re-derived beyond the ticket's own citation
  of the two test files and the `direct_abc` construction.

### Obsolete — already fixed under a different id

* **BUT-1795** ("Group chats are stored in two different places — leaving a group silently
  does nothing") — **superseded by BUT-1838.** `lib/repositories/interfaces/chat_group_repository.dart`'s
  own doc comment now states the design directly: "Chat groups: read from Firestore,
  written only by Cloud Functions... Every mutating method here is a callable invocation,
  not a Firestore write." `firebase_chat_group_repository.dart` calls
  `createChatGroup`/`addChatGroupMembers`/`removeChatGroupMember` — the exact canonical,
  single-path, server-side shape BUT-1795's acceptance criteria asked for. Resolving
  commits: `faaba5978` ("the app side of chat groups, and the four ways it was broken"),
  `d627daf25`, `c7fc9dd6b`. Closed, not selected.
* **BUT-1796** ("'Lägg till medlemmar' in a group chat has never worked") — **same
  supersession.** `addChatGroupMembers` is a live callable
  (`functions/src/groups/add-chat-group-members.ts`, confirmed on disk) invoked from
  `firebase_chat_group_repository.dart:142`, not the denied client-side rebuild the ticket
  describes. Closed citing the same BUT-1838 commits. Closed, not selected.

### Excluded, not obsolete (no code diff to grade / not autonomously buildable)

* **BUT-1884** — asks only that BUT-1801's ticket body be re-verified and rewritten; no
  production diff to build. Left unselected; a future selection pass can fold the rewrite
  into whichever ticket next touches that code, per its own recommendation.
* **BUT-1885** — Tier D: needs a production-console/Admin-SDK document count Malin (or a
  session with prod access) must run by hand. Not autonomously buildable. Left unselected,
  not scored into `needsApproval` (it is not a product choice, just an ops step already
  labeled `need-malin`).

### Needs approval — a product/policy choice, not a build call

* **BUT-1854** — "The GDPR export contradicts itself about a late joiner's chat history."
  The ticket's own text says it plainly: *"Undecided — it is not covered by any entry in
  accepted-deviations.md, so this is a question for Malin, not a decided call to
  re-litigate."* Two real options are laid out (drop the pre-join `lastMessage`, or keep it
  and record why) with a recommendation (drop it) — exactly the shape of every other
  accepted-deviations entry, all of which are recorded as Malin's explicit call. Not built.

## Batches

### Batch A — social-messaging-polls (area: social)

Both tickets touch `messaging_service.dart`'s poll-close path, so they run as one batch to
keep file sets disjoint across batches (BUT-1928's fix reaches the same file through the
private `_appendWinnerToWeeklyPlanAndShare` / `_appendWinnerToGroupPlan` methods that write
the poll winner into the plan). Split into ≤3-file commits per the repo's batch advisory —
do not land all four files in one commit.

**BUT-1928 — [Tier A, build, plan-mode] A failed plan read silently overwrites the week**
Files: `lib/services/menu/weekly_menu_plan_service.dart`,
`lib/services/menu/group_weekly_menu_plan_service.dart`, `lib/services/messaging_service.dart`
Change: `getWeek` (both personal and group) distinguishes "read failed" from "no plan yet",
and the poll-close winner-append path refuses to save when the read failed instead of
building and upserting an empty plan over the existing one.
Acceptance:
1. (diff) `WeeklyMenuPlanService.getWeek` and `GroupWeeklyMenuPlanService.getWeek` surface a
   read failure distinguishably from "no plan yet" instead of both collapsing to null/empty.
2. (diff) The poll-close winner-append path refuses to save when the read failed, rather
   than building and upserting an empty plan over the existing one.
3. (diff) A test proves a simulated read failure no longer overwrites an existing week's
   plan, for both the personal and the group path; a genuine empty week still builds and
   saves normally.
4. (diff) Negative constraint: the deterministic doc-id scheme and the upsert `set`
   semantics are unchanged — only the failure path changes.

**BUT-1928 residuals — NOT fixed here, file as follow-ups**

1. *Two save-after-read callers still go through `getWeek`.* `readWeek` closed the poll-close
   path only. `weekly_menu_plan_viewmodel.dart` adopts `getWeek`'s result as `_plan` and later
   calls `_service.save(...)` on it, and `onboarding_viewmodel.dart`'s `_seedSampleMenu` guards
   on `plan.isNotEmpty` — which a failed read answers `false` — before seeding and saving. Both
   are the original BUT-1928 harm on the personal week; both need the same `readWeek` treatment
   or an explicit refusal. (`menu_placement_viewmodel.dart` and `slot_picker_dialog.dart` also
   read-then-write and want checking under the same ticket.)
2. *The unavailable-read route never sets `readFailed`.* Both repositories map a week they
   cannot answer for to `null` via `!snapshot.exists` rather than throwing, so an offline /
   never-cached week reports `readFailed: false` with an empty plan and the guard stays silent
   on the most likely real failure. `fetchForWeek` cannot distinguish "no doc" from "no answer"
   today, so no wrapper above it can — the fix belongs at the repository layer. The doc comments
   on both `readWeek`s now state this limit explicitly instead of claiming full coverage.

**BUT-1926 — [Tier A, build, plan-mode] Two fail-open holes in the poll/blocklist path**
Files: `lib/services/messaging_service.dart`,
`lib/widgets/messaging/builders/message_content_builder.dart`
Change: the widened catch in `getConversationMessages` stops discarding author-block
filtering when the newer ballot-strip throws; `closePoll`'s block-filter resolution stops
depending on `tryGet` succeeding to register; the duplicate refusal log and the hardcoded
Swedish fallback string are fixed alongside.
Acceptance:
1. (diff) `getConversationMessages`'s catch returns the author-filtered list (or narrows the
   `try` to the block-fetch alone) — never the raw unfiltered `messages` — when
   `_withoutBlockedBallots` throws.
2. (diff) `closePoll` resolves `BlockedUserFilter` with `get<T>()` (or refuses explicitly on
   null) instead of `tryGet`, so a poll can never close on an unfiltered tally purely
   because of DI registration.
3. (diff) A refused close is logged once, not twice, for the same `PollCloseRefusedException`.
4. (diff) `message_content_builder.dart`'s no-poll-data fallback uses
   `context.l10n.messagingPoll` instead of the hardcoded Swedish string.
5. (diff) Negative constraint: the ticket's "Test gaps" and "harm narrative still present
   tense" sections are NOT addressed here — file a follow-up ticket for them instead of
   expanding scope.

### Batch B — backend-security-rules (area: backend)

**BUT-1917 — [Tier C, build, plan-mode, full-panel] Blocking is not enforced by the rules**
Files: `firestore.rules`, `lib/repositories/firebase/firebase_block_repository.dart` (or
wherever the block list gains a rules-readable shape), a `poll_votes` rules test file.
Change: `poll_votes` `allow create` denies a write from someone the poll message's author
has blocked, closing the store-policy gap ("blocked" must mean "cannot interact", not
"invisible to you") that BUT-1909's client-side filtering left open.
Router returned **full-panel** (Security Architect, Trust & Safety, Privacy/DPO, Legal,
Software Architect, PM, DBA, Perf Engineer, FinOps, Support) — panel policy is `park`, so
this still builds; it parks In Review rather than closing automatically, on top of the
mandatory `firebase-backend-security` + `firestore-rules-tester` commit gates.
Acceptance:
1. (diff) `poll_votes`'s `allow create` denies a voter uid that appears in the poll
   message's author's block list.
2. (diff) A rules test proves a blocked person's vote is denied and an unblocked person's
   is allowed, on the real rule (not a hand-rolled predicate).
3. (diff) Negative constraint: does not touch BUT-1832's votability decision or BUT-1838's
   `memberSince` cutoff — both stay exactly as `accepted-deviations.md` records them.
4. (diff) The chosen shape for "where the block list lives so rules can read it" is stated
   in the commit body with its read-cost implication (CLAUDE.md cost principles) — not
   silently decided.

### Batch C — settings-accessibility (area: settings)

**BUT-1837 — [Tier A, build, plan-mode] Feedback-FAB semantics node covers the whole screen**
Files: `lib/widgets/common/feedback_fab.dart`, `lib/app/butlery_app.dart`, a new widget test.
Change: the Semantics node wrapping `FeedbackFAB` stops adopting the entire screen's
subtree and stops intercepting taps aimed at other controls.
Acceptance:
1. (diff) A widget test asserts the `FeedbackFAB`'s `SemanticsNode.rect` matches the
   button's own size, not the viewport's.
2. (diff) A widget test asserts a tap in the middle of another control (e.g. a form field)
   does not open the feedback dialog.
3. (run) Reproduced fixed on a real device with TalkBack/VoiceOver on — the ticket's own
   "NOT verified on mobile" gap; this is a run criterion, not gradeable from the diff alone.
4. (diff) Negative constraint: `FeedbackFAB`'s visual size and position are unchanged —
   only its semantics boundary is fixed.

### Batch D — account-gdpr-backend (area: account)

Both tickets are Article 17 cascade-completeness fixes and both plausibly touch
`account-deletion-cascade.ts`, so they run as one batch to keep files disjoint.

**BUT-1800 — [Tier A, build, plan-mode, full-panel] Account deletion misses two analytics
collections**
Files: `functions/src/account/account-deletion-cascade.ts`,
`functions/src/account/request-account-deletion.ts`,
`functions/src/__tests__/account-deletion-cascade.test.ts`
Change: add a deleter each for `analytics/retention/events` and
`analytics/lapsed_users/events`, registered in the orchestrator's tier list (an
unregistered deleter deletes nothing — the exact BUT-1789 trap).
Acceptance:
1. (diff) Both collections' rows for the deleted user are erased by a cascade run (test).
2. (diff) Another user's same-day rows, and any anonymous/aggregate row, survive (test).
3. (diff) Both new deleters are registered in `request-account-deletion.ts`'s tier list.

**BUT-1716 — [Tier B, build, plan-mode, full-panel] Second shared-shopping repo stamps no
attribution at all**
Files: `lib/repositories/firebase/firebase_shared_shopping_repository.dart`,
`functions/src/account/account-deletion-cascade.ts` (verify/extend the subcollection scrub),
tests.
Change: determine whether the subcollection shared-shopping write path
(`firebase_shared_shopping_repository.dart`) is still reachable; if so, stamp
`lastActivityBy*` attribution there (matching BUT-1697's array-path fix); if not, delete it.
Either way, prove the deletion cascade scrubs subcollection-shaped attribution fields.
Acceptance:
1. (diff) A written, code-cited answer on reachability (the call chain traced in the
   commit body), matching what BUT-1716 asks for.
2. (diff) If reachable: attribution is stamped there with a test. If not reachable: the
   path is deleted, not left as inert-looking code.
3. (diff) A test proves the cascade scrubs subcollection-shaped `purchasedByUserId`/
   `addedByUserId`, or proves no such documents can exist.

Router for this batch returned **full-panel** on both files (Security Architect,
Privacy/DPO, Trust & Safety, DBA, Legal, PM, Software Architect, Perf, FinOps, Vendor) —
same `park` handling as Batch B: builds, parks In Review, specialist gates still mandatory.

### Batch E — test-infra-goldens (area: backend/tooling)

**BUT-1931 — [Tier A, build, plan-mode] Golden tests cannot fail — the comparator's own
error is swallowed**
Files: `test/widget/golden/golden_helper.dart`, any golden PNG that genuinely diverges once
re-run, `test/widget/golden/failures/` (cleared).
Change: `butleryGolden` stops silencing `matchesGoldenFile`'s own comparator error along
with the asset-load errors it was meant to suppress.
Acceptance:
1. (diff) `FlutterError.onError` is restored before `expectLater`/`matchesGoldenFile` runs,
   or the silencing is scoped to the `pump` call only — not left swallowing the
   comparator's own error.
2. (run) Every golden going through `butleryGolden` was re-run under the fixed helper; any
   that genuinely diverged got a human-reviewed update, not a mechanical overwrite. Not
   provable from the diff alone — the ticket itself calls for "a human eye on the diff".
3. (diff) A test (or a documented manual step run and pasted into the PR body) proves the
   gate can now go red: mutate one golden pixel and watch the suite fail.
4. (diff) `test/widget/golden/failures/` is cleared in this commit.

### Batch F — social-groups-functions (area: social)

**BUT-1929 — [Tier B, build] A deleted group conversation wedges every future poll**
Files: `functions/src/groups/ensure-category-chat.ts`,
`lib/core/errors/chat_group_error_mapper.dart`,
`functions/src/__tests__/ensure-category-chat.test.ts`
Change: `ensureCategoryChat`'s conversation-existence check currently sits inside the
transaction, but the steady-state early return skips the transaction entirely — so a
category whose backing conversation was deleted (rules allow it; BUT-1838's accepted
deviation records the deletion module's refusal as UX, not a control) hands back a dead
conversation id forever. Preferred fix per the ticket: let the create branch self-heal by
re-stamping the pointer when the conversation is missing, rather than adding a `get()` to
the steady-state's common path. If a hoisted existence check is chosen instead, it must
throw with a `details['reason']` the error mapper recognizes — otherwise a silent wedge
becomes an equally silent `genericFallback`, which is the exact regression the ticket's
2026-08-23 addendum found.
Acceptance:
1. (diff) A poll posted into a category whose chat conversation was deleted no longer
   receives the dead conversation id — proven by a test that creates the chat, deletes the
   conversation, then polls again with an unchanged roster.
2. (diff) Whichever fix shape is chosen, the user-visible failure text (if any is still
   reachable) is Swedish and names what happened — never `genericFallback` — proven by a
   widget/unit test on `ChatGroupErrorMapper`.
3. (diff) Negative constraint: the existing drifted-roster deleted-conversation test case is
   unchanged and still passes — this is an additive case, not a rewrite of the guard.

### Batch G — test-hygiene-log-sanitizer (area: backend, test-only)

**BUT-1913 — [Tier A, build] Two BUT-1872 tests hang on an id shape nothing creates**
Files: `test/unit/repositories/firebase/modules/conversation_mutation_module_test.dart`,
`test/unit/repositories/firebase/modules/message_mutation_module_test.dart`
Change: both masking tests assert against the exception's raw FIELD
(`ResourceNotFoundException.resourceId` / `PermissionDeniedException.userId`) instead of a
single-segment `direct_abc` id form that only the test constructs and that a future
harmonization of `maskConversationId`'s pattern would silently stop distinguishing.
Acceptance:
1. (diff) Both tests assert against the exception's raw field, using a real two-segment id
   (the shape the app actually produces), not the `direct_abc` construction.
2. (diff) Both files are fixed in the same commit, not just one.
3. (diff) Negative constraint: no change to `log_sanitizer.dart` or to any exception class's
   masking behavior — this is a test-shape fix only.

## Needs approval (not built — Malin's call)

* **BUT-1854** — GDPR export: drop a late joiner's pre-join `lastMessage`, or keep it and
  record why. See the "Needs approval" note above for the full reasoning; recommendation is
  to drop it (option A), matching every neighbouring accepted-deviations entry on this
  export section.

## Obsolete (closed this pass, citing the resolving commit)

* **BUT-1795** — superseded by BUT-1838 (`faaba5978`, `d627daf25`, `c7fc9dd6b`).
* **BUT-1796** — superseded by BUT-1838 (same commits) — `addChatGroupMembers` callable is
  live and is what the client now calls.

## Needs you (Tier D)

* **BUT-1885** — needs a production-console/Admin-SDK document count of the top-level
  `recipes` collection. Not selected this pass (already `need-malin`-labeled; excluded from
  scoring, not carried as a build candidate).

## Excluded from consideration entirely

`onboarding-reserved`-labeled tickets (BUT-677, BUT-722) — never scored, never selected,
per the standing rule.

## Deviation log

(empty at Selection — filled in by Implementation as batches run)

---

# ARCHIVED — previous sprint plan (2026-08-22)

# PLAN 2026-08-22 — sprint (--pick malin): six tickets Malin chose in session

Selected interactively 2026-08-22 via `/delivery:sprint-execute --pick malin`. Malin picked
all four offered clusters, which resolve to six tickets. Every premise below was checked
against CURRENT `main` (working tree at 52a6f8e9e), not against the ticket text.

Router (`python tools/stakeholder_router.py --json`) returned tier **single** for all five
path-groups — no `full-panel`, so nothing is pulled from the sprint on the dispatch gate.
Panel policy is `park`: a contested outcome goes to In Review rather than auto-closing.

## Selection record

| Ticket | Disposition | Tier | Router | Owning role(s) |
| --- | --- | --- | --- | --- |
| BUT-1908 poll shows "0 röster", closes on real votes | build | C (repo + service + VM + widget) | single | Trust & Safety |
| BUT-1909 blocking does not reach poll votes | build | C (same module, security) | single | Trust & Safety |
| BUT-1915 raw uid into Crashlytics via MenuOperationError | build | A | single | Localization / i18n |
| BUT-1910 rating field drops the comma | build | A | single | Localization / i18n |
| BUT-1906 diet badges missing in grid view | build-review | B (UI-visual) | single | Creative Director / Brand Lead |
| BUT-1894 real-time-guard costs 859 s per commit | build | A | single | Software Architect |

BUT-1894 carries a **recorded decision** (Linear comment, 2026-08-18): the earlier rewrite
was torn down because it failed OPEN on two cases. Those two cases are copied into its
acceptance criteria below and are binding.

### Step-0 premise check (grep of main, not of `git log`)

* BUT-1908 — `maxHydratedPolls = 20` at `message_query_module.dart:23`, `_pollIds` still
  `.take()`s, `poll_message_widget.dart:98-100` still gates only on
  `poll.isActive && poll.creatorId == currentUserId`. **Premise holds.**
* BUT-1909 — `_tally()` at `:194` reads every `poll_votes` row with no block filter;
  `BlockedUserFilter` is applied only in `messaging_service.dart:254 _filterBlocked`, on
  `m.senderId`. **Premise holds.**
* BUT-1915 — `menu_participants.dart:112` still throws
  `MenuOperationError(message: l.validationUserNotParticipant(userId))` with the raw uid.
  **Premise holds.**
* BUT-1910 — `skriv_sjalv_recept_view.dart:677` still calls `double.tryParse(value)`;
  `lib/core/utils/swedish_decimal_input.dart` exists. **Premise holds.**
* BUT-1906 — `lib/widgets/recipe/recipe_card.dart` still carries the "deliberately NOT
  here" note in the grid layout. **Premise holds.**
* BUT-1894 — `scripts/check_test_real_time.sh` unchanged since 2026-06-22. **Premise holds.**

## Risky-ticket plan expansion (Phase 1.5 fired for 1908, 1909, 1915, 1894)

### BUT-1908 + BUT-1909 — one implementation, two tickets

They touch the same tally and must agree on one answer, so they ship together.

**Blast radius:** `lib/repositories/firebase/modules/message_query_module.dart`,
`lib/services/messaging_service.dart`, `lib/viewmodels/chat_viewmodel.dart`,
`lib/widgets/messaging/poll_message_widget.dart`,
`lib/widgets/messaging/builders/message_content_builder.dart`, the two ARB files,
plus tests.

**Design — hydration state (1908).** The client cannot today tell "zero votes" from "the
votes were never read". Both are `voterIds == []`. A boolean is not enough: past-the-cap is
a client choice a re-read repairs, a failed read may be permanent, and the two need
different Swedish text. So hydration writes a marker into the IN-MEMORY metadata only:

    metadata['pollVoteHydration'] = 'ok' | 'capped' | 'failed'

Safe to add because nothing round-trips a hydrated `Message` back to Firestore: the repo's
`closePoll` (`message_mutation_module.dart:475-497`) re-reads the raw document and writes
`isClosed` alone, and no other writer sends a hydrated metadata map. Verified by grep of
every `'metadata':` write under `lib/repositories/`.

**Design — blocked voters (1909).** Filtering belongs in the SERVICE, not the repository:
blocking is viewer-scoped, `MessagingService` already owns `BlockedUserFilter`, and the
repository has no business knowing who the viewer blocked. One helper strips blocked uids
from every option's `voterIds`, and it runs on BOTH surfaces so the number on screen and
the winner can never disagree:

1. `_filterBlocked` (covers the live stream at `:222` and the page at `:239`), and
2. `closePoll`, which reads through `_messagingRepository.getMessage` directly and would
   otherwise bypass the filter entirely.

**Design — the close path (1908 items 3-5).** `closePoll` refuses when the tally was not
read: no plan write, no `isClosed` flip, throw a typed failure. `ChatViewModel.closePoll`
returns a result instead of swallowing, and the chat view shows the Swedish reason. The cap
logs when it excludes a poll.

**Rollback shape:** every change is additive and in-memory; reverting the commit restores
the previous behaviour with no data migration, because nothing new is persisted.

**Acceptance criteria**

BUT-1908
1. `diff` — Hydration records three distinguishable states, and a poll excluded by the cap
   or failed on read is NOT reported as `ok`. Pinned by a test per state.
2. `diff` — `PollMessageWidget` does not draw an ENABLED close button on a poll whose votes
   were not read, and shows Swedish text saying so instead of a bare "0 röster". Two tests:
   capped and failed.
3. `diff` — `MessagingService.closePoll` throws rather than flipping `isClosed` or writing a
   plan when the poll it read was not hydrated. Test asserts BOTH omissions, not just one.
4. `diff` — `ChatViewModel.closePoll` no longer swallows: it surfaces the failure to the
   caller. Test asserts the failure reaches the viewmodel's consumer.
5. `diff` — The cap logs the ids it excluded. **Negative constraint:** the log must not
   print a raw conversation id or uid.

BUT-1909
1. `diff` — A blocked voter is excluded from the tally on the DISPLAY path and on the CLOSE
   path, proven by one test each.
2. `diff` — Displayed count and resolved winner are computed from the SAME filtered tally.
   A test with a blocked majority asserts the number on screen and the winner agree.
3. `diff` — Fail-open is preserved: a block-list lookup error serves the unfiltered tally
   rather than blanking the poll, matching `_filterBlocked`'s existing contract.
4. `diff` — **Negative constraint:** the repository module gains no knowledge of blocking.
   `message_query_module.dart` must not import or reference `BlockedUserFilter`.

### BUT-1915 — raw uid into a crash report

**Blast radius:** `lib/services/realtime/modules/menu_participants.dart`, the two ARB files
(if the placeholder is dropped), plus a test.

Scope is the FIRST item of the ticket only — mask at the throw, as the neighbouring
`AppLogger.info` line already does. The ticket's item 2 (should `MenuOperationError`,
`RepositoryException` and `StorageUploadException` mask in their own `toString()`) is a
design decision that belongs with BUT-1907's architecture-test arm; it gets a follow-up, not
a guess inside this sprint.

**Acceptance criteria**
1. `diff` — The uid in `validationUserNotParticipant` is masked at the throw site, using the
   same masking the neighbouring log line uses.
2. `diff` — A test proves `MenuOperationError.toString()` on that path contains no raw uid.
3. `diff` — **Negative constraint:** no change to `permission_exceptions.dart` and no new
   masking added to `MenuOperationError.toString()` itself — that is BUT-1907's call, and
   deciding it here would pre-empt the architecture test that is meant to find the rest.

## Stakeholder critiques folded in (Phase 1.4, tier `single`)

Each is ONE blind critique from the owning role, run before any code was written. Every
MUST-HAVE below is now a binding acceptance criterion.

### Creative Director / Brand Lead — BUT-1906

* **Badge-weight mismatch, not in the original plan.** The grid's allergen row draws
  ICON-ONLY compact chips (`recipe_card.dart:372-376`, `showLabel: false`), while the
  dietary row is called elsewhere with `showLabel: true` (`recipe_card.dart:258-262`),
  i.e. full Swedish words. Stacking narrow icon chips over wide text chips on a ~160-180dp
  tile is two densities on one card. Either the grid's dietary row also goes icon-only, or
  the two-labelled-badge case is explicitly tested and accepted. Not decided implicitly by
  `CompactDietaryRow`'s default.
* Fixtures must include the TWO-badge worst case (`maxBadges: 2`), not one diet tag — that
  is the case that wraps at 1.75-2x and eats BUT-1895's remaining margin.
* Row order stays allergen (hazard) above dietary (preference), matching the detailed
  layout at `recipe_card.dart:237-263`.
* Badges are not shrunk to fit. Reaffirmed: a shrunk badge is worse for a colour-blind user
  who relies on its shape than a slightly taller card.
* `_buildCompactLayout` staying badge-free is accepted for this ticket, and is noted as a
  standing third-spelling drift risk rather than a fix owed here.

### Localization / i18n — BUT-1910 and BUT-1915

* **BUT-1910: the rating validator is not in conflict.** `FormValidators.rating()`
  (`form_validators.dart:160-166`) delegates to `numberRange(min: 0, max: 5)`, which does
  its OWN comma-aware parse at `:116`. So `"4,5"` passes the validator today while
  `setRating` gets `null` from `double.tryParse` — the validator owns range, the parser
  only has to read the value. No bounds work is owed to `parseSwedishDecimal`.
* **BUT-1910: the pantry display round trip is safe, verified.** `formattedQuantity`
  (`pantry_item.dart:154-156`) is read back into an editable field at exactly one site,
  `add_pantry_item_sheet.dart:99`, and `_submit()` at `:176-178` already comma-normalises.
  A comma round-trips.
* **BUT-1910: the selection sentence must be falsifiable, and the load-bearing fact is
  DEFAULT-vs-NULL.** `parseSwedishNumber`'s silent `1.0` fallback would corrupt a rating
  field invisibly. The sentence says: `parseSwedishDecimal`/`formatSwedishDecimal` for any
  hand-typed, round-tripped field, because they return `null` and let the caller decide;
  `TextFormatting.parseSwedishNumber`/`formatFractional` for non-interactive recipe-text
  parsing, where the `1.0` fallback is an accepted default rather than a form value;
  `formatRatingComma` for the rating pills, which need a fixed decimal place. It is a
  ROUTING rule and must not carry a COUNT of the formatters — the first draft said "a third
  formatter and a second parser", "truncates", and "pooled-rating display only", and the
  code-reviewer gate measured all three false.
* **BUT-1915: the Swedish sentence question is moot — the string never reaches a user.**
  `RealtimeMenuViewModel._onServiceStateChanged` (`:361-364`) runs the error through
  `sanitizeErrorForUser`, which returns a generic localized message. The interpolated uid's
  only destinations are `AppLogger.error` and `MenuOperationError.toString()`. So the ARB
  placeholder STAYS and no ARB edit is needed; this is a log/crash-report fix only.
* **BUT-1915 MUST-HAVE: the twin class is outside the plan's stated blast radius.**
  `lib/services/realtime/modules/recipe_participants.dart:92-96` and `:121-125` throw
  `RecipeOperationError(message: l.validationUserNotParticipant(userId), ...)` — identical
  unmasked-uid shape, same family. Both throw sites join the diff with their own test.
  This is the repo's standing "a boundary bug has a TWIN CLASS" rule, met head-on.

### Software Architect — BUT-1894

* **Root cause MEASURED, and it is not the grep.** The two `grep -rEn` calls
  (`check_test_real_time.sh:89`) finish in ~0.4 s total. `DateTime.now()` alone matches
  **1,066 lines** under `test/unit`, and every matched line spawns `is_suppressed` (an `awk`,
  `:60-63`) plus, in baseline mode, `is_baselined` (`echo|sed|sed` + `grep -qxF`, `:49-55`)
  — about **four processes per match, ~4,300 in total**. On Windows/Git-Bash process
  creation is the expensive primitive, and 4,300 spawns lands in the measured 646-859 s
  band. **Binding: the rewrite must remove per-match subprocess spawns** (one `awk`/`perl`
  pass per file, reading suppression and baseline once), not "optimise the grep".
* **Shape verdict: the check stays pre-commit; the full-tree scan is what is wrong.**
  `lefthook.yml:93-95` already glob-gates on `*_test.dart`, then greps all of `test/`
  anyway. Every other gate in that file takes `{staged_files}`. Moving it to CI would only
  delay the same design flaw. Scope it to the staged files.
* **Fixture layout is binding**, at `scripts/__tests__/check_test_real_time/fixtures/`:
  (a) a real BINARY `*_test.dart` blob → exit 1; (b) a baselined file holding only comments
  and blank lines → exit 0, not a `set -e` death; (c) a suppressed violation → exit 0;
  (d) an un-baselined `DateTime.now()` → exit 1; (e) a long `Future.delayed` inside each
  `DELAYED_SCOPE` dir → exit 1 regardless of baseline. Driven by
  `scripts/__tests__/check_test_real_time_test.sh`, which runs the REAL script and asserts
  exit codes. Confirmed by the reviewer: no fixture test for this script exists anywhere in
  the repo today, which is how the fail-open rewrite got as far as it did.
* **Strike the false comment at `lefthook.yml:87`**, do not soften it. "Usually fast" is the
  same false claim restated. It carries the measured number and a date.

### Trust & Safety / Content Moderation — BUT-1908 + BUT-1909

Verdict: the service-not-repository layering is right and the negative constraint stands.
Two binding changes, because as first written the design shipped a DISPLAY fix labelled as
a blocking fix, and its fail-open clause let a blocked person decide a household artifact.

* **MUST-HAVE — fail-open is SPLIT BY SURFACE. This REPLACES BUT-1909's acceptance
  criterion 3 as originally written.** Fail-open is correct on DISPLAY. On the CLOSE path it
  means: the block-list fetch fails, `BlockedUserFilter._cached` stays `{}`
  (`blocked_user_filter.dart:52-55`), the blocked ballot resolves the winner at
  `messaging_service.dart:689`, and it lands in a plan other members see. So when the block
  list is UNKNOWN — `ServiceLocator.tryGet` returned null, or the fetch threw — `closePoll`
  REFUSES: no plan write, no `isClosed` flip, and the retry reason is surfaced. One test
  asserts both omissions.
* **MUST-HAVE — no disclosure of the filtering in group-visible output.** The winner write
  stays recipe-id-only (it is today, `:853-893`). Nothing in the plan entry, the share
  message or any log may say the tally was filtered or by how much — publishing that leaks
  who the creator has blocked. This is a negative constraint beside BUT-1908's criterion 5.
* **MUST-HAVE — say plainly, in the ticket, that this is NOT block enforcement.**
  `firestore.rules` still lets a blocked user write `poll_votes` on my message, every OTHER
  member's screen still counts them, and `getBlockedUserIds`
  (`firebase_block_repository.dart:112-127`) is one-directional, so someone who blocked ME
  is unfiltered in my own poll. Store policy (Apple 1.2, Play UGC) reads "block" as CANNOT
  INTERACT. A follow-up ticket for rules-level enforcement on `poll_votes` create is owed.
  BUT-1832's accepted deviation covers the VOTABILITY of share cards, not this.
* Creator's-list-decides is endorsed: the closer is the actor, and the alternative
  reproduces the exact BUT-1908 harm of screen and write disagreeing. The residual — other
  members cannot reproduce the margin — is smaller than the harm avoided.
* On the three states: as a SAFETY control they are ceremony, because `capped` and `failed`
  must disable close identically. So the close gate tests `ok` / not-`ok`, and the third
  value survives to drive the Swedish text and the log, not the gate.
* Noted, not owed here: `closePoll` re-reads at `:670` rather than acting on the displayed
  tally, so a vote landing between render and tap still writes a winner the creator never
  saw; and `searchMessages` (`:495-511`) applies no block filter at all. Both get follow-ups.

## Non-risky tickets

### BUT-1910 — rating field drops the comma

1. `diff` — `skriv_sjalv_recept_view.dart` parses the rating through `parseSwedishDecimal`;
   typing `8,5` sets the rating to 8.5. Test pins it.
2. `diff` — `add_pantry_item_sheet.dart` uses the same helper, so `,5` and `1,5,5` behave as
   they do on the shopping surface. Test pins both.
3. `diff` — `pantry_item.dart:154` displays the quantity with a comma, so a shopping item and
   a pantry item no longer spell the same number two ways.
4. `diff` — `swedish_decimal_input.dart` states in one sentence which of the three formatters
   applies when and why they are not merged.

### BUT-1906 — diet badges in the grid card (Tier B, parks In Review)

1. `diff` — The dietary row renders in `_buildGridLayout`, after the allergen row.
2. `diff` — `recipe_card_grid_badges_test.dart` fixtures carry diet tags and the overflow
   cases pass up to 2x text scale.
3. `diff` — If it does not fit, `_gridAspectRatio` in `mina_recept_view.dart` is raised and
   the new number is pinned by a test. **Negative constraint:** the badges are not shrunk.
4. `diff` — The "deliberately NOT here — see BUT-1906" comment is removed, not reworded.

## Needs you (Tier D)

None in this batch. BUT-1894's timing measurement is a `run` criterion, not Tier D.

## Deviation log

- [discovery] BUT-1910: the ticket's own worked example is wrong twice. "8,5" is outside the
  field's 0-5 range, and the claim that ",5 fell back to 1.0" is REFUTED — measured with
  `dart run`, the old path read ",5" and "0,5" as 0.5 perfectly well. The real defects were
  "1,5,5" being typeable (parse null, fallback 1.0), the period on the pantry display, and
  the rating field dropping any comma. Two of the three new pantry cases are therefore
  CONTROLS, and their comments now say so.
- [deviation] BUT-1910: `edit_recipe_view.dart` joined the diff. It carried the IDENTICAL
  rating field and it is the screen the app opens for an EXISTING recipe, from every list
  and detail surface — `SkrivSjalvReceptView` is reached only when writing, importing or
  forking. The fix as planned was on the wrong screen for most users. Raised as BLOCKING by
  `integration-reviewer`; this is the repo's standing twin-class rule, met head-on.
- [discovery] BUT-1910: my own comment shipped SIX false claims across three rounds — "a
  third comma formatter", "a second parser", "truncates to two decimals", "pooled-rating
  display only", "Only the 1,5,5 case discriminates", "the other two are controls". Each was
  measured false by a gate. One repair silently did not land at all: a multi-edit script
  asserted on a later anchor and aborted before its single write, discarding the earlier
  edits — the repo's own lesson, hit live. Every strike is now grep-verified.
- [discovery] BUT-1909: the display-path test passed while measuring nothing. The fixture
  used this suite's `FakeMessage`, which has no `copyWith`, so the strip threw and
  `_filterBlocked`'s fail-open catch swallowed it and served the page unfiltered — i.e. the
  test measured the CATCH and would have gone green asserting the opposite. Fixed by using a
  real `Message`. The same suite also skips production `ServiceLocator` init, so
  `tryGet<BlockedUserFilter>` returned null until the group initialised its own container.

- [needs-human] BUT-1906 NOT SHIPPED — the ticket's REMEDY is refuted, its problem is not.
  Building it and measuring gave three results, in this order:
  (1) Adding the dietary row to `_buildGridLayout` overflows the tile at EVERY 360dp text
      scale, which was clean to 2x before. The two-badge worst case the Creative Director
      asked for is what exposed it; the one-badge fixture the suite already had did not.
  (2) The ticket's prescribed fix — raise `_gridAspectRatio` — changes NOTHING. Measured at
      0.75 / 0.70 / 0.66 / 0.62: five 360dp failures at every value. That matches what
      `recipe_card_grid_badges_test.dart` already records, that closing the residual needs an
      absolute `mainAxisExtent` rather than a ratio, which is BUT-1911.
  (3) The Creative Director's alternative — icon-only badges for spatial parity with the
      allergen row — is not available. `DietaryStatusBadge` picks its icon from the STATUS,
      not the diet, so vegansk and vegetarisk both render the same green `Icons.eco_outlined`.
      Icon-only would put two identical leaves on the card, which is information loss, not a
      compact treatment.
  Reverted to keep main clean; a 23px silent clip is worse than the missing badge. BUT-1906
  is BLOCKED ON BUT-1911 and parks In Review for Malin.

- [discovery] BUT-1894: the recorded decision and the Software Architect critique disagreed
  on ONE fixture. Malin's comment says a comment-only baseline must still make the guard
  exit non-zero; the critique's fixture (b) asked for exit 0. Resolved by splitting it,
  because the two were describing different inputs: a comment-only baseline is now an EMPTY
  allow-list, so a violation beside it still exits 1 (her case, pinned), while a clean tree
  beside it exits 0 (the old script died there under `set -e` and failed commits that had
  done nothing wrong). Both directions have a fixture. Nothing was made more permissive.
- [discovery] BUT-1894: the root cause was NOT what the ticket guessed. The ticket said the
  script "does a full-tree search" and proposed scoping it. Scoping was right but is worth
  ~0.1 s; the 859 s was ~4,300 subprocess spawns, four per matched line. Both were done.
- [deviation] BUT-1915: the code-reviewer and testing-specialist gates INDEPENDENTLY found a
  second leak in the same two files — `validationUserAlreadyParticipant` carried a raw
  DISPLAY NAME to the same Crashlytics sink. Both recommended a follow-up ticket. Fixed in
  this commit instead: same defect class, same files, same sink, one token each, and this
  repo's standing rule is that a twin class ships in the same commit. Shipping a PII fix
  while leaving a known cleartext PII leak in the same method was the worse option.
- [deviation] BUT-1915: `lib/core/utils/logger.dart` joined the diff. It carried a doc
  comment citing this exact defect as its live "measured example", which the fix falsifies.
  Struck rather than reworded, per code-style. Raised as BLOCKING by `integration-reviewer`.
- [discovery] BUT-1910: the ticket's worked example "8,5" is out of range. The field is
  labelled "Betyg (0-5)" and `FormValidators.rating()` bounds it to 0-5, so 8,5 fails
  whichever separator is typed. The defect is the separator, not the magnitude, so the tests
  use 4,5. The ticket text is not wrong about the bug, only about its example.
- [discovery] BUT-1910: the pantry sheet's unreadable-field fallback now differs by mode —
  1.0 on add, the item's existing quantity on edit. That is what `parseSwedishDecimal`'s own
  doc comment specifies and what the shopping dialogs already do; the sheet had a single
  `?? 1.0` for both, so an unreadable edit silently reset the amount to 1.


---

# ARCHIVED — previous sprint plan (2026-08-20)

# PLAN 2026-08-20 — sprint (--pick malin): four tickets Malin chose in session

Selected interactively 2026-08-20 via `/delivery:sprint-execute --pick malin`. Malin picked
all four offered candidates. Every premise below was checked against CURRENT `main`, not
against the ticket text.

The router (`python tools/stakeholder_router.py --json`) returned tier **single** for all
four, so each gets ONE blind critique from its owning role before implementation. Panel
policy is `park`, so a contested outcome goes to In Review rather than auto-closing.

## Selection record

| Ticket | Disposition | Tier | Router | Owning role |
| --- | --- | --- | --- | --- |
| BUT-1891 decimal quantity | build | A | single | Product Designer / UX |
| BUT-1895 grid allergen badges | build-review | B (UI-visual) | single | Creative Director / Brand Lead |
| BUT-1897 PII via exception object | build | C (security, multi-file) | single | Trust & Safety |
| BUT-1883 poll cap / closePoll | build | A | single | Trust & Safety |

Closed during selection: **BUT-1887** — Malin recorded the close decision in a comment on
2026-08-19; the ticket had simply never been transitioned out of Backlog.

Not selected, and why: the `need-malin` lane (BUT-1878, 1885, 1880, 1904, 1731, 1838, 1848)
is Phase 3.6 decision-queue material, not build material.

---

## BUT-1891 — you cannot type a decimal in a shopping quantity  [Tier A]

**Premise: HOLDS.** `lib/widgets/styled/styled_input.dart:297-301` still applies
`FilteringTextInputFormatter.digitsOnly` whenever `keyboardType == TextInputType.number` and
no explicit `inputFormatters` is passed. Both quantity fields in `shopping_item_dialogs.dart`
(`:199`, `:333`) hit that default.

**Blast radius — CORRECTED after review, and the first version was wrong.** The plan listed
eight call sites as reaching `StyledInput`'s digits-only default. Measured properly, only
ONE production file does: `skriv_sjalv_recept_view.dart:584,598` (portions and time). The
others — `edit_recipe_view`, `heirloom_section`, `mfa_settings_view`,
`assisted_import_dialog`, `rule_condition_card` — set `TextInputType.number` on a bare
`TextField`/`TextFormField` and never touch `StyledInput`, so that default protects nothing
in them. `StyledInput.number` has no production caller at all.

The two shopping quantity fields are the third and fourth, and they are the bug.

Callers already on `numberWithOptions(decimal: true)` do NOT satisfy the
`== TextInputType.number` equality, so they get `null` formatters today and no option below
touches them.

**Chosen shape — do NOT change the shared default.** Add a decimal-permitting formatter and
pass it explicitly from the two shopping quantity fields. Changing `StyledInput`'s default
would admit a decimal point into servings, minutes and an MFA code.

**Acceptance criteria**
1. (diff) Typing `1,5` into a shopping-item quantity field leaves `1,5` in the field and
   `1.5` reaches the save call.
2. (diff) A test proves an integer-only field still refuses both a comma and a period.
3. (diff) `replaceAll(',', '.')` in the dialogs is reachable — proven by the AC1 test — or
   deleted. It is not left as dead code that looks like handling.
4. (diff) NEGATIVE CONSTRAINT: `StyledInput`'s default formatter branch is byte-identical
   to main.

---

## BUT-1895 — the allergen marks are missing in grid view  [Tier B — parks In Review]

**Premise: HOLDS.** `recipe_card.dart` draws the allergen row, the dietary row and the
unassessed indicator ONLY inside `_buildDetailedLayout` (`:237-260`). `_buildGridLayout`
(`:323-346`) and `_buildCompactLayout` (`:288-321`) draw none of them.
`MinaReceptRecipeCard` (`recipe_card_widget.dart:47-57`) selects `ContentCardStyle.grid`
whenever `viewModel.isGridView`, and it passes the preferences correctly — so the data
arrives and the layout drops it.

**The product decision inside this ticket** (its item 1): nothing in the code says whether
grid-without-badges was a design call or an oversight. Best guess to build: allergen
information is safety-visible and must not depend on which view toggle happens to be saved,
so the grid gets the allergen row. This is exactly the case where the outcome is Malin's to
sign off → In Review, never auto-Done.

**Scope**
- Item 1: allergen badges in `_buildGridLayout`. The COMPACT layout stays out of scope this
  run (a 60px row is a separate design call) — stated in the close-out, not left silent.
- Item 2: first tests for `MinaReceptRecipeCard` — pin `showOnCards == false` ⇒ no badges and
  `showOnCards == true` ⇒ badges. It lives under `lib/views/`, so the tests belong to
  `e2e-test-specialist` and `test/views/`; the ticket records that this drifted past the
  wrong agent twice already.
- Item 3: a distinguishing test that `TagResultDisplay._getAllergensToShow` drops UNKNOWN.
- Item 5: correct the over-promising `reason` string in `compact_tag_rows_test.dart`.
- Item 4 (the producer-less `coveragePercent` arm on `AllergenStatusBadge`): comment it as
  producer-less rather than deleting it. Deleting is its own call and the widget test still
  guards the widget.
- Point 8 from the ticket's comment thread (the `recipeAllergensUnassessedA11y` screen-reader
  label) is included: it is the only user-visible surface of the BUT-1780 change with no
  coverage at all.

**Acceptance criteria**
1. (diff) A widget test renders `RecipeCard` in grid style with a tracked allergen and finds
   the badge; the same assertion in detailed style still passes.
2. (diff) A test file for `MinaReceptRecipeCard` exists and reddens if `showOnCards` stops
   gating `userAllergenPrefs`.
3. (diff) A test feeds a `TagResult` carrying an UNKNOWN allergen status and asserts no badge
   is drawn for it.
4. (diff) `find.bySemanticsLabel` covers `recipeAllergensUnassessedA11y`.
5. (diff) NEGATIVE CONSTRAINT: `_buildCompactLayout` is unchanged, and the change is reported
   as grid-only.

---

## BUT-1897 — a crash report can carry a person's id  [Tier C — security, multi-file]

**Premise: re-verified at Step 0 before anything is written**, because the ticket was last
edited 2026-08-19 and the tree has moved since. Two claims to check: (a) `AppLogger` still
hands the raw `error` object to `recordError`, (b) the six repositories the ticket names
still pass `userId: currentUser` raw into `PermissionDeniedException`.

**The decision the ticket leaves open** is one choke point (wrap the error object before
`recordError`) versus N throw sites. A wrapper loses the exception TYPE, which is what makes
a Crashlytics report groupable. Planned shape: fix the throw sites AND add the
architecture-test arm — the arm is what stops the next one, and a runtime choke point cannot
be proven by a test that only reads source.

**Acceptance criteria**
1. (diff) The architecture test gains an arm over exception CONSTRUCTION: raw identifiers
   passed to `resourceId:` / `resource:` / `userId:`, or interpolated into a `StateError(` /
   `Exception(` message, under `lib/repositories/` and `lib/services/`.
2. (diff) That arm is proven to fire — it reddens against the `message_deletion_module`
   `StateError` exactly as that line stands on main today, before any fix.
3. (diff) Every site the arm flags is either masked or explicitly allow-listed with a written
   reason.
4. (diff) NEGATIVE CONSTRAINT: no change to what `AppLogger` sends as the error OBJECT unless
   the critique asks for it — the type is load-bearing for Crashlytics grouping.

---

## BUT-1883 — a poll past the cap can close on the wrong option  [Tier A]

**Premise: PLAN-STALE — half of it already shipped, and the ticket does not say so.**
Checked on `main` 2026-08-20:

- The cap still exists (`message_query_module.dart:23`, `:177`).
- A test DOES now exist (`message_query_module_test.dart:604`). It pins that the cap keeps
  the NEWEST polls rather than the oldest, which closes the "0 röster on screen" half: the
  dropped poll is now one scrolled off the top.
- **Still open, and it is the dangerous half:** nothing stops `closePoll` from acting on a
  poll whose votes were never hydrated. The module's own comment (`:150-158`) still names the
  consequence — the wrong recipe written into the week's plan.

So the remaining work is one guard plus its test, not the two items the ticket lists. The
ticket body is corrected before implementation (Phase 2 "plan-stale" branch).

**Acceptance criteria**
1. (diff) `closePoll` refuses to resolve a winner from a poll whose votes were never
   hydrated, instead of falling through to the first option.
2. (diff) A test proves the refusal, and it reddens if the guard is removed.
3. (diff) The refusal is visible to the user in Swedish, not a silent no-op.
4. (diff) The Linear ticket body is corrected to record that the newest-first half already
   shipped.

---

## Needs you (Tier D)

None in this batch — all four are code-only.

## Post-sprint steps

1. Full `dart analyze --fatal-infos` on the changed files.
2. File follow-up Linear tickets BEFORE the commit.
3. Commit through the review gates (`code-reviewer`, `testing-specialist`,
   `firebase-backend-security` where repositories are touched, `integration-reviewer`).
4. Push to main.
5. Transition: BUT-1891 / BUT-1897 / BUT-1883 → Done on an all-pass; BUT-1895 → In Review.
6. Phase 3.6 decision queue (`malin` was passed).

## Outcome verification (Phase 2.7)

Graded by fresh-context verifiers that saw only the criteria, the scoped diff and the tests
— not by the implementer.

- **BUT-1891** — 5/5 PASS. Also confirmed independently: `StyledInput` is byte-identical to
  main, `formattedAmount` has exactly one consumer and it is display-only, and the
  `replaceAll(',', '.')` dead code is gone rather than left looking like handling.
- **BUT-1895** — 6/6 PASS. The verifier found one real gap the criteria did not cover: the
  tile's aspect-ratio formula was hardcoded a second time inside its own test, so a retuned
  production value would have left the test green against its own stale copy. Moved to
  `AppDimensions.recipeGridAspectRatio` and imported — which immediately reddened, because
  the delegate had been reading `MediaQuery` from a context ABOVE the test's own override.
  Every "2x" case had been measuring a 1x tile.
- **BUT-1897** — 7/8 PASS, one FAIL, fixed. `SecurityViolationException` and
  `AuthenticationException` were in the same file and were not masked, and both have throw
  sites that put an id in `details:`. The verifier also found the composite-id hole
  (`<uid>_2026-W34` escapes a `\b`-bounded rule) and two false-positive regressions
  (the type label, and class names in web stack frames). All four fixed and pinned.
- **BUT-1883** — NOT GRADED, because nothing was built. See the deviation log.

## Review gate

Seven specialist runs. Two blocked and were fixed rather than argued with:

- `code-reviewer` on the widgets: a doc comment I inserted swallowed the neighbouring
  function's, and a "correction" I wrote made a positional claim that was false. Both fixed;
  re-review passed.
- `firebase-backend-security` on the web sink: the stack carve-out re-exported the message it
  had just masked, because under dart2js the first line of a stack IS the exception's
  `toString()`. Split at the first frame instead; re-review passed, then found that Firefox
  and Safari emit a third frame shape the splitter did not know, which is now covered.

Every fix in this sprint was mutation-probed — the fix is reverted and the test watched to
redden — including one test that turned out VACUOUS on the first probe (the UNKNOWN-allergen
case passed with the filter deleted, because an UNKNOWN badge draws a third icon the
assertion never named).

## Deviation log

- [discovery] BUT-1891: plan said "add a formatter at the two call sites" → found the
  DISPLAY half open too (`formattedAmount` returned `amount.toString()`, i.e. "1.5", under a
  doc comment promising "1,5 l Mjölk") → fixed both, because the input fix alone is undone
  one screen later. Raised by the Product Designer critique, verified in the code.
- [discovery] BUT-1891: `StyledInput.number` has NO production caller — only tests. The
  shared default is still untouched, and now has a case pinning that it refuses both
  separators.
- [deviation] BUT-1895: plan said "add the allergen row to the grid" → the grid tile
  ALREADY overflowed its own box by 70px at 1x and 175px at 2x, for every recipe, measured.
  Adding a row to a container that clips was not possible → the image became the layout's
  slack (`Expanded`) and the tile height now scales with the text size
  (`_gridAspectRatio`). Conservative in the sense that it fixes the container rather than
  shrinking the content, which is what the Creative Director's must-have required.
- [deviation] BUT-1895: the unassessed marker was NOT in the plan's grid scope. Added on the
  Creative Director's blocking condition — shipping the badges without it recreates, in the
  grid, the "silence reads as safe" bug the marker exists to close.
- [discovery] BUT-1895 item 5 (the over-promising `reason` in `compact_tag_rows_test.dart`)
  was already corrected on main. Nothing done; recorded so it is not re-filed.
- [deviation] BUT-1897: plan said "fix the throw sites AND add an architecture-test arm" →
  the Trust & Safety critique showed the arm is the WEAKER control (it reads source; the
  leak is a runtime value) and that ~50 sites is the wrong count anyway (53 across 22 files).
  Took the choke point instead: the exception classes mask inside their own `toString()`.
  That also covers two paths no throw-site sweep reaches — an uncaught exception going
  straight to `recordError` from `main.dart`, and the web sink where Crashlytics is skipped.
  The arm is filed as BUT-1907 with the conditions it must meet.
- [discovery] BUT-1897: masking the whole joined string turned `PermissionDeniedException`
  into `Perm***` — the class name is 25 alphanumeric characters, the exact shape of a uid.
  Caught by the existing tests on the first run; the type label now sits outside the mask
  and a case pins it.
- [needs-human] BUT-1883: the ticket's premise is REFUTED, not stale. `closePoll` re-reads
  the single message on an uncapped path, and `_resolveWinner` returns null on a zero-vote
  poll — so the "wrong recipe in the week's plan" it specifies cannot happen. No guard was
  built. The two false comments that caused the ticket were corrected, the real (inverted)
  defect is BUT-1908, and the blocking gap the critique found is BUT-1909.
- [discovery] A `\b` written through a Python heredoc landed as a literal BACKSPACE byte in
  `log_sanitizer.dart` — the exact shape of the BUT-1901/1902 lesson. Caught by reading the
  bytes back, repaired with `chr(92)`, and the file is control-byte clean.



---

# PLAN 2026-08-17 — get the functions deploy through, then remove the dead functions

Approved by Malin in-session (AskUserQuestion, 2026-08-17): "Sätt tak på 10 instanser".
The cleanup half is her follow-up ask ("men kanske också radera gamla engångsgrejer när vi
ändå håller på?") and is scoped below with one question left to her.

## Background — what is actually broken

The `firestore:indexes` deploy succeeded earlier today (19/19 TTL policies ACTIVE, verified).
The `functions` deploy then failed on 53 of 71 functions. Every failure reported
`Container Healthcheck failed`, which reads like broken code and is not — the real line is:

    Quota exceeded for total allowable CPU per project per region.

Measured, not assumed:
- 71 Cloud Run services in europe-west1, every one at `cpu=1`.
- `maxInstances` is set **nowhere** in `functions/src` (grep: 0 hits), and
  `setGlobalOptions` sets only `region`. Unset means the platform default of 100.
- So the project reserves ~7100 vCPU of admission headroom before a single request arrives.
- Nothing was deleted or corrupted by the failed deploy. The three new BUT-1838 group
  callables DID get created and are ACTIVE (`createChatGroup`, `addChatGroupMembers`,
  `removeChatGroupMember`); every other function still runs its previous revision.
- `leaveGroupConversation` is still deployed. Firebase skipped the delete because the
  updates failed ("Deploys failed. Skipping deletes.").

Honest gap: the quota value gcloud reports for `CpuAllocPerProjectRegion` in europe-west1 is
20000, which does **not** obviously conflict with 7100. I could not reconcile the exact
accounting from the quota API, so the deploy itself is the test of the fix rather than a
calculation I can show. If step 1 does not clear it, the fallback is a quota increase
request, and I will say so rather than keep guessing.

## What the review changed (recorded here because two of my claims were wrong)

`cloud-functions-specialist` passed with 0 blocking, having dumped the compiled
`__endpoint` manifest rather than reasoning about the SDK. It corrected two things:

- **70 gen2 services, not 71.** `onUserDeleted` is a gen1 auth trigger — v2
  `setGlobalOptions` cannot configure it and it consumes no Cloud Run CPU. That also answers
  the open question below about its blank `state`: gen1 reports `status`, not `state`, so the
  blank is the API shape, not a failed deploy. The reservation is ~7000 vCPU, not ~7100.
- **"10 concurrent" was the wrong mental model in my own head.** `concurrency` is a separate
  option defaulting to 80 at cpu >= 1, so the real ceiling is ~800 in-flight requests per
  function. Verified there is no fan-out victim: scheduled sweeps get one invocation per tick,
  notification fan-out is in-process (`MAX_PER_RUN = 200` under one `Promise.all`), and the
  two ingredient triggers that could genuinely queue both carry `retry: true`, so throttled
  events are redelivered rather than dropped.

It also found the change was pinned by no test, which turned out to matter more than it
sounded — see below.

## Step 1 — cap the instances (unblocks the deploy)

1. `functions/src/index.ts`: `setGlobalOptions({ region: "europe-west1", maxInstances: 10 })`,
   with a comment stating the RULE (an unset ceiling reserves 100 per function and the wall
   only appears mid-deploy), not just the current numbers.
1b. `functions/src/__tests__/deploy-manifest.test.ts` (new) pins BOTH invariants against the
   compiled deploy manifest: every gen2 export in `europe-west1`, and every one carrying an
   instance ceiling. The region hazard was previously guarded by a comment in `index.ts` and
   nothing else, and a comment does not redden.
   **The first version of this suite contained a vacuous assertion and the mutation probe is
   the only thing that caught it.** `firebase-functions` does not leave an unset
   `maxInstances` as null — it stores a sentinel object whose `toJSON` renders as `null`, so
   `JSON.stringify` printed "null", `"maxInstances" in endpoint` was true, and `x == null` was
   FALSE. The presence check stayed green under a mutant that stripped the option from all 70
   functions. Now tested as `typeof x === "number"`. Do not "simplify" it back to a null check.
   Probed 2026-08-17: healthy 4/4; ceiling removed reddens the presence check naming all 70;
   region changed reddens the region check naming 64; `index.ts` restored byte-identical
   (md5 compared).
1c. `functions/src/ingredients/on-ingredient-soft-deleted.ts:40` said `setGlobalOptions` "sets
   the region and nothing else" — true when written, false as of this change, and it is the
   recorded BUT-1781 rationale for a local timeout. Rewritten to state the rule. Grepped the
   whole tree for the same phrasing: one occurrence, fixed.
   - Per-function options win over global ones, so any function that later needs more
     concurrency raises its own. None sets `maxInstances` today, so nothing is overridden.
   - Pre-launch, zero users: 10 is far above real demand and doubles as a cost ceiling
     (CLAUDE.md cost principles).
2. `npx tsc --noEmit` in `functions/`.
3. `cloud-functions-specialist` review (commit gate for `functions/src`).
4. Commit, push to main.
5. `firebase deploy --only functions --force --project butlery-app-1`.
   `--force` is required for two reasons, both verified as intended:
   - `onIngredientPropertiesChanged` now carries `retry: true`, which is deliberate and
     documented in its own source with an event-age guard bounding the retry window.
   - it auto-confirms deleting `leaveGroupConversation`, removed on purpose in BUT-1838 and
     replaced by the three group callables. Verified zero callers anywhere in the repo.
6. **Verify per-function `state` from the API, not from `functions:list` names** — a deploy
   that removes Cloud Run services can leave a replacement `FAILED` while the name still
   lists (repo lesson, 2026-08-03). Expect 71 ACTIVE and no `leaveGroupConversation`.
   Note `onUserDeleted` reports an empty `state`; confirm whether it is a 1st-gen function
   (which reports `status`, not `state`) rather than treating the blank as a failure.

## Step 2 — CORRECTED: none of the five is safe to delete, and my evidence was bad

I told Malin these five were "one-shot migrations, safe to remove" on the strength of a
whole-repo grep showing zero callers. She approved on that basis. **The premise was wrong**,
and the error is the one the digest already names: "unreferenced" proven against code cannot
see a function a HUMAN invokes. An admin callable has zero callers BY DESIGN.

Reading what each one actually is, rather than counting references to it:

- **`bulkMarkForRetagging` / `getRetagStatus`** — not a migration at all. Its own header calls
  it "the operator escape hatch that DRAINS the `stale-ingredient` / `stale-properties`
  markers the ingredient cascades write". That is the manual recovery path for exactly the
  failure `concurrency: 1` was added tonight to prevent, and `on-ingredient-soft-deleted.ts:63`
  names it as such. Deleting it would remove the repair tool in the same change that hardened
  the thing it repairs.
- **`seedSiteConfigs` / `getSiteConfigStats`** — an ongoing ops tool, not a one-shot. It seeds
  the CSS selectors that let a new Swedish recipe site be supported WITHOUT an app release.
- **`backfillCanonicalRatings`** — carries a hard gate refusing to run until
  `enable_pooled_ratings` is on in prod and the privacy-policy pooling disclosure has shipped.
  It has never run, so it is PENDING, not spent.
- **`backfillRecipeCommentsDenorm`** and **`backfillSharedListContributors`** — the only two
  that really are one-shot, and both carry an explicit lifecycle contract naming the two
  conditions for their own deletion: a successful invocation returning `hasMore: false`, then
  a 30-day soak. Neither has been invoked (the only log lines are today's deploy). By their own
  written rule they must NOT be deleted yet.

Two of the five also share a module with a function I had put in the KEEP column, so "delete
five files" was never the shape of the change either.

**Recommendation: delete nothing.** The reason to delete was quota pressure, and that is gone
— the reservation went 7100 -> 700 vCPU, and these five cost 50 of it. Deleting now trades a
real recovery path and a pending migration for no benefit.

The five were removed from PRODUCTION earlier tonight to break the quota deadlock, and the
deploy has since recreated all of them. Production and source agree again.

## Open questions

Blast-radius ranked. Only one, and it is deferrable without blocking step 1:

1. **Does 2b go or stay?** Highest blast radius of the two, because it deletes working
   admin tooling rather than spent migrations. Asked after step 1 ships; default is KEEP.

No architecture-changing unknowns. Assumptions stated: (a) `maxInstances: 10` is above any
real pre-launch demand — the app has no users; (b) the failed deploy left production
consistent, which was verified by reading every function's state, not inferred.

## Step 1½ — a red GDPR test, found on the way, fixed here

`test:request-account-deletion` was RED on main before this change (it came in with
`a329de0f5`, today's salvage commit). It is not caused by this work and it is not a
production defect, but it had to be understood before deploying, because the cascade code it
covers is on main and NOT yet in production — the deploy is what would make it live.

Root cause: the suite's local fake Firestore had no `limit()` on its query object, so the
`chat_groups` and `messages` steps threw `where(...).limit is not a function`. The production
code is correct; real Firestore has `.limit`. But the consequence was real — **those two GDPR
erasure steps were being exercised by nothing in that suite**, and the failure was reported as
"step failed", which reads like a broken cascade.

Fixed by giving the fake a `limit()` (the same precedent the file's own `listDocuments` note
records), and by making the assertion print `result.errors` instead of only the collection
names — the old message sent the reader to the whole cascade rather than to the line that
threw. Suite is 4/4 and the full CF lane is 88/88.

## Acceptance criteria

- [x] `npx tsc --noEmit` clean.
- [x] Full CF unit lane green: **88/88 suites (346s)**, up from 87/88 with
      `test:request-account-deletion` red.
- [x] The new deploy-manifest suite is non-vacuous — mutation-probed both ways, `index.ts`
      restored byte-identical (md5 compared).
- [ ] `cloud-functions-specialist` opened the FINAL bytes and passed (the first review graded
      an earlier version; every later edit un-proves it).
- [ ] `firebase deploy --only functions` exits 0 with zero failed functions.
- [ ] Per-function `state` read back from the API: every function ACTIVE, count matches
      source exports, `leaveGroupConversation` gone.
- [x] `onUserDeleted`'s blank state explained: it is gen1, which reports `status` rather than
      `state`. Not a failed deploy.
- [ ] BUT-1792 closed (its two remaining criteria were the TTL deploy, now done).
