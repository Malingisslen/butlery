/**
 * Firestore rules tests for /unified_shared_shopping_lists (BUT-1725).
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
import { arrayUnion, arrayRemove } from "firebase/firestore";

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
// UPDATE — actor gates unchanged by the diff (3 assertions across 3 tests)
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

async function run(): Promise<void> {
  console.log("unified_shared_shopping_lists rules tests (BUT-1725)\n");
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
