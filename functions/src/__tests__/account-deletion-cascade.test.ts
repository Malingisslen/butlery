/**
 * BUT-1766 / BUT-1768: per-step semantics of the account-deletion cascade for
 * the two collections it silently skipped.
 *
 * `request-account-deletion.test.ts` covers ORCHESTRATION only — its fake makes
 * every query return an empty snapshot, so every step "succeeds" whatever it
 * queries. That is exactly the blind spot both defects lived in: `deleteMessages`
 * swept `conversations/{id}/messages`, a subcollection with no rule block and no
 * writer, and `realtime_menus` had no step at all. Neither showed up as a
 * failure anywhere — the cascade reported `messages` deleted and the audit row
 * said `gdprCompliant: true`.
 *
 * Tested against an in-memory Firestore stub, the same shape as
 * `but753-legacy-sharedwith-cascade.test.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade.test.ts
 */

import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-cascade" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteMessages,
  deleteBlocks,
  deleteBlockMirrors,
  MAX_BLOCK_SWEEP_ROWS,
  MAX_MIRROR_SWEEP_ROWS,
  deleteRealtimeMenus,
} = require("../account/account-deletion-cascade");

/** Marker standing in for `FieldValue.arrayRemove` (real SDK unavailable). */
const ARRAY_REMOVE_MARKER = Symbol("arrayRemove");
interface ArrayRemoveOp {
  [ARRAY_REMOVE_MARKER]: true;
  values: unknown[];
}
function isArrayRemoveOp(v: unknown): v is ArrayRemoveOp {
  return (
    typeof v === "object" &&
    v !== null &&
    (v as ArrayRemoveOp)[ARRAY_REMOVE_MARKER] === true
  );
}
(
  admin.firestore.FieldValue as unknown as {
    arrayRemove: (...values: unknown[]) => ArrayRemoveOp;
  }
).arrayRemove = (...values: unknown[]) => ({
  [ARRAY_REMOVE_MARKER]: true,
  values,
});

/** Marker standing in for `FieldValue.delete()`. */
const DELETE_MARKER = Symbol("fieldDelete");
interface DeleteOp {
  [DELETE_MARKER]: true;
}
function isDeleteOp(v: unknown): v is DeleteOp {
  return (
    typeof v === "object" && v !== null && (v as DeleteOp)[DELETE_MARKER] === true
  );
}
(
  admin.firestore.FieldValue as unknown as { delete: () => DeleteOp }
).delete = () => ({ [DELETE_MARKER]: true });

type DocData = Record<string, unknown>;

/** Write `value` at a dotted field path, cloning each map on the way down. */
function applyFieldPath(
  target: Record<string, unknown>,
  segments: string[],
  value: unknown,
): void {
  const [head, ...rest] = segments;
  if (rest.length === 0) {
    if (isDeleteOp(value)) {
      delete target[head];
    } else {
      target[head] = value;
    }
    return;
  }
  const child =
    typeof target[head] === "object" && target[head] !== null
      ? { ...(target[head] as Record<string, unknown>) }
      : {};
  applyFieldPath(child, rest, value);
  target[head] = child;
}

interface FakeRef {
  path: string;
  delete(): Promise<void>;
  update(data: DocData): Promise<void>;
  collection(name: string): FakeSubcollection;
  /**
   * BUT-1957: `probeResidualData` stopped naming the `users/{uid}` subcollections
   * it probes and now ENUMERATES them. Without this method the enumeration lands
   * in the probe's own outer catch, which fails CLOSED — every clean fixture in
   * this file then reports `residual_data_detected`, and the six scenarios that
   * assert a clean store go red for a reason that has nothing to do with what
   * they test. Modelled, not stubbed to `[]`: a stub returning nothing would make
   * every assertion about the enumeration pass vacuously.
   */
  listCollections(): Promise<FakeSubcollectionRef[]>;
}

/** What `listCollections()` hands back: a subcollection handle that knows its id. */
interface FakeSubcollectionRef extends FakeSubcollection {
  id: string;
}

interface FakeQuerySnapshot {
  empty: boolean;
  size: number;
  docs: { ref: FakeRef; id: string; data: () => DocData }[];
}

interface FakeSubcollection {
  get(): Promise<FakeQuerySnapshot>;
  doc(id: string): FakeRef;
  /**
   * BUT-1789: a FILTERED read of a subcollection. The top-level `collection()`
   * matcher below cannot serve this — it only ever considers 2-segment paths,
   * so `analytics/feature_retention/users` (a 3-segment prefix) is invisible to
   * it, which is precisely the shape of collection the cascade had never swept.
   */
  where(
    field: string | admin.firestore.FieldPath,
    op: string,
    value: unknown,
  ): {
    get(): Promise<FakeQuerySnapshot>;
    count(): { get(): Promise<{ data(): { count: number } }> };
  };
  /** BUT-1822: needed by `probeResidualData`'s own subcollection legs. */
  count(): { get(): Promise<{ data(): { count: number } }> };
  listDocuments(): Promise<FakeRef[]>;
}

class FakeFirestore {
  private docs = new Map<string, DocData>();
  /**
   * Every path a batch WROTE to. The fake's applyUpdate returns silently on a
   * missing doc, where a real `batch.update` throws grpc 5 and poison-pills the
   * whole chunk — so "was it written before it was deleted?" is invisible
   * unless the writes are recorded.
   */
  readonly updatedPaths: string[] = [];
  /**
   * Path -> grpc code that `ref.update()` should reject with. Empty by default,
   * so every existing scenario is untouched. See the seam in `makeRef`.
   */
  readonly updateFailures = new Map<string, number>();
  /**
   * Every path deleted, in order. BUT-1822 turns on an ORDERING invariant —
   * roster rows before the conversation document — and "both are gone at the
   * end" is exactly the assertion that cannot tell the fixed code from the
   * broken code.
   */
  readonly deletedPaths: string[] = [];

  set(path: string, data: DocData): void {
    this.docs.set(path, data);
  }

  get(path: string): DocData | undefined {
    return this.docs.get(path);
  }

  has(path: string): boolean {
    return this.docs.has(path);
  }

  /** Every stored path under `<collection>/`, top level only. */
  idsIn(collection: string): string[] {
    const out: string[] = [];
    for (const path of this.docs.keys()) {
      const segments = path.split("/");
      if (segments.length === 2 && segments[0] === collection) {
        out.push(segments[1]);
      }
    }
    return out.sort();
  }

  /** Every stored path directly under `<prefix>/` (one more segment). */
  pathsUnder(prefix: string): string[] {
    const depth = prefix.split("/").length + 1;
    const out: string[] = [];
    for (const path of this.docs.keys()) {
      if (!path.startsWith(`${prefix}/`)) continue;
      if (path.split("/").length === depth) out.push(path);
    }
    return out.sort();
  }

  private makeRef(path: string): FakeRef {
    return {
      path,
      delete: async () => {
        this.deletedPaths.push(path);
        this.docs.delete(path);
      },
      update: async (data: DocData) => {
        // BUT-1801: the failure seam. Real Firestore REJECTS `update()` on a
        // missing document with grpc code 5 (NOT_FOUND); this stub silently
        // resolved, because `applyUpdate` returns on a missing doc. That made
        // the poll-creator scrub's code-5 tolerance unstageable — inverting the
        // predicate to tolerate everything EXCEPT code 5 left the whole suite
        // green, so the branch was dead weight to the tests that were meant to
        // hold it. Tests opt in by path; nothing else changes behaviour.
        //
        // Reaches `ref.update()` ONLY. A `batch().update` does not go through
        // `makeRef`, so an injection aimed at a `commitInChunks` path would pass
        // vacuously — check which write shape the code under test uses before
        // trusting a green result from this seam.
        const injected = this.updateFailures.get(path);
        if (injected !== undefined) {
          throw Object.assign(new Error(`injected update failure on ${path}`), {
            code: injected,
          });
        }
        this.applyUpdate(path, data);
      },
      // Subcollections are real in Firestore and NOT deleted with their parent
      // — the whole point of the orphan findings this suite now covers. The
      // stub models them as deeper slash-separated keys.
      //
      // Derived from the stored paths, exactly like `listDocuments` below and
      // for the same reason: a real `listCollections()` answers from what the
      // database HOLDS, so a subcollection whose parent document is gone is
      // still listed. Returning only names the test remembered to register
      // would make the enumeration a mirror of the fixture's intent instead of
      // of its contents.
      listCollections: async (): Promise<FakeSubcollectionRef[]> => {
        const prefix = `${path}/`;
        const names = new Set<string>();
        for (const p of this.docs.keys()) {
          if (!p.startsWith(prefix)) continue;
          const rest = p.slice(prefix.length).split("/");
          if (rest.length >= 2) names.add(rest[0]);
        }
        return [...names].sort().map((name) =>
          Object.assign(this.makeRef(path).collection(name), { id: name }),
        );
      },
      collection: (name: string): FakeSubcollection => {
        const snapshotOf = (paths: string[]): FakeQuerySnapshot =>
          this.snapshotOfPaths(paths);
        const filtered = (
          field: string | admin.firestore.FieldPath,
          op: string,
          value: unknown,
        ) =>
          this.pathsUnder(`${path}/${name}`).filter((p) => {
            // `readField`, not a literal key lookup: Firestore resolves a dotted
            // `where()` field as a PATH into nested maps, and a stub that
            // disagreed would report a dotted subcollection query as matching
            // nothing while claiming to pass. The top-level matcher has always
            // done this; extending `count()` here without it would put the trap
            // on a second path.
            const fieldVal = FakeFirestore.readField(
              this.docs.get(p) as DocData,
              field,
            );
            if (op === "==") return fieldVal === value;
            if (op === "array-contains") {
              return Array.isArray(fieldVal) && fieldVal.includes(value);
            }
            return false;
          });
        return {
          get: async () => snapshotOf(this.pathsUnder(`${path}/${name}`)),
          doc: (id: string) => this.makeRef(`${path}/${name}/${id}`),
          count: () => ({
            get: async () => {
              const size = this.pathsUnder(`${path}/${name}`).length;
              return { data: () => ({ count: size }) };
            },
          }),
          // Derived from DEEPER paths, not from stored documents: the one state
          // `listDocuments()` exists to surface is a MISSING parent that still
          // owns a subcollection, and a stub that mapped stored docs could never
          // represent it.
          listDocuments: async () => {
            const prefix = `${path}/${name}`;
            const depth = prefix.split("/").length + 1;
            const ids = new Set<string>();
            for (const p of this.docs.keys()) {
              if (!p.startsWith(`${prefix}/`)) continue;
              ids.add(p.split("/").slice(0, depth).join("/"));
            }
            return [...ids].sort().map((p) => this.makeRef(p));
          },
          where: (
            field: string | admin.firestore.FieldPath,
            op: string,
            value: unknown,
          ) => ({
            get: async () => snapshotOf(filtered(field, op, value)),
            count: () => ({
              get: async () => {
                const size = filtered(field, op, value).length;
                return { data: () => ({ count: size }) };
              },
            }),
          }),
        };
      },
    };
  }

  private applyUpdate(path: string, data: DocData): void {
    const existing = this.docs.get(path);
    if (!existing) return;
    const next = { ...existing };
    for (const [k, v] of Object.entries(data)) {
      // Dotted keys are Firestore FIELD PATHS, not literal key names — the
      // whole point of `participantDisplayNames.<uid>`. A stub that stored them
      // literally would report every map-key removal as passing.
      if (k.includes(".")) {
        applyFieldPath(next, k.split("."), v);
        continue;
      }
      if (isArrayRemoveOp(v)) {
        const cur = Array.isArray(next[k]) ? (next[k] as unknown[]) : [];
        next[k] = cur.filter((item) => !v.values.includes(item));
      } else if (isDeleteOp(v)) {
        delete next[k];
      } else {
        next[k] = v;
      }
    }
    this.docs.set(path, next);
  }

  /**
   * Firestore resolves a dotted `where()` field as a PATH into nested maps —
   * `metadata.subjectUserId` is not a key called "metadata.subjectUserId". A
   * stub that looked up the literal key would report the BUT-1788 system-message
   * sweep as matching nothing while claiming to pass.
   */
  /** A `FieldPath` is not a dotted string; its parts are its `.segments`. */
  private static readField(
    data: DocData,
    field: string | admin.firestore.FieldPath,
  ): unknown {
    const segments =
      field instanceof admin.firestore.FieldPath
        ? (field as unknown as { segments: string[] }).segments
        : field.split(".");
    let cursor: unknown = data;
    for (const segment of segments) {
      if (cursor === null || typeof cursor !== "object") return undefined;
      cursor = (cursor as Record<string, unknown>)[segment];
    }
    return cursor;
  }

  collection(name: string): unknown {
    const matching = (
      field: string | admin.firestore.FieldPath,
      op: string,
      value: unknown,
    ) => {
      const matches: { path: string; data: DocData }[] = [];
      for (const [path, data] of this.docs) {
        const segments = path.split("/");
        if (segments.length !== 2 || segments[0] !== name) continue;
        const fieldVal = FakeFirestore.readField(data, field);
        if (op === "==" && fieldVal === value) {
          matches.push({ path, data });
        } else if (op === "!=" && fieldVal !== value && fieldVal !== undefined) {
          // Firestore's `!=` excludes documents where the field is ABSENT. A
          // stub that returned them would report the shared-list member-key
          // probe as matching every document in the collection.
          matches.push({ path, data });
        } else if (
          op === "array-contains" &&
          Array.isArray(fieldVal) &&
          fieldVal.includes(value)
        ) {
          matches.push({ path, data });
        }
      }
      return matches;
    };
    // Same union as `matching` and `readField`. `asDb` casts through `unknown`,
    // so this type is never checked against production either way — what it buys
    // is inside the seam: under the union an inline `field.split(".")` is a
    // compile error, and that is the defect that shipped.
    const matcher = (
      field: string | admin.firestore.FieldPath,
      op: string,
      value: unknown,
    ) => ({
      // BUT-1822: `count()` was missing, which is why `probeResidualData` — the
      // cascade's own safety net — had no test in this file at all.
      count: () => ({
        get: async () => {
          const size = matching(field, op, value).length;
          return { data: () => ({ count: size }) };
        },
      }),
      // BUT-1838: a FILTERED-AND-LIMITED top-level read. `deleteChatGroupMemberships`
      // does `.where("memberIds","array-contains",uid).limit(MAX + 1).get()` so it
      // can tell "plausible" from "seeded" and DECLINE rather than truncate — the
      // same shape the collection-group matcher below already had, and without it
      // the step throws a TypeError that says nothing about the logic under test.
      limit: (max: number) => ({
        get: async () => {
          const matches = matching(field, op, value).slice(0, max);
          return {
            empty: matches.length === 0,
            size: matches.length,
            docs: matches.map((d) => ({
              ref: this.makeRef(d.path),
              id: d.path.split("/")[1],
              data: () => d.data,
              get: (f: string) => FakeFirestore.readField(d.data, f),
            })),
          };
        },
      }),
      get: async () => {
        const matches = matching(field, op, value);
        return {
          empty: matches.length === 0,
          size: matches.length,
          docs: matches.map((d) => ({
            ref: this.makeRef(d.path),
            id: d.path.split("/")[1],
            data: () => d.data,
            // Real QueryDocumentSnapshots expose get(); the shared_content
            // membership scrub uses it to skip docs it is about to hard-delete.
            get: (f: string) => FakeFirestore.readField(d.data, f),
          })),
        };
      },
    });
    // BUT-1822: `name` can be a SLASH-SEPARATED path, and the read can be
    // unfiltered-but-limited. `tryClearRoster` — which the cascade now calls
    // before deleting a 1:1 conversation — does exactly
    // `db.collection("conversations/<id>/participants").limit(N + 1).get()`.
    // The matcher above cannot serve that: it only ever considers 2-segment
    // paths, and it is reached only through `where()` — the object `collection()`
    // itself returned had neither `get` nor `limit`, so wiring the roster clear
    // in without this would throw a TypeError that says nothing about the logic
    // under test.
    const unfiltered = (max?: number) => ({
      get: async () => {
        const paths = this.pathsUnder(name);
        return this.snapshotOfPaths(
          max === undefined ? paths : paths.slice(0, max),
        );
      },
    });
    // BUT-1957: `deleteUserSubcollections` finishes with the `system_rate_limits`
    // sweep, a documentId() PREFIX RANGE — `orderBy(documentId()).startAt(`${uid}_`)
    // .endAt(`${uid}_`)`. The matcher above cannot serve it (it is reached
    // only through `where()`), so without this the whole deleter throws before
    // any assertion about the subcollections it just swept can run.
    //
    // Modelled as a real lexicographic range on the document ID rather than as a
    // pass-through: the trailing sentinel in the production upper bound is
    // load-bearing and invisible in a diff, and a stub that ignored the bounds
    // would report an erase-everything mutant as passing.
    const idRange = (lower: string | null, upper: string | null) => ({
      startAt: (from: string) => idRange(from, upper),
      endAt: (to: string) => idRange(lower, to),
      get: async () => {
        const paths = this.pathsUnder(name).filter((p) => {
          const id = p.split("/")[1];
          if (lower !== null && id < lower) return false;
          if (upper !== null && id > upper) return false;
          return true;
        });
        return this.snapshotOfPaths(paths);
      },
    });
    return {
      where: (
        field: string | admin.firestore.FieldPath,
        op: string,
        value: unknown,
      ) => matcher(field, op, value),
      doc: (id: string) => this.makeRef(`${name}/${id}`),
      get: unfiltered().get,
      limit: (max: number) => unfiltered(max),
      orderBy: (field: string | admin.firestore.FieldPath) => {
        if (!(field instanceof admin.firestore.FieldPath)) {
          throw new Error(
            `fake: orderBy is modelled for documentId() only, got ${String(field)}`,
          );
        }
        return idRange(null, null);
      },
    };
  }

  /** Shared snapshot shape for path-listing reads. */
  private snapshotOfPaths(paths: string[]): FakeQuerySnapshot {
    return {
      empty: paths.length === 0,
      size: paths.length,
      docs: paths.map((p) => ({
        ref: this.makeRef(p),
        id: p.split("/").pop() as string,
        data: () => this.docs.get(p) as DocData,
      })),
    };
  }

  /**
   * BUT-1798. Until now this stub had no `collectionGroup`, which is exactly why
   * `removeFromSharedContent` — whose first act is a collectionGroup read — had
   * no scenario in this file at all. Matches any path whose LAST collection
   * segment is `name`, at any depth, which is what a real collection-group query
   * does.
   */
  collectionGroup(name: string): unknown {
    const matching = (
      field: string | admin.firestore.FieldPath,
      op: string,
      value: unknown,
    ) => {
      const matches: { path: string; data: DocData }[] = [];
      for (const [path, data] of this.docs) {
        const segments = path.split("/");
        // A document path is collection/doc/collection/doc/... so the
        // owning collection is the second-to-last segment.
        if (segments.length < 2) continue;
        if (segments[segments.length - 2] !== name) continue;
        const fieldVal = FakeFirestore.readField(data, field);
        if (op === "==" && fieldVal === value) {
          matches.push({ path, data });
        } else if (
          op === "array-contains" &&
          Array.isArray(fieldVal) &&
          fieldVal.includes(value)
        ) {
          matches.push({ path, data });
        }
      }
      return matches;
    };
    const snapshotOf = (matches: { path: string; data: DocData }[]) => ({
      empty: matches.length === 0,
      size: matches.length,
      docs: matches.map((d) => ({
        ref: this.makeRef(d.path),
        id: d.path.split("/").pop() as string,
        data: () => d.data,
        get: (f: string) => FakeFirestore.readField(d.data, f),
      })),
    });
    return {
      where: (
        field: string | admin.firestore.FieldPath,
        op: string,
        value: unknown,
      ) => ({
        get: async () => snapshotOf(matching(field, op, value)),
        // BUT-1822. The roster sweep reads `.limit(MAX + 1)` so it can tell
        // "plausible" from "seeded" and decline rather than truncate, and the
        // residual probe reads `.count()`. Neither existed on this stub, so
        // neither could be tested — and `probeResidualData` had no test at all.
        limit: (max: number) => ({
          get: async () => snapshotOf(matching(field, op, value).slice(0, max)),
        }),
        count: () => ({
          get: async () => {
            const size = matching(field, op, value).length;
            return { data: () => ({ count: size }) };
          },
        }),
      }),
    };
  }

  batch(): {
    delete: (ref: FakeRef) => void;
    update: (ref: FakeRef, data: DocData) => void;
    set: (ref: FakeRef, data: DocData) => void;
    commit: () => Promise<void>;
  } {
    const deletes: string[] = [];
    const updates: { path: string; data: DocData }[] = [];
    return {
      delete: (ref) => {
        deletes.push(ref.path);
      },
      update: (ref, data) => {
        this.updatedPaths.push(ref.path);
        updates.push({ path: ref.path, data });
      },
      set: (ref, data) => {
        updates.push({ path: ref.path, data });
      },
      commit: async () => {
        for (const u of updates) this.applyUpdate(u.path, u.data);
        for (const path of deletes) {
          this.deletedPaths.push(path);
          this.docs.delete(path);
        }
      },
    };
  }

  /**
   * Passthrough, not a real transaction — no isolation, no retry, writes
   * apply immediately against the same in-memory store `get`/`update` use.
   * Enough to drive the re-read-then-write logic the two callers in
   * account-deletion-cascade.ts need proven (a fresh `.exists`/`.data()` read
   * inside the handler, not the stale outer-query snapshot); nothing here
   * proves the code resists an ACTUAL concurrent writer.
   */
  async runTransaction<T>(
    handler: (tx: {
      get: (
        ref: FakeRef,
      ) => Promise<{ exists: boolean; data: () => DocData | undefined }>;
      update: (ref: FakeRef, data: DocData) => void;
      delete: (ref: FakeRef) => void;
    }) => Promise<T>,
  ): Promise<T> {
    const tx = {
      get: async (ref: FakeRef) => {
        const data = this.docs.get(ref.path);
        return { exists: data !== undefined, data: () => data };
      },
      update: (ref: FakeRef, data: DocData) => {
        this.applyUpdate(ref.path, data);
      },
      delete: (ref: FakeRef) => {
        this.docs.delete(ref.path);
      },
    };
    return handler(tx);
  }
}

interface ScenarioResult {
  name: string;
  passed: boolean;
  reason?: string;
}
const results: ScenarioResult[] = [];
function check(name: string, condition: boolean, reason?: string): void {
  results.push({ name, passed: condition, reason });
}

const asDb = (db: FakeFirestore) =>
  db as unknown as import("firebase-admin").firestore.Firestore;

const UID = "deleted-uid";
const OTHER = "other-uid";
const THIRD = "third-uid";

function seedMessage(
  db: FakeFirestore,
  id: string,
  conversationId: string,
  senderId: string,
): void {
  db.set(`messages/${id}`, {
    conversationId,
    senderId,
    senderDisplayName: senderId === UID ? "Malin" : "Anna",
    senderAvatarUrl: `https://example.test/${senderId}.jpg`,
    content: `content of ${id}`,
  });
}

