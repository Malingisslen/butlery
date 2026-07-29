/**
 * BUT-1725: tests for the `contributorUserIds` backfill.
 *
 * The migration is what makes a DEPARTED member's shared shopping lists
 * reachable by account erasure — a user who left a list has neither
 * `memberPermissions.<uid>` nor `ownerId`, while every item they added still
 * carries their name. Two lines are security-relevant, and both are about NOT
 * writing a uid:
 *   - the `"deleted"` sentinel is excluded — re-adding it would resurrect a
 *     handle erasure had already removed;
 *   - `ownerId` is only stamped while the owner is still a MEMBER. The cascade
 *     keeps `ownerId` raw on purpose but deletes the member key, and
 *     `firestore.rules` makes `contributorUserIds` append-only, so stamping a
 *     retained owner would re-create an erased uid that no client write and no
 *     future cascade run could remove.
 *
 * Everything here runs against an in-memory Firestore double — no emulator, no
 * admin app. `reconstructContributors` is pure; `runBackfill` needs
 * collection/orderBy/limit/startAfter/get plus `runTransaction`.
 *
 * Run with: npx ts-node src/__tests__/backfill-shared-list-contributors.test.ts
 */

import * as admin from "firebase-admin";

import {
  assertValidCursor,
  reconstructContributors,
  runBackfill,
} from "../migrations/backfill-shared-list-contributors";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";

type ListDoc = Record<string, unknown>;

interface FakeDocRef {
  __id: string;
}

interface Recorded {
  id: string;
  data: Record<string, unknown>;
}

/**
 * Apply the RECORDED payload, never a re-derivation of what the migration was
 * supposed to write: a double that recomputes the intended effect cannot fail
 * when the code computes a different one. The sentinel is opaque, so it is
 * unwrapped via its own `elements` — and if that shape ever changes the double
 * THROWS rather than quietly answering with a value it invented.
 */
function applyUnion(current: unknown, sentinel: unknown): string[] {
  const elements = (sentinel as { elements?: unknown }).elements;
  if (!Array.isArray(elements)) {
    throw new Error(
      "fake cannot model this write: expected a FieldValue.arrayUnion sentinel " +
        "carrying an `elements` array. Update this double to match firebase-admin " +
        "— never apply a value the payload did not name."
    );
  }
  const existing = Array.isArray(current) ? (current as string[]) : [];
  return [...new Set([...existing, ...(elements as string[])])];
}

interface FakeOptions {
  /**
   * Fires with the doc id when the SUT reads inside its transaction, BEFORE the
   * snapshot is taken — the seam used to stage "the erasure cascade committed
   * between the page read and our write".
   */
  onTransactionRead?: (id: string) => void;
  /** Doc ids whose transaction throws, to exercise the failure accounting. */
  failIds?: Set<string>;
}

/**
 * Minimal Firestore double covering exactly the surface the backfill touches.
 *
 * It models ORDERING and the recorded write payload, NOT isolation: the
 * transaction body runs once and its update lands immediately, so this proves
 * the SUT re-READS before writing, not that Firestore would abort a conflicting
 * commit. Real concurrency belongs to the emulator lane.
 */
function makeFakeDb(store: Record<string, ListDoc>, options: FakeOptions = {}) {
  const writes: Recorded[] = [];
  let transactions = 0;
  let pagesRead = 0;
  let docsRead = 0;

  function makeQuery(startAfter: string | null, limit: number | null) {
    return {
      orderBy() {
        return this;
      },
      limit(n: number) {
        return makeQuery(startAfter, n);
      },
      startAfter(id: string) {
        return makeQuery(id, limit);
      },
      async get() {
        let ids = Object.keys(store).sort();
        if (startAfter) ids = ids.filter((id) => id > startAfter);
        if (limit !== null) ids = ids.slice(0, limit);
        pagesRead += 1;
        docsRead += ids.length;
        return {
          empty: ids.length === 0,
          size: ids.length,
          docs: ids.map((id) => ({
            id,
            ref: { __id: id } as FakeDocRef,
            data: () => store[id],
          })),
        };
      },
    };
  }

  return {
    db: {
      collection() {
        return makeQuery(null, null);
      },
      async runTransaction<T>(
        fn: (tx: {
          get: (ref: FakeDocRef) => Promise<{
            exists: boolean;
            data: () => ListDoc | undefined;
          }>;
          update: (ref: FakeDocRef, data: Record<string, unknown>) => void;
        }) => Promise<T>
      ): Promise<T> {
        transactions += 1;
        return fn({
          async get(ref: FakeDocRef) {
            options.onTransactionRead?.(ref.__id);
            if (options.failIds?.has(ref.__id)) {
              throw Object.assign(new Error("simulated contention"), {
                code: 10,
              });
            }
            const doc = store[ref.__id];
            return { exists: doc !== undefined, data: () => doc };
          },
          update(ref: FakeDocRef, data: Record<string, unknown>) {
            writes.push({ id: ref.__id, data });
            const [field] = Object.keys(data);
            store[ref.__id] = {
              ...store[ref.__id],
              [field]: applyUnion(store[ref.__id][field], data[field]),
            };
          },
        });
      },
    },
    writes,
    get transactions() {
      return transactions;
    },
    stats: () => ({ pagesRead, docsRead }),
  };
}

