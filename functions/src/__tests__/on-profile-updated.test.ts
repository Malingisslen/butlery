/**
 * BUT-1510 — `propagateProfileUpdate` cursor-pagination tests.
 *
 * onProfileUpdated fans a displayName/avatar change out to ~10 denormalized
 * collections. Before this change each fan-out loaded its whole result set with
 * one unbounded `.get()`, so a prolific user (thousands of messages/comments)
 * could OOM the function or blow the 540s timeout. The genuinely-unbounded
 * collections now page with a per-collection documentId cursor
 * (`batchUpdateQueryPaginated`). The behavior worth pinning:
 *
 *   1. A no-op change (neither name nor avatar differs) reads and writes
 *      nothing.
 *   2. A fan-out larger than one write batch (BATCH_LIMIT) is paged: no single
 *      page exceeds BATCH_LIMIT, and EVERY matching doc is updated exactly once
 *      (cursor neither skips nor revisits) while non-matching docs are left
 *      untouched.
 *   3. The paged writers never touch the field their query filters on
 *      (so the cursor is stable) — only the denorm name/avatar fields land.
 *   4. Avatar-only changes update the avatar denorm and skip the name-only
 *      collections (realtime/shopping/friends/group_invitations).
 *   5. The dual-field collections (owner + last-editor) still set BOTH fields
 *      on an overlap doc after the merge→two-pass rewrite.
 *   6. The `members` collection group is paged across subcollections; the
 *      conversations map key stays keyed by the acting user.
 *   7. BUT-1724 — personal shopping lists are updated in the acting user's OWN
 *      `users/{uid}/unified_shopping_lists` subcollection; the non-existent
 *      top-level collection of that name is never queried, and a last-activity
 *      stamp naming another member is left alone.
 *
 * Run: npx ts-node src/__tests__/on-profile-updated.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-on-profile-updated" });
}

import { BATCH_LIMIT } from "../shared/batch-update";
import { Collections } from "../shared/collections";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { propagateProfileUpdate } = require("../social/on-profile-updated");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runTests, assertEqual } = require("./_unit-runner");

interface FakeDoc {
  id: string;
  data: Record<string, unknown>;
}

interface Predicate {
  field: string;
  op: string;
  value: unknown;
}

function matches(doc: FakeDoc, p: Predicate | null): boolean {
  if (!p) return true;
  const actual = getPath(doc.data, p.field);
  if (p.op === "==") return actual === p.value;
  if (p.op === "array-contains") {
    return Array.isArray(actual) && actual.includes(p.value);
  }
  throw new Error(`unsupported op: ${p.op}`);
}

function getPath(obj: Record<string, unknown>, path: string): unknown {
  return path.split(".").reduce<unknown>((acc, key) => {
    if (acc && typeof acc === "object") {
      return (acc as Record<string, unknown>)[key];
    }
    return undefined;
  }, obj);
}

function setPath(
  obj: Record<string, unknown>,
  path: string,
  value: unknown
): void {
  const keys = path.split(".");
  let cursor = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    const key = keys[i];
    if (typeof cursor[key] !== "object" || cursor[key] === null) {
      cursor[key] = {};
    }
    cursor = cursor[key] as Record<string, unknown>;
  }
  cursor[keys[keys.length - 1]] = value;
}

interface RecordedPage {
  collectionKey: string;
  size: number;
}

/**
 * In-memory Firestore double covering only the surface onProfileUpdated uses:
 * `collection().where().orderBy().limit().startAfter().get()`,
 * `collectionGroup("members")`, subcollection reads for friends, and
 * `batch().update()/commit()`. `store` is keyed by collection path so a
 * collection group can scan every `.../members` key.
 */
