/**
 * Firestore rules tests for `chat_groups/{groupId}` (BUT-1838).
 *
 * A chat group is the shared object a group chat hangs off — Malin's decision,
 * 2026-08-13: a group is its own thing, like WhatsApp, not a `friend_categories`
 * list (those have an owner, live under `users/{ownerId}/`, and two people's
 * "Familjen" are two different lists).
 *
 * THE ONE THING THIS BLOCK EXISTS TO GUARANTEE: membership is server-written.
 * `memberIds` is the truth about who is in the group, and every create, add and
 * removal goes through a callable that runs the minor-membership gate FIRST. The
 * old gate was an `onDocumentCreated` trigger on the conversation, so it ran once
 * — when the chat was born — and never for anyone added afterwards. A rule cannot
 * iterate a member list to do the check itself, which is exactly why the gate had
 * to live in a trigger, so the only way to make it unbypassable is to make the
 * write unreachable from a client. A client-writable `memberIds` is a
 * client-writable child-safety gate; there is no partial version of that.
 *
 * What the rule therefore permits from a client is exactly two things:
 *   - READ, if you are in `memberIds` (or you are an app-level moderator).
 *   - UPDATE, if you are in `adminIds`, and only `['name','updatedAt']`, with a
 *     1..100-character string name.
 * `create` and `delete` are `if false` — Admin SDK only.
 *
 * `hasOnly` is an ALLOW-list here on purpose. The mirror rule on `conversations`
 * is a DENY-list, and that is precisely how `memberSince` slipped through an
 * earlier draft of this same change.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npm run test:rules:chat-groups
 */

import * as fs from "fs";
import * as http from "http";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

// MUTATION-PROBE SEAM (same contract as conversations-rules.test.ts): both
// values are overridable so a probe can point this suite at a MUTATED COPY of
// firestore.rules under a FRESH projectId without ever writing to the real
// rules file. Defaults are the real rules + real project.
const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-chat-groups";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ?? path.resolve(__dirname, "../../../firestore.rules");

// In `adminIds` AND `memberIds` — may rename.
const ADMIN_MEMBER_UID = "cg-admin-uid";
// In `memberIds` only — may read, may not rename.
const MEMBER_UID = "cg-member-uid";
// In neither — may do nothing at all.
const STRANGER_UID = "cg-stranger-uid";
// App-level moderator (a document at /admins/{uid}), NOT a group member. The
// `allow read: if isAdmin()` branch is separate from the membership branch.
const APP_ADMIN_UID = "cg-app-admin-uid";

// The emulator persists documents across `npm run` invocations, so a fixed-id
// create test would silently become an update on the second run. This suite
// clears its own namespace in setup(), and every mutating test re-seeds, but the
// token keeps ids unique anyway for the ones that must stay creates.
const RUN = Date.now().toString(36);

const GROUP_ID = `cg-familjen-${RUN}`;
const OTHER_GROUP_ID = `cg-other-${RUN}`;

let env: RulesTestEnvironment;

function clearFirestore(): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: 8080,
        method: "DELETE",
        path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
      },
      (res) => {
        res.on("data", () => undefined);
        res.on("end", resolve);
      }
    );
    req.on("error", reject);
    req.end();
  });
}

// Constant, never `new Date()`: the update rule pins the diff to
// ['name','updatedAt'], so a re-stamped createdAt would deny for a reason that
// has nothing to do with the rule under test and would read exactly like a rule
// defect (the BUT-1725 lesson, paid for once already).
const FIXTURE_CREATED_AT = new Date("2026-08-13T09:00:00.000Z");

