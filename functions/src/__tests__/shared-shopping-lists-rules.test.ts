/**
 * Firestore rules tests for /unified_shared_shopping_lists.
 *
 * BUT-1725 added an append-only guard on the erasure trail:
 *
 *   function keepsContributorTrail() {
 *     return request.resource.data.get('contributorUserIds', [])
 *              .hasAll(resource.data.get('contributorUserIds', []))
 *       && request.resource.data.get('contributorUserIds', []).size() <= 200;
 *   }
 *
 * `contributorUserIds` is the ONLY handle account erasure has on a shared list
 * a member has already LEFT — the cascade queries it with `array-contains` to
 * find lists whose items still carry that person's `addedByDisplayName`. So no
 * CLIENT write may drop an entry, the owner included. The Admin SDK cascade
 * bypasses rules and keeps its `arrayRemove`.
 *
 * The predicate is a conjunct on EVERY client update to the collection, so the
 * catastrophic failure mode is not a leak but a BLANKET DENY: get it wrong and
 * every household shopping write stops. The suite therefore leads with allow
 * paths (SSL1, SSL10, SSL11, SSL12) — a blanket-deny regression passes every
 * deny test with zero allow proof.
 *
 * Create side: only the <= 200 bound applies (no prior array to preserve).
 *
 * BUT-1706 extends the suite past the trail to the collection's OTHER rules,
 * which had no coverage at all: the read gate (SSL26-SSL31, including the
 * revoked-member deny that makes the Art. 15 contributor probe refusable), the
 * two create conjuncts SSL1-SSL5 left unpinned (SSL32-SSL34), and owner-only
 * delete (SSL35-SSL36).
 *
 * SSL40 closes the actor-gate hole the first BUT-1706 pass left: the revoked
 * member was pinned on READ only, while the scenario the client's
 * `_onReplayRejected` handler exists for is a revoked member's WRITE.
 *
 * SSL41-SSL43 cover the privileged-key conjunct, which had a deny test for one
 * of its three anchors. The ADR added alongside this suite asserts that
 * predicate, so leaving it unproven would let the record and the rules drift
 * apart silently. SSL43 is its allow half — without it a blanket deny on
 * `memberPermissions` passes every other test while breaking member removal.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/shared-shopping-lists-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
// Client-SDK sentinels only — `ctx.firestore()` is the CLIENT SDK, and an
// admin sentinel throws `invalid-argument` before any rule is evaluated (which
// would also make an assertFails deny test pass for the wrong reason).
import { arrayUnion, arrayRemove, deleteField } from "firebase/firestore";

const PROJECT_ID = "butlery-shared-shopping-lists-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "list-owner-uid";
const EDITOR = "list-editor-uid";
const VIEWER = "list-viewer-uid";
const STRANGER = "stranger-uid";
// In `contributorUserIds` but NO LONGER in `memberPermissions` — the exact
// person the trail exists for. Their uid is what a household member must not
// be able to strip.
const DEPARTED = "departed-member-uid";
// BUT-1718: a member holding `admin` who is NOT `ownerId`. The base fixture has
// no such actor — OWNER is both — so the self-removal tests that need one seed
// it through `validListBody`'s `extra` rather than widening the fixture forty
// other assertions rest on.
const ADMIN_MEMBER = "list-admin-member-uid";

const COL = "unified_shared_shopping_lists";
const CAP = 200;

// Per-run token so create-allow doc ids never collide with a doc persisted by a
// prior run on the shared emulator (the emulator keeps data across `npm run`
// invocations, which would silently turn a create into an update).
const RUN = Date.now().toString(36);

let env: RulesTestEnvironment;

// FIXED, not `new Date()`: the member branch of `allow update` forbids a
// non-owner from touching `createdAt` (L1647), so a builder that re-stamps the
// timestamp on every call makes every whole-document write by an edit member
// deny for a reason that has nothing to do with BUT-1725. SSL25 pins that rule.
const CREATED_AT = new Date("2026-01-01T00:00:00.000Z");

/** `['bulk-0', ... , 'bulk-<n-1>']` — filler for the size-bound tests. */
function bulkContributors(n: number, prefix = "bulk"): string[] {
  return Array.from({ length: n }, (_, i) => `${prefix}-${i}`);
}

/** Minimal-but-valid shared shopping list owned by OWNER. */
function validListBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    ownerId: OWNER,
    memberPermissions: {
      [OWNER]: "admin",
      [EDITOR]: "edit",
      [VIEWER]: "view",
    },
    items: [],
    createdAt: CREATED_AT,
    name: "Veckohandling",
    contributorUserIds: [OWNER, EDITOR, DEPARTED],
    ...extra,
  };
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

/**
 * Seed a stored list bypassing rules. Re-seeded per test, so every read/update
 * test is idempotent on a persistent emulator.
 */