function makeFakeDb(seed: Record<string, FakeDoc[]>) {
  const store: Record<string, FakeDoc[]> = {};
  for (const [k, docs] of Object.entries(seed)) {
    store[k] = docs.map((d) => ({ id: d.id, data: structuredClone(d.data) }));
  }

  const pages: RecordedPage[] = [];
  const writes: Array<{ collectionKey: string; id: string; data: Record<string, unknown> }> = [];

  function docSnap(collectionKey: string, doc: FakeDoc) {
    return {
      id: doc.id,
      _sortKey: `${collectionKey}|${doc.id}`,
      ref: { _ck: collectionKey, _id: doc.id },
      data: () => doc.data,
    };
  }

  interface QueryState {
    predicate: Predicate | null;
    ordered: boolean;
    limitN: number;
    afterKey: string | null;
  }

  /**
   * IMMUTABLE, like a real Firestore `Query`: every builder call returns a NEW
   * query rather than mutating shared state. That matters since BUT-1724 made
   * `paginatedDualUpdate` take a `CollectionReference` and call `.where()` on
   * the SAME reference twice (once per denorm field). A mutable double would
   * let the second leg's predicate leak into the first leg's later pages, so a
   * dual-field fixture bigger than one page would silently assert the wrong
   * thing — today's fixtures are single-page, which is exactly why the trap
   * would go unnoticed.
   */
  function makeQuery(
    collectionKeys: string[],
    state: QueryState = {
      predicate: null,
      ordered: false,
      limitN: Number.POSITIVE_INFINITY,
      afterKey: null,
    }
  ) {
    const { predicate, ordered, limitN, afterKey } = state;

    return {
      where(field: string, op: string, value: unknown) {
        return makeQuery(collectionKeys, {
          ...state,
          predicate: { field, op, value },
        });
      },
      orderBy() {
        return makeQuery(collectionKeys, { ...state, ordered: true });
      },
      limit(n: number) {
        return makeQuery(collectionKeys, { ...state, limitN: n });
      },
      startAfter(snap: { _sortKey: string }) {
        return makeQuery(collectionKeys, { ...state, afterKey: snap._sortKey });
      },
      async get() {
        let rows: ReturnType<typeof docSnap>[] = [];
        for (const ck of collectionKeys) {
          for (const doc of store[ck] || []) {
            if (matches(doc, predicate)) rows.push(docSnap(ck, doc));
          }
        }
        if (ordered) {
          rows.sort((a, b) =>
            a._sortKey < b._sortKey ? -1 : a._sortKey > b._sortKey ? 1 : 0
          );
        }
        if (afterKey !== null) {
          rows = rows.filter((r) => r._sortKey > afterKey!);
        }
        const sliced =
          limitN === Number.POSITIVE_INFINITY ? rows : rows.slice(0, limitN);
        // Record only the reads that carried a real limit (the paged path);
        // the unbounded friends/group readers don't set one.
        if (limitN !== Number.POSITIVE_INFINITY) {
          pages.push({ collectionKey: collectionKeys.join(","), size: sliced.length });
        }
        return {
          empty: sliced.length === 0,
          size: sliced.length,
          docs: sliced,
        };
      },
    };
  }

  function collectionRef(name: string) {
    const q = makeQuery([name]);
    return Object.assign(q, {
      doc(id: string) {
        return {
          collection(sub: string) {
            const subKey = `${name}/${id}/${sub}`;
            const subQ = makeQuery([subKey]);
            return Object.assign(subQ, {
              doc(subId: string) {
                return { _ck: subKey, _id: subId };
              },
            });
          },
        };
      },
    });
  }

  const db = {
    collection: (name: string) => collectionRef(name),
    collectionGroup: (name: string) => {
      const keys = Object.keys(store).filter(
        (k) => k === name || k.endsWith(`/${name}`)
      );
      return makeQuery(keys);
    },
    batch: () => {
      const ops: Array<{ ref: { _ck: string; _id: string }; data: Record<string, unknown> }> = [];
      return {
        update(ref: { _ck: string; _id: string }, data: Record<string, unknown>) {
          ops.push({ ref, data });
        },
        async commit() {
          for (const { ref, data } of ops) {
            const arr = store[ref._ck] || (store[ref._ck] = []);
            let doc = arr.find((d) => d.id === ref._id);
            if (!doc) {
              doc = { id: ref._id, data: {} };
              arr.push(doc);
            }
            for (const [key, value] of Object.entries(data)) {
              setPath(doc.data, key, value);
            }
            writes.push({ collectionKey: ref._ck, id: ref._id, data });
          }
          ops.length = 0;
        },
      };
    },
    /**
     * BUT-1770: a PASSTHROUGH, exactly like `FakeFirebaseFirestore` on the Dart
     * side — the handler runs once, staged writes apply on return, and there is
     * no isolation, abort or retry. It models the READ/REWRITE shape of the
     * embedded-items leg, which is what these cases assert; it proves nothing
     * about concurrency, and no test below claims otherwise.
     */
    runTransaction: async <T>(
      handler: (tx: {
        get: (ref: { _ck: string; _id: string }) => Promise<{
          exists: boolean;
          data: () => Record<string, unknown> | undefined;
        }>;
        update: (ref: { _ck: string; _id: string }, data: Record<string, unknown>) => void;
      }) => Promise<T>
    ): Promise<T> => {
      const staged: Array<{ ref: { _ck: string; _id: string }; data: Record<string, unknown> }> = [];
      const result = await handler({
        async get(ref) {
          const doc = (store[ref._ck] || []).find((d) => d.id === ref._id);
          return { exists: !!doc, data: () => doc?.data };
        },
        update(ref, data) {
          staged.push({ ref, data });
        },
      });
      for (const { ref, data } of staged) {
        const arr = store[ref._ck] || (store[ref._ck] = []);
        const doc = arr.find((d) => d.id === ref._id);
        if (!doc) continue;
        for (const [key, value] of Object.entries(data)) {
          setPath(doc.data, key, value);
        }
        writes.push({ collectionKey: ref._ck, id: ref._id, data });
      }
      return result;
    },
  } as unknown as admin.firestore.Firestore;

  return { db, store, pages, writes };
}

