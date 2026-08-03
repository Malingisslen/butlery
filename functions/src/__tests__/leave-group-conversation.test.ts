/**
 * BUT-1788: unit tests for the leave-group / remove-member callable's pure
 * cores — `authorizeDeparture` (who may cut whom) and `buildDepartureUpdate`
 * (the single write's shape).
 *
 * No emulator: the callable's Firestore I/O is thin around these two, and the
 * authorization decision is the part a tampered client attacks. The write shape
 * is asserted because a missed map key leaves a departed member's display name
 * on a document they can no longer read.
 *
 * Run with: npx ts-node src/__tests__/leave-group-conversation.test.ts
 */

import * as admin from "firebase-admin";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-leave-group" });
}

// Stand-ins for the sentinel values — the real SDK needs a live connection to
// produce them, and only their IDENTITY matters to the shape assertions below.
const ARRAY_REMOVE = Symbol("arrayRemove");
const DELETE = Symbol("delete");
const SERVER_TIMESTAMP = Symbol("serverTimestamp");
(
  admin.firestore.FieldValue as unknown as {
    arrayRemove: (...v: unknown[]) => unknown;
    delete: () => unknown;
    serverTimestamp: () => unknown;
  }
).arrayRemove = (...values: unknown[]) => ({ op: ARRAY_REMOVE, values });
(
  admin.firestore.FieldValue as unknown as { delete: () => unknown }
).delete = () => DELETE;
(
  admin.firestore.FieldValue as unknown as { serverTimestamp: () => unknown }
).serverTimestamp = () => SERVER_TIMESTAMP;

interface Verdict {
  kind: string;
  code?: string;
}

interface LeaveResponse {
  success: boolean;
  removed: boolean;
  remainingParticipants: number;
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  authorizeDeparture,
  buildDepartureUpdate,
  removeGroupParticipantWithDeps,
} = require("../messaging/leave-group-conversation") as {
  authorizeDeparture: (input: {
    callerUid: string;
    targetUid: string;
    participantIds: string[];
    isGroup: boolean;
    creatorId: string | null;
  }) => Verdict;
  buildDepartureUpdate: (uid: string) => Record<string, unknown>;
  removeGroupParticipantWithDeps: (
    database: admin.firestore.Firestore,
    callerUid: string,
    conversationId: string,
    targetUid: string,
  ) => Promise<LeaveResponse>;
};

const GROUP = ["admin", "member", "other"];

function verdict(
  callerUid: string,
  targetUid: string,
  overrides: Partial<{
    participantIds: string[];
    isGroup: boolean;
    creatorId: string | null;
  }> = {},
): Verdict {
  return authorizeDeparture({
    callerUid,
    targetUid,
    participantIds: overrides.participantIds ?? GROUP,
    isGroup: overrides.isGroup ?? true,
    creatorId: overrides.creatorId === undefined ? "admin" : overrides.creatorId,
  });
}

// ---------------------------------------------------------------------------
// Fake Firestore for the ORCHESTRATION half (removeGroupParticipantWithDeps).
//
// The pure cases above cannot see any of the guarantees the callable's doc
// comment makes about WRITES: that a no-op re-invocation writes nothing at all
// (no second "har lämnat gruppen" row in the thread), that a padded
// participantIds cannot flip a group onto the direct-conversation refusal, and
// that a failed mirror cleanup never fails the user's leave. Same shape as the
// hand-rolled db in verify-signup-age.test.ts.
// ---------------------------------------------------------------------------

interface FakeDocRef {
  path: string;
  collection(sub: string): FakeColRef;
  delete(): Promise<void>;
}

interface FakeColRef {
  path: string;
  doc(id: string): FakeDocRef;
  add(data: Record<string, unknown>): Promise<FakeDocRef>;
}

interface FakeTx {
  get(ref: FakeDocRef): Promise<{
    exists: boolean;
    data(): Record<string, unknown> | undefined;
  }>;
  update(ref: FakeDocRef, data: Record<string, unknown>): void;
}

interface FakeState {
  /** Conversation document data; null means the doc does not exist. */
  doc: Record<string, unknown> | null;
  updates: { path: string; data: Record<string, unknown> }[];
  added: { path: string; data: Record<string, unknown> }[];
  deleted: string[];
  /** When true every mirror/message delete rejects. */
  failDeletes?: boolean;
  /** When true the system-message `add()` rejects. */
  failAdds?: boolean;
}