async function seedList(
  listId: string,
  extra: Record<string, unknown> = {}
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`${COL}/${listId}`)
      .set(validListBody(extra));
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ====================================================================
// CREATE — size bound only (5 assertions across 5 tests)
// ====================================================================

// SSL1: create-allow baseline. The client seats `[uid]`. If this reddens, the
// new `.get('contributorUserIds', []).size() <= 200` conjunct broke creation
// outright.
test("shared lists: owner CAN create a list seating themselves in contributorUserIds", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/create-seat-${RUN}`)
      .set(validListBody({ contributorUserIds: [OWNER] }))
  );
});

// SSL2: back-compat — an older client that sends no contributorUserIds at all
// must still be able to create (the `get(..., [])` default is size 0).
test("shared lists: owner CAN create a list with NO contributorUserIds field (default [])", async () => {
  const body = validListBody();
  delete body.contributorUserIds;
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx.firestore().doc(`${COL}/create-absent-${RUN}`).set(body)
  );
});

// SSL3: create at the cap — the bound is `<= 200`, so exactly 200 ALLOWS.
test("shared lists: owner CAN create a list with exactly 200 contributors (bound is inclusive)", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/create-at-cap-${RUN}`)
      .set(validListBody({ contributorUserIds: bulkContributors(CAP) }))
  );
});

// SSL4: create over the cap — deny. Pairs with SSL3: the only delta is one
// extra element, so the denial can only be the size bound.
test("shared lists: owner CANNOT create a list with 201 contributors (over the size bound)", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/create-over-cap-${RUN}`)
      .set(validListBody({ contributorUserIds: bulkContributors(CAP + 1) }))
  );
});

// SSL5: pre-existing ownership gate still holds — a non-owner cannot create a
// list naming someone else as owner. Guards against the new conjunct being
// bolted on in a way that reorders/short-circuits the ownership check.
test("shared lists: a non-owner CANNOT create a list owned by someone else", async () => {
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/create-not-owner-${RUN}`)
      .set(validListBody({ contributorUserIds: [STRANGER] }))
  );
});

// ====================================================================
// UPDATE — the deny-everything regression guard (5 assertions across 5 tests)
// ====================================================================

// SSL6: THE load-bearing allow. An ordinary household write (tick an item)
// that never mentions contributorUserIds must still pass — `update()` merges,
// so request.resource.data still carries the stored array unchanged.
test("shared lists: an edit member CAN update items without touching contributorUserIds", async () => {
  await seedList("upd-items");
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/upd-items`)
      .update({ items: [{ id: "i1", name: "Mjölk", isBought: true }] })
  );
});

// SSL7: the owner branch of `allow update` must also survive the new conjunct.
test("shared lists: the owner CAN update an unrelated field (name) with the trail intact", async () => {
  await seedList("upd-owner-name");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx.firestore().doc(`${COL}/upd-owner-name`).update({ name: "Helghandling" })
  );
});

// SSL8: whole-document update carrying every field, trail preserved verbatim —
// the shape `updateCollaborativeList` produces when the client rebuilds the
// doc. Proves the predicate is not accidentally diff-sensitive.
test("shared lists: an edit member CAN write the whole document back with the trail preserved", async () => {
  await seedList("upd-whole-doc");
  const body = validListBody({
    items: [{ id: "i2", name: "Ägg", isBought: false }],
    // Same set, DIFFERENT ORDER — `mutateCollaborativeList` builds the array
    // from a Dart Set, so element order is not preserved across writes.
    // hasAll() is set-semantics, so this must ALLOW.
    contributorUserIds: [DEPARTED, EDITOR, OWNER],
  });
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx.firestore().doc(`${COL}/upd-whole-doc`).update(body)
  );
});

// SSL9: legacy list created before the backfill has NO contributorUserIds.
// `resource.data.get(..., [])` is `[]`, `[].hasAll([])` is true → allow.
test("shared lists: an edit member CAN update a legacy list that has no contributorUserIds", async () => {
  const legacy = validListBody({ items: [] });
  delete legacy.contributorUserIds;
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`${COL}/upd-legacy`).set(legacy);
  });
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/upd-legacy`)
      .update({ items: [{ id: "i3", name: "Smör" }] })
  );
});

// SSL10: seating yourself on a legacy list (the migration path every client
// write takes once BUT-1725 ships).
test("shared lists: an edit member CAN seat themselves on a legacy list with no trail", async () => {
  const legacy = validListBody();
  delete legacy.contributorUserIds;
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`${COL}/upd-legacy-seat`).set(legacy);
  });
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/upd-legacy-seat`)
      .update({ contributorUserIds: arrayUnion(EDITOR) })
  );
});

// ====================================================================
// UPDATE — append-only trail, allow path (2 assertions across 2 tests)
// ====================================================================

// SSL11: arrayUnion is the shape the client actually queues (`_withContributor`
// / the offline replay path). Rules see the POST-transform array, so this must
// satisfy hasAll().
test("shared lists: an edit member CAN arrayUnion themselves into contributorUserIds", async () => {
  await seedList("upd-union", { contributorUserIds: [OWNER, DEPARTED] });
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/upd-union`)
      .update({
        contributorUserIds: arrayUnion(EDITOR),
        items: [{ id: "i4", name: "Bröd" }],
      })
  );
});