const UID = "user-1";
const OTHER = "other-9";

void (async () => {
  await runTests("propagateProfileUpdate — cursor pagination", [
    {
      name: "no-op change reads and writes nothing",
      fn: async () => {
        const fake = makeFakeDb({
          [Collections.messages]: [
            { id: "m1", data: { senderId: UID, senderDisplayName: "Old" } },
          ],
        });
        const total = await propagateProfileUpdate(
          fake.db,
          UID,
          "Same",
          "Same",
          "av",
          "av"
        );
        assertEqual(total, 0, "no docs updated");
        assertEqual(fake.writes.length, 0, "no writes");
        assertEqual(fake.pages.length, 0, "no paged reads");
      },
    },
    {
      name: "messages fan-out larger than one batch is paged, every match updated once",
      fn: async () => {
        const N = BATCH_LIMIT * 2 + 137; // spans 3 pages
        const msgs: FakeDoc[] = [];
        for (let i = 0; i < N; i++) {
          msgs.push({
            id: `m${String(i).padStart(5, "0")}`,
            data: { senderId: UID, senderDisplayName: "Old" },
          });
        }
        // Interleave some docs from another sender that must stay untouched.
        for (let i = 0; i < 5; i++) {
          msgs.push({
            id: `z${i}`,
            data: { senderId: OTHER, senderDisplayName: "Keep" },
          });
        }

        const fake = makeFakeDb({ [Collections.messages]: msgs });
        await propagateProfileUpdate(fake.db, UID, "Old", "New", "av", "av");

        const messagePages = fake.pages.filter((p) =>
          p.collectionKey.includes(Collections.messages)
        );
        const maxPage = Math.max(...messagePages.map((p) => p.size));
        assertEqual(
          maxPage <= BATCH_LIMIT,
          true,
          `no page exceeds BATCH_LIMIT (max=${maxPage})`
        );
        assertEqual(
          messagePages.length >= 3,
          true,
          `paged across >=3 reads (got ${messagePages.length})`
        );

        const stored = fake.store[Collections.messages];
        const updatedCount = stored.filter(
          (d) => d.data.senderId === UID && d.data.senderDisplayName === "New"
        ).length;
        assertEqual(updatedCount, N, "every UID message updated exactly once");

        const untouched = stored.filter(
          (d) => d.data.senderId === OTHER && d.data.senderDisplayName === "Keep"
        ).length;
        assertEqual(untouched, 5, "other sender's docs untouched");

        // senderId (the filter field) must never be rewritten.
        const filterFieldWrite = fake.writes.some((w) => "senderId" in w.data);
        assertEqual(filterFieldWrite, false, "filter field never written");
      },
    },
    {
      name: "avatar-only change skips the name-only collections",
      fn: async () => {
        const fake = makeFakeDb({
          [Collections.messages]: [
            { id: "m1", data: { senderId: UID, senderDisplayName: "Anna" } },
          ],
          [Collections.realtimeRecipes]: [
            { id: "r1", data: { ownerId: UID, ownerDisplayName: "Anna" } },
          ],
          [Collections.groupInvitations]: [
            {
              id: "g1",
              data: { fromUserId: UID, status: "pending", fromUserName: "Anna" },
            },
          ],
          [`${Collections.users}/${UID}/friends`]: [
            { id: "friend-1", data: {} },
          ],
          // BUT-1724: the personal-list leg is a name-only collection too, and
          // it is the newest one — moving it out of the `nameChanged` guard
          // would write `ownerDisplayName: undefined` (an Admin-SDK throw the
          // per-step catch swallows) and bill two reads per avatar change for
          // every user, with no other assertion here able to see it.
          [`${Collections.users}/${UID}/${Collections.unifiedShoppingLists}`]: [
            {
              id: "p1",
              data: {
                ownerId: UID,
                lastActivityByUserId: UID,
                ownerDisplayName: "Anna",
                lastActivityByDisplayName: "Anna",
              },
            },
          ],
        });

        await propagateProfileUpdate(
          fake.db,
          UID,
          "Anna",
          "Anna", // name unchanged
          "old-av",
          "new-av" // avatar changed
        );

        assertEqual(
          fake.store[Collections.messages][0].data.senderAvatarUrl,
          "new-av",
          "message avatar denorm updated"
        );
        assertEqual(
          "senderDisplayName" in
            (fake.writes.find((w) => w.collectionKey === Collections.messages)
              ?.data ?? {}),
          false,
          "name not written on an avatar-only change"
        );
        // Name-only collections must not be touched at all.
        assertEqual(
          fake.store[Collections.realtimeRecipes][0].data.ownerDisplayName,
          "Anna",
          "realtime owner name untouched on avatar-only change"
        );
        assertEqual(
          fake.store[Collections.groupInvitations][0].data.fromUserName,
          "Anna",
          "group invitation untouched on avatar-only change"
        );
        const personal =
          fake.store[
            `${Collections.users}/${UID}/${Collections.unifiedShoppingLists}`
          ][0];
        assertEqual(
          personal.data.ownerDisplayName,
          "Anna",
          "personal shopping list owner name untouched on avatar-only change"
        );
        assertEqual(
          fake.writes.some((w) =>
            w.collectionKey.endsWith(`/${Collections.unifiedShoppingLists}`)
          ),
          false,
          "no write issued to the personal shopping lists at all"
        );

        // Positive control on the SAME fixture: without it, "no personal write"
        // is also satisfied by a fixture the leg could never have matched, and
        // the guard could be deleted with this test still green.
        await propagateProfileUpdate(
          fake.db,
          UID,
          "Anna",
          "Annika",
          "new-av",
          "new-av"
        );
        assertEqual(
          personal.data.ownerDisplayName,
          "Annika",
          "control: a name change DOES reach the same personal list"
        );
      },
    },
    {
      name: "dual-field overlap doc gets BOTH owner and last-editor names",
      fn: async () => {
        const fake = makeFakeDb({
          [Collections.realtimeRecipes]: [
            // owner == last-editor == UID (the common overlap case).
            {
              id: "both",
              data: {
                ownerId: UID,
                lastEditedBy: UID,
                ownerDisplayName: "Old",
                lastEditedByDisplayName: "Old",
              },
            },
            // owner only.
            { id: "owner", data: { ownerId: UID, lastEditedBy: OTHER } },
            // editor only.
            { id: "editor", data: { ownerId: OTHER, lastEditedBy: UID } },
          ],
        });

        await propagateProfileUpdate(fake.db, UID, "Old", "New", "av", "av");

        const rows = fake.store[Collections.realtimeRecipes];
        const both = rows.find((d) => d.id === "both")!;
        assertEqual(both.data.ownerDisplayName, "New", "overlap owner name");
        assertEqual(
          both.data.lastEditedByDisplayName,
          "New",
          "overlap editor name"
        );

        const ownerOnly = rows.find((d) => d.id === "owner")!;
        assertEqual(ownerOnly.data.ownerDisplayName, "New", "owner-only name");
        assertEqual(
          ownerOnly.data.lastEditedByDisplayName,
          undefined,
          "owner-only editor field left alone"
        );

        const editorOnly = rows.find((d) => d.id === "editor")!;
        assertEqual(
          editorOnly.data.lastEditedByDisplayName,
          "New",
          "editor-only name"
        );
        assertEqual(
          editorOnly.data.ownerDisplayName,
          undefined,
          "editor-only owner field left alone"
        );
      },
    },
    {
      name: "personal shopping lists update in the user's own subcollection, never a top-level one",
      fn: async () => {
        const personalKey = `${Collections.users}/${UID}/${Collections.unifiedShoppingLists}`;
        const fake = makeFakeDb({
          [personalKey]: [
            // Owner == last-activity == UID: both denorm names move.
            {
              id: "p-own",
              data: {
                ownerId: UID,
                lastActivityByUserId: UID,
                ownerDisplayName: "Old",
                lastActivityByDisplayName: "Old",
              },
            },
            // Copied out of a collaborative list: the last-activity stamp names
            // someone else and must survive this user's rename.
            {
              id: "p-copied",
              data: {
                ownerId: UID,
                lastActivityByUserId: OTHER,
                ownerDisplayName: "Old",
                lastActivityByDisplayName: "Keep",
              },
            },
          ],
          // A top-level `unified_shopping_lists` collection does not exist in
          // production (firestore.rules grants no match). Seeding one here is
          // the trap: if the function ever queries it again, this row changes.
          [Collections.unifiedShoppingLists]: [
            { id: "ghost", data: { ownerId: UID, ownerDisplayName: "Old" } },
          ],
          [Collections.unifiedSharedShoppingLists]: [
            { id: "s1", data: { ownerId: UID, ownerDisplayName: "Old" } },
          ],
        });

        await propagateProfileUpdate(fake.db, UID, "Old", "New", "av", "av");

        const personal = fake.store[personalKey];
        const own = personal.find((d) => d.id === "p-own")!;
        assertEqual(own.data.ownerDisplayName, "New", "personal owner name");
        assertEqual(
          own.data.lastActivityByDisplayName,
          "New",
          "personal last-activity name"
        );

        const copied = personal.find((d) => d.id === "p-copied")!;
        assertEqual(
          copied.data.ownerDisplayName,
          "New",
          "copied list owner name"
        );
        assertEqual(
          copied.data.lastActivityByDisplayName,
          "Keep",
          "another member's last-activity stamp untouched"
        );

        assertEqual(
          fake.store[Collections.unifiedShoppingLists][0].data
            .ownerDisplayName,
          "Old",
          "top-level unified_shopping_lists never read"
        );
        assertEqual(
          fake.store[Collections.unifiedSharedShoppingLists][0].data
            .ownerDisplayName,
          "New",
          "shared shopping list still updated"
        );
      },
    },
    {
      name: "members collection group is paged across subcollections; conversation key stays user-scoped",
      fn: async () => {
        const fake = makeFakeDb({
          "shared_content/A/members": [
            { id: UID, data: { userId: UID, displayName: "Old" } },
          ],
          "shared_content/B/members": [
            { id: UID, data: { userId: UID, displayName: "Old" } },
            { id: OTHER, data: { userId: OTHER, displayName: "Keep" } },
          ],
          [Collections.conversations]: [
            {
              id: "c1",
              data: {
                participantIds: [UID, OTHER],
                participantDisplayNames: { [UID]: "Old", [OTHER]: "Keep" },
              },
            },
          ],
        });

        await propagateProfileUpdate(fake.db, UID, "Old", "New", "av", "av");

        assertEqual(
          fake.store["shared_content/A/members"][0].data.displayName,
          "New",
          "member A updated"
        );
        const bMembers = fake.store["shared_content/B/members"];
        assertEqual(
          bMembers.find((d) => d.id === UID)!.data.displayName,
          "New",
          "member B (UID) updated"
        );
        assertEqual(
          bMembers.find((d) => d.id === OTHER)!.data.displayName,
          "Keep",
          "other member untouched"
        );

        const conv = fake.store[Collections.conversations][0].data
          .participantDisplayNames as Record<string, string>;
        assertEqual(conv[UID], "New", "conversation name keyed by acting user");
        assertEqual(conv[OTHER], "Keep", "other participant name untouched");
      },
    },
    {
      name: "BUT-1770: item subcollections are swept by collection group on both attribution fields",
      fn: async () => {
        const fake = makeFakeDb({
          // Personal-list items live in a subcollection of the list document.
          [`${Collections.users}/${UID}/${Collections.unifiedShoppingLists}/l1/items`]: [
            {
              id: "i1",
              data: {
                addedByUserId: UID,
                addedByDisplayName: "Old",
                lastModifiedByUserId: UID,
                lastModifiedByDisplayName: "Old",
              },
            },
            {
              id: "i2",
              data: {
                addedByUserId: OTHER,
                addedByDisplayName: "Keep",
                lastModifiedByUserId: UID,
                lastModifiedByDisplayName: "Old",
              },
            },
          ],
          // shared_content keeps its own `items` subcollection with the same
          // two attribution pairs — the collection group must reach it too.
          "shared_content/A/items": [
            {
              id: "i3",
              data: {
                addedByUserId: UID,
                addedByDisplayName: "Old",
                lastModifiedByUserId: OTHER,
                lastModifiedByDisplayName: "Keep",
              },
            },
          ],
        });

        await propagateProfileUpdate(fake.db, UID, "Old", "New", "av", "av");

        const personal =
          fake.store[
            `${Collections.users}/${UID}/${Collections.unifiedShoppingLists}/l1/items`
          ];
        const i1 = personal.find((d) => d.id === "i1")!.data;
        assertEqual(i1.addedByDisplayName, "New", "own added-by name renamed");
        assertEqual(
          i1.lastModifiedByDisplayName,
          "New",
          "own last-modified name renamed"
        );

        const i2 = personal.find((d) => d.id === "i2")!.data;
        assertEqual(
          i2.addedByDisplayName,
          "Keep",
          "another person's added-by name untouched"
        );
        assertEqual(
          i2.lastModifiedByDisplayName,
          "New",
          "the same row's last-modified name is still renamed (independent pair)"
        );

        assertEqual(
          fake.store["shared_content/A/items"][0].data.addedByDisplayName,
          "New",
          "shared_content items subcollection reached by the collection group"
        );
        assertEqual(
          fake.store["shared_content/A/items"][0].data
            .lastModifiedByDisplayName,
          "Keep",
          "another person's last-modified name untouched"
        );

        // The cursor fields must never be rewritten, or paging could skip docs.
        const rewroteFilterField = fake.writes.some(
          (w) => "addedByUserId" in w.data || "lastModifiedByUserId" in w.data
        );
        assertEqual(rewroteFilterField, false, "filter fields never written");
      },
    },
    {
      name: "BUT-1770: the claim chip and the purchase attribution are renamed too",
      fn: async () => {
        // `assignedToDisplayName` is the only item name the UI actually renders
        // (the BUT-238 "Tar jag" chip and the "Annas del" heading), and
        // `purchasedByDisplayName` ships in the Art. 15 bundle. A version of
        // this leg covering only addedBy/lastModifiedBy renamed two fields with
        // no reader and left both of these stale — the exact symptom the ticket
        // describes. Both storage shapes in one scenario.
        const fake = makeFakeDb({
          "shared_content/A/items": [
            {
              id: "i1",
              data: {
                assignedToUserId: UID,
                assignedToDisplayName: "Old",
                purchasedByUserId: UID,
                purchasedByDisplayName: "Old",
              },
            },
            {
              id: "i2",
              data: {
                assignedToUserId: OTHER,
                assignedToDisplayName: "Keep",
                purchasedByUserId: OTHER,
                purchasedByDisplayName: "Keep",
              },
            },
          ],
          [Collections.unifiedSharedShoppingLists]: [
            {
              id: "sl1",
              data: {
                ownerId: OTHER,
                contributorUserIds: [OTHER, UID],
                items: [
                  {
                    id: "a",
                    name: "Mjölk",
                    assignedToUserId: UID,
                    assignedToDisplayName: "Old",
                    purchasedByUserId: OTHER,
                    purchasedByDisplayName: "Keep",
                  },
                ],
              },
            },
          ],
        });

        await propagateProfileUpdate(fake.db, UID, "Old", "New", "av", "av");

        const sub = fake.store["shared_content/A/items"];
        assertEqual(
          sub.find((d) => d.id === "i1")!.data.assignedToDisplayName,
          "New",
          "own claim-chip name renamed in the items subcollection"
        );
        assertEqual(
          sub.find((d) => d.id === "i1")!.data.purchasedByDisplayName,
          "New",
          "own purchased-by name renamed in the items subcollection"
        );
        assertEqual(
          sub.find((d) => d.id === "i2")!.data.assignedToDisplayName,
          "Keep",
          "another person's claim-chip name untouched"
        );

        const items = fake.store[Collections.unifiedSharedShoppingLists]
          .find((d) => d.id === "sl1")!.data.items as Array<
          Record<string, unknown>
        >;
        assertEqual(
          items[0].assignedToDisplayName,
          "New",
          "own claim-chip name renamed in the embedded array"
        );
        assertEqual(
          items[0].purchasedByDisplayName,
          "Keep",
          "someone else's purchase on the same row is untouched"
        );

        const rewroteFilterField = fake.writes.some(
          (w) => "assignedToUserId" in w.data || "purchasedByUserId" in w.data
        );
        assertEqual(rewroteFilterField, false, "filter fields never written");
      },
    },
    {
      name: "BUT-1770: the embedded items array on a shared list is rewritten row by row",
      fn: async () => {
        const fake = makeFakeDb({
          [Collections.unifiedSharedShoppingLists]: [
            {
              id: "sl1",
              data: {
                ownerId: OTHER,
                ownerDisplayName: "Keep",
                contributorUserIds: [OTHER, UID],
                items: [
                  {
                    id: "a",
                    name: "Mjölk",
                    addedByUserId: UID,
                    addedByDisplayName: "Old",
                    lastModifiedByUserId: OTHER,
                    lastModifiedByDisplayName: "Keep",
                  },
                  {
                    id: "b",
                    name: "Bröd",
                    addedByUserId: OTHER,
                    addedByDisplayName: "Keep",
                    lastModifiedByUserId: UID,
                    lastModifiedByDisplayName: "Old",
                  },
                ],
              },
            },
            {
              // No contributor trail for UID → not this user's rows to touch.
              id: "sl2",
              data: {
                ownerId: OTHER,
                contributorUserIds: [OTHER],
                items: [
                  {
                    id: "c",
                    addedByUserId: OTHER,
                    addedByDisplayName: "Keep",
                  },
                ],
              },
            },
          ],
        });

        await propagateProfileUpdate(fake.db, UID, "Old", "New", "av", "av");

        const items = fake.store[Collections.unifiedSharedShoppingLists]
          .find((d) => d.id === "sl1")!.data.items as Array<
          Record<string, unknown>
        >;
        assertEqual(items[0].addedByDisplayName, "New", "row a added-by renamed");
        assertEqual(
          items[0].lastModifiedByDisplayName,
          "Keep",
          "row a last-modified belongs to someone else"
        );
        assertEqual(
          items[1].addedByDisplayName,
          "Keep",
          "row b added-by belongs to someone else"
        );
        assertEqual(
          items[1].lastModifiedByDisplayName,
          "New",
          "row b last-modified renamed"
        );
        assertEqual(items[0].name, "Mjölk", "unrelated item fields preserved");

        const untouched = fake.store[Collections.unifiedSharedShoppingLists]
          .find((d) => d.id === "sl2")!.data.items as Array<
          Record<string, unknown>
        >;
        assertEqual(
          untouched[0].addedByDisplayName,
          "Keep",
          "a list without the contributor trail is never rewritten"
        );

        // `contributorUserIds` is the outer cursor's filter field — writing it
        // would let paging skip or revisit a list.
        const rewroteTrail = fake.writes.some(
          (w) => "contributorUserIds" in w.data
        );
        assertEqual(rewroteTrail, false, "contributor trail never written");
      },
    },
    {
      name: "BUT-1770: an avatar-only change leaves item attribution alone",
      fn: async () => {
        const fake = makeFakeDb({
          "shared_content/A/items": [
            { id: "i1", data: { addedByUserId: UID, addedByDisplayName: "Old" } },
          ],
          [Collections.unifiedSharedShoppingLists]: [
            {
              id: "sl1",
              data: {
                contributorUserIds: [UID],
                items: [{ id: "a", addedByUserId: UID, addedByDisplayName: "Old" }],
              },
            },
          ],
        });

        await propagateProfileUpdate(fake.db, UID, "Same", "Same", "old", "new");

        assertEqual(
          fake.store["shared_content/A/items"][0].data.addedByDisplayName,
          "Old",
          "item subcollection untouched on an avatar-only change"
        );
        const items = fake.store[Collections.unifiedSharedShoppingLists][0].data
          .items as Array<Record<string, unknown>>;
        assertEqual(
          items[0].addedByDisplayName,
          "Old",
          "embedded items untouched on an avatar-only change"
        );
      },
    },
    {
      name: "BUT-1770: the collection-group index for every item attribution field is declared",
      fn: async () => {
        // The fake models DATA, not Firestore's index layer. A collection-group
        // equality query needs an explicit COLLECTION_GROUP single-field index:
        // the automatic ones are collection-scoped, so without these the sweep
        // throws FAILED_PRECONDITION in production and the fake would never say
        // so.
        // eslint-disable-next-line @typescript-eslint/no-require-imports
        const fs = require("fs");
        // eslint-disable-next-line @typescript-eslint/no-require-imports
        const path = require("path");
        const config = JSON.parse(
          fs.readFileSync(
            path.join(__dirname, "..", "..", "..", "firestore.indexes.json"),
            "utf8"
          )
        ) as {
          fieldOverrides: Array<{
            collectionGroup: string;
            fieldPath: string;
            indexes: Array<{ order?: string; queryScope: string }>;
          }>;
        };

        // All four pairs `UnifiedShoppingItem.toFirestore()` persists — the
        // same group `account-deletion-cascade.ts` scrubs. A missing override
        // here is a FAILED_PRECONDITION on the rename path in production.
        for (const fieldPath of [
          "addedByUserId",
          "lastModifiedByUserId",
          "assignedToUserId",
          "purchasedByUserId",
        ]) {
          const override = config.fieldOverrides.find(
            (f) => f.collectionGroup === "items" && f.fieldPath === fieldPath
          );
          assertEqual(
            !!override?.indexes.some(
              (ix) =>
                ix.queryScope === "COLLECTION_GROUP" && ix.order === "ASCENDING"
            ),
            true,
            `items.${fieldPath} declares an ASCENDING COLLECTION_GROUP index`
          );
        }
      },
    },
  ]);
})();