// The shape `createChatGroup` writes under the Admin SDK. `memberSince` lives on
// the CONVERSATION, never here — a third copy of one fact is the pattern the
// repo was burned by in BUT-1798, and the rule that reads it (`messages` read)
// reads the conversation anyway.
function chatGroupBody(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    name: "Familjen",
    memberIds: [ADMIN_MEMBER_UID, MEMBER_UID],
    adminIds: [ADMIN_MEMBER_UID],
    memberDisplayNames: {
      [ADMIN_MEMBER_UID]: "Admin",
      [MEMBER_UID]: "Medlem",
    },
    memberAvatarUrls: {
      [ADMIN_MEMBER_UID]: null,
      [MEMBER_UID]: null,
    },
    conversationId: `conv-${GROUP_ID}`,
    createdBy: ADMIN_MEMBER_UID,
    createdAt: FIXTURE_CREATED_AT,
    updatedAt: FIXTURE_CREATED_AT,
    ...extra,
  };
}

async function seed(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`chat_groups/${GROUP_ID}`).set(chatGroupBody());
    // A SECOND group the reader is not in, seeded so the collection-level LIST
    // deny below is not vacuously empty.
    await db.doc(`chat_groups/${OTHER_GROUP_ID}`).set(
      chatGroupBody({
        name: "Grannarna",
        memberIds: [STRANGER_UID],
        adminIds: [STRANGER_UID],
        memberDisplayNames: { [STRANGER_UID]: "Främling" },
        memberAvatarUrls: { [STRANGER_UID]: null },
      })
    );
    await db.doc(`admins/${APP_ADMIN_UID}`).set({ role: "moderator" });
  });
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await clearFirestore();
  await seed();
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ============================================================================
// CHAT GROUPS — READ
// ============================================================================

// G1: ALLOW — a member reads the group. This is how the app renders the member
// list, the group name and the avatars.
test("chat_groups: a member can read their group", async () => {
  const ctx = env.authenticatedContext(MEMBER_UID);
  const snap = await assertSucceeds(
    ctx.firestore().doc(`chat_groups/${GROUP_ID}`).get()
  );
  if (!snap.exists) throw new Error("expected the seeded group — fixture broken");
});

// G2: DENY — a non-member reads nothing. The document carries every member's
// display name and avatar URL, so this is the privacy boundary of the whole
// collection.
test("chat_groups: a non-member cannot read a group", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(`chat_groups/${GROUP_ID}`).get());
});

// G3: DENY — unauthenticated.
test("chat_groups: an unauthenticated caller cannot read a group", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`chat_groups/${GROUP_ID}`).get());
});

// G4: ALLOW — an app-level moderator reads a group they are not a member of.
// A SEPARATE `allow read: if isAdmin()` statement; rules OR their allows, so
// this must not be reachable through the membership branch.
test("chat_groups: an app admin can read a group they are not a member of", async () => {
  const ctx = env.authenticatedContext(APP_ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`chat_groups/${GROUP_ID}`).get());
});

// G5: ALLOW — the client's real query. A `get()`-only read suite has NOT tested
// the read rule: LIST is a separate branch, evaluated per candidate document,
// and the engine refuses the WHOLE query if one candidate fails. The app lists
// its groups with `where('memberIds','array-contains',me)`, which is the filter
// that makes the predicate provable. Asserting non-emptiness keeps a broken
// filter from passing this vacuously.
test("chat_groups: a member can LIST their groups with an array-contains filter", async () => {
  const ctx = env.authenticatedContext(MEMBER_UID);
  const snap = await assertSucceeds(
    ctx
      .firestore()
      .collection("chat_groups")
      .where("memberIds", "array-contains", MEMBER_UID)
      .get()
  );
  if (snap.empty) throw new Error("expected at least one group — fixture broken");
});

// G6: DENY — the unfiltered sweep. Pairs with G5: a second group the caller is
// not in is seeded, so the engine cannot prove the predicate for every candidate
// and must refuse. Without this, `resource.data.get('memberIds', [])` (a
// presence-tolerant read) would be an open question — that exact shape is what
// leaked cook_snaps in BUT-1214.
test("chat_groups: an unfiltered collection read is denied", async () => {
  const ctx = env.authenticatedContext(MEMBER_UID);
  await assertFails(ctx.firestore().collection("chat_groups").limit(10).get());
});