// SSL12: growth to exactly the cap is still allowed — 199 stored + 1 unioned.
test("shared lists: an edit member CAN grow the trail to exactly 200 entries", async () => {
  await seedList("upd-to-cap", {
    contributorUserIds: bulkContributors(CAP - 1),
  });
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/upd-to-cap`)
      .update({ contributorUserIds: arrayUnion(EDITOR) })
  );
});

// ====================================================================
// UPDATE — append-only trail, deny path (6 assertions across 6 tests)
// ====================================================================

// SSL13: a household member rewrites the array WITHOUT the departed member —
// the Art. 17 evasion the rule exists to stop.
test("shared lists: an edit member CANNOT drop a departed member's uid from the trail", async () => {
  await seedList("upd-drop-editor");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-drop-editor`)
      .update({ contributorUserIds: [OWNER, EDITOR] })
  );
});

// SSL14: the OWNER is bound too. Load-bearing — the owner branch of
// `allow update` has no diff restriction at all, so without the conjunct
// sitting OUTSIDE the `(owner || member)` parenthesis the owner could strip it.
test("shared lists: the OWNER CANNOT drop a departed member's uid from the trail", async () => {
  await seedList("upd-drop-owner");
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-drop-owner`)
      .update({ contributorUserIds: [OWNER, EDITOR] })
  );
});

// SSL15: the sentinel form of the same attack.
test("shared lists: the owner CANNOT arrayRemove a departed member's uid from the trail", async () => {
  await seedList("upd-array-remove");
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-array-remove`)
      .update({ contributorUserIds: arrayRemove(DEPARTED) })
  );
});

// SSL16: wiping the trail entirely.
test("shared lists: the owner CANNOT clear contributorUserIds to an empty array", async () => {
  await seedList("upd-clear");
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`${COL}/upd-clear`).update({ contributorUserIds: [] })
  );
});

// SSL17: a full `set()` (no merge) on an EXISTING doc that omits the field —
// the path a buggy client retry or an old app version hits. Run as OWNER so
// the owner branch's lack of a diff restriction isolates the denial to
// keepsContributorTrail().
test("shared lists: the owner CANNOT set() the whole doc without contributorUserIds (field dropped)", async () => {
  await seedList("upd-set-drop");
  const body = validListBody();
  delete body.contributorUserIds;
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`${COL}/upd-set-drop`).set(body)
  );
});

// SSL18: same actor, same doc, same operation as SSL17 but WITH the trail —
// fail-closed proof that SSL17's denial is the trail, not the body or the
// set-on-existing path.
test("shared lists: the owner CAN set() the whole doc when contributorUserIds is preserved", async () => {
  await seedList("upd-set-keep");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx.firestore().doc(`${COL}/upd-set-keep`).set(validListBody())
  );
});

// ====================================================================
// UPDATE — size bound (2 assertions across 2 tests)
// ====================================================================

// SSL19: growing past the cap denies. Pairs with SSL12 (199 + 1 = 200 allowed);
// only the stored count differs, so the denial can only be the bound.
test("shared lists: an edit member CANNOT grow the trail past 200 entries", async () => {
  await seedList("upd-over-cap", { contributorUserIds: bulkContributors(CAP) });
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-over-cap`)
      .update({ contributorUserIds: arrayUnion(EDITOR) })
  );
});

// SSL20: DOCUMENTED CONSEQUENCE, not an endorsement. The bound is on
// request.resource.data, so a stored list that is ALREADY over 200 (a legacy
// doc, or one the Admin-SDK backfill grew past the cap — the Admin SDK bypasses
// rules) is frozen: even an items-only write that touches nothing else denies.
// If this ever fires in production the fix is a rule change, not a client one.
test("shared lists: a list already over 200 contributors is frozen — even an items-only update denies", async () => {
  await seedList("upd-already-over", {
    contributorUserIds: bulkContributors(CAP + 5),
  });
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-already-over`)
      .update({ items: [{ id: "i5", name: "Ost" }] })
  );
});

// ====================================================================
// UPDATE — actor gates unchanged by the diff
// ====================================================================

