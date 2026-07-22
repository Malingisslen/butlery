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

  function makeQuery(collectionKeys: string[]) {
    let predicate: Predicate | null = null;
    let ordered = false;
    let limitN = Number.POSITIVE_INFINITY;
    let afterKey: string | null = null;

    const q = {
      where(field: string, op: string, value: unknown) {
        predicate = { field, op, value };
        return q;
      },
      orderBy() {
        ordered = true;
        return q;
      },
      limit(n: number) {
        limitN = n;
        return q;
      },
      startAfter(snap: { _sortKey: string }) {
        afterKey = snap._sortKey;
        return q;
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
    return q;
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
  ]);
})();