const item = (fields: Record<string, unknown>) => fields;

/** A list corpus of [n] docs, each needing exactly one uid stamped. */
function buildCorpus(n: number): Record<string, ListDoc> {
  const store: Record<string, ListDoc> = {};
  for (let i = 0; i < n; i++) {
    store[`l${String(i).padStart(6, "0")}`] = {
      ownerId: `o${i}`,
      memberPermissions: { [`o${i}`]: "owner" },
      items: [],
    };
  }
  return store;
}

const cases: UnitCase[] = [
  {
    name: "reconstructContributors collects owner, lastActivity and all four item uid fields",
    fn: () => {
      const uids = reconstructContributors({
        ownerId: "owner",
        memberPermissions: { owner: "owner" },
        lastActivityByUserId: "activer",
        items: [
          item({ addedByUserId: "adder" }),
          item({ purchasedByUserId: "buyer" }),
          item({ assignedToUserId: "assignee" }),
          item({ lastModifiedByUserId: "editor" }),
        ],
      });
      assertEqual(
        [...uids].sort().join(","),
        "activer,adder,assignee,buyer,editor,owner",
        "every uid still visible on the document must become reachable"
      );
    },
  },
  {
    name: "reconstructContributors de-duplicates a uid seen on several fields",
    fn: () => {
      const uids = reconstructContributors({
        ownerId: "u1",
        memberPermissions: { u1: "owner" },
        lastActivityByUserId: "u1",
        items: [
          item({ addedByUserId: "u1", purchasedByUserId: "u1" }),
          item({ addedByUserId: "u2" }),
        ],
      });
      assertEqual(uids.length, 2, "duplicates must collapse");
      assertEqual([...uids].sort().join(","), "u1,u2", "wrong uid set");
    },
  },
  {
    name: 'reconstructContributors EXCLUDES the "deleted" sentinel and empty values',
    fn: () => {
      const uids = reconstructContributors({
        ownerId: "deleted",
        memberPermissions: { deleted: "owner" },
        lastActivityByUserId: "",
        items: [
          item({ addedByUserId: "deleted", purchasedByUserId: null }),
          item({ addedByUserId: "survivor" }),
          "not-an-object",
        ],
      });
      assertEqual(
        uids.join(","),
        "survivor",
        'the cascade writes "deleted" IN PLACE OF a uid — re-adding it would ' +
          "resurrect a handle account erasure already removed"
      );
    },
  },
  {
    // The exact shape `deleteShoppingLists` leaves on a list an erased owner
    // shared with someone: `ownerId` RETAINED raw (rules read it for write
    // authorization, so nulling it would orphan the list for the others), member
    // key deleted, activity stamp nulled, items anonymized. The sentinel test
    // above cannot see this case — `ownerId` is never set to "deleted".
    name: "reconstructContributors excludes an ERASED owner whose member key the cascade deleted",
    fn: () => {
      const uids = reconstructContributors({
        ownerId: "erased-uid",
        ownerDisplayName: null,
        memberPermissions: { other: "owner" },
        lastActivityByUserId: null,
        lastActivityByDisplayName: null,
        items: [
          item({
            addedByUserId: "deleted",
            addedByDisplayName: null,
            purchasedByUserId: null,
            lastModifiedByUserId: "deleted",
          }),
        ],
      });
      assertEqual(
        uids.join(","),
        "",
        "firestore.rules makes contributorUserIds append-only, so a re-stamped " +
          "erased owner is removable by no client write and by no future cascade run"
      );
    },
  },
  {
    name: "reconstructContributors still stamps an owner who is STILL a member",
    fn: () => {
      const uids = reconstructContributors({
        ownerId: "live-owner",
        memberPermissions: { "live-owner": "owner", friend: "edit" },
        items: [],
      });
      assertEqual(
        uids.join(","),
        "live-owner",
        "gating on membership must not stop stamping a live owner — the create " +
          "rule pins them into memberPermissions"
      );
    },
  },
  {
    name: "reconstructContributors tolerates a document with no items array",
    fn: () => {
      const uids = reconstructContributors({
        ownerId: "owner",
        memberPermissions: { owner: "owner" },
      });
      assertEqual(uids.join(","), "owner", "owner alone must still be stamped");
    },
  },
  {
    name: "runBackfill stamps a list that has no trail yet",
    fn: async () => {
      const store: Record<string, ListDoc> = {
        l1: {
          ownerId: "owner",
          memberPermissions: { owner: "owner" },
          items: [item({ addedByUserId: "friend" })],
        },
      };
      const fake = makeFakeDb(store);
      const res = await runBackfill(fake.db as never, {
        dryRun: false,
        maxLists: 100,
      });

      assertEqual(res.migrated, 1, "the list needed a trail");
      assertEqual(res.skipped, 0, "nothing to skip on a first pass");
      assertEqual(res.failed, 0, "no failures expected");
      assertEqual(fake.writes.length, 1, "exactly one update");
      assertEqual(
        (store.l1.contributorUserIds as string[]).sort().join(","),
        "friend,owner",
        "both uids must land"
      );
    },
  },
  {
    // The whole migration is one field NAME plus one sentinel. `probeResidualData`
    // and `deleteShoppingLists` both query
    // `unified_shared_shopping_lists.contributorUserIds array-contains <uid>`;
    // a payload under any other key, or a plain array overwriting a live editor's
    // work, is a write nothing reads or a write that loses data — while the
    // backfill still reports `migrated: n, success: true`.
    name: "runBackfill writes arrayUnion(missing) under contributorUserIds, the field erasure queries",
    fn: async () => {
      const store: Record<string, ListDoc> = {
        l1: {
          ownerId: "owner",
          memberPermissions: { owner: "owner" },
          items: [item({ addedByUserId: "friend" })],
        },
      };
      const fake = makeFakeDb(store);
      await runBackfill(fake.db as never, { dryRun: false, maxLists: 100 });

      assertEqual(fake.writes.length, 1, "exactly one update");
      assertEqual(
        Object.keys(fake.writes[0].data).join(","),
        "contributorUserIds",
        "the update must name the field account erasure queries, and nothing else"
      );
      const sentinel = fake.writes[0].data
        .contributorUserIds as admin.firestore.FieldValue;
      assertEqual(
        sentinel.isEqual(
          admin.firestore.FieldValue.arrayUnion("owner", "friend")
        ),
        true,
        "must be arrayUnion of exactly the MISSING uids in reconstruction order — " +
          "a plain array would clobber a member ticking items right now"
      );
    },
  },
  {
    name: "runBackfill is idempotent — a second pass writes nothing",
    fn: async () => {
      const store: Record<string, ListDoc> = {
        l1: {
          ownerId: "owner",
          memberPermissions: { owner: "owner" },
          items: [item({ addedByUserId: "friend" })],
        },
        l2: {
          ownerId: "owner2",
          memberPermissions: { owner2: "owner" },
          items: [],
        },
      };
      const fake = makeFakeDb(store);
      const first = await runBackfill(fake.db as never, {
        dryRun: false,
        maxLists: 100,
      });
      assertEqual(first.migrated, 2, "both lists need a first pass");

      const second = await runBackfill(fake.db as never, {
        dryRun: false,
        maxLists: 100,
      });
      assertEqual(second.migrated, 0, "a re-run must not re-write");
      assertEqual(second.skipped, 2, "both docs already cover their trail");
      assertEqual(
        fake.writes.length,
        2,
        "the second pass must issue no further updates"
      );
    },
  },
  {
    // The reason the write is a transaction rather than a 450-op batch: the
    // erasure cascade can scrub this very list between the page read and the
    // write, and a union built from the stale page would re-add exactly the uids
    // the cascade had just removed — in a field rules make append-only.
    name: "runBackfill does NOT undo a cascade scrub that landed after the page read",
    fn: async () => {
      const store: Record<string, ListDoc> = {
        l1: {
          ownerId: "departing",
          memberPermissions: { departing: "owner", other: "edit" },
          lastActivityByUserId: "departing",
          items: [item({ addedByUserId: "departing" })],
        },
      };
      const fake = makeFakeDb(store, {
        // Stage the cascade's scrub landing first: member key gone, activity
        // stamp nulled, item anonymized, ownerId RETAINED raw as the cascade
        // deliberately leaves it.
        onTransactionRead: (id) => {
          store[id] = {
            ownerId: "departing",
            memberPermissions: { other: "edit" },
            lastActivityByUserId: null,
            items: [item({ addedByUserId: "deleted" })],
          };
        },
      });
      const res = await runBackfill(fake.db as never, {
        dryRun: false,
        maxLists: 100,
      });

      assertEqual(fake.transactions, 1, "the doc looked stampable on the page");
      assertEqual(
        fake.writes.length,
        0,
        "re-deriving inside the transaction must find nothing left to add"
      );
      assertEqual(res.migrated, 0, "nothing was migrated");
      assertEqual(res.skipped, 1, "a race is a skip, not a failure");
      assertEqual(
        store.l1.contributorUserIds as undefined,
        undefined,
        "the erased uid must not be resurrected on a doc the cascade just cleaned"
      );
    },
  },
  {
    name: "runBackfill counts a failing transaction and reports success: false",
    fn: async () => {
      const store: Record<string, ListDoc> = {
        l1: {
          ownerId: "o1",
          memberPermissions: { o1: "owner" },
          items: [],
        },
        l2: {
          ownerId: "o2",
          memberPermissions: { o2: "owner" },
          items: [],
        },
      };
      const fake = makeFakeDb(store, { failIds: new Set(["l1"]) });
      const res = await runBackfill(fake.db as never, {
        dryRun: false,
        maxLists: 100,
      });

      assertEqual(res.failed, 1, "the contended doc must be counted");
      assertEqual(res.success, false, "a partial pass is not a success");
      assertEqual(
        res.migrated,
        1,
        "one failure must not abort the remaining docs in the page"
      );
      assertEqual(
        (store.l2.contributorUserIds as string[]).join(","),
        "o2",
        "the healthy doc must still be stamped"
      );
    },
  },
  {
    name: "runBackfill with dryRun: true counts but writes nothing",
    fn: async () => {
      const store: Record<string, ListDoc> = {
        l1: {
          ownerId: "owner",
          memberPermissions: { owner: "owner" },
          items: [item({ addedByUserId: "friend" })],
        },
      };
      const fake = makeFakeDb(store);
      const res = await runBackfill(fake.db as never, {
        dryRun: true,
        maxLists: 100,
      });

      assertEqual(res.migrated, 1, "a dry run still reports what it WOULD do");
      assertEqual(fake.writes.length, 0, "a dry run must not write");
      assertEqual(fake.transactions, 0, "a dry run must not open a transaction");
      assertEqual(
        store.l1.contributorUserIds as undefined,
        undefined,
        "the document must be untouched"
      );
    },
  },
  {
    name: "runBackfill reports hasMore + nextCursor at the maxLists boundary",
    fn: async () => {
      // The page size is the module's BATCH_SIZE (450); a SHORT page ends the
      // scan before maxLists is ever consulted, so the boundary only exists on
      // a full page.
      const store = buildCorpus(450);
      const fake = makeFakeDb(store);
      const res = await runBackfill(fake.db as never, {
        dryRun: true,
        maxLists: 10,
      });

      assertEqual(res.hasMore, true, "the caller must know to invoke again");
      assertEqual(res.batchesProcessed, 1, "the ceiling stops it after one page");
      assertEqual(
        res.nextCursor,
        "l000449",
        "the cursor must be the last id of the page just processed"
      );
    },
  },
  {
    name: "runBackfill reports hasMore: false and nextCursor: null once exhausted",
    fn: async () => {
      const store: Record<string, ListDoc> = {
        l1: { ownerId: "owner", memberPermissions: { owner: "owner" }, items: [] },
      };
      const fake = makeFakeDb(store);
      const res = await runBackfill(fake.db as never, {
        dryRun: false,
        maxLists: 100,
      });
      assertEqual(res.hasMore, false, "one short page means the scan is done");
      assertEqual(res.nextCursor, null, "nothing left to resume from");
    },
  },
  {
    // The lifecycle gate at the top of the module ("remove this file once a run
    // returns hasMore: false") only opens if exhaustion is reported honestly on
    // the LAST allowed page. Inferring completion from `batchesProcessed >= MAX`
    // reports hasMore: true exactly when the corpus IS done.
    name: "runBackfill reports hasMore: false when the FINAL allowed page is short",
    fn: async () => {
      // 22 full pages of 450 + a 100-doc final page = the 23rd and last allowed
      // batch, short.
      const store = buildCorpus(22 * 450 + 100);
      const fake = makeFakeDb(store);
      const res = await runBackfill(fake.db as never, {
        dryRun: true,
        maxLists: 999999,
      });

      assertEqual(res.batchesProcessed, 23, "the cap was reached exactly");
      assertEqual(fake.stats().docsRead, 10000, "the whole corpus was scanned");
      assertEqual(
        res.hasMore,
        false,
        "a short final page means exhausted, however many batches it took"
      );
      assertEqual(res.nextCursor, null, "and therefore nothing to resume");
    },
  },
  {
    name: "runBackfill resumes from startAfter, leaving earlier docs untouched",
    fn: async () => {
      const store = buildCorpus(6);
      const fake = makeFakeDb(store);
      await runBackfill(fake.db as never, {
        dryRun: false,
        maxLists: 100,
        startAfter: "l000003",
      });

      assertEqual(
        fake.writes.map((w) => w.id).join(","),
        "l000004,l000005",
        "only documents after the cursor may be touched"
      );
      assertEqual(
        store["l000000"].contributorUserIds as undefined,
        undefined,
        "a document before the cursor must not be re-scanned"
      );
    },
  },
  {
    // Without a caller-supplied cursor this is the shape that stalls: every
    // invocation restarts at the first id, so a corpus larger than
    // BATCH_SIZE * MAX_BATCHES_PER_INVOCATION is never reached however many
    // times it is run.
    name: "successive startAfter invocations cover a corpus larger than one invocation's cap",
    fn: async () => {
      const store = buildCorpus(20000);
      let cursor: string | null | undefined = undefined;
      let invocations = 0;
      let scanned = 0;

      for (;;) {
        const fake = makeFakeDb(store);
        const res: Awaited<ReturnType<typeof runBackfill>> = await runBackfill(
          fake.db as never,
          {
            dryRun: true,
            maxLists: 999999,
            ...(cursor ? { startAfter: cursor } : {}),
          }
        );
        invocations += 1;
        scanned += fake.stats().docsRead;
        if (!res.hasMore) {
          assertEqual(res.nextCursor, null, "a finished run offers no cursor");
          break;
        }
        cursor = res.nextCursor;
        assertEqual(
          typeof cursor,
          "string",
          "an unfinished run MUST hand back a cursor or the corpus is stranded"
        );
        if (invocations > 10) throw new Error("cursor failed to advance");
      }

      assertEqual(invocations, 2, "20,000 docs take two invocations at 10,350/run");
      assertEqual(scanned, 20000, "every document must be reached exactly once");
    },
  },
  {
    name: "assertValidCursor rejects every malformed document id",
    fn: () => {
      const rejected = [
        "",
        "a/b",
        ".",
        "..",
        "__name__",
        "x".repeat(1501),
        // 1500 is a BYTE limit, not a length: 751 two-byte chars is 1502 bytes.
        "ä".repeat(751),
      ];
      for (const value of rejected) {
        let threw = false;
        try {
          assertValidCursor(value);
        } catch {
          threw = true;
        }
        assertEqual(
          threw,
          true,
          `a cursor is interpolated into a query bound — ${JSON.stringify(
            value.slice(0, 12)
          )} must be refused`
        );
      }
      assertEqual(
        assertValidCursor("l000004"),
        "l000004",
        "a well-formed doc id must pass through unchanged"
      );
    },
  },
];

void runTests("backfill-shared-list-contributors", cases);