// SSL21: view-only members stay read-only. Proves the new conjunct did not
// widen the actor set (it is ANDed, but a botched parenthesis could reorder it).
test("shared lists: a view-only member CANNOT update even with the trail preserved", async () => {
  await seedList("upd-viewer");
  const ctx = env.authenticatedContext(VIEWER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-viewer`)
      .update({ items: [{ id: "i6", name: "Kaffe" }] })
  );
});

// SSL22: a non-member stranger.
test("shared lists: a non-member CANNOT update the list", async () => {
  await seedList("upd-stranger");
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-stranger`)
      .update({ items: [{ id: "i7", name: "Te" }] })
  );
});

// SSL40: a REVOKED member — still in `contributorUserIds`, no longer in
// `memberPermissions` — cannot UPDATE. Distinct from both neighbours and not
// implied by either: SSL22 removes the actor from the document entirely, and
// SSL29 pins the same actor on READ. This is the actor shape the client's
// `_onReplayRejected` path exists for — a queued offline edit replayed by
// someone whose access was revoked while they were offline — so leaving it
// unpinned means the one scenario the handler was written for is the one the
// rules were never proven to refuse.
test("shared lists: a REVOKED member (trail only, no memberPermissions key) CANNOT update", async () => {
  await seedList("upd-departed");
  const ctx = env.authenticatedContext(DEPARTED);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-departed`)
      .update({ items: [{ id: "i9", name: "Mjölk" }] })
  );
});

// SSL23: unauthenticated.
test("shared lists: an unauthenticated caller CANNOT update the list", async () => {
  await seedList("upd-anon");
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-anon`)
      .update({ items: [{ id: "i8", name: "Salt" }] })
  );
});

// SSL25: pre-existing L1647 immutability, pinned here because it is the reason
// SSL8 must reuse the stored createdAt. Same actor and body as SSL8 except a
// re-stamped createdAt — proving SSL8's allow is about the trail, not luck.
test("shared lists: an edit member CANNOT change createdAt on a whole-document write", async () => {
  await seedList("upd-created-at");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-created-at`)
      .update(validListBody({ createdAt: new Date() }))
  );
});

// ====================================================================
// ACCESS CONTROL — the privileged-key conjunct (3 assertions)
// ====================================================================
//
// `!diff(resource.data).affectedKeys().hasAny(['ownerId','memberPermissions',
// 'createdAt'])` has THREE anchors and had a deny test for exactly one of them
// (`createdAt`, SSL25). `ADR-002-collaborative-list-membership-guard.md`, added
// in this same commit, asserts "firestore.rules forbids a non-owner from
// touching either", and its whole threat model — "the removed member kept their
// rules-granted write" — rests on that being true. An ADR asserting a predicate
// the suite does not prove is exactly the shape that goes stale unnoticed.
//
// SSL43 is the ALLOW half and is load-bearing in the opposite direction: SSL29
// and SSL40 both need a document already in the revoked state, and both reach it
// through `withSecurityRulesDisabled`. Nothing proved a client owner can
// actually perform the revocation, so a blanket-deny regression on
// `memberPermissions` would keep every other test green while making member
// removal impossible in the app.

// SSL41: an edit member cannot promote themselves.
test("shared lists: an edit member CANNOT raise their own permission level", async () => {
  await seedList("upd-self-promote");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/upd-self-promote`)
      .update({ [`memberPermissions.${EDITOR}`]: "admin" })
  );
});

// SSL42: an edit member cannot seize ownership. Distinct anchor from SSL41 —
// the conjunct is a `hasAny`, so one anchor passing says nothing about another.
test("shared lists: an edit member CANNOT take over ownerId", async () => {
  await seedList("upd-seize-owner");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx.firestore().doc(`${COL}/upd-seize-owner`).update({ ownerId: EDITOR })
  );
});

// SSL43: the owner CAN revoke a member — the write that produces the state
// SSL29 and SSL40 assert against.
test("shared lists: the owner CAN revoke a member's permission", async () => {
  await seedList("upd-owner-revoke");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/upd-owner-revoke`)
      .update({
        memberPermissions: { [OWNER]: "admin", [VIEWER]: "view" },
      })
  );
});

// ====================================================================
// SERVER SIDE — the cascade must remain able to scrub (1 assertion)
// ====================================================================

// SSL24: the Admin SDK bypasses rules, so the deletion cascade's arrayRemove
// still works. Without this, "append-only for everyone" would mean the erasure
// trail could never be cleaned up either.
test("shared lists: the Admin SDK CAN still remove a uid from the trail (cascade path)", async () => {
  await seedList("srv-cascade");
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`${COL}/srv-cascade`)
      .update({ contributorUserIds: [OWNER, EDITOR] });
  });
  let remaining: unknown;
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await ctx.firestore().doc(`${COL}/srv-cascade`).get();
    remaining = (snap.data() as Record<string, unknown>).contributorUserIds;
  });
  const list = remaining as string[];
  if (list.includes(DEPARTED)) {
    throw new Error(
      `Admin SDK write did not land: contributorUserIds still holds ${DEPARTED}`
    );
  }
});

