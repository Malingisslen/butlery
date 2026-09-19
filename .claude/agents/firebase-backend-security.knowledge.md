# firebase-backend-security — accumulated knowledge

Core card: read on every review, after the shared review core. The chapters are listed under
`knowledge.tiers` in `.claude/shared-plugin.json`; read each chapter whose `paths` match a
file in the diff. The archive, `firebase-backend-security.knowledge.archive.md`, is never
read at review. A new principle goes into the chapter it is about, and into this card only
if it applies to every review; `knowledge-caps-gate` refuses a core card over 15,000 chars
and a chapter over 20,000.

---

## Repository layer contract

**Every repository in `lib/repositories/` MUST use `PermissionValidationMixin`** (CLAUDE.md
rule #3, non-negotiable — missing it is Critical). But `with PermissionValidationMixin` is
the LETTER, not the substance: grep the class body for an actual
`logPermissionCheck`/`validateOwnership` call before crediting it — a read-only +
callable-write repository can carry the mixin and call nothing in it, leaving zero Art. 30
rows for a cross-user mutation (archive: BUT-1838 `FirebaseChatGroupRepository`). A
callable-backed mutator should log the callable's OUTCOME (never `granted:true` before it
answers — that forges the trail) and check whether the CF itself writes an audit row.

**Service access**: `ServiceLocator.get<T>()` (widgets/VMs) or constructor injection (DI
modules). Never `FirebaseFirestore.instance` directly — inject `FirestoreRepository`.
`FirebaseRecipeRepository` is registered as the `RecipeRepository` interface — use the
interface for `ServiceLocator.get`.

## Data-source rules (CLAUDE.md)

| Need | Use |
|---|---|
| Complete user data (settings, avatar, social) | `userService.currentUserProfile` |
| Auth/permission checks only | `permissionService.currentUserId` |