/**
 * A 1:1 thread goes entirely — including the counterparty's messages. Once the
 * conversation doc is gone the read rule
 * (`get(conversations/$(conversationId)).data.participantIds`) can never resolve
 * again, so anything left on that `conversationId` is unreachable PII that no
 * later erasure could even find.
 */
async function scenario_directConversationIsErasedWhole(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-direct", { participantIds: [UID, OTHER] });
  seedMessage(db, "m1", "c-direct", UID);
  seedMessage(db, "m2", "c-direct", OTHER);

  await deleteMessages(asDb(db), UID);

  check(
    "1:1 conversation document is deleted",
    !db.has("conversations/c-direct"),
  );
  check(
    "both directions of the 1:1 thread are deleted",
    db.idsIn("messages").length === 0,
    `left behind: ${JSON.stringify(db.idsIn("messages"))}`,
  );
}

/**
 * The regression guard for the actual defect: the old implementation read
 * `conversations/{id}/messages`, which this stub can hold but which nothing
 * writes. Seeding BOTH paths proves the step reads the live one — under the old
 * code the top-level message survives untouched and the subcollection doc is
 * what gets deleted.
 */
async function scenario_readsTopLevelNotSubcollection(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-direct", { participantIds: [UID, OTHER] });
  seedMessage(db, "live", "c-direct", UID);
  // The phantom path, spelled as a two-segment key this stub's queries can see.
  db.set("conversations/c-direct/messages/phantom", {
    senderId: UID,
    content: "never written in production",
  });

  await deleteMessages(asDb(db), UID);

  check(
    "the TOP-LEVEL message is the one that gets erased",
    !db.has("messages/live"),
    "the sweep still reads the phantom subcollection",
  );
}

/**
 * A surviving group thread keeps its structure — `replyToMessageId` points at
 * ids that would dangle — so the user's own rows are anonymized, the same
 * treatment `deleteCommentsAndRatings` gives `recipe_comments`, and everyone
 * else's rows are untouched.
 */
async function scenario_groupThreadIsAnonymizedNotGutted(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-group", { participantIds: [UID, OTHER, THIRD] });
  seedMessage(db, "mine", "c-group", UID);
  seedMessage(db, "theirs", "c-group", OTHER);

  await deleteMessages(asDb(db), UID);

  const mine = db.get("messages/mine");
  check(
    "own group message is kept as a tombstone, not deleted",
    mine !== undefined,
  );
  check(
    "own group message loses uid, name, avatar and content",
    mine?.senderId === "deleted" &&
      mine?.senderDisplayName === "[Raderad användare]" &&
      mine?.senderAvatarUrl === null &&
      mine?.content === "[Borttaget meddelande]",
    `got ${JSON.stringify(mine)}`,
  );

  const theirs = db.get("messages/theirs");
  check(
    "another member's message is untouched",
    theirs?.senderId === OTHER && theirs?.content === "content of theirs",
  );

  const convo = db.get("conversations/c-group");
  check(
    "the group continues with the deleted user removed",
    JSON.stringify(convo?.participantIds) === JSON.stringify([OTHER, THIRD]),
    `got ${JSON.stringify(convo?.participantIds)}`,
  );
}

/**
 * Membership is the WRONG handle on its own (the BUT-1725 lesson): leave a group
 * and the conversation query stops finding you, while every message you wrote
 * keeps your name on a thread the others still read.
 */
async function scenario_messagesInLeftConversationsAreReached(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-left", { participantIds: [OTHER, THIRD] });
  seedMessage(db, "orphan", "c-left", UID);

  await deleteMessages(asDb(db), UID);

  const orphan = db.get("messages/orphan");
  check(
    "a message in a conversation the user LEFT is still anonymized",
    orphan?.senderId === "deleted" &&
      orphan?.senderDisplayName === "[Raderad användare]",
    `got ${JSON.stringify(orphan)}`,
  );
}

/**
 * BUT-1768. `ownerId`, never `userId` — the BUT-1396 trap that made
 * `deleteRealtimeRecipes` match zero documents for months.
 */
async function scenario_realtimeMenusOwnedAreDeleted(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/mine", {
    ownerId: UID,
    userId: "not-the-owner-field",
    lastEditedBy: UID,
    lastEditedByDisplayName: "Malin",
  });
  db.set("realtime_menus/theirs", {
    ownerId: OTHER,
    lastEditedBy: OTHER,
    lastEditedByDisplayName: "Anna",
  });

  await deleteRealtimeMenus(asDb(db), UID);

  check(
    "a realtime menu the user OWNS is deleted",
    !db.has("realtime_menus/mine"),
  );
  check(
    "a realtime menu owned and edited by someone else is untouched",
    db.get("realtime_menus/theirs")?.lastEditedByDisplayName === "Anna",
  );
}

/**
 * The other half of the decision: a menu the user does not own stays (it is its
 * owner's data and the other participants are still collaborating on it), but
 * the denormalised last-editor identity pair goes — nothing renames it once the
 * account is gone, so it would otherwise sit there forever.
 */
async function scenario_realtimeMenuLastEditorIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/shared", {
    ownerId: OTHER,
    participantIds: [OTHER, UID],
    lastEditedBy: UID,
    lastEditedByDisplayName: "Malin",
    title: "Veckans middagar",
  });

  await deleteRealtimeMenus(asDb(db), UID);

  const shared = db.get("realtime_menus/shared");
  check(
    "a menu the user only EDITED is kept for its owner",
    shared !== undefined && shared.title === "Veckans middagar",
  );
  check(
    "its last-editor pair is anonymized, not nulled",
    shared?.lastEditedBy === "deleted" &&
      shared?.lastEditedByDisplayName === "[Raderad användare]",
    `got ${JSON.stringify(shared)}`,
  );
}

/**
 * Anonymizing the message ROWS is not the whole erasure: the conversation
 * DOCUMENT carries uid-keyed maps and a full `lastMessage` copy, and every
 * remaining group member reads it. Nothing renames or erases those once the
 * account is gone — `on-profile-updated.ts`, which maintains
 * `participantDisplayNames` / `participantAvatarUrls`, stops firing.
 */
async function scenario_groupConversationDocumentIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-group", {
    participantIds: [UID, OTHER, THIRD],
    participantDisplayNames: { [UID]: "Malin", [OTHER]: "Anna" },
    participantAvatarUrls: {
      [UID]: "https://example.test/malin.jpg",
      [OTHER]: "https://example.test/anna.jpg",
    },
    lastReadTimestamps: { [UID]: 1, [OTHER]: 2 },
    perUserSettings: { [UID]: { isMuted: true }, [OTHER]: { isPinned: true } },
    lastMessage: {
      senderId: UID,
      senderDisplayName: "Malin",
      senderAvatarUrl: "https://example.test/malin.jpg",
      content: "Vi ses klockan sex",
    },
  });
  seedMessage(db, "mine", "c-group", UID);

  await deleteMessages(asDb(db), UID);

  const convo = db.get("conversations/c-group") as Record<
    string,
    Record<string, unknown>
  >;
  check(
    "the deleted user's display name is gone from the conversation doc",
    !(UID in convo.participantDisplayNames),
    `got ${JSON.stringify(convo.participantDisplayNames)}`,
  );
  check(
    "the deleted user's avatar URL is gone from the conversation doc",
    !(UID in convo.participantAvatarUrls),
    `got ${JSON.stringify(convo.participantAvatarUrls)}`,
  );
  check(
    "their read receipts and per-user settings are gone",
    !(UID in convo.lastReadTimestamps) && !(UID in convo.perUserSettings),
    `got ${JSON.stringify({
      lastRead: convo.lastReadTimestamps,
      settings: convo.perUserSettings,
    })}`,
  );
  check(
    "the other members' entries in every map are untouched",
    convo.participantDisplayNames[OTHER] === "Anna" &&
      convo.participantAvatarUrls[OTHER] === "https://example.test/anna.jpg" &&
      convo.lastReadTimestamps[OTHER] === 2,
    `got ${JSON.stringify(convo.participantDisplayNames)}`,
  );
  check(
    "the embedded lastMessage copy is tombstoned like the message row",
    convo.lastMessage.senderId === "deleted" &&
      convo.lastMessage.senderDisplayName === "[Raderad användare]" &&
      convo.lastMessage.senderAvatarUrl === null &&
      convo.lastMessage.content === "[Borttaget meddelande]",
    `got ${JSON.stringify(convo.lastMessage)}`,
  );
}

/** A lastMessage written by someone else must survive the departure intact. */
async function scenario_anotherMembersLastMessageIsNotTombstoned(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-group", {
    participantIds: [UID, OTHER, THIRD],
    participantDisplayNames: { [UID]: "Malin", [OTHER]: "Anna" },
    lastMessage: {
      senderId: OTHER,
      senderDisplayName: "Anna",
      content: "Jag handlar imorgon",
    },
  });

  await deleteMessages(asDb(db), UID);

  const convo = db.get("conversations/c-group") as Record<
    string,
    Record<string, unknown>
  >;
  check(
    "another member's lastMessage preview is left alone",
    convo.lastMessage.senderId === OTHER &&
      convo.lastMessage.content === "Jag handlar imorgon",
    `got ${JSON.stringify(convo.lastMessage)}`,
  );
}

/**
 * Firestore does not cascade a document delete to its subcollections. Deleting
 * the parent menu bare leaves `presence/{uid}` (which carries a displayName)
 * and `votes/{voteId}` (whose `votes` map is keyed by uid) permanently
 * orphaned: unreadable by any client, unfindable by any later erasure, and
 * invisible to a residual probe that counts top-level documents.
 */
async function scenario_ownedRealtimeMenuChildrenAreDeleted(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/mine", { ownerId: UID, participantIds: [UID, OTHER] });
  db.set("realtime_menus/mine/presence/" + UID, {
    displayName: "Malin",
    isActive: true,
  });
  db.set("realtime_menus/mine/votes/slot-1", {
    votes: { [UID]: "option-a", [OTHER]: "option-b" },
  });

  await deleteRealtimeMenus(asDb(db), UID);

  check(
    "the owned menu document is deleted",
    !db.has("realtime_menus/mine"),
  );
  check(
    "its presence subcollection goes with it",
    db.pathsUnder("realtime_menus/mine/presence").length === 0,
    `left behind: ${JSON.stringify(db.pathsUnder("realtime_menus/mine/presence"))}`,
  );
  check(
    "its votes subcollection goes with it",
    db.pathsUnder("realtime_menus/mine/votes").length === 0,
    `left behind: ${JSON.stringify(db.pathsUnder("realtime_menus/mine/votes"))}`,
  );
}

/**
 * The third residual on this surface, and the one `scrubLastEditor` cannot
 * reach: a collaborator who joined, was seen and voted but never made the final
 * edit. Their presence document, their `participants` MAP KEY (which
 * `firestore.rules` reads as live write authorization) and their ballot entry
 * all sat on someone else's menu indefinitely.
 */
async function scenario_realtimeParticipationIsRemoved(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/theirs", {
    ownerId: OTHER,
    participantIds: [OTHER, UID],
    participants: { [OTHER]: "owner", [UID]: "editor" },
    lastEditedBy: OTHER,
    lastEditedByDisplayName: "Anna",
  });
  db.set("realtime_menus/theirs/presence/" + UID, { displayName: "Malin" });
  db.set("realtime_menus/theirs/presence/" + OTHER, { displayName: "Anna" });
  db.set("realtime_menus/theirs/votes/slot-1", {
    votes: { [UID]: "option-a", [OTHER]: "option-b" },
  });

  await deleteRealtimeMenus(asDb(db), UID);

  const menu = db.get("realtime_menus/theirs") as DocData;
  check(
    "someone else's menu still exists — it is their data",
    menu !== undefined && menu.ownerId === OTHER,
  );
  check(
    "the deleted user is removed from participantIds",
    JSON.stringify(menu.participantIds) === JSON.stringify([OTHER]),
    `got ${JSON.stringify(menu.participantIds)}`,
  );
  check(
    "their participants MAP KEY — a live write grant — is removed",
    !(UID in (menu.participants as Record<string, unknown>)),
    `got ${JSON.stringify(menu.participants)}`,
  );
  check(
    "their presence document is deleted, the other member's is not",
    !db.has(`realtime_menus/theirs/presence/${UID}`) &&
      db.has(`realtime_menus/theirs/presence/${OTHER}`),
    `left: ${JSON.stringify(db.pathsUnder("realtime_menus/theirs/presence"))}`,
  );
  const ballot = (db.get("realtime_menus/theirs/votes/slot-1") as DocData)
    .votes as Record<string, unknown>;
  check(
    "their uid is stripped from the vote map, the other vote is kept",
    !(UID in ballot) && ballot[OTHER] === "option-b",
    `got ${JSON.stringify(ballot)}`,
  );
}

/**
 * BUT-1789: the per-user-per-day feature-retention rows must go, and only
 * those.
 *
 * `analytics/feature_retention/users/{uid}_{date}` held one behavioural row per
 * active day — cooked / imported / shared / meal-planned / shopped — with the
 * uid in both the id and a `userId` field, and no step, TTL or deviation entry
 * covering it. Three properties, all of which a wrong implementation gets
 * wrong in a different way:
 *
 *   - EVERY day of the deleted user goes, not just the newest (the rows
 *     accumulate for the life of the account);
 *   - another user's row on the same day survives (a prefix/`listDocuments`
 *     sweep of the whole subcollection would take it);
 *   - the `daily/{date}` aggregate survives (integer counts, no uid — the
 *     accepted residual; deleting it would destroy other people's history).
 */
async function scenario_featureRetentionRowsAreErased(): Promise<void> {
  const db = new FakeFirestore();
  const row = (uid: string, date: string) =>
    db.set(`analytics/feature_retention/users/${uid}_${date}`, {
      userId: uid,
      date,
      cooked: true,
      imported: false,
      shared: false,
      mealPlanned: false,
      shopped: true,
    });
  row(UID, "2026-04-27");
  row(UID, "2026-04-28");
  row(UID, "2026-04-29");
  row(OTHER, "2026-04-29");
  db.set("analytics/feature_retention/daily/2026-04-29", {
    date: "2026-04-29",
    dau: { cooked: 2, imported: 0, shared: 0, mealPlanned: 0, shopped: 2 },
  });

  const { deleteFeatureRetentionFlags } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await deleteFeatureRetentionFlags(asDb(db), UID);

  const left = db.pathsUnder("analytics/feature_retention/users");
  check(
    "every feature-retention day of the deleted user is erased",
    left.every((p) => !p.includes(`/${UID}_`)),
    `left: ${JSON.stringify(left)}`,
  );
  check(
    "another user's row for the same day is untouched",
    db.has(`analytics/feature_retention/users/${OTHER}_2026-04-29`),
    `left: ${JSON.stringify(left)}`,
  );
  check(
    "the anonymous daily aggregate is kept (accepted residual)",
    db.has("analytics/feature_retention/daily/2026-04-29"),
    `daily left: ${JSON.stringify(
      db.pathsUnder("analytics/feature_retention/daily"),
    )}`,
  );
}

/**
 * BUT-1800. `analytics/retention/events` and `analytics/lapsed_users/events`
 * were left out of BUT-1789's scope.
 * Both carry `userId`; the second has AUTO ids, so it can only be reached by a
 * field query — a doc-id form would find nothing and look exactly like
 * "nothing to delete".
 */
async function scenario_retentionAnalyticsRowsAreErased(): Promise<void> {
  const db = new FakeFirestore();
  const retention = (uid: string, day: number) =>
    db.set(`analytics/retention/events/${uid}_d${day}`, {
      userId: uid,
      day,
      wasActive: true,
      lifecycleStage: "active",
    });
  retention(UID, 1);
  retention(UID, 7);
  retention(OTHER, 7);
  // Auto ids, exactly as `detect-lapsed-users.ts` writes them: the id says
  // nothing about the subject, so only `userId` can find these.
  db.set("analytics/lapsed_users/events/aUtOiD1", {
    userId: UID,
    daysInactive: 30,
    notificationSent: true,
  });
  db.set("analytics/lapsed_users/events/aUtOiD2", {
    userId: OTHER,
    daysInactive: 30,
    notificationSent: true,
  });

  const { deleteRetentionAnalytics } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await deleteRetentionAnalytics(asDb(db), UID);

  const retentionLeft = db.pathsUnder("analytics/retention/events");
  check(
    "every retention event of the deleted user is erased",
    retentionLeft.every((p: string) => !p.includes(`/${UID}_`)),
    `left: ${JSON.stringify(retentionLeft)}`,
  );
  check(
    "another user's retention event for the same day is untouched",
    db.has(`analytics/retention/events/${OTHER}_d7`),
    `left: ${JSON.stringify(retentionLeft)}`,
  );

  const lapsedLeft = db.pathsUnder("analytics/lapsed_users/events");
  check(
    "the deleted user's auto-id lapsed row is erased despite its opaque id",
    !db.has("analytics/lapsed_users/events/aUtOiD1"),
    `left: ${JSON.stringify(lapsedLeft)}`,
  );
  check(
    "another user's lapsed row is untouched",
    db.has("analytics/lapsed_users/events/aUtOiD2"),
    `left: ${JSON.stringify(lapsedLeft)}`,
  );
}

/**
 * The probe leg for the two analytics parents. Without this the leg is
 * decoration: `batchDeleteAll` commits non-strict, so a swallowed chunk failure
 * leaves rows behind while `deleteRetentionAnalytics` still returns true — the
 * probe is the only thing that can contradict it.
 *
 * Both parents separately, because a probe that catches one and misses the
 * other still certifies a bad erasure clean.
 */
async function scenario_probeSeesLeftoverRetentionAnalytics(): Promise<void> {
  const { probeResidualData, RETENTION_ANALYTICS_PARENTS } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");

  // The deleter's own list, not a copy: a third parent added to the const must
  // widen this scenario too, or the probe silently under-covers it.
  for (const parent of RETENTION_ANALYTICS_PARENTS) {
    const clean = new FakeFirestore();
    clean.set(`analytics/${parent}/events/somebodyElse`, { userId: OTHER });
    const cleanResult = {
      deletedCollections: [],
      failedCollections: [] as string[],
      errors: [],
    };
    await probeResidualData(asDb(clean), UID, cleanResult);
    check(
      `another user's ${parent} row is not this user's residual`,
      !cleanResult.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
    );

    const dirty = new FakeFirestore();
    dirty.set(`analytics/${parent}/events/mine`, { userId: UID });
    const dirtyResult = {
      deletedCollections: [],
      failedCollections: [] as string[],
      errors: [],
    };
    await probeResidualData(asDb(dirty), UID, dirtyResult);
    check(
      `a leftover ${parent} row is reported as residual data`,
      dirtyResult.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
    );
  }
}

/**
 * The "nothing to delete" case: the step must still report success. An empty
 * query is knowledge, not a failure.
 */
async function scenario_retentionAnalyticsWithNoRowsSucceeds(): Promise<void> {
  const db = new FakeFirestore();
  db.set("analytics/retention/events/someoneElse_d1", { userId: OTHER, day: 1 });

  const { deleteRetentionAnalytics } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  const ok = await deleteRetentionAnalytics(asDb(db), UID);

  check("a user with no analytics rows still reports success", ok === true, `got ${ok}`);
  check(
    "and nobody else's rows were swept",
    db.has("analytics/retention/events/someoneElse_d1"),
    "other user's row vanished",
  );
}

/**
 * BUT-1798. `removeFromSharedContent` discovered membership ONLY through a
 * `members/{uid}` subcollection doc, which is written by
 * `BaseSharedContentRepository.addMember()` and by nothing else. The three
 * direct-share managers (recipe_sharing_manager, social_menu_operations,
 * shopping_social_share_module) write the parent document only — so every
 * recipient of an ad-hoc shared recipe, menu or list has been un-erasable for
 * this collection's entire life, on documents the Art. 15 export has just
 * started returning.
 *
 * The further trap this pins: the owner is always in their own membership
 * array, so scrubbing without excluding owned docs would update every document
 * the very next step hard-deletes — wasted writes, and a NOT_FOUND poison-pill
 * on retry.
 *
 * Membership was briefly stored under two spellings, and this scenario used to
 * prove both were cleared. Retired 2026-08-03: with only test data there was
 * nothing for the second field to protect, and two copies of one fact could
 * only drift.
 */
async function scenario_adHocSharedContentMembershipIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();

  // A share the deleted user received, alongside a third party who must survive.
  db.set("shared_content/three-way-recipe", {
    contentType: "recipe",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID, THIRD],
  });
  // A plain two-person share.
  db.set("shared_content/current-recipe", {
    contentType: "recipe",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
  });
  // Owned by the deleted user AND listing them as a recipient — the normal
  // shape, since the writer puts the sharer in their own arrays.
  db.set("shared_content/owned-by-deleted", {
    contentType: "recipe",
    sharedByUserId: UID,
    sharedToUserIds: [UID, OTHER],
  });
  // Someone else's share, no relation to the deleted user.
  db.set("shared_content/unrelated", {
    contentType: "menu",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, THIRD],
  });

  const { removeFromSharedContent } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await removeFromSharedContent(asDb(db), UID);

  const threeWay = db.get("shared_content/three-way-recipe") as DocData;
  check(
    "an ad-hoc share the deleted user RECEIVED is reached at all",
    !(threeWay.sharedToUserIds as string[]).includes(UID),
    `left: ${JSON.stringify(threeWay.sharedToUserIds)}`,
  );
  check(
    "the other two members of that share are untouched",
    (threeWay.sharedToUserIds as string[]).length === 2,
    `left: ${JSON.stringify(threeWay.sharedToUserIds)}`,
  );

  const current = db.get("shared_content/current-recipe") as DocData;
  check(
    "the membership field is cleared on a plain two-person share",
    !(current.sharedToUserIds as string[]).includes(UID),
    `to: ${JSON.stringify(current.sharedToUserIds)}`,
  );

  check(
    "content OWNED by the deleted user is deleted outright",
    !db.has("shared_content/owned-by-deleted"),
    `still present: ${JSON.stringify(db.get("shared_content/owned-by-deleted"))}`,
  );
  // The check above passes even without the owner-skip, because the delete runs
  // last either way. THIS is the one that pins the skip: a real batch.update on
  // a doc that is about to be deleted throws NOT_FOUND and takes the whole
  // chunk down on retry, so the owned doc must never be written at all.
  check(
    "…and is never written on the way there (the NOT_FOUND poison-pill)",
    !db.updatedPaths.includes("shared_content/owned-by-deleted"),
    `wrote: ${JSON.stringify(db.updatedPaths)}`,
  );

  const unrelated = db.get("shared_content/unrelated") as DocData;
  check(
    "an unrelated share between two other people is left alone",
    (unrelated.sharedToUserIds as string[]).length === 2,
    `to: ${JSON.stringify(unrelated.sharedToUserIds)}`,
  );
}