function makeState(doc: Record<string, unknown> | null): FakeState {
  return { doc, updates: [], added: [], deleted: [] };
}

function makeDb(state: FakeState): admin.firestore.Firestore {
  const makeDoc = (path: string): FakeDocRef => ({
    path,
    collection: (sub: string) => makeCol(`${path}/${sub}`),
    delete: async () => {
      if (state.failDeletes) throw new Error("mirror delete failed");
      state.deleted.push(path);
    },
  });
  const makeCol = (path: string): FakeColRef => ({
    path,
    doc: (id: string) => makeDoc(`${path}/${id}`),
    add: async (data: Record<string, unknown>) => {
      if (state.failAdds) throw new Error("system message write failed");
      state.added.push({ path, data });
      return makeDoc(`${path}/auto-id`);
    },
  });
  const tx: FakeTx = {
    get: async (ref: FakeDocRef) => ({
      exists: state.doc !== null,
      data: () => state.doc ?? undefined,
      ref,
    }),
    update: (ref: FakeDocRef, data: Record<string, unknown>) => {
      state.updates.push({ path: ref.path, data });
    },
  };
  return {
    collection: (name: string) => makeCol(name),
    runTransaction: (fn: (t: FakeTx) => Promise<unknown>) => fn(tx),
  } as unknown as admin.firestore.Firestore;
}

/** A three-person group whose admin ("admin") created it. */
function groupDoc(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    isGroup: true,
    participantIds: ["admin", "member", "other"],
    participantDisplayNames: { admin: "Ada", member: "Bea", other: "Cim" },
    metadata: { creatorId: "admin" },
    ...overrides,
  };
}

async function captureError(fn: () => Promise<unknown>): Promise<string> {
  try {
    await fn();
    return "";
  } catch (e) {
    const err = e as { code?: string };
    return err.code ?? String(e);
  }
}

