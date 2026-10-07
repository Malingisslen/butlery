/**
 * BUT-2169: a block hides what two people shared with each other, both
 * directions, and an unblock brings it back.
 *
 * What this file cannot prove: `_fake-firestore` runs each transaction once,
 * with no isolation, and answers queries without indexes. Concurrency and the
 * composite indexes the two queries need belong on the emulator lane.
 */

import {
  holdPair,
  releasePair,
  pairFromEvent,
  handleBlockEvent,
  holdSharesOnBlock,
  HOLD_TIMEOUT_SECONDS,
  MAX_ROWS_PER_DIRECTION,
} from "../social/hold-shares-on-block";
import { FakeFirestore, FakeDoc } from "./_fake-firestore";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";

const A = "user-a";
const B = "user-b";
const C = "user-c";

const live = async () => true;

function block(db: FakeFirestore, blocker: string, blocked: string): void {
  db.seed(`blocks/${blocker}_${blocked}`, { blockerId: blocker, blockedId: blocked });
}

function unblock(db: FakeFirestore, blocker: string, blocked: string): void {
  db.docs.delete(`blocks/${blocker}_${blocked}`);
}

function seedRecipeShare(
  db: FakeFirestore,
  id: string,
  owner: string,
  recipient: string,
  recipientGrants: string[] = ["direct"],
): void {
  db.seed(`shared_content/${id}`, {
    contentType: "recipe",
    sharedByUserId: owner,
    sharedToUserIds: [owner, recipient],
    originalRecipeId: `r-${id}`,
  });
  db.seed(`users/${owner}/recipes/r-${id}`, {
    socialData: {
      ownerId: owner,
      memberPermissions: { [owner]: "admin", [recipient]: "view" },
      grants: { [recipient]: recipientGrants },
    },
  });
}

function row(db: FakeFirestore, id: string): FakeDoc {
  const doc = db.read(`shared_content/${id}`);
  if (!doc) throw new Error(`row ${id} missing`);
  return doc;
}

function recipe(db: FakeFirestore, owner: string, id: string): FakeDoc {
  const doc = db.read(`users/${owner}/recipes/r-${id}`);
  if (!doc) throw new Error(`recipe ${id} missing`);
  return doc;
}

function perms(db: FakeFirestore, owner: string, id: string): string {
  const social = recipe(db, owner, id).socialData as FakeDoc;
  return Object.keys(social.memberPermissions as FakeDoc).sort().join(",");
}