/**
 * BUT-1788. The departure callable writes "<Name> har lämnat gruppen" under
 * `senderId: "system"` into a group the user has since LEFT. Three separate
 * legs of this cascade miss it: the `senderId == uid` sweep (wrong author), the
 * `lastMessage` tombstone (only fires when the user is the SENDER), and the
 * `participantIds array-contains uid` query (they are no longer a participant,
 * so the conversation is never even visited). `metadata.subjectUserId` is the
 * only queryable handle on a name embedded in free text.
 */
async function scenario_systemMessageAboutDepartedUserIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();
  // The user is NOT in participantIds — they left. This is the whole point:
  // every other leg of deleteMessages skips this conversation entirely.
  db.set("conversations/c-left", {
    participantIds: [OTHER, THIRD],
    lastMessage: {
      senderId: "system",
      senderDisplayName: "System",
      content: "Malin har lämnat gruppen",
    },
  });
  db.set("messages/sys-left", {
    conversationId: "c-left",
    senderId: "system",
    senderDisplayName: "System",
    content: "Malin har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: UID },
  });
  // A system row about SOMEONE ELSE, in the same collection, must survive.
  db.set("messages/sys-other", {
    conversationId: "c-left",
    senderId: "system",
    senderDisplayName: "System",
    content: "Anna har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: OTHER },
  });

  await deleteMessages(asDb(db), UID);

  const scrubbed = db.get("messages/sys-left");
  check(
    "the departure row about the deleted user is tombstoned",
    scrubbed?.content === "[Borttaget meddelande]",
    `content: ${String(scrubbed?.content)}`,
  );
  check(
    "the erasure handle itself is cleared so the probe reads zero",
    (scrubbed?.metadata as Record<string, unknown> | undefined)
      ?.subjectUserId === undefined,
    `metadata: ${JSON.stringify(scrubbed?.metadata)}`,
  );
  check(
    "the denormalized lastMessage copy is tombstoned too",
    (db.get("conversations/c-left")?.lastMessage as Record<string, unknown>)
      ?.content === "[Borttaget meddelande]",
  );
  check(
    "a departure row about ANOTHER user is untouched",
    db.get("messages/sys-other")?.content === "Anna har lämnat gruppen",
  );
}

/**
 * The mirror must only be rewritten when it is still SHOWING the row being
 * erased — a newer message may have replaced the preview, and blindly stamping
 * the tombstone would erase that message's copy instead.
 */
async function scenario_newerLastMessageSurvivesTheSystemScrub(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-left", {
    participantIds: [OTHER, THIRD],
    lastMessage: {
      senderId: OTHER,
      senderDisplayName: "Anna",
      content: "Vi ses på lördag",
    },
  });
  db.set("messages/sys-left", {
    conversationId: "c-left",
    senderId: "system",
    content: "Malin har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: UID },
  });

  await deleteMessages(asDb(db), UID);

  check(
    "a newer preview from another member is left alone",
    (db.get("conversations/c-left")?.lastMessage as Record<string, unknown>)
      ?.content === "Vi ses på lördag",
  );
  check(
    "the system row is still tombstoned",
    db.get("messages/sys-left")?.content === "[Borttaget meddelande]",
  );
}

/**
 * A Firestore whose transaction on a NAMED conversation always throws — the
 * ordinary transient outcome on a live group (contention, DEADLINE_EXCEEDED).
 * Everything else behaves exactly like FakeFirestore.
 */
class FlakyMirrorFirestore extends FakeFirestore {
  constructor(private readonly failingPaths: Set<string>) {
    super();
  }

  async runTransaction<T>(
    handler: (tx: {
      get: (
        ref: { path: string },
      ) => Promise<{ exists: boolean; data: () => DocData | undefined }>;
      update: (ref: { path: string }, data: DocData) => void;
      delete: (ref: { path: string }) => void;
    }) => Promise<T>,
  ): Promise<T> {
    return super.runTransaction((tx) =>
      handler({
        ...tx,
        get: async (ref: { path: string }) => {
          if (this.failingPaths.has(ref.path)) {
            throw Object.assign(new Error("ABORTED: too much contention"), {
              code: 10,
            });
          }
          return tx.get(ref as never);
        },
      } as never),
    );
  }
}

/**
 * BUT-1788, the ordering half. `metadata.subjectUserId` is the ONLY handle that
 * finds these rows again, and the mirror scrub's failure is swallowed on
 * purpose. Clearing the handle in the same write that tombstones the content —
 * i.e. BEFORE the mirror — made a transient mirror failure permanent and
 * quadruple-silent: the mirror keeps the deleted user's name, a re-run
 * early-exits on an empty query, `probeResidualData` (keyed on that same field)
 * counts zero and certifies a clean erasure, and the callable still answers
 * `success: true`. Nothing heals it later — `syncConversationLastMessage`
 * triggers on message create/delete, never on update.
 *
 * The codebase's own recorded rule: a cascade step keyed on a shared handle
 * must destroy that handle LAST.
 */
async function scenario_failedMirrorScrubKeepsTheRetryHandle(): Promise<void> {
  const db = new FlakyMirrorFirestore(new Set(["conversations/c-flaky"]));
  db.set("conversations/c-flaky", {
    participantIds: [OTHER, THIRD],
    lastMessage: {
      senderId: "system",
      senderDisplayName: "System",
      content: "Malin har lämnat gruppen",
    },
  });
  db.set("messages/sys-flaky", {
    conversationId: "c-flaky",
    senderId: "system",
    content: "Malin har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: UID },
  });
  // A second conversation whose mirror scrub SUCCEEDS, in the same run: one bad
  // conversation must not hold back the rest.
  db.set("conversations/c-ok", {
    participantIds: [OTHER, THIRD],
    lastMessage: {
      senderId: "system",
      senderDisplayName: "System",
      content: "Malin har lämnat gruppen",
    },
  });
  db.set("messages/sys-ok", {
    conversationId: "c-ok",
    senderId: "system",
    content: "Malin har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: UID },
  });

  await deleteMessages(asDb(db), UID);

  const flaky = db.get("messages/sys-flaky");
  check(
    "a row whose mirror scrub failed KEEPS its erasure handle",
    (flaky?.metadata as Record<string, unknown> | undefined)?.subjectUserId ===
      UID,
    `metadata: ${JSON.stringify(flaky?.metadata)}`,
  );
  check(
    "…and keeps its original content, so the retry can match the mirror again",
    flaky?.content === "Malin har lämnat gruppen",
    `content: ${String(flaky?.content)}`,
  );
  check(
    "a row whose mirror scrub SUCCEEDED is fully cleared in the same run",
    db.get("messages/sys-ok")?.content === "[Borttaget meddelande]" &&
      (db.get("messages/sys-ok")?.metadata as Record<string, unknown>)
        ?.subjectUserId === undefined,
    `sys-ok: ${JSON.stringify(db.get("messages/sys-ok"))}`,
  );

  // The retry: same data, mirror now healthy. It must converge — which is only
  // possible because the handle survived.
  const healthy = new FakeFirestore();
  for (const path of db.pathsUnder("conversations")) {
    healthy.set(path, db.get(path) as DocData);
  }
  for (const path of db.pathsUnder("messages")) {
    healthy.set(path, db.get(path) as DocData);
  }
  await deleteMessages(asDb(healthy), UID);

  check(
    "the re-run finds the missed row and scrubs the mirror it left behind",
    (healthy.get("conversations/c-flaky")?.lastMessage as Record<
      string,
      unknown
    >)?.content === "[Borttaget meddelande]",
    `lastMessage: ${JSON.stringify(healthy.get("conversations/c-flaky")?.lastMessage)}`,
  );
  check(
    "the re-run then clears the handle it was holding on to",
    (healthy.get("messages/sys-flaky")?.metadata as Record<string, unknown>)
      ?.subjectUserId === undefined &&
      healthy.get("messages/sys-flaky")?.content === "[Borttaget meddelande]",
    `sys-flaky: ${JSON.stringify(healthy.get("messages/sys-flaky"))}`,
  );
  check(
    "the already-clean conversation is not re-tombstoned by the re-run",
    (healthy.get("conversations/c-ok")?.lastMessage as Record<string, unknown>)
      ?.content === "[Borttaget meddelande]",
  );
}

/** Seed one roster row the way `ConversationParticipant.toFirestore` writes it. */
function seedRosterRow(
  db: FakeFirestore,
  conversationId: string,
  uid: string,
  displayName: string,
): void {
  db.set(`conversations/${conversationId}/participants/${uid}`, {
    conversationId,
    participantId: uid,
    displayName,
    avatarUrl: `https://example.test/${uid}.jpg`,
    role: "member",
    isMuted: false,
  });
}

/**
 * BUT-1822 leg 2: the erased user's OWN roster row, in a surviving group. It
 * carries their displayName and avatarUrl, and nothing in the cascade had ever
 * touched this path — the conversation document keeps running for everyone else,
 * so there is no later erasure that could find it.
 */
async function scenario_ownRosterRowIsErasedInSurvivingGroup(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-group", {
    participantIds: [UID, OTHER, "third-uid"],
    participantDisplayNames: { [UID]: "Raderad", [OTHER]: "Kvar" },
  });
  seedRosterRow(db, "c-group", UID, "Raderad");
  seedRosterRow(db, "c-group", OTHER, "Kvar");

  await deleteMessages(asDb(db), UID);

  check(
    "the erased user's roster row is deleted from a surviving group",
    !db.has(`conversations/c-group/participants/${UID}`),
  );
  check(
    "another member's roster row is untouched",
    db.has(`conversations/c-group/participants/${OTHER}`),
  );
  check(
    "the surviving group document itself is kept",
    db.has("conversations/c-group"),
  );
}

/**
 * BUT-1822 leg 1, and the ordering it turns on. Deleting the conversation is the
 * write that makes `parentDoc() == null` true, and every predicate that could
 * surface a row reads through the parent — so whatever rows survive become
 * UNREADABLE forever (delete and the `lastReadAt` stamp key on the subject's
 * own uid, and no client flow uses either). The SURVIVING partner's row is
 * the one that matters: its `participantId` is not the erased uid, so leg 2's
 * collection-group sweep can never reach it either. Until BUT-1838 this was worse
 * than unreachable — a bootstrap branch re-opened those rows to any signed-in
 * user, so the partner kept LIST over the erased user's name and avatar forever.
 *
 * Asserting only "both are gone" would pass on the broken code too, since the
 * sweep would still take the erased user's own row. The ORDER is the test.
 */
async function scenario_rosterIsClearedBeforeTheParentDelete(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/direct_a_b", { participantIds: [UID, OTHER] });
  seedRosterRow(db, "direct_a_b", UID, "Raderad");
  seedRosterRow(db, "direct_a_b", OTHER, "Partner");

  await deleteMessages(asDb(db), UID);

  check(
    "the 1:1 conversation is gone",
    !db.has("conversations/direct_a_b"),
  );
  check(
    "the SURVIVING partner's roster row is gone too (no collectionGroup leg can find it)",
    !db.has(`conversations/direct_a_b/participants/${OTHER}`),
    `left: ${JSON.stringify(db.pathsUnder("conversations/direct_a_b/participants"))}`,
  );
  const parentAt = db.deletedPaths.indexOf("conversations/direct_a_b");
  const partnerAt = db.deletedPaths.indexOf(
    `conversations/direct_a_b/participants/${OTHER}`,
  );
  check(
    "the roster row is deleted BEFORE the parent document",
    partnerAt >= 0 && parentAt >= 0 && partnerAt < parentAt,
    `delete order: ${JSON.stringify(db.deletedPaths)}`,
  );
}

/**
 * When the roster cannot be proven clear, `tryClearRoster` returns false and the
 * parent must NOT be deleted — a live parent that no longer names the erased
 * user still lets the SURVIVING partner list what is left — the read rule is
 * not row-scoped and `buildGroupDepartureUpdate` only `arrayRemove`s the erased
 * uid — which is acceptable because leg 2 sweeps the erased user's own row.
 * Deleting the parent instead makes every row unreadable
 * forever (and, until BUT-1838, re-opened a bootstrap branch over them). But an untouched document keeps their name in
 * `participantDisplayNames` forever, so the departure update runs instead.
 *
 * Staged SYNTHETICALLY, via the clearer's refusal cap — the cheapest way to
 * force a false verdict. Production does NOT reach the branch that way for a
 * direct conversation: only the two attested participants may write rows, and
 * `directIdBinds` pins `participantIds` to exactly two with the update rule
 * denying any diff that touches it — so such a roster holds at most TWO
 * client-written rows, ever, which can never reach the refusal cap. For a
 * `direct_` id the real route is therefore a transient roster read or delete
 * failure; a LEGACY non-direct conversation reaches this branch too and can hit
 * the cap through rows seeded before BUT-1838.
 */
async function scenario_unclearableRosterLeavesTheParentStanding(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/direct_seeded", {
    participantIds: [UID, OTHER],
    participantDisplayNames: { [UID]: "Raderad", [OTHER]: "Partner" },
    participantAvatarUrls: { [UID]: "https://example.test/x.jpg" },
  });
  seedRosterRow(db, "direct_seeded", UID, "Raderad");
  seedRosterRow(db, "direct_seeded", OTHER, "Partner");
  // 500 is MAX_ROSTER_ROWS; the read is `.limit(MAX + 1)`, so 501 rows is the
  // smallest roster the clearer refuses.
  for (let i = 0; i < 499; i++) {
    seedRosterRow(db, "direct_seeded", `seeded-${i}`, `Seeded ${i}`);
  }

  const ok = await deleteMessages(asDb(db), UID);

  check(
    "an unclearable roster leaves the conversation standing",
    db.has("conversations/direct_seeded"),
  );
  check(
    "…and the step reports INCOMPLETE, so the audit cannot say gdprCompliant",
    ok === false,
    // A `direct_` id is literally `direct_<erasedUid>_<survivorUid>`: the
    // surviving document keeps the erased user's identifier in its own id,
    // where no field-keyed probe can see it. Reporting success here would
    // certify an erasure that did not happen.
    `deleteMessages returned ${ok}`,
  );
  // `?? {}` deliberately: the failure this scenario guards against is the
  // conversation being DELETED, and reading through an absent document would
  // throw a TypeError that kills the whole runner instead of reddening one
  // assertion.
  const convo = (db.get("conversations/direct_seeded") ?? {}) as DocData;
  // Mutation-proven, with one honest caveat: this single assertion passes
  // VACUOUSLY if the conversation is deleted instead (an absent document has no
  // name to find), so it is the two below — participantIds present-and-cleaned,
  // and the partner's name still there — that catch a wrongly-deleted parent.
  // Do not "simplify" them away as redundant; each of the three reddens under a
  // different mutant.
  check(
    "…but the erased user's name is stripped from it anyway",
    (convo.participantDisplayNames as DocData)?.[UID] === undefined &&
      (convo.participantAvatarUrls as DocData)?.[UID] === undefined,
    `left: ${JSON.stringify(convo.participantDisplayNames)}`,
  );
  check(
    "…and their participantIds entry is removed",
    Array.isArray(convo.participantIds) &&
      !(convo.participantIds as string[]).includes(UID),
    `participantIds: ${JSON.stringify(convo.participantIds)}`,
  );
  check(
    "the partner's name is kept — it is not theirs to erase",
    (convo.participantDisplayNames as DocData)?.[OTHER] === "Partner",
  );
}

/**
 * The residual probe is the safety net for this whole class of gap: the deleter
 * must stay a strict superset of it. Before BUT-1822 the probe had NO
 * collection-group leg for `participants`, so it certified every erasure clean
 * over live roster rows — and this file tested none of `probeResidualData`.
 *
 * A clean store is asserted first. Without it, a stub method the probe needs but
 * does not have would land in one of its per-leg catches, count as residual, and
 * make the second half of this scenario pass for the wrong reason.
 */
async function scenario_probeSeesLeftoverRosterRows(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  clean.set("conversations/c-group", { participantIds: [OTHER] });
  const cleanResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a store with nothing of the user's left probes CLEAN",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set("conversations/c-group", { participantIds: [OTHER] });
  seedRosterRow(dirty, "c-group", UID, "Raderad");
  const dirtyResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "one leftover roster row is reported as residual data",
    dirtyResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );
}

/**
 * BUT-1971: the three group-weekly-menu legs of the residual probe.
 *
 * The deleter finds a group plan through three handles — the queryable roster,
 * the document-level `lastModifiedBy`, and the ACL key
 * `memberPermissions.<uid>` — because the Art. 15 export discovers on the last
 * of those and erasure may never be narrower than export. The probe carries the
 * same three, and they are the only thing that contradicts a scrub which
 * reported success over a failed chunk (`commitInChunks` runs `strict: false`).
 *
 * Nothing observed them. The integration lane asserts `failedCollections` is
 * EMPTY, so deleting any one leg makes the probe blind and the assertion
 * happier, not redder. Each case below seeds a document reachable by exactly
 * ONE handle, so removing that leg leaves its case green-expected-red.
 *
 * The ACL leg is queried with a `FieldPath`, which the fake resolves via
 * `.segments`; teaching it to is what makes that case measure the leg rather
 * than the stub. Each of the three legs was mutation-probed with a compiling
 * mutant and its own case reddened alone.
 *
 * The clean control is weaker here than beside the roster scenario, and that is
 * worth knowing rather than assuming: a fake that mis-resolves a `FieldPath`
 * matches nothing instead of throwing, so it produces a silent zero, and only
 * the DIRTY ACL case can see that. Measured — the control stays green under
 * that mutant. It still earns its place for the roster scenario's reason: a
 * method the probe needs but the fake lacks lands in a per-leg catch and counts
 * as residual, which would make every dirty half pass for the wrong reason.
 */
async function scenario_probeSeesLeftoverGroupMenuPlans(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const result = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  });

  // All three handles are clean while the uid is still on the per-dish
  // provenance and in the trail, so the probe reads CLEAN over data that is
  // present. The two rows are projections, not what `toFirestore` writes: the
  // probe reads neither field, and only their presence matters here.
  const clean = new FakeFirestore();
  clean.set("group_weekly_menu_plans/g1_2026-W30", {
    participantUserIds: [OTHER],
    memberPermissions: { [OTHER]: "admin" },
    lastModifiedBy: OTHER,
    entries: [{ id: "e1", proposedBy: UID, votedInBy: [UID, OTHER] }],
    editTrail: [{ actorId: UID, subjectId: OTHER, entryId: "e1" }],
  });
  const cleanResult = result();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a group menu plan clean on all three handles probes CLEAN — even with the " +
      "uid still on the dishes and in the trail, which no handle can reach",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  // Each case is spelled out whole rather than spread over a shared base: a
  // spread that overwrites an earlier key is a TS2783 error, and silencing it
  // by reordering is how a case ends up seeding a handle it did not mean to.
  for (const [label, doc] of [
    [
      "the roster",
      {
        participantUserIds: [OTHER, UID],
        memberPermissions: { [OTHER]: "admin" },
        lastModifiedBy: OTHER,
      },
    ],
    [
      "the last writer",
      {
        participantUserIds: [OTHER],
        memberPermissions: { [OTHER]: "admin" },
        lastModifiedBy: UID,
      },
    ],
    [
      "the permission key",
      {
        participantUserIds: [OTHER],
        memberPermissions: { [OTHER]: "admin", [UID]: "edit" },
        lastModifiedBy: OTHER,
      },
    ],
  ] as const) {
    const dirty = new FakeFirestore();
    dirty.set("group_weekly_menu_plans/g1_2026-W30", doc);
    const dirtyResult = result();
    await probeResidualData(asDb(dirty), UID, dirtyResult);
    check(
      `a group menu plan still naming the user in ${label} is reported as residual`,
      dirtyResult.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
    );
  }
}

/**
 * BUT-1801: the recipes leg of the residual probe.
 *
 * Until this fix, `probeResidualData` counted `recipes` as a TOP-LEVEL collection
 * filtered by a `userId` field, alongside `user_notifications` and friends. No
 * production writer puts a recipe there — every `FirestoreCollections.recipes`
 * site in `lib/` that builds a path is user-scoped (the one that does not,
 * `recipe_stats_repository`, is a `collectionGroup` read and builds none), and
 * no rule lets a client write the top-level collection — so the count returned
 * zero on every real deletion. The probe certified every erasure clean without ever looking at a
 * recipe, and would have gone on saying so if `deleteRecipes` broke.
 *
 * Note "no production writer", not "no such collection": the Admin SDK needs no
 * rule, and `request-account-deletion.integration.test.ts` plants a document
 * there deliberately to prove the cascade's top-level leg still sweeps it. An
 * earlier draft of this docstring said the collection could not exist, which is
 * the claim that briefly justified deleting that leg.
 *
 * That is the failure mode this scenario exists to make impossible to reintroduce:
 * the dirty half seeds a recipe at the ONLY path recipes live at,
 * `users/{uid}/recipes`, and requires the probe to see it. Point the probe back at
 * the top-level collection and the dirty half goes green — which is the bug.
 *
 * The clean half runs first for the same reason as the roster scenario above: a
 * stub method the probe needs but does not have would land in a per-leg catch,
 * count as residual, and make the dirty half pass for the wrong reason.
 */
async function scenario_probeSeesLeftoverRecipes(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  // Somebody else's recipe. If the probe were user-blind — a collection-group
  // sweep with no uid scoping, say — this is what would make it cry wolf.
  clean.set(`users/${OTHER}/recipes/r-other`, { core: { title: "Pannkakor" } });
  const cleanResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "another user's recipes do not read as residual for this user",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set(`users/${OTHER}/recipes/r-other`, { core: { title: "Pannkakor" } });
  dirty.set(`users/${UID}/recipes/r-mine`, { core: { title: "Köttbullar" } });
  const dirtyResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "one leftover recipe under users/{uid}/recipes is reported as residual data",
    dirtyResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );
}

/**
 * The collection-group query the two legs above depend on needs a declared
 * index; Firestore's automatic single-field indexes cover COLLECTION scope only.
 * Nothing in a stub-backed suite can notice a missing or misspelled one — the
 * query would throw FAILED_PRECONDITION in production, land in the probe's own
 * catch, and be logged as a residual that isn't there.
 *
 * The COLLECTION entry is not optional either: a `fieldOverride` REPLACES the
 * automatic indexing for that field.
 */
async function scenario_rosterIndexIsDeclared(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const config = JSON.parse(
    fs.readFileSync(
      path.join(__dirname, "..", "..", "..", "firestore.indexes.json"),
      "utf8",
    ),
  ) as {
    fieldOverrides?: {
      collectionGroup: string;
      fieldPath: string;
      indexes: { order?: string; queryScope: string }[];
    }[];
  };
  const entry = (config.fieldOverrides ?? []).find(
    (o) => o.collectionGroup === "participants" && o.fieldPath === "participantId",
  );
  check(
    "firestore.indexes.json declares the participants/participantId override",
    entry !== undefined,
  );
  const scopes = (entry?.indexes ?? [])
    .filter((i) => i.order === "ASCENDING")
    .map((i) => i.queryScope);
  check(
    "…for COLLECTION_GROUP scope, which the cascade's sweep and probe query",
    scopes.includes("COLLECTION_GROUP"),
    `scopes: ${JSON.stringify(scopes)}`,
  );
  check(
    "…and for COLLECTION scope, which the override would otherwise remove",
    scopes.includes("COLLECTION"),
    `scopes: ${JSON.stringify(scopes)}`,
  );
}