const cases: UnitCase[] = [
  {
    name: "a member leaving the group is allowed",
    fn: () => assertEqual(verdict("member", "member").kind, "proceed", "self-leave"),
  },
  {
    name: "the admin leaving their own group is allowed",
    fn: () => assertEqual(verdict("admin", "admin").kind, "proceed", "admin self-leave"),
  },
  {
    name: "the admin removing another member is allowed",
    fn: () => assertEqual(verdict("admin", "member").kind, "proceed", "admin removal"),
  },
  {
    name: "a non-admin member cannot remove another member",
    fn: () => {
      const v = verdict("member", "other");
      assertEqual(v.kind, "deny", "non-admin removal kind");
      assertEqual(v.code, "permission-denied", "non-admin removal code");
    },
  },
  {
    name: "an outsider cannot remove a member",
    fn: () => {
      const v = verdict("stranger", "member");
      assertEqual(v.kind, "deny", "outsider kind");
      assertEqual(v.code, "permission-denied", "outsider code");
    },
  },
  {
    // Fail CLOSED: with no trustworthy admin identity nobody inherits the
    // removal right — otherwise every participant would become an admin.
    name: "a group with no recorded creator has no admin",
    fn: () => {
      const v = verdict("admin", "member", { creatorId: null });
      assertEqual(v.kind, "deny", "creatorless removal kind");
      assertEqual(v.code, "permission-denied", "creatorless removal code");
    },
  },
  {
    name: "a member can still leave a group with no recorded creator",
    fn: () =>
      assertEqual(
        verdict("member", "member", { creatorId: null }).kind,
        "proceed",
        "creatorless self-leave",
      ),
  },
  {
    name: "a direct conversation refuses removal outright",
    fn: () => {
      const v = verdict("a", "a", { isGroup: false, participantIds: ["a", "b"] });
      assertEqual(v.kind, "deny", "direct kind");
      assertEqual(v.code, "failed-precondition", "direct code");
    },
  },
  {
    // Idempotency: a double-tap or a retry after a dropped response must not
    // write a second system message into the thread.
    name: "leaving twice is a no-op, not an error",
    fn: () =>
      assertEqual(
        verdict("gone", "gone", { participantIds: GROUP }).kind,
        "noop",
        "repeat self-leave",
      ),
  },
  {
    name: "admin removing an already-removed member is a no-op",
    fn: () =>
      assertEqual(
        verdict("admin", "gone").kind,
        "noop",
        "repeat admin removal",
      ),
  },
  {
    // The authorization runs before idempotency, so a stranger probing for
    // membership gets the same denial whether or not the uid is present.
    name: "a stranger removing an absent uid is still denied",
    fn: () =>
      assertEqual(verdict("stranger", "gone").kind, "deny", "stranger probe"),
  },
  {
    name: "the write erases all four uid-keyed maps plus participantIds",
    fn: () => {
      const update = buildDepartureUpdate("u1") as Record<string, unknown>;
      assertEqual(
        (update.participantIds as { op: symbol }).op === ARRAY_REMOVE,
        true,
        "participantIds uses arrayRemove",
      );
      for (const map of [
        "participantDisplayNames",
        "participantAvatarUrls",
        "lastReadTimestamps",
        "perUserSettings",
      ]) {
        assertEqual(update[`${map}.u1`], DELETE, `${map} key deleted`);
      }
      assertEqual(update.updatedAt, SERVER_TIMESTAMP, "updatedAt stamped");
    },
  },
  {
    // Guards the sanitisation contract: a uid is spliced into a FIELD PATH, so
    // a bare `${map}.${uid}` with a dotted uid would address a nested map and
    // silently leave the name behind. The callable rejects such uids upstream
    // via isValidDocId — this pins that the write itself is the reason why.
    name: "the write addresses the uid as a single field-path segment",
    fn: () => {
      const update = buildDepartureUpdate("abc") as Record<string, unknown>;
      assertEqual(
        Object.keys(update).includes("participantDisplayNames.abc"),
        true,
        "literal segment key",
      );
    },
  },
  {
    // Discriminator for the MEMBERSHIP branch. Every other denial fixture is a
    // caller who is neither a participant NOR the creator, so the creatorId
    // check denies them too and deleting `!participantIds.includes(callerUid)`
    // leaves the suite green. Here the caller IS the recorded creator but has
    // already left: only the membership branch can refuse them.
    name: "a creator who has left the group can no longer remove members",
    fn: () => {
      const v = verdict("admin", "member", {
        participantIds: ["member", "other"],
      });
      assertEqual(v.kind, "deny", "departed creator kind");
      assertEqual(v.code, "permission-denied", "departed creator code");
    },
  },
  {
    name: "an admin removal writes one update, one system message and both mirrors",
    fn: async () => {
      const state = makeState(groupDoc());
      const res = await removeGroupParticipantWithDeps(
        makeDb(state),
        "admin",
        "c1",
        "member",
      );

      assertEqual(res.removed, true, "removed");
      assertEqual(res.remainingParticipants, 2, "remaining after removal");

      assertEqual(state.updates.length, 1, "exactly one conversation write");
      assertEqual(state.updates[0].path, "conversations/c1", "write target");
      const update = state.updates[0].data;
      assertEqual(
        (update.participantIds as { op: symbol }).op === ARRAY_REMOVE,
        true,
        "participantIds arrayRemove",
      );
      assertEqual(
        update["participantDisplayNames.member"],
        DELETE,
        "departed name deleted",
      );

      // The mirrors the client used to clear itself, at the exact paths
      // `ConversationParticipantModule.removeParticipant` uses.
      assertEqual(
        state.deleted.includes("conversations/c1/participants/member"),
        true,
        "participants mirror",
      );
      assertEqual(
        state.deleted.includes("users/member/conversation_memberships/c1"),
        true,
        "membership mirror",
      );

      assertEqual(state.added.length, 1, "exactly one system message");
      assertEqual(state.added[0].path, "messages", "top-level messages");
      const msg = state.added[0].data;
      assertEqual(msg.conversationId, "c1", "message conversationId");
      assertEqual(msg.senderId, "system", "message senderId");
      assertEqual(msg.type, "system", "message type");
      // Swedish UI string, mirroring `chatParticipantLeft` in app_sv.arb, with
      // the display name read off the doc rather than the "?" fallback.
      assertEqual(
        msg.content,
        "Bea har lämnat gruppen",
        "message content",
      );
    },
  },
  {
    // The idempotency claim in the callable's header. The pure no-op verdict
    // above cannot see the writes: only this proves a retry after a dropped
    // response adds no second "har lämnat gruppen" row to the thread.
    name: "a repeat removal of an absent uid writes absolutely nothing",
    fn: async () => {
      const state = makeState(groupDoc());
      const res = await removeGroupParticipantWithDeps(
        makeDb(state),
        "admin",
        "c1",
        "gone",
      );

      assertEqual(res.success, true, "idempotent success");
      assertEqual(res.removed, false, "nothing removed");
      assertEqual(res.remainingParticipants, 3, "membership unchanged");
      assertEqual(state.updates.length, 0, "no conversation write");
      assertEqual(state.added.length, 0, "no second system message");
      assertEqual(state.deleted.length, 0, "no mirror deletes");
    },
  },
  {
    // Group-ness is judged on the RAW participantIds, so a padded list cannot
    // shrink a group to size 2 and buy the "direct conversation" refusal.
    // Judging on the sanitised list would deny this with failed-precondition.
    name: "a padded participant list is still a group, and the leave lands",
    fn: async () => {
      const state = makeState({
        participantIds: ["a", "b", "__x__"],
        participantDisplayNames: { a: "Ada" },
        metadata: { creatorId: "a" },
      });
      const res = await removeGroupParticipantWithDeps(
        makeDb(state),
        "a",
        "c1",
        "a",
      );

      assertEqual(res.removed, true, "padded group leave proceeds");
      assertEqual(res.remainingParticipants, 1, "junk uid not counted");
      assertEqual(state.updates.length, 1, "membership write landed");
    },
  },
  {
    // Best-effort mirror cleanup: the participantIds cut IS the access
    // revocation, so a mirror failure must not fail the user's leave — and
    // must not skip the system message that follows it.
    name: "a failing mirror cleanup still completes the leave",
    fn: async () => {
      const state = makeState(groupDoc());
      state.failDeletes = true;
      const res = await removeGroupParticipantWithDeps(
        makeDb(state),
        "member",
        "c1",
        "member",
      );

      assertEqual(res.success, true, "leave still succeeds");
      assertEqual(res.removed, true, "still removed");
      assertEqual(state.updates.length, 1, "membership write landed");
      assertEqual(state.added.length, 1, "system message still written");
    },
  },
  {
    // The system message is decoration on top of an already-committed access
    // cut. If its write could fail the call, the user would be told the leave
    // failed for a group they are already out of — and their retry now hits
    // the no-oracle gate, so they would never get a success.
    name: "a failing system-message write still completes the leave",
    fn: async () => {
      const state = makeState(groupDoc());
      state.failAdds = true;
      const res = await removeGroupParticipantWithDeps(
        makeDb(state),
        "member",
        "c1",
        "member",
      );

      assertEqual(res.success, true, "leave still succeeds");
      assertEqual(res.removed, true, "still removed");
      assertEqual(res.remainingParticipants, 2, "count still reported");
      assertEqual(state.updates.length, 1, "membership write landed");
      assertEqual(state.deleted.length, 2, "mirrors still cleared");
    },
  },
  {
    // The ORCHESTRATOR's group test (`isGroup === true || raw.length > 2`) has
    // no other fixture: every direct-conversation case above either calls the
    // pure core directly or comes from a stranger, who is stopped by the
    // no-oracle gate before this line runs. Without this case, hard-coding
    // `isGroup = true` leaves the whole suite green — and that mutant lets one
    // half of a 1:1 thread evict the other, cutting their access to the entire
    // conversation history.
    name: "a 1:1 participant cannot evict the other, and nothing is written",
    fn: async () => {
      const dm = makeState({
        isGroup: false,
        participantIds: ["a", "b"],
        participantDisplayNames: { a: "Ada", b: "Bo" },
        metadata: { creatorId: "a" },
      });
      const evictCode = await captureError(() =>
        removeGroupParticipantWithDeps(makeDb(dm), "a", "direct_a_b", "b"),
      );
      assertEqual(evictCode, "failed-precondition", "DM eviction refused");

      // Leaving a 1:1 yourself is refused the same way — membership there is
      // fixed at create, matching the old client-side ValidationException.
      const selfLeaveCode = await captureError(() =>
        removeGroupParticipantWithDeps(makeDb(dm), "a", "direct_a_b", "a"),
      );
      assertEqual(selfLeaveCode, "failed-precondition", "DM self-leave refused");

      assertEqual(dm.updates.length, 0, "no membership write on a DM");
      assertEqual(dm.added.length, 0, "no system message on a DM");
      assertEqual(dm.deleted.length, 0, "no mirror deletes on a DM");
    },
  },
  {
    name: "a denied removal writes nothing and surfaces permission-denied",
    fn: async () => {
      const state = makeState(groupDoc());
      const code = await captureError(() =>
        removeGroupParticipantWithDeps(makeDb(state), "member", "c1", "other"),
      );

      assertEqual(code, "permission-denied", "denial code");
      assertEqual(state.updates.length, 0, "no write on denial");
      assertEqual(state.added.length, 0, "no system message on denial");
    },
  },
  {
    // BUT-1788 follow-up. The callable used to answer three DIFFERENT ways for
    // a conversation the caller is not in — `not-found`, `failed-precondition`
    // "cannot remove from a direct conversation", or a no-op carrying the real
    // member count. Direct-conversation ids are deterministic from two uids and
    // every uid is enumerable from `public_profiles`, so those three answers
    // let any signed-in account reconstruct the private messaging graph.
    // All three are now one indistinguishable reply that carries no count.
    name: "a non-member learns nothing about a conversation they are not in",
    fn: async () => {
      const missing = makeState(null);
      const absent = await removeGroupParticipantWithDeps(
        makeDb(missing),
        "stranger",
        "missing",
        "stranger",
      );

      const group = makeState(groupDoc());
      const outsideGroup = await removeGroupParticipantWithDeps(
        makeDb(group),
        "stranger",
        "c1",
        "stranger",
      );

      const dm = makeState({
        isGroup: false,
        participantIds: ["a", "b"],
        metadata: { creatorId: "a" },
      });
      const outsideDm = await removeGroupParticipantWithDeps(
        makeDb(dm),
        "stranger",
        "direct_a_b",
        "stranger",
      );

      // Byte-identical across all three, and no member count anywhere.
      for (const [label, res] of [
        ["missing conversation", absent],
        ["group the caller is not in", outsideGroup],
        ["DM the caller is not in", outsideDm],
      ] as const) {
        assertEqual(res.success, true, `${label}: uniform success`);
        assertEqual(res.removed, false, `${label}: nothing removed`);
        assertEqual(
          res.remainingParticipants,
          0,
          `${label}: no member count disclosed`,
        );
      }

      assertEqual(missing.updates.length, 0, "no write, missing doc");
      assertEqual(group.updates.length, 0, "no write, outsider on group");
      assertEqual(group.added.length, 0, "no system message for an outsider");
      assertEqual(dm.updates.length, 0, "no write, outsider on DM");
    },
  },
  {
    // A member of a REAL group must still get the true count back — otherwise
    // the test above passes on a function that always returns 0.
    name: "a real participant still gets the real remaining count",
    fn: async () => {
      const state = makeState(groupDoc());
      const res = await removeGroupParticipantWithDeps(
        makeDb(state),
        "member",
        "c1",
        "member",
      );
      assertEqual(res.remainingParticipants, 2, "real count for a member");
    },
  },
  {
    // GDPR Art. 17. The row embeds a display name in free text under
    // senderId:"system", which no cascade query can reach — the cascade's
    // `senderId == uid` leg does not match it, and once the person has left the
    // cascade never visits that conversation at all. `metadata.subjectUserId`
    // is the only queryable handle, and `anonymizeSystemMessagesAboutUser`
    // consumes exactly this field name.
    name: "the departure system message carries an Art. 17 erasure handle",
    fn: async () => {
      const state = makeState(groupDoc());
      await removeGroupParticipantWithDeps(makeDb(state), "admin", "c1", "member");

      assertEqual(state.added.length, 1, "one system message");
      const meta = state.added[0].data.metadata as Record<string, unknown>;
      assertEqual(
        meta?.subjectUserId,
        "member",
        "subjectUserId names the person the row is about",
      );
      assertEqual(
        meta?.systemEvent,
        "participant_left",
        "systemEvent labels the row",
      );
    },
  },
];

void runTests("leaveGroupConversation — authorization + write shape", cases);