// ====================================================================
// READ — the actor gate that had NO coverage at all (6 assertions)
// ====================================================================
//
// BUT-1706. Everything above tests writes, so the read rule
//   `uid == resource.data.ownerId || uid in resource.data.memberPermissions`
// was unpinned — and it is the rule the whole shopping feature depends on: it
// decides whether a household sees its list, and it is why an unfiltered
// collection query is refused outright rather than over-sharing (BUT-1746).

// SSL26: the owner reads their own list.
test("shared lists: the owner CAN read the list", async () => {
  await seedList("read-owner");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`${COL}/read-owner`).get());
});

// SSL27: an edit member reads it — the ordinary household case.
test("shared lists: an edit member CAN read the list", async () => {
  await seedList("read-editor");
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(ctx.firestore().doc(`${COL}/read-editor`).get());
});

// SSL28: a VIEW-only member reads it. Load-bearing: read is gated on membership,
// NOT on edit rights (SSL21 denies the same actor a write), so a rule change
// that reused the edit predicate for reads would blank the list for every
// view-only member.
test("shared lists: a view-only member CAN read the list", async () => {
  await seedList("read-viewer");
  const ctx = env.authenticatedContext(VIEWER);
  await assertSucceeds(ctx.firestore().doc(`${COL}/read-viewer`).get());
});

// SSL29: a REVOKED member — still in `contributorUserIds`, no longer in
// `memberPermissions` — cannot read. This is the exact predicate that makes the
// Art. 15 contributor probe refusable (BUT-1747): the trail can name a list the
// requester may no longer read, which is why only the Admin-SDK cascade can
// enumerate those.
test("shared lists: a REVOKED member (trail only, no memberPermissions key) CANNOT read", async () => {
  await seedList("read-departed");
  const ctx = env.authenticatedContext(DEPARTED);
  await assertFails(ctx.firestore().doc(`${COL}/read-departed`).get());
});

// SSL30: a non-member.
test("shared lists: a non-member CANNOT read the list", async () => {
  await seedList("read-stranger");
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(ctx.firestore().doc(`${COL}/read-stranger`).get());
});

// SSL31: unauthenticated.
test("shared lists: an unauthenticated caller CANNOT read the list", async () => {
  await seedList("read-anon");
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`${COL}/read-anon`).get());
});

// ====================================================================
// CREATE — the two conjuncts SSL1-SSL5 left unpinned (3 assertions)
// ====================================================================
//
// BUT-1706. SSL1 is the all-fields allow baseline, so each test below differs
// from it in exactly ONE way and its denial can only be that conjunct. All three
// are mirrored client-side in `ShoppingRepositoryRoutingModule` — an unmirrored
// conjunct means the audit log records a grant the server then refuses.