// ─── BUT-1838: chat-group membership ──────────────────────────────────────

/**
 * Seeds a chat group the way `groups/chat-group-writes.ts` writes one: the group
 * document, its conversation (carrying `groupId`, which is what marks the
 * conversation group-owned), a roster row per member and each member's
 * conversation-membership mirror. Every uid-keyed carrier is populated, because
 * an assertion that a key is GONE proves nothing over a key that was never there.
 */
function seedChatGroup(
  db: FakeFirestore,
  groupId: string,
  conversationId: string,
  opts: {
    members: string[];
    admins: string[];
    createdBy: string;
    addedBy?: string;
  },
): void {
  const { members, admins, createdBy } = opts;
  const addedBy = opts.addedBy ?? createdBy;
  const perUid = <T>(value: (uid: string) => T): Record<string, T> =>
    Object.fromEntries(members.map((uid) => [uid, value(uid)]));

  db.set(`chat_groups/${groupId}`, {
    name: "Familjen",
    memberIds: [...members],
    adminIds: [...admins],
    memberDisplayNames: perUid((uid) => (uid === UID ? "Raderad" : `Namn ${uid}`)),
    memberAvatarUrls: perUid((uid) => `https://example.test/${uid}.jpg`),
    memberAddedBy: perUid(() => addedBy),
    conversationId,
    createdBy,
    createdAt: "t0",
    updatedAt: "t0",
  });
  db.set(`conversations/${conversationId}`, {
    participantIds: [...members],
    participantDisplayNames: perUid((uid) =>
      uid === UID ? "Raderad" : `Namn ${uid}`,
    ),
    participantAvatarUrls: perUid((uid) => `https://example.test/${uid}.jpg`),
    lastReadTimestamps: perUid(() => "t0"),
    perUserSettings: perUid(() => ({ isMuted: false })),
    memberSince: perUid(() => "t0"),
    groupId,
    isGroup: true,
    title: "Familjen",
  });
  for (const uid of members) {
    seedRosterRow(db, conversationId, uid, uid === UID ? "Raderad" : `Namn ${uid}`);
    db.set(`users/${uid}/conversation_memberships/${conversationId}`, {
      conversationId,
    });
  }
}

/** The five uid-keyed maps a conversation document carries. */
const CONVERSATION_UID_MAPS = [
  "participantDisplayNames",
  "participantAvatarUrls",
  "lastReadTimestamps",
  "perUserSettings",
  "memberSince",
] as const;

/**
 * BUT-1838, the surviving-group case. "Who is in this group" lives in three
 * places (group, conversation, roster row) precisely because three readers need
 * it and none can read the others — so an erasure that clears one and not the
 * others leaves copies that disagree, which is the BUT-1798 failure in a new
 * collection. All three go through the one writer, `stageMemberRemoval`.
 *
 * `memberSince` is the newest of the five conversation maps and the easiest to
 * forget: it is the history cut-off `firestore.rules` reads, and a stale entry
 * would silently pin an old cut-off if the uid were ever reused.
 */
async function scenario_chatGroupMembershipIsErasedEverywhere(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  seedChatGroup(db, "g-keep", "cg-keep", {
    members: [UID, OTHER, THIRD],
    admins: [UID, OTHER],
    createdBy: OTHER,
  });

  const ok = await deleteChatGroupMemberships(asDb(db), UID);
  check("a surviving group reports the step complete", ok === true, `returned ${ok}`);

  const group = (db.get("chat_groups/g-keep") ?? {}) as DocData;
  check(
    "the uid leaves chat_groups.memberIds",
    Array.isArray(group.memberIds) && !(group.memberIds as string[]).includes(UID),
    `memberIds: ${JSON.stringify(group.memberIds)}`,
  );
  check(
    "…and adminIds, so nobody administers a group they are not in",
    Array.isArray(group.adminIds) &&
      !(group.adminIds as string[]).includes(UID) &&
      (group.adminIds as string[]).includes(OTHER),
    `adminIds: ${JSON.stringify(group.adminIds)}`,
  );
  check(
    "…and both group display maps and memberAddedBy",
    (group.memberDisplayNames as DocData)?.[UID] === undefined &&
      (group.memberAvatarUrls as DocData)?.[UID] === undefined &&
      (group.memberAddedBy as DocData)?.[UID] === undefined,
    `left: ${JSON.stringify(group.memberDisplayNames)} / ${JSON.stringify(group.memberAddedBy)}`,
  );
  check(
    "the other members' group entries survive the dot-path deletes",
    (group.memberDisplayNames as DocData)?.[OTHER] !== undefined &&
      (group.memberAddedBy as DocData)?.[THIRD] !== undefined,
    `left: ${JSON.stringify(group.memberDisplayNames)}`,
  );

  const convo = (db.get("conversations/cg-keep") ?? {}) as DocData;
  check(
    "the uid leaves the conversation's participantIds",
    Array.isArray(convo.participantIds) &&
      !(convo.participantIds as string[]).includes(UID),
    `participantIds: ${JSON.stringify(convo.participantIds)}`,
  );
  const stillKeyed = CONVERSATION_UID_MAPS.filter(
    (map) => (convo[map] as DocData)?.[UID] !== undefined,
  );
  check(
    "…and every one of the FIVE uid-keyed conversation maps, memberSince included",
    stillKeyed.length === 0,
    `still keyed by the erased uid: ${JSON.stringify(stillKeyed)}`,
  );
  check(
    "another member keeps all five",
    CONVERSATION_UID_MAPS.every((map) => (convo[map] as DocData)?.[OTHER] !== undefined),
    `partner maps: ${JSON.stringify(CONVERSATION_UID_MAPS.map((m) => (convo[m] as DocData)?.[OTHER]))}`,
  );

  check(
    "the roster row goes with them",
    !db.has(`conversations/cg-keep/participants/${UID}`),
  );
  check(
    "another member's roster row is untouched",
    db.has(`conversations/cg-keep/participants/${OTHER}`),
  );
  check(
    "the group and its conversation keep running for everyone else",
    db.has("chat_groups/g-keep") && db.has("conversations/cg-keep"),
  );
  check(
    "the erased user's conversation-membership mirror is cleared",
    !db.has(`users/${UID}/conversation_memberships/cg-keep`),
  );
}

/**
 * `createdBy` is not membership, so `stageMemberRemoval` does not touch it — and
 * a group the erased user created can outlive them by years. Left alone it is a
 * raw uid on a document other people keep reading, which Art. 17 does not permit
 * and which no field-keyed probe would ever flag once the membership is gone.
 * Same re-homing `deleteFamilyData` already does for households.
 *
 * Three groups, because the rule has three outcomes and a single fixture would
 * pass under two different implementations: prefer a surviving ADMIN (not merely
 * the first survivor), fall back to any survivor when no admin survives, and
 * leave someone else's `createdBy` alone.
 */
async function scenario_createdByIsReHomedWhenTheCreatorIsErased(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  // OTHER sorts first among the survivors but is NOT an admin, so "first
  // survivor" and "surviving admin" give different answers here. That is the
  // discriminator: with a fixture where they agree, the preference is unpinned.
  seedChatGroup(db, "g-admin", "cg-admin", {
    members: [UID, OTHER, THIRD],
    admins: [UID, THIRD],
    createdBy: UID,
  });
  seedChatGroup(db, "g-no-admin", "cg-no-admin", {
    members: [UID, OTHER],
    admins: [UID],
    createdBy: UID,
  });
  seedChatGroup(db, "g-not-mine", "cg-not-mine", {
    members: [UID, OTHER],
    admins: [OTHER],
    createdBy: OTHER,
  });

  await deleteChatGroupMemberships(asDb(db), UID);

  check(
    "createdBy is re-homed to a surviving ADMIN, not merely the first survivor",
    (db.get("chat_groups/g-admin") as DocData)?.createdBy === THIRD,
    `createdBy: ${String((db.get("chat_groups/g-admin") as DocData)?.createdBy)}`,
  );
  check(
    "…falling back to any survivor when no admin survives",
    (db.get("chat_groups/g-no-admin") as DocData)?.createdBy === OTHER,
    `createdBy: ${String((db.get("chat_groups/g-no-admin") as DocData)?.createdBy)}`,
  );
  check(
    "…and someone else's createdBy is left alone",
    (db.get("chat_groups/g-not-mine") as DocData)?.createdBy === OTHER,
    `createdBy: ${String((db.get("chat_groups/g-not-mine") as DocData)?.createdBy)}`,
  );
}

/**
 * The erased user was the LAST member: the group has nobody left, so it goes —
 * and the order is the test, not the end state.
 *
 * Deleting the conversation is the write that makes `parentDoc() == null` true in
 * firestore.rules. With the bootstrap branch gone that no longer re-opens a write
 * path, but the rows would still be orphaned under a parent nobody can produce,
 * carrying names and avatars, which is exactly the residual BUT-1825 exists for.
 * So: roster FIRST, then the thread, then the conversation, then the group.
 *
 * The stale `ghost` row is what makes the ordering observable at all — the erased
 * user's own row goes inside the removal transaction, so a fixture with only that
 * row would leave `tryClearRoster` nothing to delete and nothing to order against.
 * It is also the realistic shape: a row whose owner left without it being cleared.
 */
async function scenario_emptiedChatGroupIsTakenDownRosterFirst(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  seedChatGroup(db, "g-solo", "cg-solo", {
    members: [UID],
    admins: [UID],
    createdBy: UID,
  });
  seedRosterRow(db, "cg-solo", "ghost-uid", "Spöke");
  seedMessage(db, "gm1", "cg-solo", UID);
  seedMessage(db, "gm2", "cg-solo", OTHER);

  const ok = await deleteChatGroupMemberships(asDb(db), UID);
  check("an emptied group reports the step complete", ok === true, `returned ${ok}`);

  check("the group document is deleted", !db.has("chat_groups/g-solo"));
  check("the conversation is deleted", !db.has("conversations/cg-solo"));
  check(
    "the whole thread goes with it, both directions",
    db.idsIn("messages").length === 0,
    `left: ${JSON.stringify(db.idsIn("messages"))}`,
  );
  check(
    "no roster row outlives the parent",
    db.pathsUnder("conversations/cg-solo/participants").length === 0,
    `left: ${JSON.stringify(db.pathsUnder("conversations/cg-solo/participants"))}`,
  );

  const at = (path: string) => db.deletedPaths.indexOf(path);
  const rosterAt = at("conversations/cg-solo/participants/ghost-uid");
  const threadAt = at("messages/gm1");
  const convoAt = at("conversations/cg-solo");
  const groupAt = at("chat_groups/g-solo");
  check(
    "order: roster, then thread, then conversation, then group",
    rosterAt >= 0 &&
      threadAt >= 0 &&
      convoAt >= 0 &&
      groupAt >= 0 &&
      rosterAt < threadAt &&
      threadAt < convoAt &&
      convoAt < groupAt,
    `delete order: ${JSON.stringify(db.deletedPaths)}`,
  );
}

/**
 * The gate. When the roster cannot be proven clear the parent must NOT be
 * deleted — an empty group whose documents linger is untidy, whereas an
 * unreachable set of rows carrying people's names is a disclosure — and the step
 * must report INCOMPLETE rather than certifying an erasure it did not finish.
 *
 * Staged SYNTHETICALLY, via the clearer's refusal cap, which is the cheapest way
 * to force a false verdict. Production reaches it through a transient roster read
 * or delete failure; nothing writes 501 rows to a group conversation.
 */
async function scenario_unclearableRosterLeavesTheChatGroupStanding(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  seedChatGroup(db, "g-shell", "cg-shell", {
    members: [UID],
    admins: [UID],
    createdBy: UID,
  });
  // 500 is MAX_ROSTER_ROWS and the read is `.limit(MAX + 1)`, so 501 rows is the
  // smallest roster the clearer refuses. All 501 are seeded ON TOP of the erased
  // user's own row, because that one is deleted inside the removal transaction
  // BEFORE the clearer ever reads — counting it (as the 1:1 fixture above can)
  // leaves 500 and the clearer succeeds, which is how the first version of this
  // fixture passed while proving nothing.
  for (let i = 0; i < 501; i++) {
    seedRosterRow(db, "cg-shell", `seeded-${i}`, `Seeded ${i}`);
  }

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  check(
    "an unclearable roster leaves the group standing",
    db.has("chat_groups/g-shell"),
  );
  check(
    "…and its conversation standing",
    db.has("conversations/cg-shell"),
  );
  check(
    "…and the step reports INCOMPLETE, so the audit cannot say gdprCompliant",
    ok === false,
    `deleteChatGroupMemberships returned ${ok}`,
  );
  check(
    "…while the membership cut still landed",
    Array.isArray((db.get("chat_groups/g-shell") as DocData)?.memberIds) &&
      ((db.get("chat_groups/g-shell") as DocData).memberIds as string[]).length === 0,
    `memberIds: ${JSON.stringify((db.get("chat_groups/g-shell") as DocData)?.memberIds)}`,
  );
  check(
    "…and the refusal deleted NOTHING — a partial clear is the worst outcome",
    db.has("conversations/cg-shell/participants/seeded-0"),
  );
}

/**
 * Above the cap the sweep DECLINES rather than truncating. A truncated pass that
 * reported success would certify an erasure it did not perform; declining is
 * loud, because the probe leg beside it is an uncapped `count()`.
 */
async function scenario_implausibleChatGroupCountDeclines(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {
    deleteChatGroupMemberships,
    MAX_CHAT_GROUPS_PER_USER,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_CHAT_GROUPS_PER_USER; i++) {
    db.set(`chat_groups/g-${i}`, {
      memberIds: [UID, OTHER],
      adminIds: [OTHER],
      conversationId: `cg-${i}`,
      createdBy: OTHER,
    });
  }

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  check(
    "an implausible chat-group count declines the sweep",
    ok === false,
    `returned ${ok}`,
  );
  check(
    "…without truncating: not one group is touched",
    db.deletedPaths.length === 0 &&
      ((db.get("chat_groups/g-0") as DocData).memberIds as string[]).includes(UID),
    `deleted: ${JSON.stringify(db.deletedPaths)}`,
  );
}

/**
 * BUT-1856: the departure tombstone is a raw uid the membership sweep cannot
 * reach.
 *
 * `departedUserIds` records who left a chat group so the meal-vote category sync
 * will not seat them again. The sweep above finds groups by `memberIds
 * array-contains`, and a tombstoned uid is by definition NOT in `memberIds` — so
 * without its own leg a deleted account's uid stays on every group it ever left.
 *
 * Non-vacuous by construction: the fixture's ONLY trace of the erased user is
 * the tombstone. They are in no `memberIds` anywhere, so the first leg visits
 * nothing and every assertion here is answered by the second leg alone.
 */
async function scenario_departureTombstoneIsErased(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("chat_groups/g-left", {
    memberIds: [OTHER],
    adminIds: [OTHER],
    departedUserIds: [UID, "someone-else"],
    conversationId: "cg-left",
    createdBy: OTHER,
  });
  db.set("chat_groups/g-untouched", {
    memberIds: [OTHER],
    adminIds: [OTHER],
    departedUserIds: ["someone-else"],
    conversationId: "cg-untouched",
    createdBy: OTHER,
  });

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  const after = (db.get("chat_groups/g-left") as DocData)
    .departedUserIds as string[];
  check(
    "the erased uid is gone from departedUserIds",
    !after.includes(UID),
    `departedUserIds: ${JSON.stringify(after)}`,
  );
  check(
    "…and the other tombstones survive — this is an erasure, not a reset",
    after.includes("someone-else"),
    `departedUserIds: ${JSON.stringify(after)}`,
  );
  check("…and the step reports COMPLETE", ok === true, `returned ${ok}`);
  check(
    "…and a group that never knew this user is not rewritten",
    !db.updatedPaths.includes("chat_groups/g-untouched"),
    `updated: ${JSON.stringify(db.updatedPaths)}`,
  );
}

/**
 * BUT-1856: the residual legs answer different queries from the membership
 * sweep, so that sweep's own cap must not take them down with it.
 *
 * Staged by seeding past `MAX_CHAT_GROUPS_PER_USER` groups the user is a MEMBER
 * of — which makes the membership sweep decline — while one further group holds
 * only a tombstone. With the legs below the decline, the tombstone survived for
 * a reason that had nothing to do with tombstones.
 */
async function scenario_residualLegsSurviveTheMembershipDecline(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {
    deleteChatGroupMemberships,
    MAX_CHAT_GROUPS_PER_USER,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_CHAT_GROUPS_PER_USER; i++) {
    db.set(`chat_groups/g-${i}`, {
      memberIds: [UID, OTHER],
      adminIds: [OTHER],
      conversationId: `cg-${i}`,
      createdBy: OTHER,
    });
  }
  db.set("chat_groups/g-tomb", {
    memberIds: [OTHER],
    adminIds: [OTHER],
    departedUserIds: [UID],
    conversationId: "cg-tomb",
    createdBy: OTHER,
  });

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  const tomb = (db.get("chat_groups/g-tomb") as DocData)
    .departedUserIds as string[];
  check(
    "the tombstone is erased even though the membership sweep declined",
    !tomb.includes(UID),
    `departedUserIds: ${JSON.stringify(tomb)}`,
  );
  check(
    "…and the declining sweep still reports INCOMPLETE",
    ok === false,
    `returned ${ok}`,
  );
}

/**
 * BUT-1856: the meal-vote pointer names the social group's OWNER, on a chat that
 * outlives them.
 *
 * The chat is only torn down when nobody is left, so an owner who deletes their
 * account normally leaves `sourceCategoryOwnerId` — a raw uid — on a document the
 * surviving members keep reading. The same residual class `createdBy` is
 * re-homed for, and the membership sweep cannot reach it: the fixture's owner is
 * NOT in `memberIds`, because leaving the chat does not stop you owning the
 * social group.
 */
async function scenario_mealVotePointerOwnerIsErased(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("chat_groups/g-cat", {
    memberIds: [OTHER],
    adminIds: [OTHER],
    conversationId: "cg-cat",
    createdBy: OTHER,
    sourceCategoryId: "cat-1",
    sourceCategoryOwnerId: UID,
  });

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  const after = db.get("chat_groups/g-cat") as DocData;
  check(
    "the owner uid is gone from the meal-vote pointer",
    after.sourceCategoryOwnerId === undefined,
    `sourceCategoryOwnerId: ${JSON.stringify(after.sourceCategoryOwnerId)}`,
  );
  check(
    "…and the dangling category id goes with it, not on its own",
    after.sourceCategoryId === undefined,
    `sourceCategoryId: ${JSON.stringify(after.sourceCategoryId)}`,
  );
  check(
    "…while the chat itself is left standing for its remaining members",
    db.has("chat_groups/g-cat"),
    "group kept",
  );
  check("…and the step reports COMPLETE", ok === true, `returned ${ok}`);
}

/**
 * THE EXCLUSION. A conversation carrying a `groupId` is owned entirely by
 * `deleteChatGroupMemberships`, which removes the uid from the group AND the
 * conversation in one transaction. `deleteMessages` must not touch it: doing so
 * would make it a second writer of membership — the drift this repo has been
 * burned by more than once — and, because the two legs run in parallel, a race
 * that strips the conversation while `chat_groups.memberIds` still names the
 * erased user.
 *
 * Non-vacuous by construction: the fixture is a THREE-participant conversation
 * with the uid in every carrier, so without the early return it takes the
 * group-departure branch and every assertion below flips. Mutation-proven
 * 2026-08-14 — deleting the `groupId` early return reddens exactly the two
 * conversation-document checks here and nothing else.
 *
 * What deleteMessages still legitimately does to a group conversation: it
 * tombstones the user's own MESSAGE rows (their content is theirs wherever it
 * was written), and `deleteOwnRosterRows` sweeps their roster row as a backstop.
 * Both are idempotent with the group leg, and neither writes membership.
 */
async function scenario_deleteMessagesSkipsGroupOwnedConversations(): Promise<void> {
  const db = new FakeFirestore();
  seedChatGroup(db, "g-owned", "cg-owned", {
    members: [UID, OTHER, THIRD],
    admins: [OTHER],
    createdBy: OTHER,
  });
  seedMessage(db, "own", "cg-owned", UID);

  await deleteMessages(asDb(db), UID);

  const convo = (db.get("conversations/cg-owned") ?? {}) as DocData;
  check(
    "a group-owned conversation keeps its participantIds untouched by deleteMessages",
    Array.isArray(convo.participantIds) &&
      (convo.participantIds as string[]).includes(UID),
    `participantIds: ${JSON.stringify(convo.participantIds)}`,
  );
  const untouched = CONVERSATION_UID_MAPS.every(
    (map) => (convo[map] as DocData)?.[UID] !== undefined,
  );
  check(
    "…and all five uid-keyed maps: the group leg owns this document",
    untouched,
    `maps: ${JSON.stringify(CONVERSATION_UID_MAPS.map((m) => (convo[m] as DocData)?.[UID]))}`,
  );
  check(
    "the group document is not touched by deleteMessages either",
    ((db.get("chat_groups/g-owned") as DocData).memberIds as string[]).includes(UID),
  );
  // The two things it DOES do, asserted so "skips" is not read as "ignores".
  check(
    "the user's own message in that thread is still tombstoned",
    (db.get("messages/own") as DocData)?.content === "[Borttaget meddelande]",
    `content: ${String((db.get("messages/own") as DocData)?.content)}`,
  );
}

/**
 * The probe leg that ships with the deleter. Every other leg in
 * `probeResidualData` has one, and a deleter without a probe is exactly how an
 * erasure becomes silently incomplete — so the pairing is asserted, not assumed.
 */