// ============================================================================
// CHAT GROUPS — CREATE / DELETE (Admin SDK only)
// ============================================================================

// G7: DENY — a client cannot create a group, not even one naming itself as the
// sole admin and member. `createChatGroup` is a callable that runs the
// minor-membership gate on every proposed member before it writes; a client
// create would be the gate's bypass.
test("chat_groups: a client cannot create a group", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/cg-client-create-${RUN}`)
      .set(chatGroupBody())
  );
});

// G8: DENY — the same create by someone with no relationship to anything. Pairs
// with G7: `if false` means false for everyone, and a rule narrowed to
// "non-members cannot create" would still pass G8 while failing the point.
test("chat_groups: a stranger cannot create a group", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/cg-stranger-create-${RUN}`)
      .set(chatGroupBody())
  );
});

// G9: DENY — a group ADMIN cannot delete the group. Deletion happens under the
// Admin SDK when the last member leaves, so it stays consistent with the
// conversation and the roster; a client delete would orphan both.
test("chat_groups: a group admin cannot delete the group", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(ctx.firestore().doc(`chat_groups/${GROUP_ID}`).delete());
});

// G10: DENY — an app-level moderator cannot delete it either. isAdmin() grants
// READ here and nothing else; `allow create, delete: if false` has no admin
// escape hatch by design.
test("chat_groups: an app admin cannot delete a group", async () => {
  const ctx = env.authenticatedContext(APP_ADMIN_UID);
  await assertFails(ctx.firestore().doc(`chat_groups/${GROUP_ID}`).delete());
});

// ============================================================================
// CHAT GROUPS — UPDATE (rename only, admin only)
// ============================================================================

// G11: ALLOW — the one client write this collection permits. It is also the
// load-bearing allow of the whole file: every deny below survives a rule that
// froze the document completely, and only this one would go red.
test("chat_groups: a group admin can rename the group", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ name: "Familjen igen", updatedAt: new Date() })
  );
});

// G12: ALLOW — renaming without touching `updatedAt`. `hasOnly` is a SUBSET
// test, so a one-key diff is legal; pinning it stops a future reader "fixing"
// the rule into `hasAll(['name','updatedAt'])` and breaking a client that only
// sends the name.
test("chat_groups: a group admin can rename without stamping updatedAt", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`chat_groups/${GROUP_ID}`).update({ name: "Familjen" })
  );
});

// G13: DENY — an ordinary MEMBER renames. Same document, same payload as G11;
// only `adminIds` membership differs, so the deny is attributable.
test("chat_groups: an ordinary member cannot rename the group", async () => {
  const ctx = env.authenticatedContext(MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ name: "Kapad", updatedAt: new Date() })
  );
});

// G14: DENY — a non-member renames.
test("chat_groups: a non-member cannot rename the group", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ name: "Kapad", updatedAt: new Date() })
  );
});

// G15: DENY — an app-level moderator renames. isAdmin() is read-only here.
test("chat_groups: an app admin cannot rename the group", async () => {
  const ctx = env.authenticatedContext(APP_ADMIN_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ name: "Modererad", updatedAt: new Date() })
  );
});

// ============================================================================
// CHAT GROUPS — the membership lock (the child-safety boundary)
// ============================================================================

// G16: DENY — a group ADMIN adds a member. This is the ticket in one assertion:
// if this ever passes, the minor-membership gate is bypassable, because rules
// cannot run it and `addChatGroupMembers` is the only place it lives.
test("chat_groups: a group admin cannot add a uid to memberIds", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({
        memberIds: [ADMIN_MEMBER_UID, MEMBER_UID, STRANGER_UID],
        updatedAt: new Date(),
      })
  );
});

// G17: DENY — a group admin REMOVES a member. Removal is server-side too,
// because it must scrub the departing member's name, avatar and stamp out of
// both the group and the conversation in one operation (otherwise it is the
// BUT-1705 defect again, in a new collection).
test("chat_groups: a group admin cannot remove a uid from memberIds", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ memberIds: [ADMIN_MEMBER_UID], updatedAt: new Date() })
  );
});