// SSL32: `request.auth.uid in request.resource.data.memberPermissions`. The
// `UnifiedShoppingList.collaborative` factory always seats the owner; the plain
// constructor does not, and it is on the public interface.
test("shared lists: the owner CANNOT create a list without seating themselves in memberPermissions", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/create-unseated-${RUN}`)
      .set(
        validListBody({
          memberPermissions: { [EDITOR]: "edit" },
          contributorUserIds: [OWNER],
        })
      )
  );
});

// SSL33: `hasRequiredFields([... 'items' ...])`. A conversion or a retry that
// omits the array is refused, not silently accepted as an empty list.
test("shared lists: the owner CANNOT create a list with no items field", async () => {
  const body = validListBody({ contributorUserIds: [OWNER] });
  delete body.items;
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`${COL}/create-no-items-${RUN}`).set(body)
  );
});

// SSL34: `hasRequiredFields([... 'createdAt' ...])`.
test("shared lists: the owner CANNOT create a list with no createdAt field", async () => {
  const body = validListBody({ contributorUserIds: [OWNER] });
  delete body.createdAt;
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`${COL}/create-no-created-at-${RUN}`).set(body)
  );
});

// ====================================================================
// DELETE — owner-only, previously unpinned (2 assertions)
// ====================================================================

// SSL35: the owner deletes their list.
test("shared lists: the owner CAN delete the list", async () => {
  await seedList("del-owner");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`${COL}/del-owner`).delete());
});

// SSL36: an edit member cannot. Deletion is destructive for the whole household
// and is not part of "can edit items"; pairs with SSL35, whose only delta is the
// actor.
test("shared lists: an edit member CANNOT delete the list", async () => {
  await seedList("del-editor");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(ctx.firestore().doc(`${COL}/del-editor`).delete());
});

// ====================================================================
// READ — the LIST/QUERY path (3 assertions)
// ====================================================================
//
// BUT-1746. SSL26-SSL31 all exercise a single-document `get()`, which cannot
// see the branch that actually broke: rules are not filters, so for a QUERY the
// engine evaluates `uid in resource.data.memberPermissions` against every
// candidate document and refuses the whole query if any one of them fails.
// That is why `.where('memberPermissions.$uid', isNotEqualTo: null)` — which
// builds NO condition (cloud_firestore query.dart:659) — did not over-share but
// made the shopping screen refuse to load.
//
// So the client's fixed query shape needs a rules-layer ALLOW, and the
// unfiltered shape needs a rules-layer DENY. `isNull: false` compiles to
// `where(field, '!=', null)` (query.dart:676-682), which is the JS spelling
// used below — pin the SDK-equivalent filter, not a hand-picked one.
//
// Neither direction is provable from the Dart side: `fake_cloud_firestore`
// evaluates no rules at all, so the unit tests in
// `shopping_repository_query_module_test.dart` prove the FILTER works and say
// nothing about whether the server accepts it.

// SSL37: the fixed query shape is accepted, and returns the member's list.
test("shared lists: an edit member CAN run the client's membership-filtered query", async () => {
  await seedList("query-mine");
  const ctx = env.authenticatedContext(EDITOR);
  const snap = await assertSucceeds(
    ctx
      .firestore()
      .collection(COL)
      .where(`memberPermissions.${EDITOR}`, "!=", null)
      .limit(200)
      .get()
  );
  // Premise: the query is not vacuously allowed by matching nothing.
  if ((snap as { empty: boolean }).empty) {
    throw new Error(
      "fixture did not stage a readable list — an empty result would let a " +
        "broken filter pass this test"
    );
  }
});

// SSL38: the UNFILTERED read of the same collection is refused outright, even
// for a member of one of the lists. This is the BUT-1746 symptom, and the only
// delta from SSL37 is the missing `where()`.
test("shared lists: an edit member CANNOT run an UNFILTERED collection query", async () => {
  await seedList("query-mine");
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`${COL}/query-foreign`)
      .set(
        validListBody({
          ownerId: STRANGER,
          memberPermissions: { [STRANGER]: "admin" },
        })
      );
  });
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(ctx.firestore().collection(COL).limit(200).get());
});

// SSL39: a member of NOTHING gets an allowed-but-empty result rather than a
// denial — the filtered query is safe for every actor, so a household with no
// shared lists sees an empty screen, not an error.
test("shared lists: a non-member CAN run the filtered query and gets nothing", async () => {
  await seedList("query-mine");
  // NOT `STRANGER`: SSL38 seeds a list STRANGER owns, and the emulator keeps it
  // across runs — this actor must be a member of nothing, ever.
  const ctx = env.authenticatedContext("list-nobody-uid");
  const snap = await assertSucceeds(
    ctx
      .firestore()
      .collection(COL)
      .where("memberPermissions.list-nobody-uid", "!=", null)
      .limit(200)
      .get()
  );
  if (!(snap as { empty: boolean }).empty) {
    throw new Error(
      "a non-member's filtered query returned documents — the filter is not " +
        "scoping to membership"
    );
  }
});

// ====================================================================
// SELF-REMOVAL — BUT-1718 / ADR-0004
// ====================================================================
//
// The `removesOnlySelfFromMembers()` arm has five conjuncts, so one shared
// mutant cannot grade it. Every conjunct below was probed by deleting it from
// `firestore.rules` alone and re-running this suite; the attributions in the
// comments are what those runs measured, not what the predicate looks like it
// should do.
//
// Every case gets its own document id — this suite shares one emulator and
// clears nothing between tests, so a reused id turns a create into an update
// and an assertion into a coincidence.

/** The write `leaveList` narrows to: one member key deleted, plus the stamp. */
function leavePayload(uid: string): Record<string, unknown> {
  return {
    [`memberPermissions.${uid}`]: deleteField(),
    updatedAt: new Date("2026-09-12T00:00:00.000Z"),
  };
}

// SSL44: the arm itself. EDITOR holds `edit`, so the member arm below could
// never carry this write — it denies any diff touching `memberPermissions`.
test("shared lists: an edit member CAN remove their own memberPermissions key", async () => {
  await seedList("leave-editor");
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx.firestore().doc(`${COL}/leave-editor`).update(leavePayload(EDITOR))
  );
});

// SSL45: the case the whole ticket exists for. A view-only member cannot write
// ANYTHING through the member arm (`in ['edit','admin']`), and is the person
// most likely to want out. If this denies, the feature is useless to exactly
// the population it was built for.
test("shared lists: a VIEW-ONLY member CAN remove their own memberPermissions key", async () => {
  await seedList("leave-viewer");
  const ctx = env.authenticatedContext(VIEWER);
  await assertSucceeds(
    ctx.firestore().doc(`${COL}/leave-viewer`).update(leavePayload(VIEWER))
  );
});

// SSL46: a non-owner `admin`. Distinct from SSL44 — `canManageShoppingList`
// grants this actor member management in the CLIENT while the rules grant it
// nothing, so its permission level must not be what decides a leave.
test("shared lists: a non-owner ADMIN member CAN remove their own memberPermissions key", async () => {
  await seedList("leave-admin-member", {
    memberPermissions: {
      [OWNER]: "admin",
      [EDITOR]: "edit",
      [VIEWER]: "view",
      [ADMIN_MEMBER]: "admin",
    },
  });
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/leave-admin-member`)
      .update(leavePayload(ADMIN_MEMBER))
  );
});