async function scenario_probeSeesLeftoverChatGroupMembership(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const dirty = new FakeFirestore();
  dirty.set("chat_groups/g-left", {
    memberIds: [UID, OTHER],
    conversationId: "cg-left",
    createdBy: OTHER,
  });
  const result = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(dirty), UID, result);
  check(
    "a leftover chat-group membership is reported as residual data",
    result.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(result.failedCollections)}`,
  );
}

/**
 * BUT-1917: the DECLINE path names a recovery, and this pins the half of it
 * that is checkable here.
 *
 * `MAX_BLOCK_SWEEP_ROWS` says that above the cap the leg declines and a human
 * recovers by running `admin/reset-user-data.ts`. That script is list-driven —
 * it iterates `COLLECTIONS_TO_DELETE` — so membership in that list is
 * NECESSARY for the recovery to reach this collection. It was absent, and the claim had been inherited from
 * `MAX_ROSTER_SWEEP_ROWS`, where `conversations` IS listed.
 *
 * Membership is not SUFFICIENT, and this scenario does not claim it is. The
 * script also has to RUN, which it did not between 2026-03-19 and 2026-09-05
 * (BUT-2010).
 *
 * Asserted rather than written down, because prose is what let one docstring
 * borrow another's reasoning in the first place.
 */
async function scenario_resetScriptDeleteListNamesBlocks(): Promise<void> {
  // Imported, not parsed. The lists moved to their own side-effect-free module
  // in BUT-2028 precisely so this could stop reading source text — the old form
  // needed comment-stripping and an anchor on the list's last entry, and the
  // anchor carried a note telling the next person to move it when they append.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { COLLECTIONS_TO_DELETE } = require("../admin/reset-collection-lists");
  const names = (COLLECTIONS_TO_DELETE as { name: string }[]).map((t) => t.name);

  check(
    "the reset script's delete list is non-empty",
    names.length > 0,
    "COLLECTIONS_TO_DELETE imported as empty — the check below would pass " +
      "vacuously",
  );

  check(
    "the reset script's delete list names `blocks`",
    // The constant, not the literal "blocks": production reads the collection
    // through `Collections.blocks`, and a test restating the string would keep
    // passing if the two ever diverged.
    names.includes(Collections.blocks),
    "`MAX_BLOCK_SWEEP_ROWS` tells a human to recover by running " +
      "admin/reset-user-data.ts, but that script only deletes what " +
      "COLLECTIONS_TO_DELETE names, and it does not name this collection — so " +
      "the declined rows would survive a full reset",
  );
}

/**
 * BUT-2010: the reset script's two lists must not overlap.
 *
 * This is the invariant whose breach made the script do NOTHING for five and a
 * half months. `tag_configs` sat in both `COLLECTIONS_TO_DELETE` and
 * `COLLECTIONS_TO_KEEP`, so the script's own safety guard exited before Phase 1
 * on every run — correctly, since deleting seed data is exactly what that guard
 * exists to prevent.
 *
 * The guard was never the problem. Nothing NOTICED it was firing: the script is
 * run by hand, rarely, and an early `process.exit(1)` reads like a refusal
 * rather than a defect. Meanwhile `MAX_BLOCK_SWEEP_ROWS` named it as the
 * recovery for a declined Art. 17 erasure, which made a broken script into a
 * written promise.
 */
async function scenario_resetScriptListsDoNotOverlap(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const lists = require("../admin/reset-collection-lists");
  const toDelete = (lists.COLLECTIONS_TO_DELETE as { name: string }[]).map(
    (t) => t.name,
  );
  const toKeep = lists.COLLECTIONS_TO_KEEP as string[];

  // Both lists are imported, so a partially-read list is no longer a failure
  // mode and the last-entry anchors that guarded against one are gone with it.
  // What survives is an emptiness check: a disjointness filter over an empty
  // list passes while proving nothing, which is exactly what happened to the
  // text-parsing version of this scenario the moment the lists moved.
  check(
    "the reset script's lists are both non-empty",
    toDelete.length > 0 && toKeep.length > 0,
    `imported ${toDelete.length} delete and ${toKeep.length} keep entries — ` +
      "the disjointness check below would pass vacuously",
  );

  const overlap = toDelete.filter((name) => toKeep.includes(name));
  check(
    "the reset script's delete and keep lists are disjoint",
    overlap.length === 0,
    `${overlap.join(", ")} is in BOTH lists, so reset-user-data.ts exits at ` +
      "its overlap guard before Phase 1 and deletes nothing at all — which is " +
      "how it stayed inert from 2026-03-19 to 2026-09-05 while " +
      "MAX_BLOCK_SWEEP_ROWS named it as the recovery for a declined " +
      "Art. 17 erasure",
  );
}

/**
 * BUT-2028: every Firestore collection this repo knows about is DECIDED —
 * deleted, kept, or deliberately untouched with a reason.
 *
 * `admin/reset-user-data.ts` promises a clean slate. Before this guard, a
 * collection was covered only if someone remembered to add it: top-level
 * collections appeared in neither list, several of them uid-keyed personal data
 * that Phase 1 orphans by deleting every Auth user first. Nothing reddened,
 * and the run printed CLEANUP COMPLETE regardless.
 *
 * **Two independent sources, because neither sees the whole picture.**
 * `firestore.rules` names every collection a CLIENT can touch but is blind to
 * server-only ones; the Cloud Functions source names every collection the
 * SERVER touches but is blind to the ones only the app writes. `system` — the
 * collection holding the app's kill switches — is invisible to the rules file
 * (it has no block, since only the Admin SDK reads it) and is reached through
 * `.doc("system/config")` rather than `.collection(...)`, which is why the
 * server scan reads document-path literals too. That was this ticket's own bug
 * hiding inside its own fix: a guard written without it would have been blind
 * to precisely the collection the kill switch lives in.
 */
async function scenario_everyCollectionIsDecided(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const lists = require("../admin/reset-collection-lists");

  const repoRoot = path.join(__dirname, "..", "..", "..");
  const functionsSrc = path.join(__dirname, "..");

  // --- Source A: firestore.rules -----------------------------------------
  //
  // Comments are stripped BEFORE parsing. The rules file's comments contain
  // brace-carrying prose and map literals, and the brace counter below would
  // read those as real nesting.
  const rulesSource: string = fs.readFileSync(
    path.join(repoRoot, "firestore.rules"),
    "utf8",
  );
  const rulesLines: string[] = rulesSource
    .split("\n")
    .map((line: string) => line.replace(/\/\/.*$/, ""));

  // Two readings of the same thing, kept separate so they can disagree.
  // `byDepth` tracks brace nesting: a top-level collection is a `match` at
  // depth 2, inside `service … {` and `match /databases/{db}/documents {`.
  // `byIndent` only looks at four-space indentation. Neither is trustworthy
  // alone — a stray brace breaks the first, a reformat breaks the second — so
  // the guard asserts they agree and then uses the depth reading.
  const byDepth: string[] = [];
  const byIndent: string[] = [];
  let depth = 0;
  for (const line of rulesLines) {
    const m = line.match(/^(\s*)match\s+\/(\S+)\s*\{/);
    if (m) {
      if (depth === 2) byDepth.push(m[2]);
      if (m[1].length === 4) byIndent.push(m[2]);
    }
    for (const ch of line) {
      if (ch === "{") depth++;
      else if (ch === "}") depth--;
    }
  }

  check(
    "the two readings of firestore.rules agree on which matches are top-level",
    byDepth.length === byIndent.length &&
      byDepth.every((p, i) => p === byIndent[i]),
    `brace-depth found ${byDepth.length} top-level matches, indentation found ` +
      `${byIndent.length} — one of the two readings is wrong, so neither can ` +
      "be trusted to say what the rules file covers",
  );

  /** First path segment of a match, or null for a wildcard-rooted one. */
  function firstSegment(matchPath: string): string | null {
    const first = matchPath.split("/")[0];
    // `match /{path=**}/members/{id}` is a COLLECTION-GROUP rule and
    // `match /{document=**}` is the terminal catch-all. Neither names a
    // top-level collection, and taking their first segment would invent one.
    return first.startsWith("{") ? null : first;
  }

  const fromRules = new Set<string>();
  for (const p of byDepth) {
    const seg = firstSegment(p);
    if (seg) fromRules.add(seg);
  }

  // Positive anchors. A count would go stale on the next rules block; these
  // say what the parse must be CAPABLE of, which does not.
  check(
    "the rules parse reached collections at the top and the bottom of the file",
    // `users` opens the documents block; `parse_events` is the last named
    // match before the terminal catch-all. A parse that stops early keeps the
    // first and loses the second.
    fromRules.has("users") && fromRules.has("parse_events"),
    `parsed ${fromRules.size} top-level collections from firestore.rules ` +
      `(users: ${fromRules.has("users")}, parse_events: ` +
      `${fromRules.has("parse_events")})`,
  );
  check(
    "the rules parse rejects collection-group wildcards",
    // `members` has a `match /{path=**}/members/{memberId}` block and no
    // top-level one. If it appears here, `firstSegment` stopped rejecting
    // wildcard-rooted paths and the guard is inventing top-level collections
    // out of subcollection rules.
    !fromRules.has("members"),
    "`members` was read as a top-level collection — it is only ever a " +
      "subcollection, reached through a {path=**} collection-group rule",
  );

  // --- Source B: the Cloud Functions source ------------------------------
  const serverFiles: string[] = [];
  (function walk(dir: string) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        // Tests are excluded deliberately: their fixtures name collections
        // that exist only to be denied, and a fixture is not evidence that
        // production touches anything.
        if (entry.name === "__tests__") continue;
        walk(path.join(dir, entry.name));
      } else if (entry.name.endsWith(".ts")) {
        serverFiles.push(path.join(dir, entry.name));
      }
    }
  })(functionsSrc);

  // Resolves `Collections.x` to the string it stands for.
  const constants: Record<string, string> = {};
  {
    const source: string = fs.readFileSync(
      path.join(functionsSrc, "shared", "collections.ts"),
      "utf8",
    );
    for (const m of source.matchAll(/^\s+([A-Za-z0-9_]+):\s*"([^"]+)"/gm)) {
      constants[m[1]] = m[2];
    }
  }

  function stripTsComments(source: string): string {
    return source
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .split("\n")
      .map((line: string) => line.replace(/\/\/.*$/, ""))
      .join("\n");
  }

  // One set per extraction branch, unioned at the end. Kept separate so each
  // branch gets an anchor that dies alone: a name discoverable by two routes
  // proves nothing about either.
  const fromCollectionLiteral = new Set<string>();
  const fromConstant = new Set<string>();
  const fromCollectionGroup = new Set<string>();
  const fromDocPath = new Set<string>();

  // A collection name is an identifier. This rejects the template fragments
  // and path shapes that string literals in this codebase also carry.
  const looksLikeCollection = /^[A-Za-z_][A-Za-z0-9_]*$/;
  function record(into: Set<string>, name: string | undefined): void {
    if (name && looksLikeCollection.test(name)) into.add(name);
  }

  for (const file of serverFiles) {
    const source: string = stripTsComments(fs.readFileSync(file, "utf8"));

    // A `const NAME = "collection"` declared in this file, exported or not.
    // Without it, a collection reached through such a constant is invisible
    // unless it also happens to have a rules block — `llm_response_samples`
    // (private) and `canonical_recipe_stats` (exported) are both that shape.
    // The `export` half is not decoration: the first version of this branch
    // omitted it and left the exported case relying on the same accident the
    // branch exists to stop relying on. An identifier IMPORTED from another
    // file stays unresolved, because this map is per-file.
    const localConstants: Record<string, string> = {};
    for (const m of source.matchAll(
      /^\s*(?:export\s+)?const\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*string\s*)?=\s*"([^"]+)"\s*;/gm,
    )) {
      localConstants[m[1]] = m[2];
    }

    // `.collection(X)` — but only where X is the FIRST link of its chain.
    // `db.collection("users").doc(uid).collection("consent")` must yield
    // `users` alone; `consent` is a subcollection, and reporting it as
    // top-level would demand a list entry for something that does not exist
    // there. The collapse looks back to the nearest statement boundary and
    // skips the match if a `.doc(` stands between.
    //
    // The look-back is a heuristic in one direction only: two handles built
    // inside one expression, where an unrelated `.doc(` precedes a genuine
    // top-level `.collection(...)`, are skipped. That direction hides a
    // collection from the guard rather than inventing one.
    for (const m of source.matchAll(
      /\.collection\(\s*(?:"([^"]+)"|Collections\.([A-Za-z0-9_]+)|([A-Za-z_][A-Za-z0-9_]*))\s*\)/g,
    )) {
      const before = source.slice(Math.max(0, m.index - 400), m.index);
      const boundary = Math.max(
        before.lastIndexOf(";"),
        before.lastIndexOf("{"),
        before.lastIndexOf("}"),
      );
      if (before.slice(boundary + 1).includes(".doc(")) continue;
      if (m[1] !== undefined) record(fromCollectionLiteral, m[1]);
      else if (m[2] !== undefined) record(fromCollectionLiteral, constants[m[2]]);
      // An identifier that resolves to no local const is a runtime value
      // (a parameter, a config field) and is skipped rather than guessed.
      else record(fromConstant, localConstants[m[3]]);
    }

    for (const m of source.matchAll(
      /collectionGroup\(\s*(?:"([^"]+)"|Collections\.([A-Za-z0-9_]+))\s*\)/g,
    )) {
      record(fromCollectionGroup, m[1] ?? constants[m[2]]);
    }

    // Document-path literals: `.doc("system/config")`. Without this the guard
    // is blind to `system`, which is where BUT-2028's own kill switch lives —
    // it has no rules block and is never reached through `.collection(...)`.
    // The backtick form is read too, up to its first interpolation:
    // `` .doc(`pings/${groupId}/pings/${pingId}`) `` names `pings`.
    for (const m of source.matchAll(/\.doc\(\s*"([^"\s]+\/[^"\s]+)"\s*\)/g)) {
      record(fromDocPath, m[1].split("/")[0]);
    }
    for (const m of source.matchAll(
      /\.doc\(\s*`([A-Za-z_][A-Za-z0-9_]*)\//g,
    )) {
      record(fromDocPath, m[1]);
    }
  }

  const fromServer = new Set<string>([
    ...fromCollectionLiteral,
    ...fromConstant,
    ...fromCollectionGroup,
    ...fromDocPath,
  ]);

  check(
    "the server scan resolves collection constants declared in the file",
    // `llm/llm-sample-capture.ts` writes through `const COLLECTION = "…"`.
    // Only this branch can find it; without it the collection is visible to
    // the guard purely by accident of having a rules block.
    // `canonical_recipe_stats` is the EXPORTED case
    // (`ratings/update-pooled-rating-stats.ts`), and it is the only thing that
    // can fail if the `export` half of the pattern is dropped.
    fromConstant.has("llm_response_samples") &&
      fromConstant.has("canonical_recipe_stats"),
    // Both memberships are reported: the check is a conjunction, and a
    // failure message naming only one half points a reader at the wrong half.
    `the const branch found ${fromConstant.size} collections ` +
      `(llm_response_samples: ${fromConstant.has("llm_response_samples")}, ` +
      `canonical_recipe_stats: ${fromConstant.has("canonical_recipe_stats")})` +
      " — a collection named through a constant in its own file is invisible " +
      "to the guard again",
  );
  check(
    "the server scan reads backtick document paths",
    // `triggers/ping_onCreate.ts` builds `pings/${groupId}/pings/${pingId}`.
    fromDocPath.has("pings"),
    `the document-path branch found ${[...fromDocPath].join(", ")} — the ` +
      "backtick form stopped being read",
  );
  check(
    "the server scan sees collections firestore.rules cannot show",
    // Both are server-only and have no rules block at all, so source A is
    // blind to them by construction. `system` additionally proves the
    // document-literal branch runs.
    fromServer.has("system") && fromServer.has("system_ip_audit_caps"),
    `scanned ${serverFiles.length} server files and found ` +
      `${fromServer.size} collections (system: ${fromServer.has("system")}, ` +
      `system_ip_audit_caps: ${fromServer.has("system_ip_audit_caps")})`,
  );
  check(
    "the chain collapse keeps subcollections out of the server scan",
    // `consent` and `settings` are written by this repo's server code ONLY as
    // `db.collection("users").doc(uid).collection(...)` chains. If either
    // shows up here the collapse stopped working, and the guard would start
    // demanding a top-level list entry for a subcollection.
    !fromServer.has("consent") && !fromServer.has("settings"),
    "a users/{uid} subcollection was read as a top-level collection — the " +
      "`.doc(` look-back stopped collapsing chains",
  );

  // --- The union, and the three lists ------------------------------------
  const known = new Set<string>([...fromRules, ...fromServer]);
  const subNames: Set<string> = lists.KNOWN_SUBCOLLECTION_NAMES;

  const staleSubNames = [...subNames].filter((name) => !known.has(name));
  check(
    "every filtered subcollection name is still written somewhere",
    staleSubNames.length === 0,
    `${staleSubNames.join(", ")} is filtered out as a subcollection but no ` +
      "source names it any more — the filter is hiding nothing, and it would " +
      "hide a real top-level collection that later takes the name",
  );

  const discovered = [...known].filter((name) => !subNames.has(name)).sort();

  const toDelete = new Set(
    (lists.COLLECTIONS_TO_DELETE as { name: string }[]).map((t) => t.name),
  );
  const toKeep = new Set(lists.COLLECTIONS_TO_KEEP as string[]);
  const untouched: Record<string, string> =
    lists.COLLECTIONS_DELIBERATELY_UNTOUCHED;
  const untouchedNames = new Set(Object.keys(untouched));

  const undecided = discovered.filter(
    (name) =>
      !toDelete.has(name) && !toKeep.has(name) && !untouchedNames.has(name),
  );
  check(
    "every collection this repo knows about is decided",
    undecided.length === 0,
    `${undecided.length} collection(s) appear in firestore.rules or in ` +
      `functions/src but in none of the three lists: ${undecided.join(", ")}` +
      " — reset-user-data.ts neither deletes nor protects them, and Phase 1 " +
      "deletes every Auth user first, so anything uid-keyed is left orphaned " +
      "and unreachable by the account cascade",
  );

  const reasonless = Object.entries(untouched).filter(
    ([, reason]) => reason.trim().length < 20,
  );
  check(
    "every deliberately-untouched collection states a reason",
    reasonless.length === 0,
    `${reasonless.map(([name]) => name).join(", ")} has no real reason — the ` +
      "register exists so a skip is a decision someone wrote down, and a " +
      "one-word string reads as decided while recording nothing",
  );

  const staleUntouched = [...untouchedNames].filter(
    (name) => !discovered.includes(name),
  );
  check(
    "no deliberately-untouched entry names a collection that is gone",
    staleUntouched.length === 0,
    `${staleUntouched.join(", ")} is registered as deliberately untouched but ` +
      "no source names it — the reason it carries describes something that no " +
      "longer exists, and a reader would trust it",
  );

  // Disjointness over all THREE pairs. The delete/keep pair had its own guard
  // (BUT-2010, the overlap that made the script inert for five months); a
  // third list makes two more pairs, and the script's own runtime guard covers
  // only the original one.
  const pairs: [string, Set<string>, string, Set<string>][] = [
    ["delete", toDelete, "keep", toKeep],
    ["delete", toDelete, "untouched", untouchedNames],
    ["keep", toKeep, "untouched", untouchedNames],
  ];
  for (const [leftName, left, rightName, right] of pairs) {
    const overlap = [...left].filter((name) => right.has(name));
    check(
      `the ${leftName} and ${rightName} lists are disjoint`,
      overlap.length === 0,
      `${overlap.join(", ")} is in both — a collection with two verdicts has ` +
        "no verdict, and which one wins depends on which list a reader opens",
    );
  }
}

/**
 * BUT-2028: the reset script REFUSES a live run, in code, ahead of Phase 1.
 *
 * This exists because of what BUT-2010 taught. The overlap guard protected this
 * script for five and a half months and nobody watched it fire; fixing that
 * guard removed the only mechanism enforcing the header's warning, leaving the
 * prohibition as prose while `admin-init.ts` hardcodes the production project. A warning with no mechanism is the same shape as a
 * promise nobody tests.
 *
 * Two properties, and the ORDER is one of them: the refusal must sit ahead of
 * Phase 1, or it refuses a run that has already deleted the Auth users. Source
 * order stands in for execution order only while the refusal is inline in
 * `main()`; move it into a helper and this check stops meaning that.
 *
 * `--dry-run` must stay reachable — inspecting the script is how anyone
 * resolves BUT-2028 — so the refusal is asserted to be conditional on a live
 * run rather than unconditional.
 */
async function scenario_resetScriptRefusesLiveRuns(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const scriptPath = path.join(__dirname, "..", "admin", "reset-user-data.ts");
  // Comment lines are dropped first, for the same reason the sibling scenario
  // drops them: commenting the guard out is the cheapest way to disarm it, and
  // over raw source every check below would stay green above a dead `if`. The
  // 200-char `!dryRun` lookback is the other reason — a future comment carrying
  // that token would satisfy it.
  const source = (fs.readFileSync(scriptPath, "utf8") as string)
    .split("\n")
    .filter((line: string) => !line.trim().startsWith("//"))
    .join("\n");

  const refusalAt = source.indexOf("BUT_2028_ACK_FLAG)");
  check(
    "the reset script refuses live runs while BUT-2028 is open",
    refusalAt >= 0,
    "no BUT-2028 live-run refusal found in reset-user-data.ts — the header " +
      "warning and two docstrings then have no mechanism behind them, against " +
      "a hardcoded production project",
  );
  if (refusalAt < 0) return;

  check(
    "the refusal is conditional on a live run, not on every run",
    source.slice(refusalAt - 200, refusalAt).includes("!dryRun"),
    "the BUT-2028 refusal is not guarded by `!dryRun`, so --dry-run is " +
      "refused too — and inspecting the script is how BUT-2028 gets resolved",
  );

  // Presence and position prove a reference, never an EFFECT. Measured: swap
  // `process.exit(1)` for a `console.warn` and the checks above all stay green
  // while the script prints REFUSED and walks into Phase 1 against production
  // — the same shape as the guard this ticket exists to close, one level up.
  check(
    "the refusal EXITS rather than only printing",
    source
      .slice(refusalAt, source.indexOf("initializeAdminApp(", refusalAt))
      .includes("process.exit(1)"),
    "the BUT-2028 refusal prints and falls through into Phase 1",
  );

  const phaseOneAt = source.indexOf("Phase 1: Firebase Auth users");
  check(
    "the refusal runs BEFORE Phase 1 deletes the Auth users",
    phaseOneAt > refusalAt,
    "the BUT-2028 refusal sits after Phase 1, so it would refuse a run that " +
      "has already deleted every Auth user",
  );

  // The blind spot the OVERLAP guard had, closed for this one. That guard kept
  // working for five and a half months while nothing watched whether it could
  // still fire; baking the ack flag into `package.json` leaves the refusal
  // intact and permanently satisfied, which is the same shape.
  const pkg = fs.readFileSync(
    path.join(__dirname, "..", "..", "package.json"),
    "utf8",
  ) as string;
  const scripts = JSON.parse(pkg).scripts as Record<string, string>;
  // The flag is READ from the script, never restated: matching the literal
  // means a rename leaves this searching for a string nothing uses, green while
  // an npm script bakes in the new one. Same reason the sibling scenario
  // matches `Collections.blocks` rather than "blocks".
  const flagMatch = source.match(/BUT_2028_ACK_FLAG = "([^"]+)"/);
  check(
    "the ack flag's spelling is readable from the script",
    flagMatch !== null,
    "BUT_2028_ACK_FLAG's declaration was not found, so the npm-script check " +
      "below cannot know what to look for",
  );
  if (flagMatch === null) return;
  const ackFlag = flagMatch[1];

  const baked = Object.entries(scripts)
    .filter(([, cmd]) => cmd.includes("reset-user-data"))
    .filter(([, cmd]) => cmd.includes(ackFlag))
    .map(([name]) => name);
  check(
    "no npm script pre-acknowledges BUT-2028 for the operator",
    baked.length === 0,
    `${baked.join(", ")} passes ${ackFlag}, so the refusal is ` +
      "satisfied before the operator sees it — the guard still runs and still " +
      "proves nothing, which is exactly how the overlap guard went unnoticed",
  );
}

