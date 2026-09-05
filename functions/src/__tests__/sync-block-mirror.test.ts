/**
 * BUT-1917: the block mirror's trigger core.
 *
 * The mirror is what lets `firestore.rules` answer "has anyone in this room
 * blocked the writer?" in ONE document access. Firestore caps a rule evaluation
 * at 10 accesses and DENIES past the cap, so a per-counterparty check would not
 * merely be slow — a nine-person group would stop accepting votes. That makes
 * the mirror a correctness dependency of the rule, not an optimisation, and
 * these cases pin the three properties the rule will lean on:
 *
 *   1. the list is INCOMING blocks only, and it is recomputed from source;
 *   2. an older invocation cannot overwrite a newer one (`sourceRev`);
 *   3. an unblock is reflected, not just a block.
 *
 * What this file cannot prove, stated so nothing here is read as more than it
 * is: `_fake-firestore` runs a transaction callback exactly once, with no
 * isolation, contention, abort or retry, and a transactional read does not see
 * that transaction's own pending writes. So the `sourceRev` cases below pin the
 * DECISION (compare, then write or skip) against a pre-seeded document; they do
 * not demonstrate that two real concurrent invocations resolve correctly. That
 * belongs on the emulator lane.
 */

import {
  MAX_MIRROR_ENTRIES,
  RECONCILE_REV_SKEW_MS,
  isUsableUidSegment,
  blockedIdFromEvent,
  rebuildMirrorFor,
  reconcileMirrors,
} from "../social/sync-block-mirror";
import { FakeFirestore } from "./_fake-firestore";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";

const VICTIM = "victim-uid";
const BLOCKER_A = "blocker-a";
const BLOCKER_B = "blocker-b";
const MIRROR = `users/${VICTIM}/block_mirror/current`;

function seedBlock(db: FakeFirestore, blockerId: string, blockedId: string): void {
  db.seed(`blocks/${blockerId}_${blockedId}`, { blockerId, blockedId });
}

/**
 * A live owner for the mirror under test.
 *
 * Required by every case that expects a WRITE: `rebuildMirrorFor` refuses to
 * write a mirror for a user document that does not exist, so that the account
 * cascade's own `blocks` deletions cannot re-create the erased user's mirror
 * after the sweep. A fixture without this is asserting the deleted-account
 * path, whether it means to or not.
 */
function seedOwner(db: FakeFirestore, uid: string = VICTIM): void {
  db.seed(`users/${uid}`, { displayName: "Kvar" });
}

function mirrorIds(db: FakeFirestore): string[] {
  const doc = db.read(MIRROR);
  return (doc?.blockedByUserIds as string[] | undefined) ?? [];
}