// SSL47: the control for SSL44, one variable apart — same actor, same write
// shape, somebody else's key. Proves the allow is about SELF, not about
// `memberPermissions` having become writable.
// OVER-DETERMINED, measured: two conjuncts refuse it independently — the caller
// is still in the map afterwards, AND the changed key is not theirs — so
// deleting either one alone leaves this green. It flips only when both go.
// SSL48 is the single-conjunct anchor for the map diff.
test("shared lists: an edit member CANNOT remove ANOTHER member's key", async () => {
  await seedList("leave-boot-other");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx.firestore().doc(`${COL}/leave-boot-other`).update(leavePayload(VIEWER))
  );
});

// SSL48: leaving while promoting somebody. This is the case the MAP diff buys
// over a keys-only comparison: the key set shrinks by exactly the caller, and
// `affectedKeys()` still reports VIEWER because their value changed.
// The single-conjunct anchor for `affectedKeys().hasOnly([request.auth.uid])`,
// measured: delete that conjunct and this case alone goes green.
test("shared lists: an edit member CANNOT change another member's level while leaving", async () => {
  await seedList("leave-and-promote");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/leave-and-promote`)
      .update({
        ...leavePayload(EDITOR),
        [`memberPermissions.${VIEWER}`]: "admin",
      })
  );
});

// SSL49: ADR-0004's second mandatory case. The array is append-only and capped,
// so `keepsContributorTrail()` ALLOWS a union — only the two-key allowlist
// refuses it. Run against a three-key version of the rule this must wrongly
// pass, which is what makes it the pin on the override ADR-0004 records.
// Conjunct: the document-level `hasOnly(['memberPermissions','updatedAt'])`.
test("shared lists: a leaving member CANNOT union a foreign uid into the trail", async () => {
  await seedList("leave-union-trail");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/leave-union-trail`)
      .update({
        ...leavePayload(EDITOR),
        contributorUserIds: arrayUnion("outsider-uid"),
      })
  );
});

// SSL50: the other direction on the same field. OVER-DETERMINED and kept
// anyway: the allowlist refuses it and so does `keepsContributorTrail()`, which
// binds every arm. Kept because those two predicates are edited independently
// and a leave must never be the write that strips the erasure handle.
test("shared lists: a leaving member CANNOT shrink the trail", async () => {
  await seedList("leave-shrink-trail");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/leave-shrink-trail`)
      .update({
        ...leavePayload(EDITOR),
        contributorUserIds: arrayRemove(DEPARTED),
      })
  );
});

// SSL51: ADR-0004's first mandatory case, `items` half. Under the deny-list
// draft this ALLOWS — a view-only member wiping the list on the way out — which
// is why the arm is an allowlist.
// Conjunct: the document-level `hasOnly(['memberPermissions','updatedAt'])`.
// The fixture is seeded WITH a row, because the base fixture's `items` is `[]`
// and writing `[]` over `[]` is no diff at all — the first version of this test
// passed an empty array and ALLOWED, proving nothing about the allowlist.
test("shared lists: a leaving member CANNOT touch items in the same write", async () => {
  await seedList("leave-wipe-items", {
    items: [{ id: "i20", name: "Kaffe", isBought: false }],
  });
  const ctx = env.authenticatedContext(VIEWER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/leave-wipe-items`)
      .update({ ...leavePayload(VIEWER), items: [] })
  );
});

// SSL52: ADR-0004's first mandatory case, `name` half. Same conjunct as SSL51
// and kept separately because `items` is the damaging field while `name` is the
// one a deny-list naming only the access-control keys would also let through.
test("shared lists: a leaving member CANNOT rename the list in the same write", async () => {
  await seedList("leave-rename");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/leave-rename`)
      .update({ ...leavePayload(EDITOR), name: "Kapad lista" })
  );
});

// SSL53: seizing ownership on the way out. OVER-DETERMINED: the new arm's
// allowlist and the member arm's deny-list each refuse it. SSL42 pins the same
// grab through the member arm.
test("shared lists: a leaving member CANNOT seize ownerId in the same write", async () => {
  await seedList("leave-seize-owner");
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/leave-seize-owner`)
      .update({ ...leavePayload(EDITOR), ownerId: EDITOR })
  );
});