Never mix these. Two live-recurring variants: (1) `PermissionService.currentUser`
SYNTHESIZES a `UserProfile` from the Auth user (`displayName ?? 'User'`) — it looks like a
profile handle but is the auth-only side wearing the user-data type; any
`permissionService.currentUser.<profile field>` stamped onto a document another user reads
is a finding on sight. (2) A denormalized actor-name field written via `copyWith` (whose
`name ?? this.name` default keeps the PREVIOUS editor's name while the id advances)
misattributes on any multi-user doc — stamp an id/name PAIR atomically from
`UserService.profileDisplayName` (profile-first, no Auth fallback) at PERSIST time, never
`authRepository.currentUser?.displayName`, and teach the read side that empty means
"unknown" rather than defaulting to a placeholder.

## Firestore rules pairing

`firestore.rules` (~72KB) MUST match repository permissions in lockstep — a drift is either
a security hole (rule too permissive) or an app break (rule too strict). A new field on a
model with `toFirestore()` is a rules change too: `hasOnly` allowlists fail CLOSED and
SILENTLY (an unlisted field denies every write, with no signal beyond "nothing saved") — grep
`firestore.rules` for its validator in the SAME edit, and demand a rules test that day (one
allowed set, one rejected extra key). The MIRROR failure: `hasRequiredFields` pins KEYS, not
VALUES, so anything a create rule does not constrain is client-writable — including a
server-only MARKER a Cloud Function stamps (`type: 'duplicateBlocked'`, text and all). Never
rest a privacy argument on "the server empties it first"; read the create rule.

The `firestore-rules-tester` agent owns proving rule behavior — hand off after rule changes
rather than writing rules tests yourself.

## Cost principles (CLAUDE.md)

- Avoid unnecessary reads/writes. Batch (Firestore limit: 500 ops/batch; a consolidated
  update is 1 op/doc). Cache aggressively; use indexed queries; prefer deterministic logic
  over LLM calls.

## How new learning enters this file

This file is a **principles document, edited in place** — never a log. Every dated,
ticket-specific narrative belongs in `firebase-backend-security.knowledge.archive.md`
instead, however recent; the test is SHAPE (a story about which ticket found what), not age.

- **Extends an existing bullet?** Edit it in place — merge aggressively; most findings are
  a new instance of a pattern already here.
- **A genuinely new durable rule** (a future run would act differently because of it): add
  one tight bullet under the right category, AND append the full dated narrative to the
  archive. It earns its place only if SHARP and FINDABLE — a principle that takes a
  paragraph to say will not be read. Malin's Art. 15/17 balancing calls are DECISIONS, not
  lessons: cite `docs/architecture/ACCEPTED_DEVIATIONS.md` rather than restating the
  reasoning, and never let a merge blur two decisions made deliberately differently.
- **A one-off verified-clean review with no new reusable rule**: archive only.
- If an edit would grow this file, sharpen or retire a principle first. A bullet that has
  accumulated several "CLOSED 2026-..." status updates inline should become ONE sentence
  describing the current rule, with the history left in the archive.

## Principles

### The one architecture fact behind the most bugs
Butlery splits a user across **two** Firestore docs with different read rules: `users/{uid}`
(private, `isOwner||isAdmin`, CF-authoritative for `birthYear`/`isMinor`) vs
`public_profiles/{uid}` (world-readable to any authenticated user, client-written via
`saveProfile`, and what search/cross-user reads and the client's OWN hydration actually use).
**A server-set flag written only to `users/{uid}` protects nothing that search, another user,
or the client's own UI reads.** For any "CF sets flag X, client/search reacts to X" design,
name which doc each end touches before approving it.

### Parallel write paths to the same collection
- A tidy `service.<feature>.op()` facade and the module chain the UI actually calls can
  diverge (one is dead code) — grep the real caller (view/VM) before crediting any fix; a
  fix on the unreached twin reviews green and changes nothing.
- TWO STORAGE SHAPES for one field (a parent-doc array AND a matching subcollection) means
  a write filling only one shape is invisible after the next read through the other — check
  which shape every writer/reader uses. Fix: put the fan-out in the SERIALIZER so every
  write inherits it by construction, gate a copy-then-delete on a SERVER-confirmed count
  (`metadata.isFromCache == false`, never a local-cache answer), and on a cross-tree copy
  strip foreign attribution (`addedBy*`/`purchasedBy*`) unless the uid is the copying
  owner's — rebuild via the model's full CONSTRUCTOR (a partial rebuild resets omitted
  fields to default) and check a nulled id doesn't flip a derived getter a live consumer
  reads.
- A "which shape is this" type-detection helper reading the OTHER collection first can bill
  a guaranteed-denied read on the happy path (probing shared for a personal-list id, which
  rules deny by construction) — pass the known type through explicitly instead.

- RULES ARE NOT FILTERS, and that kills whole probe designs before they are written: a list
  query is denied unless the rule can prove EVERY document it could return is readable, so a
  probe on a field the read rule does not gate (`contributorUserIds array-contains uid` where
  the rule tests `memberPermissions`) is refused for EVERY caller — a CURRENT member of the
  matching week included. The POSITIVE case is the same test and must not be over-flagged: a
  query whose `.where()` names the SAME field and value the read rule gates on
  (`where('userId', isEqualTo: uid)` against `allow read: resource.data.userId == auth.uid`)
  is the documented allowed pattern and needs no rules change — compare FIELD to FIELD before
  filing a denial. A gap note derived from such a probe's refusal therefore fires for
  users who have left nothing, i.e. it is unconditional prose wearing a conditional's shape.
  Measure it on the emulator with a same-shape ALLOWED control on the gated field, and state
  the gap unconditionally rather than probing for it.
- No `firestore.rules` match block = default-deny — grep for every new collection path, and
  remember rules DO NOT CASCADE: `allow read` on `match /users/{uid}` grants nothing on
  `users/{uid}/<sub>`, each of which needs its own block. The sharpest instance is a
  collection written ONLY by the Admin SDK and read by no client — it has never needed a
  rule, so a NEW client read of it (a fresh Art. 15 section is the usual reason) is denied
  by construction and the section is a permanent failure envelope that ships nothing.
  Fake-Firestore unit tests pass either way, so the green suite is not evidence: grep for
  the `match` block, and treat every `users/{uid}/<sub>` path the export reads as suspect
  (`fcm_tokens` is a live pre-existing case). An
  admin-only collection-group rule can make "no match block" a false claim; word it "no
  rule grants a CLIENT this read." A denied read inside a shared `try` DISCARDS sibling
  reads already collected — give each probe in a multi-read section its own inner try.
  The MIRROR hazard when that block is finally added: a read grant covers the whole
  DOCUMENT, so "safe because it holds nothing but X and Y" is a claim about STORED data,
  never about today's writer. Open the writer's history — a field a pre-migration writer
  put there (an array of maps naming third parties is the recurring shape) survives until a
  one-time script is RUN LIVE, and a hand-run script's effect is a premise, not a fact. A
  first-ever client read of such a collection is therefore a NEW third-party disclosure and
  needs its own recorded decision, exactly like a migration that re-homes rows onto a
  rules-covered path. Grade a rules SECTION HEADER as a universal over the blocks beneath
  it too ("admin-only, clients denied"), and MOVE a block that falsifies it rather than
  rewording the header.
- An automatic/background profile mutation must be a single-field `update()`, never a
  full-profile `set()` (clobbers peer-owned denormalized fields).
### Query cost, indexes, real-time listeners
- Every `.snapshots()` in `lib/repositories/` ends in `.limit(N)` (per-user ~100, per-group
  ~200, cross-user collection-group ~200-500; per-thread → cursor-paginate instead). Live
  pagination uses a DOC-cursor (`startAfterDocument`) — value-cursors miss/double-emit docs
  sharing one `serverTimestamp()`. `where(equality)+orderBy(different field)` needs a
  composite; a lone equality-or-range does not.
- **`.where(f, isNotEqualTo: null)` / `isEqualTo: null` builds NO CONDITION** —
  `cloud_firestore`'s builder adds each operator only if non-null, so a literal null
  compiles, reads as a filter, and leaves an UNFILTERED sweep. Use `isNull: false/true`. On
  a member-scoped collection this reads as "my data won't load" (rules refuse the unscoped
  query), not as an over-share. `fake_cloud_firestore` THROWS on the bad spelling, so a
  green Dart unit test proves the QUERY only, never the permission.
- A per-doc visibility rule needs a SPLIT query (owner branch unfiltered, friend branch
  STRICT equality) — a "field absent" looseness re-opens the leak.
### Third-party / infra
- Cert pinning: empty per-host pins must no-op fall through; release-safety checks must
  `throw`/`StateError` (never bare `assert`); an in-flight-request guard must key by the
  real serialization axis (per-host), not one global `Future?`; a pin-reject-then-fallback
  is safe only if the reject happens before the request hits the wire (`onRequest`, not
  `onResponse`).
- Native-only plugins have no web SDK — a `kIsWeb` branch calling one silently no-ops.
  `execFileSync(cmd, argsArray)` is immune to command injection even with
  attacker-influenced argv — the risk is shell-string interpolation, not the args.

### Testing / tooling gotchas
- `fake_cloud_firestore` enforces neither RULES nor INDEXES — a green fake test proves
  query shape only. Sharpest instance: a real `get()` on a nonexistent doc in a rules-gated
  collection returns `permission-denied` (the read rule dereferences null `resource.data`),
  while the fake returns `exists == false` — a "try shared, fall back to personal" probe
  whose `catch` RETURNS the inconclusive value instead of falling through reads as covered
  and answers "unknown" forever in production; state such a throw in the interface. It also
  IGNORES `GetOptions(source:)`, so cache-vs-server behaviour can only be pinned through a
  mocked `DocumentReference`/`Query` capturing the `GetOptions` it is handed — and that pins the base
  method only: whether the one production caller still PASSES the opt-in stays unguarded
  unless a test drives that repository through the same mock.
- Prefer real-repository + fake-Firestore + auth-state-fake tests over side-effect stubs
  that mock away the boundary under test. Cascade unit tests against a fake Firestore must
  bridge the production `ServiceLocator`, or it throws, gets caught, and the step lands
  silently in `failedCollections` — a green test proving nothing.
### Superseded
- `activity_events` and comment-image Storage orphans (both previously open follow-ups
  here) are fully closed and retired — grep the archive for the closing entries rather than
  re-filing either.

---

## When to consult the archive

- An export section returns empty or a value looks wrong, and you need to tell "denied" from
  "genuinely nothing there" — grep the archive by collection name for a prior probe-shape
  finding before re-deriving it.
- A cascade step reports success while rows are still on disk, or a residual probe stays
  red after a fix — search for the ticket/collection; the discovery-query-mismatch pattern
  has recurred multiple times and the fix is usually already recorded.
- A finding-in-progress feels familiar — search by collection name or symptom before filing
  it as new.
- You need the exact rule predicate, code excerpt, or full multi-round narrative behind a
  principle above — every principle here has its raw history in the archive.
- You're about to append a new dated entry — check first whether it should instead extend a
  bullet above.