/**
 * BUT-1917: both `blocks` legs of the residual probe.
 *
 * `deleteBlocks` sweeps through `batchDeleteAll` -> `commitInChunks(strict:
 * false)`, which swallows a failed chunk and lets the step return success — so
 * without these legs the sweep self-reports clean over rows whose document id
 * is the erased uid. They also fire when the sweep DECLINED above the cap and
 * deleted nothing, which is the state the decline deliberately leaves behind.
 *
 * One document per case, reachable by exactly ONE leg, so deleting either leg
 * from the probe list turns its case red rather than leaving both green on the
 * strength of the other.
 */
async function scenario_probeSeesLeftoverBlocks(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  });

  const clean = new FakeFirestore();
  clean.set("blocks/third-uid_fourth-uid", {
    blockerId: "third-uid",
    blockedId: "fourth-uid",
  });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "blocks between other people do not make the probe fire",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const asBlocker = new FakeFirestore();
  asBlocker.set(`blocks/${UID}_${OTHER}`, {
    blockerId: UID,
    blockedId: OTHER,
  });
  const blockerResult = emptyResult();
  await probeResidualData(asDb(asBlocker), UID, blockerResult);
  check(
    "a surviving block the user MADE is reported as residual",
    blockerResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(blockerResult.failedCollections)}`,
  );

  const asBlocked = new FakeFirestore();
  asBlocked.set(`blocks/${OTHER}_${UID}`, {
    blockerId: OTHER,
    blockedId: UID,
  });
  const blockedResult = emptyResult();
  await probeResidualData(asDb(asBlocked), UID, blockedResult);
  check(
    "a surviving block made OF the user is reported too — the other leg",
    blockedResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(blockedResult.failedCollections)}`,
  );
}

/**
 * BUT-1917: the residual probe SEES a block mirror the sweep missed.
 *
 * `deleteBlockMirrors` is a cross-user sweep, so nothing under `users/{uid}`
 * can tell whether it finished — which is exactly the shape this file's own
 * rule calls out: a deleter without a probe is how an erasure becomes silently
 * incomplete. The leg uses the same collection-group index the sweep needs, so
 * a missing index surfaces here as a false alarm rather than a false all-clear.
 */
async function scenario_probeSeesLeftoverBlockMirrors(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  clean.set("users/fourth-uid/block_mirror/current", {
    blockedByUserIds: ["third-uid"],
  });
  const cleanResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "somebody else's mirror does not make the probe fire",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set(`users/${OTHER}/block_mirror/current`, {
    blockedByUserIds: [UID],
  });
  const dirtyResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a mirror still naming the erased user is reported as residual",
    dirtyResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );
}

/**
 * BUT-1917: the erased uid comes out of OTHER people's block mirrors.
 *
 * Their own mirror goes with the `users/{uid}` subcollection sweep. This is the
 * cross-user half: a mirror belonging to somebody the erased user had blocked
 * still names them, and that document is a live safety control on an account
 * that continues to exist.
 *
 * `arrayRemove` rather than a rebuild, and the distinction has a test of its
 * own below: the mirror belongs to another user, so this cascade must take out
 * one entry rather than rewrite their document from its own view of `blocks`.
 */
async function scenario_blockMirrorsLoseTheErasedUid(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`users/${OTHER}/block_mirror/current`, {
    blockedByUserIds: [UID, "third-uid"],
    sourceRev: 1000,
  });
  // A mirror the erased user is not in. If the sweep were keyed on the
  // collection rather than the uid, this one would be rewritten too and no
  // assertion about the first would notice.
  db.set("users/fourth-uid/block_mirror/current", {
    blockedByUserIds: ["third-uid"],
    sourceRev: 1000,
  });

  const complete = await deleteBlockMirrors(asDb(db), UID);

  check("the mirror sweep reports itself complete", complete === true);
  const touched = (db.get(`users/${OTHER}/block_mirror/current`) ??
    {}) as DocData;
  check(
    "the erased uid is gone from another user's mirror",
    Array.isArray(touched.blockedByUserIds) &&
      !(touched.blockedByUserIds as string[]).includes(UID),
    `left: ${JSON.stringify(touched.blockedByUserIds)}`,
  );
  check(
    "…and the OTHER blocker on that same mirror survives",
    Array.isArray(touched.blockedByUserIds) &&
      (touched.blockedByUserIds as string[]).includes("third-uid"),
    "an `arrayRemove` takes one entry; a rebuild from this cascade's view " +
      "would have rewritten somebody else's document wholesale",
  );
  const untouched = (db.get("users/fourth-uid/block_mirror/current") ??
    {}) as DocData;
  check(
    "…and the sweep RAISES the mirror's revision",
    typeof touched.sourceRev === "number" && (touched.sourceRev as number) > 1000,
    `sourceRev: ${JSON.stringify(touched.sourceRev)} — without a raised stamp a ` +
      "`syncBlockMirror` rebuild that read `blocks` before the cascade deleted " +
      "them can land afterwards and put the uid straight back, because its own " +
      "guard would see no newer revision",
  );
  check(
    "a mirror not naming the erased user is untouched",
    Array.isArray(untouched.blockedByUserIds) &&
      (untouched.blockedByUserIds as string[]).length === 1,
  );
}

/**
 * BUT-1917: an implausible mirror count DECLINES and reports the step
 * incomplete, rather than sweeping a subset.
 *
 * Each of these documents belongs to a different living user, so a truncated
 * sweep would leave the erased uid inside a live safety control on an unknown
 * subset of them — with the audit row saying the erasure was clean.
 */
async function scenario_implausibleMirrorCountDeclines(): Promise<void> {
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_MIRROR_SWEEP_ROWS; i++) {
    db.set(`users/peer-${i}/block_mirror/current`, {
      blockedByUserIds: [UID],
      sourceRev: 1000,
    });
  }

  const complete = await deleteBlockMirrors(asDb(db), UID);

  check(
    "the step reports itself INCOMPLETE rather than truncating",
    complete === false,
  );
  const first = (db.get("users/peer-0/block_mirror/current") ?? {}) as DocData;
  check(
    "and nothing was half-swept",
    Array.isArray(first.blockedByUserIds) &&
      (first.blockedByUserIds as string[]).includes(UID),
  );
}

/**
 * BUT-1917: the block mirror's export exemption rests on `incoming_blocks`, and
 * this is what stops the two drifting apart in silence.
 *
 * `EXPORT_EXEMPT.block_mirror` says the mirror need not be exported because the
 * bundle already reproduces the same facts under `incoming_blocks`, which reads
 * the `blocks` collection the mirror is derived from. That is an argument about
 * content identity inside ONE bundle — but it is only true while that section
 * exists. Malin DECIDED on 2026-09-05 (BUT-2018) that `incoming_blocks` should
 * stop telling a requester exactly who blocked them, so the section this
 * exemption leans on is one a decision already taken will remove. Not built
 * yet, which is the only reason the premise still holds.
 *
 * Bound by a test rather than by prose because prose is exactly what would stay
 * behind, still reading as a decided call, on the day the section goes.
 */
async function scenario_blockMirrorExemptionRestsOnIncomingBlocks(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const repoRoot = path.join(__dirname, "..", "..", "..");

  const exempt = (
    require("../account/account-deletion-cascade") as {
      EXPORT_EXEMPT: Record<string, string>;
    }
  ).EXPORT_EXEMPT;

  check(
    "the block mirror is exempt from the export",
    typeof exempt[Collections.blockMirror] === "string",
    `EXPORT_EXEMPT keys: ${JSON.stringify(Object.keys(exempt))}`,
  );

  const managerPath = path.join(
    repoRoot,
    "lib",
    "services",
    "account",
    "export",
    "social_export_manager.dart",
  );
  const manager = fs.readFileSync(managerPath, "utf8") as string;

  check(
    "…and the section its reasoning depends on is still exported",
    manager.includes("'incoming_blocks'"),
    "`EXPORT_EXEMPT.block_mirror` argues the mirror is redundant because the " +
      "bundle reproduces the same uids under `incoming_blocks`. That section " +
      "is gone from social_export_manager.dart, so the exemption now excuses " +
      "the ONLY copy of those facts. Revisit it (BUT-2018) rather than " +
      "re-pointing this assertion.",
  );
}

/**
 * BUT-1917: `blocks` is erased in BOTH directions.
 *
 * The collection had no server reader at all before this, so an erased
 * account's uid survived inside every block row it was party to — including in
 * the DOCUMENT ID, `{blockerId}_{blockedId}`, which is why a field projection
 * would not have been enough and the row has to go.
 *
 * The second direction is the one worth a test of its own: those rows were
 * created by OTHER living users. That is not unprecedented here —
 * `deleteOwnRosterRows` and `tryClearRoster` do it too — but it is the half a
 * reader is most likely to assume was left alone.
 */
async function scenario_blocksAreErasedInBothDirections(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`blocks/${UID}_${OTHER}`, { blockerId: UID, blockedId: OTHER });
  db.set(`blocks/${OTHER}_${UID}`, { blockerId: OTHER, blockedId: UID });
  // A block between two people who are not being erased. If the sweep were
  // keyed on the collection rather than the uid, this row would go too — and
  // no assertion about the first two could tell.
  db.set("blocks/third-uid_fourth-uid", {
    blockerId: "third-uid",
    blockedId: "fourth-uid",
  });

  const complete = await deleteBlocks(asDb(db), UID);

  check("the blocks step reports itself complete", complete === true);
  check(
    "a block the erased user MADE is gone",
    !db.has(`blocks/${UID}_${OTHER}`),
  );
  check(
    "a block another user made OF the erased user is gone too",
    !db.has(`blocks/${OTHER}_${UID}`),
    "this row was authored by someone else and names the erased uid in its " +
      "own document id",
  );
  check(
    "a block between two other people is untouched",
    db.has("blocks/third-uid_fourth-uid"),
    `left: ${JSON.stringify(db.pathsUnder("blocks"))}`,
  );
}

/**
 * BUT-1917: an implausible block count DECLINES that direction and reports the
 * step incomplete, rather than truncating.
 *
 * The `blockedId` leg is the one this really guards: any authenticated account
 * may block this user and nothing rate-limits it, so a peer chooses how many
 * rows exist. Declining is strictly less erasure for the same alarm — the audit
 * row lands `gdprCompliant: false` either way.
 *
 * The other direction must still be swept. Two independent residues; half an
 * erasure beats none as long as the step says so.
 */
async function scenario_implausibleBlockCountDeclines(): Promise<void> {
  const db = new FakeFirestore();
  // Imported, not restated as 2000: a literal here and a literal in
  // production is two copies of one number, and the read is `.limit(MAX + 1)`,
  // so `<=` seeds exactly one row past the cap.
  for (let i = 0; i <= MAX_BLOCK_SWEEP_ROWS; i++) {
    db.set(`blocks/peer-${i}_${UID}`, {
      blockerId: `peer-${i}`,
      blockedId: UID,
    });
  }
  db.set(`blocks/${UID}_${OTHER}`, { blockerId: UID, blockedId: OTHER });

  const complete = await deleteBlocks(asDb(db), UID);

  check(
    "the step reports itself INCOMPLETE rather than truncating",
    complete === false,
  );
  check(
    "the over-cap direction is left alone rather than half-erased",
    db.has(`blocks/peer-0_${UID}`),
  );

  // The over-cap direction is `blockedId`, the LAST leg the loop visits, so by
  // the time it declines the `blockerId` leg has already run. That makes this
  // fixture unable to tell `continue` from `return` — both leave identical
  // state. The mirrored case below is what pins the `continue`, and the two
  // must stay together: this one alone would read as proving independence
  // while proving loop order.
  check(
    "the other direction was swept, before the decline",
    !db.has(`blocks/${UID}_${OTHER}`),
  );
}

/**
 * BUT-1917: the mirror of the case above, and the only one that pins
 * `continue` rather than `return`.
 *
 * Here the OVER-CAP direction is `blockerId` — the FIRST leg — so the
 * `blockedId` leg is reachable only by continuing past a declined one.
 * Swapping `continue` for `return` in `deleteBlocks` leaves the peer's block
 * standing and reddens this scenario alone.
 */
async function scenario_aDeclinedLegDoesNotStopTheOther(): Promise<void> {
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_BLOCK_SWEEP_ROWS; i++) {
    db.set(`blocks/${UID}_peer-${i}`, {
      blockerId: UID,
      blockedId: `peer-${i}`,
    });
  }
  db.set(`blocks/${OTHER}_${UID}`, { blockerId: OTHER, blockedId: UID });

  const complete = await deleteBlocks(asDb(db), UID);

  check(
    "the step still reports itself incomplete",
    complete === false,
  );
  check(
    "the declined FIRST leg is left alone",
    db.has(`blocks/${UID}_peer-0`),
  );
  check(
    "the second leg still ran — a declined leg does not abandon the rest",
    !db.has(`blocks/${OTHER}_${UID}`),
    "with `return` in place of `continue` this row survives, and the erased " +
      "uid stays on a block another user made of them",
  );
}

/**
 * BUT-1835 — the erased user's poll votes and their authorship of polls.
 *
 * Two residues, and neither covers the other. The VOTE rows live at
 * `messages/{id}/poll_votes/{uid}` under messages this user may never have
 * sent, in conversations `deleteMessages` leaves standing, so no other leg of
 * this cascade reaches them. The AUTHORSHIP lives at
 * `metadata.poll.creatorId` inside a message document; `deleteMessages`
 * anonymises `senderId` on their own messages and never looks inside
 * `metadata`, so on every surviving poll the raw uid stayed.
 *
 * Written against the SUBCOLLECTION shape BUT-1832 introduced, not the inline
 * `metadata.poll.options[].voterIds` array it replaced. That array is still
 * emitted (`Poll.toMap` writes it, `closePoll` rewrites the whole metadata map)
 * but no VOTER uid has landed in it since BUT-1832 — `closePoll` reads the raw
 * snapshot, not the hydrated model, so the display tally cannot round-trip.
 * A poll from the PRE-BUT-1832 client can still hold its author's own uid there;
 * dev-project data only, and the production comment on `deletePollVotes` carries
 * the full reasoning. Scrubbing the array instead of the subcollection would
 * chase a field no live writer fills while missing every vote made since.
 */
async function scenario_pollVotesAndAuthorshipAreErased(): Promise<void> {
  const db = new FakeFirestore();
  // A GROUP conversation, so `deleteMessages` scrubs membership and leaves the
  // conversation and its messages standing — which is what makes these rows
  // survivable in the first place.
  db.set("conversations/group-1", {
    participantIds: [UID, OTHER, "third-uid"],
    participantDisplayNames: { [UID]: "Raderad", [OTHER]: "Kvar" },
    isGroup: true,
  });
  // A poll SOMEBODY ELSE opened. The erased user only voted in it — nothing
  // else in the cascade would ever touch this message.
  db.set("messages/poll-theirs", {
    conversationId: "group-1",
    senderId: OTHER,
    content: "Vad ska vi äta?",
    metadata: {
      poll: {
        id: "p1",
        creatorId: OTHER,
        question: "Vad ska vi äta?",
        options: [{ id: "opt-a", text: "Tacos" }],
      },
    },
  });
  db.set("messages/poll-theirs/poll_votes/" + UID, {
    voterId: UID,
    optionIds: ["opt-a"],
  });
  db.set("messages/poll-theirs/poll_votes/" + OTHER, {
    voterId: OTHER,
    optionIds: ["opt-a"],
  });
  // A poll the erased user OPENED, in the same surviving conversation.
  db.set("messages/poll-mine", {
    conversationId: "group-1",
    senderId: UID,
    content: "Pizza på fredag?",
    metadata: {
      poll: {
        id: "p2",
        creatorId: UID,
        question: "Pizza på fredag?",
        options: [{ id: "opt-x", text: "Ja" }],
      },
    },
  });
  db.set("messages/poll-mine/poll_votes/" + OTHER, {
    voterId: OTHER,
    optionIds: ["opt-x"],
  });

  await deleteMessages(asDb(db), UID);

  check(
    "the erased user's vote is gone from a poll they did not open",
    !db.has(`messages/poll-theirs/poll_votes/${UID}`),
    `left: ${JSON.stringify(db.pathsUnder("messages/poll-theirs/poll_votes"))}`,
  );
  check(
    "another member's vote in the same poll is untouched",
    db.has(`messages/poll-theirs/poll_votes/${OTHER}`),
  );
  check(
    "another member's vote in the ERASED user's poll is untouched too",
    db.has(`messages/poll-mine/poll_votes/${OTHER}`),
  );

  const mine = (db.get("messages/poll-mine") ?? {}) as DocData;
  const poll = ((mine.metadata ?? {}) as DocData).poll as DocData | undefined;
  check(
    "the erased user's poll authorship is anonymised",
    poll?.creatorId === "deleted",
    `creatorId: ${JSON.stringify(poll?.creatorId)}`,
  );
  check(
    "…and the rest of the poll survives — the remaining members still use it",
    poll?.question === "Pizza på fredag?" &&
      Array.isArray(poll?.options) &&
      (poll?.options as unknown[]).length === 1,
    `poll: ${JSON.stringify(poll)}`,
  );

  const theirs = (db.get("messages/poll-theirs") ?? {}) as DocData;
  const theirPoll = ((theirs.metadata ?? {}) as DocData).poll as
    | DocData
    | undefined;
  check(
    "somebody else's poll keeps ITS creator — the scrub is keyed on the uid",
    theirPoll?.creatorId === OTHER,
    `creatorId: ${JSON.stringify(theirPoll?.creatorId)}`,
  );
}

/**
 * BUT-1801: the residual probe must SEE both poll residues.
 *
 * `deletePollVotes` deletes votes through `commitInChunks(strict:false)`, which
 * catches a whole failed chunk and lets the step return success anyway — only
 * the cap can falsify it. And the creator scrub, before BUT-1801, was one atomic
 * batch, so a single message deleted by a sibling step took the whole chunk with
 * it, silently. In both cases the step reports a clean erasure over rows that are
 * still there. The probe is the only thing that can contradict that, and it had
 * no leg for either — the same shape as the `participants` gap BUT-1822 found.
 *
 * Two residues, asserted separately, because a probe that catches one and misses
 * the other still certifies a bad erasure clean.
 */
async function scenario_probeSeesLeftoverPollResidues(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const cleanCase = new FakeFirestore();
  // Somebody else's vote on somebody else's poll: neither leg may fire on it.
  cleanCase.set("messages/poll-theirs", {
    conversationId: "group-1",
    senderId: OTHER,
    metadata: { poll: { id: "p1", creatorId: OTHER, options: [] } },
  });
  cleanCase.set("messages/poll-theirs/poll_votes/" + OTHER, {
    voterId: OTHER,
    optionIds: ["opt-a"],
  });
  const cleanResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(cleanCase), UID, cleanResult);
  check(
    "another member's poll vote and authorship do not read as this user's residual",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  // Residue 1: a vote row the sweep failed to delete.
  const leftoverVote = new FakeFirestore();
  leftoverVote.set("messages/poll-theirs", {
    conversationId: "group-1",
    senderId: OTHER,
    metadata: { poll: { id: "p1", creatorId: OTHER, options: [] } },
  });
  leftoverVote.set("messages/poll-theirs/poll_votes/" + UID, {
    voterId: UID,
    optionIds: ["opt-a"],
  });
  const voteResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(leftoverVote), UID, voteResult);
  check(
    "a poll vote the sweep failed to delete is reported as residual data",
    voteResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(voteResult.failedCollections)}`,
  );

  // Residue 2: authorship the scrub failed to anonymise. Distinct from residue
  // 1 — the message carries the raw uid in a FIELD, with no vote row at all.
  const leftoverAuthor = new FakeFirestore();
  leftoverAuthor.set("messages/poll-mine", {
    conversationId: "group-1",
    senderId: "deleted",
    metadata: { poll: { id: "p2", creatorId: UID, options: [] } },
  });
  const authorResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
  };
  await probeResidualData(asDb(leftoverAuthor), UID, authorResult);
  check(
    "poll authorship the scrub failed to anonymise is reported as residual data",
    authorResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(authorResult.failedCollections)}`,
  );
}

/**
 * BUT-1801: the poll-creator scrub tolerates NOT_FOUND and ONLY NOT_FOUND.
 *
 * The scrub updates each authored message individually rather than in one batch,
 * because a sibling step (`deleteChatGroupMemberships` deleting an emptied
 * group's whole thread) can delete a message out from under it — and a batch is
 * atomic, so one NOT_FOUND would take the whole chunk down while
 * `commitInChunks(strict:false)` swallowed the error and the step still reported
 * success.
 *
 * So code 5 means "the message is already gone", which is the outcome the scrub
 * wanted: tolerate it, stay complete. Every OTHER code is a real failure and must
 * mark the step incomplete, or a half-erased account passes as `gdprCompliant`.
 *
 * Both directions are asserted here because the fake could not stage either one
 * until this ticket added the `updateFailures` seam: inverting the predicate —
 * tolerating everything except code 5, the exact opposite of the intent — left
 * the suite 110/110 green.
 */
async function scenario_pollCreatorScrubToleratesOnlyNotFound(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deletePollVotes } = require("../account/account-deletion-cascade");

  const authoredPoll = (db: FakeFirestore, id: string): void => {
    db.set(`messages/${id}`, {
      conversationId: "group-1",
      senderId: UID,
      metadata: { poll: { id: `p-${id}`, creatorId: UID, options: [] } },
    });
  };

  // NOT_FOUND: the message was deleted by a sibling step mid-cascade.
  const vanished = new FakeFirestore();
  vanished.set("conversations/group-1", { participantIds: [UID, OTHER] });
  authoredPoll(vanished, "poll-gone");
  vanished.updateFailures.set("messages/poll-gone", 5);
  check(
    "a message deleted mid-cascade does NOT make the poll scrub incomplete",
    (await deletePollVotes(asDb(vanished), UID)) === true,
    "code 5 must be tolerated — the row is already gone",
  );

  // Any other code: a real write failure, and the step must own up to it.
  const broken = new FakeFirestore();
  broken.set("conversations/group-1", { participantIds: [UID, OTHER] });
  authoredPoll(broken, "poll-broken");
  broken.updateFailures.set("messages/poll-broken", 13); // INTERNAL
  check(
    "a real write failure DOES make the poll scrub report incomplete",
    (await deletePollVotes(asDb(broken), UID)) === false,
    "only NOT_FOUND may be tolerated",
  );
}

/**
 * BUT-1835 + BUT-1830: an implausibly large vote sweep DECLINES rather than
 * truncating, and says so.
 *
 * NOT because a peer can inflate the count — they cannot. `firestore.rules`
 * requires `request.auth.uid == voterId` on every write verb of
 * `poll_votes/{voterId}`, and posting a poll creates zero rows; a row exists
 * only when this user votes. That sentence stood here and in the constant's own
 * docstring until the BUT-1801 review disproved it (2026-08-17); it was borrowed
 * from the roster cap, where peer-seeding IS the threat.
 *
 * What the cap still guards: self-inflation, and a tampered or non-standard
 * Admin-SDK writer that rules never see. A truncated sweep would report a clean
 * erasure over rows it never looked at, which is the one outcome Art. 17 cannot
 * tolerate; declining lands the step in `failedCollections`, which is loud.
 */
