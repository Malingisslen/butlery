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
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-cascade" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteMessages,
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
  where(field: string, op: string, value: unknown): { get(): Promise<FakeQuerySnapshot> };
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
        this.docs.delete(path);
      },
      update: async (data: DocData) => {
        this.applyUpdate(path, data);
      },
      // Subcollections are real in Firestore and NOT deleted with their parent
      // — the whole point of the orphan findings this suite now covers. The
      // stub models them as deeper slash-separated keys.
      collection: (name: string): FakeSubcollection => {
        const snapshotOf = (paths: string[]): FakeQuerySnapshot => ({
          empty: paths.length === 0,
          size: paths.length,
          docs: paths.map((p) => ({
            ref: this.makeRef(p),
            id: p.split("/").pop() as string,
            data: () => this.docs.get(p) as DocData,
          })),
        });
        return {
          get: async () => snapshotOf(this.pathsUnder(`${path}/${name}`)),
          doc: (id: string) => this.makeRef(`${path}/${name}/${id}`),
          where: (field: string, op: string, value: unknown) => ({
            get: async () =>
              snapshotOf(
                this.pathsUnder(`${path}/${name}`).filter((p) => {
                  const fieldVal = (this.docs.get(p) as DocData)[field];
                  if (op === "==") return fieldVal === value;
                  if (op === "array-contains") {
                    return Array.isArray(fieldVal) && fieldVal.includes(value);
                  }
                  return false;
                }),
              ),
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
  private static readField(data: DocData, field: string): unknown {
    let cursor: unknown = data;
    for (const segment of field.split(".")) {
      if (cursor === null || typeof cursor !== "object") return undefined;
      cursor = (cursor as Record<string, unknown>)[segment];
    }
    return cursor;
  }

  collection(name: string): unknown {
    const matcher = (field: string, op: string, value: unknown) => ({
      get: async () => {
        const matches: { path: string; data: DocData }[] = [];
        for (const [path, data] of this.docs) {
          const segments = path.split("/");
          if (segments.length !== 2 || segments[0] !== name) continue;
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
    return {
      where: (field: string, op: string, value: unknown) =>
        matcher(field, op, value),
      doc: (id: string) => this.makeRef(`${name}/${id}`),
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
    return {
      where: (field: string, op: string, value: unknown) => ({
        get: async () => {
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
          return {
            empty: matches.length === 0,
            size: matches.length,
            docs: matches.map((d) => ({
              ref: this.makeRef(d.path),
              id: d.path.split("/").pop() as string,
              data: () => d.data,
              get: (f: string) => FakeFirestore.readField(d.data, f),
            })),
          };
        },
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
        for (const path of deletes) this.docs.delete(path);
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
 * BUT-1798. `removeFromSharedContent` discovered membership ONLY through a
 * `members/{uid}` subcollection doc, which is written by
 * `BaseSharedContentRepository.addMember()` and by nothing else. The three
 * direct-share managers (recipe_sharing_manager, social_menu_operations,
 * shopping_social_share_module) write the parent document only — so every
 * recipient of an ad-hoc shared recipe, menu or list has been un-erasable for
 * this collection's entire life, on documents the Art. 15 export has just
 * started returning.
 *
 * Two further traps this pins:
 *  - membership is stored under TWO spellings, and the old scrub cleared only
 *    `sharedToUserIds`, leaving the uid in `sharedWithUserIds`;
 *  - the owner is always in their own membership arrays, so scrubbing without
 *    excluding owned docs would update every document the very next step hard-
 *    deletes — wasted writes, and a NOT_FOUND poison-pill on retry.
 */
async function scenario_adHocSharedContentMembershipIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();

  // Legacy row: only the OLD spelling. No client query can even see this one.
  db.set("shared_content/legacy-recipe", {
    contentType: "recipe",
    sharedByUserId: OTHER,
    sharedWithUserIds: [OTHER, UID, THIRD],
  });
  // Post-fix row: both spellings.
  db.set("shared_content/current-recipe", {
    contentType: "recipe",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
    sharedWithUserIds: [OTHER, UID],
  });
  // Owned by the deleted user AND listing them as a recipient — the normal
  // shape, since the writer puts the sharer in their own arrays.
  db.set("shared_content/owned-by-deleted", {
    contentType: "recipe",
    sharedByUserId: UID,
    sharedToUserIds: [UID, OTHER],
    sharedWithUserIds: [UID, OTHER],
  });
  // Someone else's share, no relation to the deleted user.
  db.set("shared_content/unrelated", {
    contentType: "menu",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, THIRD],
    sharedWithUserIds: [OTHER, THIRD],
  });

  const { removeFromSharedContent } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await removeFromSharedContent(asDb(db), UID);

  const legacy = db.get("shared_content/legacy-recipe") as DocData;
  check(
    "a legacy row carrying only sharedWithUserIds is reached at all",
    !(legacy.sharedWithUserIds as string[]).includes(UID),
    `left: ${JSON.stringify(legacy.sharedWithUserIds)}`,
  );
  check(
    "the other members of that legacy row are untouched",
    (legacy.sharedWithUserIds as string[]).length === 2,
    `left: ${JSON.stringify(legacy.sharedWithUserIds)}`,
  );

  const current = db.get("shared_content/current-recipe") as DocData;
  check(
    "BOTH spellings are cleared, not just the one the query matched",
    !(current.sharedToUserIds as string[]).includes(UID) &&
      !(current.sharedWithUserIds as string[]).includes(UID),
    `to: ${JSON.stringify(current.sharedToUserIds)} with: ${JSON.stringify(
      current.sharedWithUserIds,
    )}`,
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
    (unrelated.sharedToUserIds as string[]).length === 2 &&
      (unrelated.sharedWithUserIds as string[]).length === 2,
    `to: ${JSON.stringify(unrelated.sharedToUserIds)}`,
  );
}

/**
 * BUT-1788. `leaveGroupConversation` writes "<Name> har lämnat gruppen" under
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
  await scenario_systemMessageAboutDepartedUserIsScrubbed();
  await scenario_newerLastMessageSurvivesTheSystemScrub();
  await scenario_failedMirrorScrubKeepsTheRetryHandle();

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