const cases: UnitCase[] = [
  {
    name: "a block takes the blocked person off the blocker's recipe share and its recipe",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);

      block(db, A, B);
      const held = await holdPair(db.db, A, B);

      assertEqual(held, 1, "one row held");
      assertEqual((row(db, "s1").sharedToUserIds as string[]).join(","), A, "B left the inbox field");
      assertEqual((row(db, "s1").blockHeldUserIds as string[]).join(","), B, "B is held");
      assertEqual(perms(db, A, "s1"), A, "B lost read access to the recipe");
      const social = recipe(db, A, "s1").socialData as FakeDoc;
      assertEqual((social.grants as FakeDoc)[B], undefined, "B's grant went with it");
    },
  },
  {
    name: "the other direction: what the blocked person shared is taken off the blocker too",
    fn: async () => {
      const db = new FakeFirestore();
      db.seed("shared_content/m1", {
        contentType: "menu",
        sharedByUserId: B,
        sharedToUserIds: [B, A],
      });
      db.seed("shared_content/m1/members/user-a", { userId: A, addedBy: B });
      block(db, A, B);

      await holdPair(db.db, A, B);

      assertEqual((row(db, "m1").sharedToUserIds as string[]).join(","), B, "A left B's row");
      assertEqual(db.has("shared_content/m1/members/user-a"), false, "A's member row is gone");
      const entry = (row(db, "m1").blockHeld as FakeDoc)[A] as FakeDoc;
      assertEqual((entry.member as FakeDoc).addedBy, B, "the member row is kept for the unblock");
    },
  },
  {
    name: "a share with a third person is not touched",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, C);
      block(db, A, B);

      assertEqual(await holdPair(db.db, A, B), 0, "nothing held");
      assertEqual((row(db, "s1").sharedToUserIds as string[]).join(","), `${A},${C}`, "row unchanged");
      assertEqual(perms(db, A, "s1"), [A, C].sort().join(","), "recipe unchanged");
    },
  },
  {
    name: "holding twice changes nothing the second time",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      block(db, A, B);
      await holdPair(db.db, A, B);
      const first = JSON.stringify(row(db, "s1"));

      assertEqual(await holdPair(db.db, A, B), 0, "second pass holds nothing");
      assertEqual(JSON.stringify(row(db, "s1")), first, "row identical");
    },
  },
  {
    name: "an unblock puts back the inbox entry, the member row and the recipe permission",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      db.seed("shared_content/m1", { contentType: "menu", sharedByUserId: B, sharedToUserIds: [B, A] });
      db.seed("shared_content/m1/members/user-a", { userId: A, addedBy: B });
      block(db, A, B);
      await holdPair(db.db, A, B);
      unblock(db, A, B);

      const released = await releasePair(db.db, A, B, live);

      assertEqual(released, 2, "both rows released");
      assertEqual((row(db, "s1").sharedToUserIds as string[]).sort().join(","), [A, B].sort().join(","), "B back");
      assertEqual((row(db, "s1").blockHeldUserIds as string[]).length, 0, "nobody held");
      assertEqual((row(db, "s1").blockHeld as FakeDoc)[B], undefined, "held entry removed");
      assertEqual(perms(db, A, "s1"), [A, B].sort().join(","), "B can read the recipe again");
      const social = recipe(db, A, "s1").socialData as FakeDoc;
      assertEqual(((social.grants as FakeDoc)[B] as string[]).join(","), "direct", "grant restored");
      assertEqual(db.has("shared_content/m1/members/user-a"), true, "member row restored");
    },
  },
  {
    name: "an unblock while the other person's block still stands releases nothing",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      block(db, A, B);
      await holdPair(db.db, A, B);
      unblock(db, A, B);
      block(db, B, A);

      assertEqual(await releasePair(db.db, A, B, live), null, "declined");
      assertEqual((row(db, "s1").sharedToUserIds as string[]).join(","), A, "B still out");
    },
  },
  {
    name: "an unblock where one account is gone releases nothing",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      block(db, A, B);
      await holdPair(db.db, A, B);
      unblock(db, A, B);

      const released = await releasePair(db.db, A, B, async (uid) => uid !== B);

      assertEqual(released, null, "declined");
      assertEqual(perms(db, A, "s1"), A, "recipe permission not restored");
    },
  },
  {
    name: "a recipe handed to someone else during the block gets no permission back",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      block(db, A, B);
      await holdPair(db.db, A, B);
      unblock(db, A, B);
      const current = recipe(db, A, "s1");
      db.seed(`users/${A}/recipes/r-s1`, {
        ...current,
        socialData: { ...(current.socialData as FakeDoc), ownerId: C },
      });

      await releasePair(db.db, A, B, live);

      assertEqual(perms(db, A, "s1"), A, "the new owner's recipe is left alone");
      assertEqual((row(db, "s1").sharedToUserIds as string[]).sort().join(","), [A, B].sort().join(","), "the row itself comes back");
    },
  },
  {
    name: "the pass stops at the row cap",
    fn: async () => {
      const db = new FakeFirestore();
      for (let i = 0; i <= MAX_ROWS_PER_DIRECTION; i++) {
        db.seed(`shared_content/x${i}`, { contentType: "menu", sharedByUserId: A, sharedToUserIds: [A, B] });
      }
      block(db, A, B);
      assertEqual(await holdPair(db.db, A, B), MAX_ROWS_PER_DIRECTION, "capped");
    },
  },
  {
    name: "a hold that arrives after the block is gone holds nothing",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);

      assertEqual(await holdPair(db.db, A, B), 0, "no block, no hold");
      assertEqual(perms(db, A, "s1"), [A, B].sort().join(","), "recipe untouched");
    },
  },
  {
    name: "a re-block landing during a release keeps the row held",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      block(db, A, B);
      await holdPair(db.db, A, B);
      unblock(db, A, B);

      // The pair-level check has passed; the block is back before the row's
      // own transaction runs.
      const released = await releasePair(db.db, A, B, async () => {
        block(db, A, B);
        return true;
      });

      assertEqual(released, 0, "no row released");
      assertEqual((row(db, "s1").sharedToUserIds as string[]).join(","), A, "B still out");
      assertEqual(perms(db, A, "s1"), A, "recipe access not restored");
    },
  },
  {
    name: "access through a group stays: a block takes only the direct grant",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B, ["direct", "group:g1"]);
      block(db, A, B);

      await holdPair(db.db, A, B);

      assertEqual(perms(db, A, "s1"), [A, B].sort().join(","), "B keeps group access");
      const grants = (recipe(db, A, "s1").socialData as FakeDoc).grants as FakeDoc;
      assertEqual((grants[B] as string[]).join(","), "group:g1", "only direct went");

      unblock(db, A, B);
      await releasePair(db.db, A, B, live);
      const back = (recipe(db, A, "s1").socialData as FakeDoc).grants as FakeDoc;
      assertEqual((back[B] as string[]).join(","), "group:g1,direct", "direct comes back beside it");
    },
  },
  {
    name: "someone who reads the recipe only through a group keeps it, before and after",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B, ["group:g1"]);
      block(db, A, B);

      await holdPair(db.db, A, B);
      const entry = (row(db, "s1").blockHeld as FakeDoc)[B] as FakeDoc;
      assertEqual(entry.recipePermission, null, "nothing taken from the recipe");

      unblock(db, A, B);
      await releasePair(db.db, A, B, live);
      const grants = (recipe(db, A, "s1").socialData as FakeDoc).grants as FakeDoc;
      assertEqual((grants[B] as string[]).join(","), "group:g1", "no direct grant invented");
    },
  },
  {
    name: "a recipe entry with no grants record is not read as the share's own",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      const current = recipe(db, A, "s1");
      db.seed(`users/${A}/recipes/r-s1`, {
        ...current,
        socialData: { ...(current.socialData as FakeDoc), grants: {} },
      });
      block(db, A, B);

      await holdPair(db.db, A, B);

      assertEqual(perms(db, A, "s1"), [A, B].sort().join(","), "recipe untouched");
      assertEqual((row(db, "s1").sharedToUserIds as string[]).join(","), A, "the row is still held");
    },
  },
  {
    name: "a permission set during the block is not overwritten by the release",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      block(db, A, B);
      await holdPair(db.db, A, B);
      const current = recipe(db, A, "s1");
      const social = current.socialData as FakeDoc;
      db.seed(`users/${A}/recipes/r-s1`, {
        ...current,
        socialData: {
          ...social,
          memberPermissions: { ...(social.memberPermissions as FakeDoc), [B]: "edit" },
          grants: { [B]: ["group:g2"] },
        },
      });
      unblock(db, A, B);

      await releasePair(db.db, A, B, live);

      const after = recipe(db, A, "s1").socialData as FakeDoc;
      assertEqual((after.memberPermissions as FakeDoc)[B], "edit", "newer permission kept");
      assertEqual(((after.grants as FakeDoc)[B] as string[]).join(","), "group:g2,direct", "grants unioned");
    },
  },
  {
    name: "a recipient id the SDK cannot use as a field path is skipped, not retried",
    fn: async () => {
      const db = new FakeFirestore();
      db.seed("shared_content/x", { contentType: "menu", sharedByUserId: A, sharedToUserIds: [A, "x["] });
      const outcome = await handleBlockEvent(db.db, undefined, { blockerId: A, blockedId: "x[" }, live);
      assertEqual(outcome.kind, "skipped", "event skipped");
    },
  },
  {
    name: "the handler holds on a create and releases on a delete",
    fn: async () => {
      const db = new FakeFirestore();
      seedRecipeShare(db, "s1", A, B);
      const pair = { blockerId: A, blockedId: B };
      block(db, A, B);

      const held = await handleBlockEvent(db.db, undefined, pair, live);
      assertEqual(JSON.stringify(held), JSON.stringify({ kind: "held", count: 1 }), "create holds");

      unblock(db, A, B);
      const released = await handleBlockEvent(db.db, pair, undefined, live);
      assertEqual(JSON.stringify(released), JSON.stringify({ kind: "released", count: 1 }), "delete releases");
    },
  },
  {
    name: "the trigger declares its timeout",
    fn: async () => {
      const endpoint = (holdSharesOnBlock as { __endpoint?: { timeoutSeconds?: unknown } }).__endpoint;
      assertEqual(endpoint?.timeoutSeconds, HOLD_TIMEOUT_SECONDS, "timeoutSeconds");
      assertEqual(typeof endpoint?.timeoutSeconds, "number", "a number, not a sentinel");
    },
  },
  {
    name: "an event naming a dotted or self-referencing uid is skipped",
    fn: async () => {
      assertEqual(pairFromEvent(undefined, { blockerId: "a.b", blockedId: B }), null, "dot refused");
      assertEqual(pairFromEvent(undefined, { blockerId: A, blockedId: A }), null, "self refused");
      const pair = pairFromEvent({ blockerId: A, blockedId: B }, undefined);
      assertEqual(pair?.blockedId, B, "an unblock is read from before");
    },
  },
];

void runTests("BUT-2169 block hides shares", cases);