async function scenario_implausiblePollVoteCountDeclines(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/group-2", {
    participantIds: [UID, OTHER],
    isGroup: true,
  });
  // 2000 is MAX_POLL_VOTE_SWEEP_ROWS; the read is `.limit(MAX + 1)`, so 2001
  // rows is the smallest sweep that refuses.
  for (let i = 0; i < 2001; i++) {
    db.set(`messages/poll-${i}/poll_votes/${UID}`, {
      voterId: UID,
      optionIds: ["opt-a"],
    });
  }

  const ok = await deleteMessages(asDb(db), UID);

  check(
    "an implausible poll-vote count is not swept",
    db.has(`messages/poll-0/poll_votes/${UID}`),
  );
  check(
    "…and the step reports INCOMPLETE, so the audit cannot say gdprCompliant",
    ok === false,
    `deleteMessages returned ${ok}`,
  );
}

/**
 * BUT-1801: poll AUTHORSHIP is capped too, and for a reason the vote sweep does
 * NOT share.
 *
 * A peer cannot seat a `poll_votes` row for someone else — the rules pin
 * `request.auth.uid == voterId` on every write verb — so that cap guards only
 * self-inflation. Authorship is the opposite: the `messages` create rule pins
 * required fields but carries no `hasOnly`, so `metadata` is unconstrained and
 * any participant can plant `metadata.poll.creatorId: <victimUid>` on a message
 * in their own DM. The row count is chosen by other people, which is exactly the
 * shape that lets somebody else size a victim's erasure bill.
 *
 * The scrub was briefly UNCAPPED, justified in a comment as "self-bounded — only
 * this user authors this user's polls". That claim was false, and this file
 * already said so elsewhere. Declining beats truncating for the same reason as
 * every other cap here: a truncated scrub reports a clean erasure over rows it
 * never touched.
 *
 * What this pins is the DECLINE DECISION — mutation-proved: delete the
 * `authored.size > MAX` block and both checks below redden. It does NOT pin the
 * `.limit(MAX + 1)` on the query, and cannot: removing that limit leaves the
 * suite fully green, because the decision still sees 2001 rows and still
 * declines. The limit bounds the READ (cost), the check bounds the WRITE
 * (correctness), and only the second is observable from here. Do not read a
 * green suite as evidence the read stayed bounded.
 */
async function scenario_implausiblePollAuthorshipDeclines(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deletePollVotes } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set("conversations/group-3", { participantIds: [UID, OTHER] });
  // 2001 is the smallest count that trips a `.limit(MAX + 1)` read.
  for (let i = 0; i < 2001; i++) {
    db.set(`messages/planted-${i}`, {
      conversationId: "group-3",
      senderId: OTHER,
      metadata: { poll: { id: `p-${i}`, creatorId: UID, options: [] } },
    });
  }

  const ok = await deletePollVotes(asDb(db), UID);

  check(
    "an implausible poll-authorship count reports INCOMPLETE",
    ok === false,
    `deletePollVotes returned ${ok}`,
  );
  const planted = db.get("messages/planted-0") as
    | { metadata?: { poll?: { creatorId?: string } } }
    | undefined;
  check(
    "…and scrubs nothing rather than truncating",
    planted?.metadata?.poll?.creatorId === UID,
    `creatorId was ${planted?.metadata?.poll?.creatorId}`,
  );
}

/** A residual-probe result envelope, fresh for each probe call. */
function emptyResult(): {
  deletedCollections: string[];
  failedCollections: string[];
  errors: string[];
} {
  return { deletedCollections: [], failedCollections: [], errors: [] };
}

function sawResidual(result: { failedCollections: string[] }): boolean {
  return result.failedCollections.includes("residual_data_detected");
}

/**
 * BUT-1957: `users/{uid}/notifications`.
 *
 * Written by `analytics/detect-lapsed-users.ts` and
 * `notifications/send-activity-digest.ts`, and it carries the push text ACTUALLY
 * SHOWN (`message`/`bodyShown`) plus the win-back A/B assignment. Nothing
 * reached it — deleting `users/{uid}` does not delete its subcollections, so
 * every row survived erasure.
 *
 * The other user's row is the half that says this is a sweep and not a
 * collection wipe; `deleteUserSubcollections` reads through the user document,
 * so a mutant swapping the uid would still empty the target and only this
 * assertion would notice.
 */