// SSL54: a stranger removing a key they never held. Denied by the membership
// conjunct, not by the map diff — without it, `hasOnly([auth.uid])` says
// nothing about whether the caller was ever seated.
// Conjunct: `request.auth.uid in resource.data.memberPermissions`.
test("shared lists: a STRANGER CANNOT remove a memberPermissions key", async () => {
  await seedList("leave-stranger");
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx.firestore().doc(`${COL}/leave-stranger`).update(leavePayload(STRANGER))
  );
});

// SSL55 (BUT-1718, Malin 2026-09-12): the owner cannot write themselves out of
// the roster. Before `ownerStaysSeated()` this ALLOWED — the owner arm carried
// no field constraint at all — and only the client refused it, which is a
// product rule rather than a control. Every limb of this collection gates on
// `memberPermissions`, so an owner-less roster bricks the document.
// Denied by TWO conjuncts, measured: `ownerStaysSeated()` on the owner arm, and
// the self-removal arm's own `uid != ownerId` which keeps the owner out of it.
// Deleting either one alone flips this to allow, so it grades both.
test("shared lists: the OWNER CANNOT remove their own memberPermissions key", async () => {
  await seedList("leave-owner");
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`${COL}/leave-owner`).update(leavePayload(OWNER))
  );
});

// SSL57: deleting the WHOLE member map, not a key in it.
//
// It passes the document-level allowlist — `memberPermissions` is one of the
// two permitted keys — and is refused past it. OVER-DETERMINED, measured:
// defaulting the `in` conjunct with `.get('memberPermissions', {})` leaves this
// case denying, and it flips only when the map-diff conjunct goes as well.
// Deleting the whole map is an eviction of everyone, so the map diff refuses it
// on the merits.
//
// Kept because nothing else in this file sends a mass-eviction payload, and
// every limb of this collection gates on that map — an allow here would brick
// the document for the whole household.
test("shared lists: a leaving member CANNOT delete the whole memberPermissions map", async () => {
  await seedList("leave-nuke-map");
  const ctx = env.authenticatedContext(VIEWER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/leave-nuke-map`)
      .update({
        memberPermissions: deleteField(),
        updatedAt: new Date("2026-09-12T00:00:00.000Z"),
      })
  );
});

// SSL58: an owner who is NOT a key in their own member map cannot update at
// all, because `ownerStaysSeated()` asks about the POST-write document and an
// items-only write leaves them absent.
//
// The population is not hypothetical: `account-deletion-cascade.ts` deletes
// `memberPermissions.<owner>` while leaving `ownerId` raw when other members
// remain, so an erased owner's list has this shape. No live user is gated by it
// — that uid belongs to no account — and the create limb has required the owner
// seated since 2026-04, so no client produces one. Pinned so the verdict is a
// decision rather than a side effect.
test("shared lists: an UNSEATED owner cannot update (ownerStaysSeated reads the post-write doc)", async () => {
  await seedList("owner-unseated", {
    memberPermissions: { [EDITOR]: "edit", [VIEWER]: "view" },
  });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`${COL}/owner-unseated`)
      .update({ items: [{ id: "i30", name: "Salt" }] })
  );
});

// SSL59: the same unseated owner CAN write themselves back in, so the state
// above is recoverable rather than terminal. The control for SSL58 — without
// it, a blanket deny on this document shape would look identical.
test("shared lists: an unseated owner CAN seat themselves again", async () => {
  await seedList("owner-reseat", {
    memberPermissions: { [EDITOR]: "edit" },
  });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/owner-reseat`)
      .update({ [`memberPermissions.${OWNER}`]: "admin" })
  );
});

// SSL60: a list already past the 200-contributor cap cannot be LEFT.
//
// `keepsContributorTrail()` binds every arm including the new one, and its
// size bound reads the POST-write array, so a document seeded over the cap
// refuses a departure that does not touch the trail at all. SSL20 pins the same
// freeze for an items-only update; this is the scope the freeze gained when
// leaving became possible, and the person it traps is the one trying to get
// out.
test("shared lists: a member CANNOT leave a list already over the contributor cap", async () => {
  await seedList("leave-over-cap", {
    contributorUserIds: bulkContributors(CAP + 1, "over"),
  });
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx.firestore().doc(`${COL}/leave-over-cap`).update(leavePayload(EDITOR))
  );
});

// SSL56: the control for SSL55. A new conjunct on the owner arm can deny far
// more than it was aimed at, and a too-broad refusal hides behind a green deny
// test — this is the assertion that would redden. SSL43 (owner revokes a
// member) is the same guard from the other side and stays green.
test("shared lists: the owner CAN still remove ANOTHER member with the new conjunct", async () => {
  await seedList("leave-owner-control");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`${COL}/leave-owner-control`)
      .update(leavePayload(VIEWER))
  );
});

async function run(): Promise<void> {
  console.log(
    "unified_shared_shopping_lists rules tests\n"
  );
  console.log("=============================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  await teardown();
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