// G18: DENY — a member removes THEMSELVES. Leaving is a real product action, but
// it runs through `removeChatGroupMember`; a client-side self-removal would skip
// the scrub and desynchronise the group from its conversation.
test("chat_groups: a member cannot remove themselves from memberIds", async () => {
  const ctx = env.authenticatedContext(MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ memberIds: [ADMIN_MEMBER_UID], updatedAt: new Date() })
  );
});

// G19: DENY — self-promotion to admin. `adminIds` is immutable after creation:
// promoting or demoting an admin is a feature that does not exist yet, and when
// it is built it needs its own gated callable, not a widened update rule. This
// is the same mistake as the `metadata.creatorId` smuggling BUT-1788 closed.
test("chat_groups: a member cannot add themselves to adminIds", async () => {
  const ctx = env.authenticatedContext(MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ adminIds: [ADMIN_MEMBER_UID, MEMBER_UID], updatedAt: new Date() })
  );
});

// G20: DENY — an ADMIN changes adminIds (demoting a peer, or promoting one).
// Pairs with G19: the field is immutable for everyone, not just for members.
test("chat_groups: a group admin cannot change adminIds", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ adminIds: [MEMBER_UID], updatedAt: new Date() })
  );
});

// G21: DENY — re-pointing the group at another conversation. Not in the
// allow-list, and it would hand the group's members read access to a chat they
// were never gated into.
test("chat_groups: a group admin cannot re-point conversationId", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ conversationId: "conv-somebody-elses", updatedAt: new Date() })
  );
});

// G22: DENY — a rename bundled with a membership change in ONE write. The
// allow-list is a subset test over the whole diff, so a legal key does not
// launder an illegal one; pinning it stops a "the name is fine, so allow it"
// reading of `hasOnly`.
test("chat_groups: a legal rename bundled with a memberIds change is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({
        name: "Familjen",
        memberIds: [ADMIN_MEMBER_UID, MEMBER_UID, STRANGER_UID],
        updatedAt: new Date(),
      })
  );
});

// G23: DENY — adding an entirely new field. `hasOnly` is an allow-list, so an
// unknown key is refused rather than silently stored (the failure mode the
// `conversations` deny-list has, and the reason this one is spelled the other
// way round).
test("chat_groups: a group admin cannot add an unknown field", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ memberSince: { [MEMBER_UID]: new Date() } })
  );
});

// ============================================================================
// CHAT GROUPS — name validation
// ============================================================================

// G24: DENY — an over-long name. 100 characters is the cap; this sends 101, so
// it is the boundary's failing side.
test("chat_groups: a name longer than 100 characters is rejected", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ name: "x".repeat(101), updatedAt: new Date() })
  );
});

// G25: ALLOW — exactly 100 characters. The passing side of the same boundary:
// without it, a rule tightened to `< 100` (or to any smaller cap) would still
// pass G24 and quietly reject legal names.
test("chat_groups: a name of exactly 100 characters is accepted", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ name: "y".repeat(100), updatedAt: new Date() })
  );
});

// G26: DENY — an empty name. `size() > 0`; a blank group name renders as a blank
// row the user cannot identify or fix.
test("chat_groups: an empty name is rejected", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ name: "", updatedAt: new Date() })
  );
});

// G27: DENY — a non-string name. `name is string` runs before `size()`, which on
// a number would be an evaluation error; pinning a second type keeps a future
// rewrite from narrowing the check.
test("chat_groups: a non-string name is rejected", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`chat_groups/${GROUP_ID}`)
      .update({ name: 42, updatedAt: new Date() })
  );
});

async function run(): Promise<void> {
  console.log("chat_groups rules tests (BUT-1838)\n");
  console.log("========================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    // Every mutating test starts from the same seeded state: the rename allows
    // (G11/G12/G25) genuinely change the document, and a later deny that reads
    // `resource.data` would otherwise be measuring the previous test's write.
    await seed();
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