async function scenario_userNotificationRowsAreErased(): Promise<void> {
  const {
    deleteUserSubcollections,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set(`users/${UID}`, { displayName: "Raderad" });
  db.set(`users/${UID}/notifications/n1`, {
    message: "Vi saknar dig i köket!",
    variant: "winback_b",
    contextKey: "lapsed_14d",
  });
  db.set(`users/${UID}/notifications/n2`, { bodyShown: "3 nya recept" });
  db.set(`users/${OTHER}/notifications/n3`, { message: "Hej igen" });

  const ok = await deleteUserSubcollections(asDb(db), UID);
  check("deleteUserSubcollections reports success", ok === true, `returned ${ok}`);
  check(
    "every users/{uid}/notifications row is erased",
    db.pathsUnder(`users/${UID}/notifications`).length === 0,
    `left: ${JSON.stringify(db.pathsUnder(`users/${UID}/notifications`))}`,
  );
  check(
    "…and another user's notification rows are untouched",
    db.has(`users/${OTHER}/notifications/n3`),
    "the other user's row was swept too",
  );
}

/**
 * BUT-1956: `analytics/notifications/effectiveness`, written daily by
 * `analytics/correlate-notifications.ts` with a RAW `userId`. It was reached by
 * no cascade step, no `onUserDeleted` leg and no TTL.
 */
async function scenario_notificationEffectivenessRowsAreErased(): Promise<void> {
  const {
    deleteNotificationEffectiveness,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set("analytics/notifications/effectiveness/e1", {
    userId: UID,
    opened: true,
  });
  db.set("analytics/notifications/effectiveness/e2", {
    userId: UID,
    opened: false,
  });
  db.set("analytics/notifications/effectiveness/e3", { userId: OTHER });

  const ok = await deleteNotificationEffectiveness(asDb(db), UID);
  check(
    "deleteNotificationEffectiveness reports success",
    ok === true,
    `returned ${ok}`,
  );
  check(
    "the erased user's effectiveness rows are gone",
    !db.has("analytics/notifications/effectiveness/e1") &&
      !db.has("analytics/notifications/effectiveness/e2"),
    "at least one row survived",
  );
  check(
    "…and another user's effectiveness row survives",
    db.has("analytics/notifications/effectiveness/e3"),
    "the sweep was not keyed on userId",
  );
}

/**
 * The `listCollections()` leg of `probeResidualData` (BUT-1957).
 *
 * The leg it replaced was a hand-written include-list naming ONE subcollection,
 * so anything absent from it was not merely unreported — it was invisible, and
 * the cascade returned an all-clear with the rows still on disk. This asserts
 * the enumeration reports what the database actually holds.
 *
 * The clean control is not decoration: the probe's outer catch fails CLOSED, so
 * a fake missing `listCollections()` would count residual on every fixture and
 * make the dirty case pass for the wrong reason.
 */
async function scenario_probeEnumeratesUserSubcollections(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  clean.set(`users/${OTHER}/notifications/n3`, { message: "Hej igen" });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a user with no subcollection rows left probes CLEAN",
    !sawResidual(cleanResult),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set(`users/${UID}/notifications/n1`, { message: "Vi saknar dig" });
  const dirtyResult = emptyResult();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a leftover users/{uid}/notifications row is reported as residual",
    sawResidual(dirtyResult),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );

  // The enumeration's whole point is that it is NOT a list: a subcollection no
  // deleter and no test ever named must still be reported. A fixture using the
  // name the ticket fixed would pass equally well against a two-name include
  // list, which is the state this leg replaced.
  const unknown = new FakeFirestore();
  unknown.set(`users/${UID}/a_subcollection_nobody_listed/x`, { secret: 1 });
  const unknownResult = emptyResult();
  await probeResidualData(asDb(unknown), UID, unknownResult);
  check(
    "…and so is a subcollection no deleter has ever heard of",
    sawResidual(unknownResult),
    `failed: ${JSON.stringify(unknownResult.failedCollections)}`,
  );
}

/**
 * The two exclusions are load-bearing in the OTHER direction (BUT-1957).
 *
 * `notificationCounters` and `recentContentHashes` belong to `onUserDeleted`
 * (`cleanupContentGuardSubcollections`), which runs AFTER
 * `admin.auth().deleteUser(uid)` — so this probe, which runs before it, always
 * sees them still populated. Without the exclusion every single deletion of
 * every user would report residual and `gdprCompliant` would be false forever,
 * with nothing able to clear it.
 *
 * That failure mode is invisible to every other test in this file: they seed no
 * guard rows, so the exclusion is never exercised and deleting it stays green.
 */
async function scenario_probeExcludesTriggerOwnedSubcollections(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set(`users/${UID}/notificationCounters/2026-09-02`, { count: 4 });
  db.set(`users/${UID}/recentContentHashes/abc123`, { hash: "abc123" });
  const result = emptyResult();
  await probeResidualData(asDb(db), UID, result);
  check(
    "the two trigger-owned subcollections are NOT residual — they outlive this probe by design",
    !sawResidual(result),
    `failed: ${JSON.stringify(result.failedCollections)}`,
  );

  // The pair is exercised one at a time as well: an exclusion set that lost a
  // single entry would still be caught by the case above, but the message would
  // not say which, and a mutant dropping only one would be attributed to both.
  for (const name of ["notificationCounters", "recentContentHashes"]) {
    const single = new FakeFirestore();
    single.set(`users/${UID}/${name}/row`, { v: 1 });
    const singleResult = emptyResult();
    await probeResidualData(asDb(single), UID, singleResult);
    check(
      `…including ${name} on its own`,
      !sawResidual(singleResult),
      `failed: ${JSON.stringify(singleResult.failedCollections)}`,
    );
  }
}

/**
 * `users/{uid}/settings` must be erased as a COLLECTION, not as one document id.
 *
 * `deleteUserPreferences` used to delete `settings/preferences` by id while
 * `probeResidualData` counts the collection. `firestore.rules` leaves the id
 * unconstrained on an owner-only create, so a second document under `settings`
 * was both an un-erased Art. 17 residual and a `gdprCompliant: false` no code
 * path could clear.
 *
 * The pre-existing coverage-map case seeds `settings/preferences` and therefore
 * passes either way — it is the seeded id that made it green, not the deleter's
 * scope. This case is the one that can tell them apart.
 */
async function scenario_settingsIsErasedAsACollectionNotOneDocument(): Promise<void> {
  const {
    deleteUserPreferences,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set(`users/${UID}/settings/preferences`, { theme: "dark" });
  db.set(`users/${UID}/settings/somethingElse`, { v: 1 });
  db.set(`users/${OTHER}/settings/preferences`, { theme: "light" });

  await deleteUserPreferences(asDb(db), UID);

  check(
    "deleteUserPreferences erases a settings document that is NOT `preferences`",
    db.get(`users/${UID}/settings/somethingElse`) === undefined,
    "a second settings document survived the cascade",
  );
  check(
    "…and `preferences` itself, as before",
    db.get(`users/${UID}/settings/preferences`) === undefined,
    "the original settings document survived",
  );
  check(
    "…and another user's settings are untouched",
    db.get(`users/${OTHER}/settings/preferences`) !== undefined,
    "the other user's settings were erased too",
  );

  const result = emptyResult();
  await probeResidualData(asDb(db), UID, result);
  check(
    "…so the enumerating probe reports no residual settings",
    !sawResidual(result),
    `failed: ${JSON.stringify(result.failedCollections)}`,
  );
}

/**
 * The `users/{uid}` subcollections BUT-1957 added to `subs` that have no tier
 * step of their own.
 *
 * Some are written today and were simply never erased; others are names only
 * `admin/reset-user-data.ts` still mentions, where a row can predate their
 * removal. That distinction does not matter here, and that is the point: the
 * probe asks the database what is left instead of consulting a list, so a row
 * under ANY of these names would be reported as residual on every deletion of
 * that account with nothing able to erase it — a `gdprCompliant` that is false
 * forever and unclearable.
 *
 * The invariant this pins is DELETER ⊇ PROBE. Without it the two disagree, and
 * the direction they disagree in is the one that cannot be recovered from.
 *
 * Seeded through the whole cascade rather than the probe alone, because the
 * claim is about the two halves agreeing, not about either one on its own.
 */
async function scenario_steplessSubcollectionsAreErasedNotJustReported(): Promise<void> {
  const {
    deleteUserSubcollections,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  // `notifications` is absent: it has its own scenario above.
  const NO_OWN_STEP = [
    // written today
    "onboarding",
    "ingredients",
    "rate_limits",
    "counters",
    // no live writer found; rows can predate their removal
    "category_memberships",
    "connection_tests",
    "unified_recipes",
    "conversations",
    "fcm_tokens",
  ];

  for (const name of NO_OWN_STEP) {
    const db = new FakeFirestore();
    db.set(`users/${UID}/${name}/legacy-row`, { v: 1 });
    db.set(`users/${OTHER}/${name}/legacy-row`, { v: 1 });

    await deleteUserSubcollections(asDb(db), UID);

    const result = emptyResult();
    await probeResidualData(asDb(db), UID, result);
    check(
      `a ${name} row is erased, so the enumerating probe reports nothing`,
      !sawResidual(result),
      `failed: ${JSON.stringify(result.failedCollections)}`,
    );
    check(
      `…and another user's ${name} row survives`,
      db.get(`users/${OTHER}/${name}/legacy-row`) !== undefined,
      "the other user's legacy row was erased too",
    );
  }
}

/**
 * The `analytics/notifications/effectiveness` leg of the probe (BUT-1956).
 *
 * A deleter without a probe leg is how this class of gap survives: `batchDeleteAll`
 * commits `strict: false`, so a failed chunk is swallowed and
 * `deleteNotificationEffectiveness` returns true over rows it did not remove.
 * This leg is the only contradiction to that `return true`.
 */
async function scenario_probeSeesLeftoverNotificationEffectiveness(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  clean.set("analytics/notifications/effectiveness/e3", { userId: OTHER });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "another user's effectiveness row is not this user's residual",
    !sawResidual(cleanResult),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set("analytics/notifications/effectiveness/e1", { userId: UID });
  const dirtyResult = emptyResult();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a leftover notification-effectiveness row is reported as residual",
    sawResidual(dirtyResult),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );
}

/**
 * The RESURRECTION window (BUT-1956).
 *
 * `correlateNotificationEffectiveness` runs daily inside `dailyAnalytics` and
 * writes `effectiveness/{id}` rows from pages it is already holding in memory.
 * A cascade landing mid-run can therefore have a row written back AFTER the
 * deleter swept, and the deleter — which has already returned true — cannot
 * know. The probe runs later in the same cascade, so it can.
 *
 * This is the case that proves the probe is not merely a mirror of the deleter:
 * the deleter succeeded, the store was empty when it finished, and the run must
 * still come back `gdprCompliant: false`.
 */
async function scenario_effectivenessRowWrittenBackAfterTheSweep(): Promise<void> {
  const {
    deleteNotificationEffectiveness,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set("analytics/notifications/effectiveness/e1", { userId: UID });

  const ok = await deleteNotificationEffectiveness(asDb(db), UID);
  check(
    "the deleter reports success and leaves the collection clean",
    ok === true && !db.has("analytics/notifications/effectiveness/e1"),
    `returned ${ok}, remaining: ${JSON.stringify(db.pathsUnder("analytics/notifications/effectiveness"))}`,
  );

  // The daily correlation job flushing a page it read before the cascade began.
  db.set("analytics/notifications/effectiveness/e-resurrected", {
    userId: UID,
    opened: true,
  });

  const result = emptyResult();
  await probeResidualData(asDb(db), UID, result);
  check(
    "a row written back AFTER the sweep still fails the run — the probe is not a mirror of the deleter",
    sawResidual(result),
    `failed: ${JSON.stringify(result.failedCollections)}`,
  );
}

/**
 * BUT-1957 drift guard: no `users/{uid}` subcollection any writer in this repo
 * creates may be left unreached by the cascade.
 *
 * A one-time audit goes stale on the next feature — `notifications` and
 * `onboarding` are both cases of exactly that. So the universe here is DERIVED
 * from the sources on every run, not typed out: every
 * `.collection("users").doc(...).collection("<name>")` chain under
 * `functions/src` and `lib`. A new subcollection writer therefore enters this
 * fixture by itself and reddens this scenario until something erases it.
 *
 * Each name must land in exactly one of three buckets, and two of them are read
 * OUT OF THE PRODUCTION SOURCE rather than restated here (a restated copy is
 * what drifts):
 *  1. the `subs` list inside `deleteUserSubcollections`;
 *  2. `TRIGGER_OWNED_SUBCOLLECTIONS` in `probeResidualData` — owned by
 *     `onUserDeleted`, which runs after this cascade;
 *  3. `COVERED_BY_OWN_STEP` below, for the ones with a dedicated tier step.
 *
 * Bucket 3 cannot be filled in with a lie: each entry is EXERCISED — a row is
 * seeded under that subcollection, the named deleter is run, and the row must be
 * gone. A map entry naming a function that does not touch the collection fails
 * here.
 *
 * **What this does NOT cover, stated rather than implied.** The scan reads the
 * `collection(users).doc(...).collection(X)` chain and resolves `X` when it is a
 * literal, a `FirestoreCollections`/`Collections` member, or a file-local
 * `const`. Anything else — a path assembled in a helper, a name passed in as a
 * parameter, a getter — is invisible, and a subcollection written only that way
 * will NOT appear here.
 *
 * That gap is not hypothetical and this test has already been widened twice by
 * it: resolving the shared constants is what surfaced `ingredients`,
 * `rate_limits` and `counters`, and resolving file-local consts is what
 * surfaced `acquisition` — each of them a live writer with no deleter, and each
 * found by a reviewer rather than by this test.
 *
 * Do not write a COUNT of how many names come from `lib/` versus
 * `functions/src` here. Two such counts were written during this change and
 * both were wrong, one of them refuted by the very commit that added it.
 */
/**
 * Every `users/{uid}/<name>` subcollection named by a `.collection(users)
 * .doc(x).collection(name)` chain anywhere in `lib/` or `functions/src`, mapped
 * to the first file naming it.
 *
 * A chain is not proof of a WRITE — a read builds the same path — so a caller
 * asking "does anything write this?" is really asking "does anything touch it",
 * which is the conservative direction for both guards that use it.
 *
 * Shared by BOTH drift guards — the deletion half (DELETION ⊇ WRITERS) and the
 * export half (BUT-1992). One parser, because two scanners that must agree is
 * the shape this file exists to stop.
 */
function discoverUserSubcollectionWriters(
  repoRoot: string,
): Map<string, string> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");

  // The second `collection(...)` may be a literal OR a constant reference.
  // Matching only literals is what made the first `subs` audit miss two live
  // Dart writers (BUT-1957): every Dart repository builds the path from a
  // `FirestoreCollections` constant, so a literal-only scan saw the server and
  // essentially none of the client. Resolve the constants first.
  const collectionConstants = new Map<string, string>();
  for (const constFile of [
    path.join(repoRoot, "lib", "core", "constants", "firestore_collections.dart"),
    path.join(repoRoot, "functions", "src", "shared", "collections.ts"),
  ]) {
    if (!fs.existsSync(constFile)) continue;
    const src = fs.readFileSync(constFile, "utf8") as string;
    for (const m of src.matchAll(
      /(?:static\s+const\s+String\s+|^\s*)([A-Za-z_]\w*)\s*[:=]\s*['"]([A-Za-z_]+)['"]/gm,
    )) {
      collectionConstants.set(m[1], m[2]);
    }
  }

  // `\w*` and not `[A-Za-z_]\w*` before `[Uu]sers`. BUT-1992 measured the
  // difference: the stricter form REQUIRES a character in front of "users", so
  // it matched `FirestoreCollections.usersCollection` and never the bare
  // `FirestoreCollections.users` that every Dart repository actually writes.
  // This scan saw 15 subcollections where there are 23 — blind to
  // category_preferences, conversation_memberships, counters, friend_categories,
  // ingredients, list_category_orders, rate_limits and report_throttle. All
  // eight were already in `subs`, so nothing was unerasable; what was wrong is
  // that this check has been ranging over two thirds of its subject while
  // reading as exhaustive, and the next Dart writer of a NEW subcollection
  // would have been invisible to it.
  const chain =
    /collection\(\s*(?:['"]users['"]|(?:[A-Za-z_]\w*\.)?\w*[Uu]sers\w*)\s*\)\s*\.\s*doc\(\s*[^)]*\)\s*\.\s*collection\(\s*([^)\s]+)\s*\)/gs;
  const discovered = new Map<string, string>();
  // Comments in this repo spell example chains out in prose — this very test
  // reddened on a `.collection("users").doc(x).collection("y")` written inside
  // a comment in the cascade. Same trap BUT-1941 records for the golden lint:
  // strip comments before matching, or the scanner reads documentation as code.
  const stripComments = (t: string): string =>
    t.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
  const walk = (dir: string, exts: string[]): void => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === "__tests__" || entry.name === "node_modules") continue;
        walk(full, exts);
        continue;
      }
      if (!exts.some((e: string) => entry.name.endsWith(e))) continue;
      const text = stripComments(fs.readFileSync(full, "utf8") as string);
      // File-LOCAL consts too. `firebase_acquisition_repository.dart` writes
      // `users/{uid}/acquisition` through a private `static const` and was
      // invisible to a scan that resolved only the shared constants file —
      // which is how `acquisition` reached production unerasable.
      const localConsts = new Map<string, string>();
      for (const c of text.matchAll(
        /(?:static\s+)?const\s+(?:String\s+)?([A-Za-z_]\w*)\s*=\s*['"]([A-Za-z_]+)['"]/g,
      )) {
        localConsts.set(c[1], c[2]);
      }
      for (const m of text.matchAll(chain)) {
        const raw = m[1].trim();
        const literal = /^['"]([A-Za-z_]+)['"]$/.exec(raw);
        const viaConst = /^(?:FirestoreCollections|Collections)\.(\w+)$/.exec(raw);
        const viaLocal = /^([A-Za-z_]\w*)$/.exec(raw);
        const name = literal
          ? literal[1]
          : viaConst
            ? collectionConstants.get(viaConst[1])
            : viaLocal
              ? localConsts.get(viaLocal[1])
              : undefined;
        // An unresolvable expression (a parameter, a getter) is skipped rather
        // than guessed — it would be a name no bucket can contain, and this
        // test must fail on real drift, not on its own parser.
        if (name && !discovered.has(name)) discovered.set(name, full);
      }
    }
  };
  walk(path.join(repoRoot, "functions", "src"), [".ts"]);
  walk(path.join(repoRoot, "lib"), [".dart"]);
  return discovered;
}

async function scenario_everyUserSubcollectionHasADeleter(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const cascade = require("../account/account-deletion-cascade");

  const repoRoot = path.join(__dirname, "..", "..", "..");
  const cascadeSource = fs.readFileSync(
    path.join(__dirname, "..", "account", "account-deletion-cascade.ts"),
    "utf8",
  ) as string;

  /** Quoted string literals inside the array/set literal that follows `anchor`. */
  const namesAfter = (anchor: string): string[] => {
    const start = cascadeSource.indexOf(anchor);
    if (start < 0) return [];
    const open = cascadeSource.indexOf("[", start);
    if (open < 0) return [];
    // Bracket-matched, not `indexOf("];")`: the exclusion set is written
    // `new Set([...])`, so its literal closes with `])` and a naive scan ran on
    // to the next array in the file and swallowed half the module — which is
    // exactly the shape of over-broad parse that makes a drift guard pass while
    // ranging over the wrong thing.
    let depth = 0;
    let close = -1;
    for (let i = open; i < cascadeSource.length; i++) {
      if (cascadeSource[i] === "[") depth++;
      else if (cascadeSource[i] === "]") {
        depth--;
        if (depth === 0) {
          close = i;
          break;
        }
      }
    }
    if (close < 0) return [];
    const body = cascadeSource
      .slice(open, close)
      // Line comments in these blocks name sibling FUNCTIONS and collections in
      // prose; stripping them keeps the parse to real entries.
      .replace(/\/\/[^\n]*/g, "");
    return [...body.matchAll(/"([A-Za-z_]+)"/g)].map((m) => m[1]);
  };

  const subs = namesAfter("const subs = ");
  const triggerOwned = namesAfter("const TRIGGER_OWNED_SUBCOLLECTIONS = ");
  check(
    "the drift guard can still read `subs` out of the cascade source",
    subs.length > 5 && subs.includes("notifications"),
    `parsed subs: ${JSON.stringify(subs)}`,
  );
  check(
    "…and TRIGGER_OWNED_SUBCOLLECTIONS, both entries",
    triggerOwned.length === 2 &&
      triggerOwned.includes("notificationCounters") &&
      triggerOwned.includes("recentContentHashes"),
    `parsed exclusions: ${JSON.stringify(triggerOwned)}`,
  );

  /** name -> [exported deleter, doc id to seed]. */
  const COVERED_BY_OWN_STEP: Record<string, [string, string]> = {
    recipes: ["deleteRecipes", "r1"],
    menus: ["deleteMenus", "m1"],
    pantry: ["deletePantryItems", "p1"],
    personal_tags: ["deletePersonalTags", "t1"],
    personal_tag_groups: ["deletePersonalTagGroups", "g1"],
    consent: ["deleteConsentRecords", "c1"],
    settings: ["deleteUserPreferences", "preferences"],
    // Surfaced the moment the scanner learned to resolve constants and to skip
    // comments: it is genuinely covered by its own tier step, it was simply
    // never visible to this map before.
    unified_shopping_lists: ["deleteShoppingLists", "l1"],
  };

  const discovered = discoverUserSubcollectionWriters(repoRoot);

  check(
    "the source scan found the writers it is supposed to range over",
    discovered.has("notifications") &&
      discovered.has("onboarding") &&
      discovered.has("recentContentHashes"),
    `discovered: ${JSON.stringify([...discovered.keys()].sort())}`,
  );

  const uncovered: string[] = [];
  for (const name of [...discovered.keys()].sort()) {
    if (subs.includes(name)) continue;
    if (triggerOwned.includes(name)) continue;
    if (name in COVERED_BY_OWN_STEP) continue;
    uncovered.push(`${name} (chained in ${discovered.get(name)})`);
  }
  check(
    "every users/{uid} subcollection any repo chain names is reached by the cascade",
    uncovered.length === 0,
    `unreached, so the probe will report them as residual forever: ${JSON.stringify(uncovered)}`,
  );

  for (const [name, [fnName, docId]] of Object.entries(COVERED_BY_OWN_STEP)) {
    const db = new FakeFirestore();
    db.set(`users/${UID}`, { displayName: "Raderad" });
    db.set(`users/${UID}/${name}/${docId}`, { v: 1 });
    db.set(`users/${OTHER}/${name}/${docId}`, { v: 1 });
    const fn = cascade[fnName];
    check(
      `${fnName} is exported, so the coverage map names something real`,
      typeof fn === "function",
      `cascade.${fnName} is ${typeof fn}`,
    );
    if (typeof fn !== "function") continue;
    await fn(asDb(db), UID);
    check(
      `${fnName} really erases users/{uid}/${name}`,
      !db.has(`users/${UID}/${name}/${docId}`),
      "the row survived the step the coverage map credits it to",
    );
    check(
      `…and leaves another user's ${name} alone`,
      db.has(`users/${OTHER}/${name}/${docId}`),
      "the step is not keyed on the uid",
    );
  }
}

/**
 * BUT-1992 — the invariant is EXPORT ⊇ DELETION.
 *
 * Anything in the cascade's `subs` list must have been obtainable by its
 * subject first, or it is destroyed having never been disclosable under
 * Art. 15. Collections erased by their own tier steps are outside what this
 * ranges over; the sibling scenario proves those have a DELETER, not an export. BUT-1957 gave
 * the DELETION half a source-derived guard; this is its counterpart, and the
 * ticket's own framing is that the missing guard — not any single gap — is the
 * defect. Every future widening of `subs` repeats the mistake otherwise, and
 * nothing reddens.
 *
 * Both halves are derived from SOURCE. `subs` is parsed out of the cascade, and
 * the exported set is parsed out of the export repository's
 * `.collection(users).doc(uid).collection(X)` chains. Neither is a hand-kept
 * list, because two hand-kept lists that must agree is precisely how BUT-1957's
 * own two gaps were created.
 *
 * The anchor is the CHAIN, not `ExportResourceType`: that enum has fewer members
 * than the repository has export methods, the mapping is many-to-one, and its
 * values are log labels rather than paths — so a new section can reuse an
 * existing member and this guard would pass green (the DBA seat's finding).
 *
 * This scenario reads DART source, so its CI trigger has to reach Dart. It did
 * not: the workflow fired on `functions/**` only, and the change most likely to
 * break the invariant — a repository starting to write a new subcollection, or
 * an export section being deleted — is Dart-only, so the guard slept through
 * exactly its own case. `cloud-functions-unit.yml` now lists the `lib/` paths,
 * and `assertGuardTriggersCoverItsDartInputs` below derives what it must list
 * from the files this scenario actually opens, so the two cannot drift apart
 * silently in either direction. BUT-2002.
 */
async function scenario_exportCoversEveryDeletedSubcollection(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const cascade = require("../account/account-deletion-cascade");

  const repoRoot = path.join(__dirname, "..", "..", "..");
  const cascadeSource = fs.readFileSync(
    path.join(__dirname, "..", "account", "account-deletion-cascade.ts"),
    "utf8",
  ) as string;

  // Same bracket-matched parse the deletion half uses, for the same reason: a
  // naive `indexOf("];")` runs past a `new Set([...])` and swallows the module.
  const subsNames = (): string[] => {
    const start = cascadeSource.indexOf("const subs = ");
    const open = cascadeSource.indexOf("[", start);
    let depth = 0;
    let close = -1;
    for (let i = open; i < cascadeSource.length; i++) {
      if (cascadeSource[i] === "[") depth++;
      else if (cascadeSource[i] === "]") {
        depth--;
        if (depth === 0) {
          close = i;
          break;
        }
      }
    }
    const body = cascadeSource.slice(open, close).replace(/\/\/[^\n]*/g, "");
    return [...body.matchAll(/"([A-Za-z_]+)"/g)].map((m) => m[1]);
  };

  const subs = subsNames();
  check(
    "the export guard can still read `subs` out of the cascade source",
    subs.length > 5 && subs.includes("ingredients"),
    `parsed subs: ${JSON.stringify(subs)}`,
  );

  // The exempt map is imported from PRODUCTION source, not restated here. An
  // exemption added to a test file reads as bookkeeping and gets waved through;
  // one added to the cascade shows up in the diff a reviewer is already reading.
  const exempt = cascade.EXPORT_EXEMPT as Record<string, string>;
  check(
    "EXPORT_EXEMPT is exported from the cascade and is a real map",
    exempt && typeof exempt === "object" && Object.keys(exempt).length > 0,
    `EXPORT_EXEMPT is ${typeof exempt}`,
  );

  // An exemption with no stated reason is the rubber stamp this design exists to
  // prevent, so it fails as loudly as a missing one.
  const unreasoned = Object.entries(exempt)
    .filter(([, why]) => typeof why !== "string" || why.trim().length < 20)
    .map(([name]) => name);
  check(
    "every exemption states a reason",
    unreasoned.length === 0,
    `exempt without a written reason: ${JSON.stringify(unreasoned)}`,
  );

  // The exported set, read off the one file that performs user-scoped export
  // reads. Constants resolved, comments stripped — the repo writes example
  // chains in prose, and a scanner that reads documentation as code reddens on
  // its own docstrings.
  const collectionConstants = new Map<string, string>();
  const constFile = path.join(
    repoRoot,
    "lib",
    "core",
    "constants",
    "firestore_collections.dart",
  );
  if (fs.existsSync(constFile)) {
    const src = fs.readFileSync(constFile, "utf8") as string;
    for (const m of src.matchAll(
      /static\s+const\s+String\s+([A-Za-z_]\w*)\s*=\s*['"]([A-Za-z_]+)['"]/g,
    )) {
      collectionConstants.set(m[1], m[2]);
    }
  }

  const exportFile = path.join(
    repoRoot,
    "lib",
    "repositories",
    "firebase",
    "firebase_data_export_repository.dart",
  );
  const exportSource = (fs.readFileSync(exportFile, "utf8") as string)
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/[^\n]*/g, "");

  // `\w*` and not `[A-Za-z_]\w*` before `[Uu]sers`: the latter REQUIRES a
  // character in front, so it matches `FirestoreCollections.usersCollection`
  // and never the bare `FirestoreCollections.users` every Dart repository
  // actually writes. Measured — with the stricter form this scan found zero
  // sections and the guard would have passed by ranging over nothing.
  const chain =
    /collection\(\s*(?:['"]users['"]|(?:[A-Za-z_]\w*\.)?\w*[Uu]sers\w*)\s*\)\s*\.\s*doc\(\s*[^)]*\)\s*\.\s*collection\(\s*([^)\s]+)\s*\)/gs;
  const exported = new Set<string>();
  for (const m of exportSource.matchAll(chain)) {
    const raw = m[1].trim();
    const literal = /^['"]([A-Za-z_]+)['"]$/.exec(raw);
    const viaConst = /^FirestoreCollections\.(\w+)$/.exec(raw);
    const name = literal
      ? literal[1]
      : viaConst
        ? collectionConstants.get(viaConst[1])
        : undefined;
    if (name) exported.add(name);
  }

  check(
    "the export scan found the sections it is supposed to range over",
    exported.has("ingredients") &&
      exported.has("onboarding") &&
      exported.has("acquisition") &&
      exported.has("settings"),
    `discovered export sections: ${JSON.stringify([...exported].sort())}`,
  );

  const gaps: string[] = [];
  for (const name of [...new Set(subs)].sort()) {
    if (exported.has(name)) continue;
    if (name in exempt) continue;
    gaps.push(name);
  }
  check(
    "every subcollection the cascade erases is either exported or exempted with a reason",
    gaps.length === 0,
    "erased but never obtainable under Art. 15, and not written down as a " +
      `decision: ${JSON.stringify(gaps)}`,
  );

  // An exemption for something the cascade no longer deletes is dead text that
  // outlives its subject, and a reader cannot tell it from a live decision.
  // Seven exemptions are justified by the ABSENCE of a writer. That premise was
  // measured once, at the moment it was written, and nothing re-checks it — so
  // the day a feature starts writing one of those paths (`firestore.rules`
  // already permits the owner to write `users/{uid}/conversations`), the cascade
  // would erase rows the export never reproduced and this guard would still be
  // green, because `name in exempt` is unconditional. Reuses the SAME writer
  // scan the deletion half runs; the exemption text is the anchor, so a reason
  // rewritten away from "NO LIVE WRITER" is a deliberate act, not a silent one.
  const writers = discoverUserSubcollectionWriters(repoRoot);
  const revived = Object.entries(exempt)
    .filter(([name, why]) => why.startsWith("NO LIVE WRITER") && writers.has(name))
    .map(([name]) => `${name} (chained in ${writers.get(name)})`);
  check(
    "no legacy-only exemption has acquired a users/{uid} chain",
    revived.length === 0,
    "exempted as write-dead, but a `users/{uid}` chain names it — either a " +
      "writer appeared and the rows are now erased without ever being " +
      "exportable, or it is being exported and the exemption contradicts " +
      `that: ${JSON.stringify(revived)}`,
  );

  const stale = Object.keys(exempt).filter((n) => !subs.includes(n));
  check(
    "no exemption names a collection the cascade has stopped deleting",
    stale.length === 0,
    `exempt but absent from subs: ${JSON.stringify(stale)}`,
  );

  // BUT-2002. The two paths are the ones THIS scenario just opened, passed as
  // values rather than restated as literals — a hand-kept second copy of the
  // list is the drift this whole file exists to prevent.
  assertGuardTriggersCoverItsDartInputs(repoRoot, [constFile, exportFile]);
}

/**
 * BUT-2002. A guard that reads Dart is only as live as its CI trigger, and that
 * trigger lived in a different file with nothing tying the two together.
 *
 * Ranges over the files the caller actually opened, so it answers "will CI run
 * this scenario when one of its own inputs changes" rather than "does the
 * workflow contain some strings someone once typed".
 *
 * Checks `push` AND `pull_request` separately: they are two independent lists in
 * that file, and a fix applied to one is the obvious half-miss.
 *
 * NOT proven here: the workflow also lists `lib/services/account/**`, which this
 * scenario never reads. That glob is deliberate breadth, not a derived input —
 * the export MANAGERS and the service that builds them decide which repository
 * methods get called, so deleting a call there drops a section from the bundle
 * while the repository method survives and the chain-scan above still finds it.
 * This guard cannot see that case; the line is there so CI at least runs on it.
 */
function assertGuardTriggersCoverItsDartInputs(
  repoRoot: string,
  dartInputsAbsolute: string[],
): void {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");

  const workflowRelative = ".github/workflows/cloud-functions-unit.yml";
  const workflowPath = path.join(repoRoot, workflowRelative);
  check(
    "the guard can find its own CI workflow",
    fs.existsSync(workflowPath),
    `missing: ${workflowRelative}`,
  );
  if (!fs.existsSync(workflowPath)) return;
  const workflow = fs.readFileSync(workflowPath, "utf8") as string;

  /** The quoted entries under one `paths:` block, comments stripped. */
  const pathsUnder = (trigger: string): string[] => {
    const at = workflow.indexOf(`  ${trigger}:`);
    if (at < 0) return [];
    const pathsAt = workflow.indexOf("paths:", at);
    if (pathsAt < 0) return [];
    // The block ends at the first line that is not a comment and not a `- `
    // entry — i.e. the next key at any indentation.
    const lines = workflow.slice(pathsAt).split("\n").slice(1);
    const entries: string[] = [];
    for (const line of lines) {
      const t = line.trim();
      if (t === "" || t.startsWith("#")) continue;
      if (!t.startsWith("- ")) break;
      entries.push(t.slice(2).trim().replace(/^["']|["']$/g, ""));
    }
    return entries;
  };

  // Only the two glob shapes this file actually uses: a literal path, and a
  // trailing `/**`. Deliberately not a general glob engine — an approximate
  // matcher that silently says "covered" is the failure mode being fixed.
  const covers = (pattern: string, file: string): boolean =>
    pattern.endsWith("/**")
      ? file.startsWith(pattern.slice(0, -2))
      : pattern === file;

  // A GitHub `!` exclusion is the one shape that would make this matcher say
  // "covered" while CI skipped the file: the negation reads as an unmatchable
  // literal here, and the positive glob beside it still matches. Refused for
  // the whole trigger rather than modelled, because getting exclusion ordering
  // subtly wrong is how an approximate matcher goes quiet again.
  const rejectsNegations = (trigger: string, patterns: string[]): void => {
    check(
      `the ${trigger} trigger uses no path exclusions this guard cannot read`,
      patterns.every((p) => !p.startsWith("!")),
      "a `!` entry excludes files from the trigger, and the positive globs " +
        "beside it would still report this guard's inputs as covered: " +
        JSON.stringify(patterns.filter((p) => p.startsWith("!"))),
    );
  };

  const relativeInputs = dartInputsAbsolute.map((p) =>
    path.relative(repoRoot, p).split(path.sep).join("/"),
  );
  check(
    "the guard's Dart inputs resolved to repo-relative paths",
    relativeInputs.every((p) => p.startsWith("lib/")),
    `expected lib/ paths, got ${JSON.stringify(relativeInputs)}`,
  );

  for (const trigger of ["push", "pull_request"]) {
    const patterns = pathsUnder(trigger);
    check(
      `the ${trigger} trigger's paths: block is readable`,
      patterns.length > 0,
      `parsed no entries under ${trigger}`,
    );
    rejectsNegations(trigger, patterns);
    const uncovered = relativeInputs.filter(
      (file) => !patterns.some((p) => covers(p, file)),
    );
    check(
      `every Dart file this guard reads re-runs it on ${trigger}`,
      uncovered.length === 0,
      "this scenario reads these files but CI would not run it when they " +
        `change, so the invariant is unguarded for exactly the edit most ` +
        `likely to break it: ${JSON.stringify(uncovered)}`,
    );
  }
}

/**
 * The collection-group index the sweep needs. Firestore's AUTOMATIC single-field
 * indexes are COLLECTION-scoped, so a `collectionGroup('poll_votes')` query
 * filtered on `voterId` fails with FAILED_PRECONDITION without an explicit
 * `COLLECTION_GROUP` fieldOverride — the erasure would go from working to
 * throwing on every account deletion. Pinned here because a `--force` index
 * deploy prunes anything absent from that file.
 */
async function scenario_pollVoteIndexIsDeclared(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const indexes = JSON.parse(
    fs.readFileSync(
      path.join(__dirname, "..", "..", "..", "firestore.indexes.json"),
      "utf8",
    ),
  ) as {
    fieldOverrides?: {
      collectionGroup: string;
      fieldPath: string;
      indexes?: { order?: string; queryScope?: string }[];
    }[];
  };
  const override = (indexes.fieldOverrides ?? []).find(
    (o) => o.collectionGroup === "poll_votes" && o.fieldPath === "voterId",
  );
  check(
    "poll_votes.voterId has a COLLECTION_GROUP single-field index declared",
    (override?.indexes ?? []).some(
      (i) => i.queryScope === "COLLECTION_GROUP" && i.order === "ASCENDING",
    ),
    `override: ${JSON.stringify(override)}`,
  );
}

async function main(): Promise<void> {
  await scenario_directConversationIsErasedWhole();
  await scenario_readsTopLevelNotSubcollection();
  await scenario_groupThreadIsAnonymizedNotGutted();
  await scenario_messagesInLeftConversationsAreReached();
  await scenario_groupConversationDocumentIsScrubbed();
  await scenario_adHocSharedContentMembershipIsScrubbed();
  await scenario_anotherMembersLastMessageIsNotTombstoned();
  await scenario_realtimeMenusOwnedAreDeleted();
  await scenario_realtimeMenuLastEditorIsScrubbed();
  await scenario_ownedRealtimeMenuChildrenAreDeleted();
  await scenario_realtimeParticipationIsRemoved();
  await scenario_featureRetentionRowsAreErased();
  await scenario_retentionAnalyticsRowsAreErased();
  await scenario_retentionAnalyticsWithNoRowsSucceeds();
  await scenario_probeSeesLeftoverRetentionAnalytics();
  await scenario_systemMessageAboutDepartedUserIsScrubbed();
  await scenario_newerLastMessageSurvivesTheSystemScrub();
  await scenario_failedMirrorScrubKeepsTheRetryHandle();
  await scenario_ownRosterRowIsErasedInSurvivingGroup();
  await scenario_rosterIsClearedBeforeTheParentDelete();
  await scenario_unclearableRosterLeavesTheParentStanding();
  await scenario_probeSeesLeftoverRosterRows();
  await scenario_probeSeesLeftoverGroupMenuPlans();
  await scenario_probeSeesLeftoverRecipes();
  await scenario_rosterIndexIsDeclared();
  await scenario_chatGroupMembershipIsErasedEverywhere();
  await scenario_createdByIsReHomedWhenTheCreatorIsErased();
  await scenario_emptiedChatGroupIsTakenDownRosterFirst();
  await scenario_unclearableRosterLeavesTheChatGroupStanding();
  await scenario_implausibleChatGroupCountDeclines();
  await scenario_departureTombstoneIsErased();
  await scenario_mealVotePointerOwnerIsErased();
  await scenario_residualLegsSurviveTheMembershipDecline();
  await scenario_deleteMessagesSkipsGroupOwnedConversations();
  await scenario_probeSeesLeftoverChatGroupMembership();
  await scenario_probeSeesLeftoverBlockMirrors();
  await scenario_blockMirrorsLoseTheErasedUid();
  await scenario_implausibleMirrorCountDeclines();
  await scenario_blockMirrorExemptionRestsOnIncomingBlocks();
  await scenario_blocksAreErasedInBothDirections();
  await scenario_probeSeesLeftoverBlocks();
  await scenario_resetScriptDeleteListNamesBlocks();
  await scenario_resetScriptListsDoNotOverlap();
  await scenario_everyCollectionIsDecided();
  await scenario_resetScriptRefusesLiveRuns();
  await scenario_implausibleBlockCountDeclines();
  await scenario_aDeclinedLegDoesNotStopTheOther();
  await scenario_pollVotesAndAuthorshipAreErased();
  await scenario_probeSeesLeftoverPollResidues();
  await scenario_pollCreatorScrubToleratesOnlyNotFound();
  await scenario_implausiblePollVoteCountDeclines();
  await scenario_implausiblePollAuthorshipDeclines();
  await scenario_pollVoteIndexIsDeclared();
  await scenario_userNotificationRowsAreErased();
  await scenario_notificationEffectivenessRowsAreErased();
  await scenario_probeEnumeratesUserSubcollections();
  await scenario_probeExcludesTriggerOwnedSubcollections();
  await scenario_steplessSubcollectionsAreErasedNotJustReported();
  await scenario_settingsIsErasedAsACollectionNotOneDocument();
  await scenario_probeSeesLeftoverNotificationEffectiveness();
  await scenario_effectivenessRowWrittenBackAfterTheSweep();
  await scenario_everyUserSubcollectionHasADeleter();
  await scenario_exportCoversEveryDeletedSubcollection();

  let failed = 0;
  for (const r of results) {
    if (r.passed) {
      console.log(`  PASS  ${r.name}`);
    } else {
      console.log(`  FAIL  ${r.name}${r.reason ? `\n        ${r.reason}` : ""}`);
      failed++;
    }
  }

  console.log(
    `\nBUT-1766/BUT-1768 deletion cascade: ${results.length - failed}/${results.length} passing`,
  );
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