const cases: UnitCase[] = [
  {
    name: "the mirror lists everyone who blocked this user",
    fn: async () => {
      const db = new FakeFirestore();
      seedOwner(db);
      seedBlock(db, BLOCKER_A, VICTIM);
      seedBlock(db, BLOCKER_B, VICTIM);

      const wrote = await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(wrote, true, "the rebuild wrote");
      assertEqual(
        mirrorIds(db).join(","),
        [BLOCKER_A, BLOCKER_B].sort().join(","),
        "both blockers are in the mirror",
      );
    },
  },
  {
    name: "a block this user MADE does not reach their own mirror",
    fn: async () => {
      // The direction is the whole design. A symmetric list would silence the
      // BLOCKER in every group they share — a penalty for having used a safety
      // feature — so a mirror that included outgoing blocks would be wrong in a
      // way no count assertion would catch.
      const db = new FakeFirestore();
      seedOwner(db);
      seedBlock(db, VICTIM, BLOCKER_A);

      await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(mirrorIds(db).length, 0, "outgoing blocks are not mirrored");
    },
  },
  {
    name: "an unblock is reflected — the list is rebuilt, not appended to",
    fn: async () => {
      const db = new FakeFirestore();
      seedOwner(db);
      seedBlock(db, BLOCKER_A, VICTIM);
      seedBlock(db, BLOCKER_B, VICTIM);
      await rebuildMirrorFor(db.db, VICTIM, 1000);

      // The unblock: the row is gone by the time the trigger runs.
      db.docs.delete(`blocks/${BLOCKER_A}_${VICTIM}`);
      await rebuildMirrorFor(db.db, VICTIM, 2000);

      assertEqual(
        mirrorIds(db).join(","),
        BLOCKER_B,
        "the unblocked party is gone and the other remains",
      );
    },
  },
  {
    name: "an OLDER event does not overwrite a newer mirror",
    fn: async () => {
      const db = new FakeFirestore();
      seedOwner(db);
      seedBlock(db, BLOCKER_A, VICTIM);
      // A newer invocation already wrote an EMPTY mirror — the state an unblock
      // leaves. A stale block event arriving afterwards must not put the
      // blocker back, which is the failure this guard exists for.
      db.seed(MIRROR, { blockedByUserIds: [], sourceRev: 5000, truncated: false });

      const wrote = await rebuildMirrorFor(db.db, VICTIM, 4000);

      assertEqual(wrote, false, "the stale event skipped its write");
      assertEqual(mirrorIds(db).length, 0, "the newer state survived");
    },
  },
  {
    name: "an event at the SAME revision still writes",
    fn: async () => {
      // Strictly-greater, not >=. Two events can share a millisecond, and
      // skipping an equal one drops a real change rather than a stale one.
      const db = new FakeFirestore();
      seedOwner(db);
      seedBlock(db, BLOCKER_A, VICTIM);
      db.seed(MIRROR, { blockedByUserIds: [], sourceRev: 4000, truncated: false });

      const wrote = await rebuildMirrorFor(db.db, VICTIM, 4000);

      assertEqual(wrote, true, "the same-millisecond event wrote");
      assertEqual(mirrorIds(db).join(","), BLOCKER_A, "the change landed");
    },
  },
  {
    name: "a user nobody blocked gets an empty mirror, not a missing one",
    fn: async () => {
      // Absence and emptiness are different states to the rule, which fails
      // OPEN on a missing mirror because a missing one cannot be told from
      // "nobody has ever blocked you".
      //
      // This is NOT the common case in production: nothing triggers a rebuild
      // for a user nobody ever blocked, so such a user has no mirror at all.
      // An empty document arises after an unblock or a reconciliation pass. The
      // rule must therefore handle a MISSING mirror regardless — this case pins
      // only that an empty rebuild writes an empty document rather than
      // deleting one.
      const db = new FakeFirestore();
      seedOwner(db);

      await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(db.read(MIRROR) !== undefined, true, "the mirror exists");
      assertEqual(mirrorIds(db).length, 0, "and it is empty");
    },
  },
  {
    name: "past the cap the mirror is truncated and says so",
    fn: async () => {
      const db = new FakeFirestore();
      seedOwner(db);
      for (let i = 0; i <= MAX_MIRROR_ENTRIES; i++) {
        seedBlock(db, `peer-${String(i).padStart(5, "0")}`, VICTIM);
      }

      await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(
        mirrorIds(db).length,
        MAX_MIRROR_ENTRIES,
        "the mirror holds exactly the cap",
      );
      assertEqual(
        db.read(MIRROR)?.truncated,
        true,
        "and the document admits it was truncated",
      );
    },
  },
  {
    name: "a full mirror at exactly the cap is NOT called truncated",
    fn: async () => {
      // The flip point, both sides. Reading one past the cap is what tells a
      // full page from a clipped one; without this case a `>=` would pass.
      const db = new FakeFirestore();
      seedOwner(db);
      for (let i = 0; i < MAX_MIRROR_ENTRIES; i++) {
        seedBlock(db, `peer-${String(i).padStart(5, "0")}`, VICTIM);
      }

      await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(mirrorIds(db).length, MAX_MIRROR_ENTRIES, "all of them kept");
      assertEqual(
        db.read(MIRROR)?.truncated,
        false,
        "and it does not claim truncation",
      );
    },
  },
  {
    name: "a block row missing its blockerId is dropped, not stored as null",
    fn: async () => {
      // `firestore.rules` pins `blockerId` on create, so this shape cannot come
      // from the app — but the Admin SDK bypasses rules, and a null inside the
      // array would be compared against participant uids by the rule.
      const db = new FakeFirestore();
      seedOwner(db);
      seedBlock(db, BLOCKER_A, VICTIM);
      db.seed(`blocks/malformed_${VICTIM}`, { blockedId: VICTIM });

      await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(mirrorIds(db).join(","), BLOCKER_A, "only the valid row");
    },
  },
  {
    name: "the affected user is read from the fields, on both create and delete",
    fn: () => {
      // The document id is `{blockerId}_{blockedId}`; splitting it guesses
      // where the boundary is, and a uid containing an underscore would send
      // the rebuild to the wrong user's mirror. The field is what the create
      // rule pins, so the field is what this reads.
      assertEqual(
        blockedIdFromEvent(undefined, { blockerId: BLOCKER_A, blockedId: VICTIM }),
        VICTIM,
        "a block reads `after`",
      );
      assertEqual(
        blockedIdFromEvent({ blockerId: BLOCKER_A, blockedId: VICTIM }, undefined),
        VICTIM,
        "an unblock reads `before`",
      );
      assertEqual(
        blockedIdFromEvent(undefined, undefined),
        null,
        "neither side present yields null rather than a bad path",
      );
      assertEqual(
        blockedIdFromEvent(undefined, { blockerId: BLOCKER_A }),
        null,
        "a row without the field yields null",
      );
    },
  },
  {
    name: "reconciliation repairs a mirror the trigger never wrote, and counts it",
    fn: async () => {
      // The outage case: the block exists, the trigger never ran, so the
      // mirror is missing entirely and the blocker is unenforced.
      const db = new FakeFirestore();
      seedOwner(db);
      seedBlock(db, BLOCKER_A, VICTIM);

      const result = await reconcileMirrors(db.db, [VICTIM], 9000);

      assertEqual(result.checked, 1, "one mirror checked");
      assertEqual(result.repaired, 1, "and it was counted as repaired");
      assertEqual(mirrorIds(db).join(","), BLOCKER_A, "the mirror is correct now");
    },
  },
  {
    name: "reconciliation reports ZERO repairs when nothing drifted",
    fn: async () => {
      // Without this, a reconciliation that counted every pass as a repair
      // would look identical to one that found real drift — and the count is
      // the only thing that would tell anyone the trigger had been down.
      const db = new FakeFirestore();
      seedOwner(db);
      seedBlock(db, BLOCKER_A, VICTIM);
      await rebuildMirrorFor(db.db, VICTIM, 1000);

      const result = await reconcileMirrors(db.db, [VICTIM], 9000);

      assertEqual(result.checked, 1, "still checked");
      assertEqual(result.repaired, 0, "but nothing was wrong");
    },
  },
  {
    name: "reconciliation clears a mirror whose blocks were all removed",
    fn: async () => {
      // The case a blocks-only sweep cannot reach: no `blocks` row names this
      // user any more, so only the mirror's own existence puts them on the
      // list. Left unvisited, the mirror keeps blocking someone who unblocked.
      const db = new FakeFirestore();
      seedOwner(db);
      db.seed(MIRROR, {
        blockedByUserIds: [BLOCKER_A],
        sourceRev: 1000,
        truncated: false,
      });

      const result = await reconcileMirrors(db.db, [VICTIM], 9000);

      assertEqual(result.repaired, 1, "counted as a repair");
      assertEqual(mirrorIds(db).length, 0, "and the stale entry is gone");
    },
  },
  {
    name: "a STALE reconciliation does not overwrite a newer trigger write",
    fn: async () => {
      // The panel's condition: the `sourceRev` guard must hold between the
      // reconciliation and the trigger, not only between two triggers. A pass
      // that read `blocks` before a block landed must not write its older
      // picture over the trigger's newer one.
      const db = new FakeFirestore();
      seedOwner(db);
      db.seed(MIRROR, {
        blockedByUserIds: [BLOCKER_A],
        sourceRev: 9000,
        truncated: false,
      });

      const result = await reconcileMirrors(db.db, [VICTIM], 4000);

      assertEqual(result.repaired, 0, "the stale pass claimed no repair");
      assertEqual(
        mirrorIds(db).join(","),
        BLOCKER_A,
        "and the trigger's newer write survived",
      );
    },
  },
  {
    name: "a blockedId that is not a legal path segment is refused, not retried",
    fn: () => {
      // `firestore.rules` pins `blockerId` and the composite id, and says
      // NOTHING about the shape of `blockedId`. So the field is free-form
      // client input that becomes a path SEGMENT — and a segment the SDK
      // rejects makes `mirrorRef` throw INVALID_ARGUMENT. Under `retry: true`
      // that is a permanent loop, planted by one client write.
      for (const bad of [".", "..", "a/b", "__proto__", "x".repeat(1501)]) {
        assertEqual(
          blockedIdFromEvent(undefined, { blockedId: bad }),
          null,
          `refused: ${bad.length > 20 ? `${bad.length} bytes` : bad}`,
        );
      }
      // …and an ordinary uid still passes, so the guard is not simply refusing
      // everything.
      assertEqual(
        blockedIdFromEvent(undefined, { blockedId: VICTIM }),
        VICTIM,
        "a normal uid is unaffected",
      );
    },
  },
  {
    name: "a mirror is not written for a user who no longer exists",
    fn: async () => {
      // The account cascade deletes `blocks` rows in tier 1, and an Admin-SDK
      // delete fires this trigger exactly like a client delete. Without the
      // owner check, a rebuild landing after the mirror sweep re-creates a
      // document whose PATH carries the erased uid — after the residual probe
      // has already called the erasure clean.
      const db = new FakeFirestore();
      seedBlock(db, BLOCKER_A, VICTIM);
      // No `users/victim-uid` document: the account is gone.

      const wrote = await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(wrote, false, "nothing was written");
      assertEqual(db.read(MIRROR), undefined, "and no mirror was created");
    },
  },
  {
    name: "an existing mirror is DELETED when its owner is gone",
    fn: async () => {
      // Not merely skipped: the sweep may have run before this trigger, in
      // which case skipping would leave whatever the trigger had already
      // written. Deleting makes the late trigger finish the sweep's job
      // instead of undoing it.
      const db = new FakeFirestore();
      db.seed(MIRROR, { blockedByUserIds: [BLOCKER_A], sourceRev: 1 });

      const wrote = await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(wrote, false, "reported as no write");
      assertEqual(db.read(MIRROR), undefined, "the orphaned mirror is gone");
    },
  },
  {
    name: "a live owner still gets their mirror written",
    fn: async () => {
      // The control for the two cases above: without it, a mutant that always
      // treated the owner as missing would pass both of them.
      const db = new FakeFirestore();
      db.seed(`users/${VICTIM}`, { displayName: "Kvar" });
      seedBlock(db, BLOCKER_A, VICTIM);

      const wrote = await rebuildMirrorFor(db.db, VICTIM, 1000);

      assertEqual(wrote, true, "written");
      assertEqual(mirrorIds(db).join(","), BLOCKER_A, "with the right contents");
    },
  },
  {
    name: "the reconciliation stamps itself BEHIND the trigger's clock",
    fn: () => {
      // The trigger stamps `event.time`, a server commit time; this pass stamps
      // its own instance clock. An instance running ahead would write a future
      // revision and every genuinely newer trigger write would then be skipped
      // as stale — a frozen mirror on a safety control. A repair must never
      // outrank a real event.
      assertEqual(
        RECONCILE_REV_SKEW_MS > 0,
        true,
        "the skew is a hold-back, not zero",
      );
    },
  },
  {
    name: "the segment guard is shared, not per-call-site",
    fn: () => {
      // The trigger's poison pill had a SIBLING: `collectUidsToReconcile` read
      // the same free-form `blockedId` with none of the same protection, so one
      // client write of `blocks/{myUid}_.` would abort the weekly pass before
      // it reached anyone else — every week, indefinitely. Both call sites now
      // go through this one predicate, which is why it is exported.
      for (const bad of [".", "..", "a/b", "__proto__", "x".repeat(1501), "", 7]) {
        assertEqual(isUsableUidSegment(bad), false, `refused: ${String(bad).slice(0, 12)}`);
      }
      assertEqual(isUsableUidSegment(VICTIM), true, "an ordinary uid passes");
    },
  },
  {
    name: "one failing user does not abandon the rest of the pass",
    fn: async () => {
      // Per-uid isolation. Without it, one planted row or one transient
      // contention abandons every REMAINING user — and this pass is the only
      // net under a control whose failure shows on no screen.
      //
      // Staged by making the store itself throw for one uid: the fake does not
      // validate path segments, so a bad segment cannot raise the error the
      // production SDK would. What is proven here is the isolation, not the
      // segment rejection — that is the case above.
      const fake = new FakeFirestore();
      seedOwner(fake);
      seedBlock(fake, BLOCKER_A, VICTIM);
      const POISON = "poison-uid";

      const db = new Proxy(fake.db as object, {
        get(target, prop, receiver) {
          if (prop !== "collection") return Reflect.get(target, prop, receiver);
          return (name: string) => {
            const col = (fake.db as never as {
              collection: (n: string) => { doc: (id: string) => unknown };
            }).collection(name);
            return new Proxy(col, {
              get(t, p, r) {
                if (p !== "doc") return Reflect.get(t, p, r);
                return (id: string) => {
                  if (id === POISON) throw new Error("simulated store failure");
                  return (t as { doc: (i: string) => unknown }).doc(id);
                };
              },
            });
          };
        },
      }) as never;

      const result = await reconcileMirrors(db, [POISON, VICTIM], 9000);

      assertEqual(result.failed, 1, "the failing uid is counted as failed");
      assertEqual(result.repaired, 1, "and the healthy uid was still reconciled");
      assertEqual(result.checked, 2, "both attempts counted");
      assertEqual(mirrorIds(fake).join(","), BLOCKER_A, "its mirror is correct");
    },
  },
];

void runTests("BUT-1917 block mirror", cases);
