/**
 * Firestore rules tests for the BUT-464 friend_categories member-update
 * tightening. Members may only add/remove their OWN UID from
 * `friendUserIds`; bulk edits stay owner-only.
 *
 * Rules under test (users/{ownerUid}/friend_categories/{categoryId}):
 *   - Owner: bulk add/remove arbitrary UIDs allowed.
 *   - Member: add/remove SELF only.
 *   - Member: cannot add a third UID.
 *   - Member: cannot remove someone else.
 *   - Member: cannot mix self + foreign UID in one update.
 *   - Stranger (not in friendUserIds): cannot update at all.
 *   - Member: cannot mutate non-allowed fields (e.g. `name`).
 *   - Member: no-op update (only updatedAt) is allowed.
 *   - Member: cannot rewrite `ownerId` (BUT-2321).
 *   - Owner: create only with `ownerId` == the path uid (BUT-2321).
 *   - Owner: cannot rewrite `ownerId` on update; a handover moves the
 *     document server-side instead (BUT-2321, `handOverGroup`).
 *
 * Prerequisite: Firestore emulator must be running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/friend-categories-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-friend-categories-test";
// Mutation probes point these at a mutated copy and a fresh namespace, so the
// real rules file is never edited.
const ACTIVE_PROJECT_ID = process.env.PROBE_PROJECT_ID ?? PROJECT_ID;
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "owner-uid";
const STRANGER_UID = "stranger-uid";
const FOREIGN_UID = "foreign-uid";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: ACTIVE_PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Suites share one long-lived emulator; leftovers from an earlier run
  // turn a create-only write into a denied update.
  await env.clearFirestore();
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

async function seedCategory(
  categoryId: string,
  data: Record<string, unknown>
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`users/${OWNER_UID}/friend_categories/${categoryId}`)
      .set({
        ownerId: OWNER_UID,
        name: "Test category",
        createdAt: Date.now(),
        updatedAt: Date.now(),
        ...data,
      });
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

interface MemberUpdateCase {
  description: string;
  actorUid: string;
  categoryId: string;
  seedFriendIds: string[];
  updatePayload: Record<string, unknown>;
  expect: typeof assertSucceeds | typeof assertFails;
}

async function runMemberUpdateCase(c: MemberUpdateCase): Promise<void> {
  await seedCategory(c.categoryId, { friendUserIds: c.seedFriendIds });
  const ctx = env.authenticatedContext(c.actorUid);
  await c.expect(
    ctx
      .firestore()
      .doc(`users/${OWNER_UID}/friend_categories/${c.categoryId}`)
      .update({ updatedAt: Date.now(), ...c.updatePayload })
  );
}

// ========================================
// MEMBER UPDATES — self add/remove only
// ========================================

const memberUpdateCases: MemberUpdateCase[] = [
  {
    description: "member can REMOVE self from friendUserIds",
    actorUid: "member-remove-self",
    categoryId: "cat-remove-self",
    seedFriendIds: ["member-remove-self", STRANGER_UID],
    updatePayload: { friendUserIds: [STRANGER_UID] },
    expect: assertSucceeds,
  },
  {
    // Symmetric-difference is empty when the array is unchanged — empty set
    // satisfies hasOnly([uid]).
    description: "member can submit no-op update (only updatedAt)",
    actorUid: "member-noop",
    categoryId: "cat-noop",
    seedFriendIds: ["member-noop", STRANGER_UID],
    updatePayload: { friendUserIds: ["member-noop", STRANGER_UID] },
    expect: assertSucceeds,
  },
  {
    description: "member CANNOT add a third UID (not their own)",
    actorUid: "member-add-foreign",
    categoryId: "cat-add-foreign",
    seedFriendIds: ["member-add-foreign", STRANGER_UID],
    updatePayload: {
      friendUserIds: ["member-add-foreign", STRANGER_UID, FOREIGN_UID],
    },
    expect: assertFails,
  },
  {
    description: "member CANNOT remove someone else",
    actorUid: "member-remove-other",
    categoryId: "cat-remove-other",
    seedFriendIds: ["member-remove-other", STRANGER_UID],
    updatePayload: { friendUserIds: ["member-remove-other"] },
    expect: assertFails,
  },
  {
    description: "member CANNOT add self + foreign UID in one update",
    actorUid: "member-self-and-foreign",
    categoryId: "cat-self-and-foreign",
    seedFriendIds: ["member-self-and-foreign", STRANGER_UID],
    updatePayload: {
      friendUserIds: [
        "member-self-and-foreign",
        STRANGER_UID,
        FOREIGN_UID,
      ],
    },
    expect: assertFails,
  },
  {
    description: "STRANGER (not in friendUserIds) CANNOT update at all",
    actorUid: "stranger-not-in-list",
    categoryId: "cat-stranger-deny",
    seedFriendIds: [STRANGER_UID],
    updatePayload: {
      friendUserIds: [STRANGER_UID, "stranger-not-in-list"],
    },
    expect: assertFails,
  },
  {
    description: "member CANNOT mutate non-allowed fields (name)",
    actorUid: "member-mutate-name",
    categoryId: "cat-mutate-name",
    seedFriendIds: ["member-mutate-name", STRANGER_UID],
    updatePayload: {
      friendUserIds: [STRANGER_UID],
      name: "hijacked-name",
    },
    expect: assertFails,
  },
  // MO1 + MO2 (BUT-2321): same member, same document, same seed. MO2 is
  // MO1's fail-closed control.
  {
    // MO1
    description: "member CANNOT rewrite ownerId to themselves",
    actorUid: "member-takeover",
    categoryId: "cat-member-takeover",
    seedFriendIds: ["member-takeover", STRANGER_UID],
    updatePayload: { ownerId: "member-takeover" },
    expect: assertFails,
  },
  {
    // MO2
    description: "member can touch updatedAt alone on the takeover fixture",
    actorUid: "member-takeover",
    categoryId: "cat-member-takeover",
    seedFriendIds: ["member-takeover", STRANGER_UID],
    updatePayload: {},
    expect: assertSucceeds,
  },
];

for (const c of memberUpdateCases) {
  test(c.description, () => runMemberUpdateCase(c));
}

// ========================================
// OWNER UPDATES — bulk allowed
// ========================================

test(
  "owner can bulk-add multiple foreign UIDs",
  async () => {
    const categoryId = "cat-owner-bulk-add";
    await seedCategory(categoryId, { friendUserIds: [STRANGER_UID] });
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/${categoryId}`)
        .update({
          friendUserIds: [STRANGER_UID, FOREIGN_UID, "newcomer-uid"],
          updatedAt: Date.now(),
        })
    );
  }
);

test(
  "owner can bulk-remove multiple UIDs",
  async () => {
    const categoryId = "cat-owner-bulk-remove";
    await seedCategory(categoryId, {
      friendUserIds: [STRANGER_UID, FOREIGN_UID, "extra-uid"],
    });
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/${categoryId}`)
        .update({
          friendUserIds: [STRANGER_UID],
          updatedAt: Date.now(),
        })
    );
  }
);

// ====================================================================
// OWNER CREATE — ownerId bound to the path uid (BUT-2321)
// ====================================================================

const CREATE_CATEGORY_ID = "cat-owner-create";
const HANDOVER_TARGET_UID = "handover-target-uid";

// The key set `FriendCategory.toFirestore()` writes.
function validCategoryBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    ownerId: OWNER_UID,
    name: "Familjen",
    description: null,
    emoji: null,
    friendUserIds: [OWNER_UID],
    createdAt: new Date(),
    updatedAt: new Date(),
    sortOrder: 0,
    isDefault: false,
    isHousehold: false,
    ...extra,
  };
}

// Every create case writes the same id, so the document must be absent
// before each one or the write is evaluated as an UPDATE.
async function ensureCreateTargetAbsent(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const ref = ctx
      .firestore()
      .doc(`users/${OWNER_UID}/friend_categories/${CREATE_CATEGORY_ID}`);
    await ref.delete();
    if ((await ref.get()).exists) {
      throw new Error(`fixture: ${CREATE_CATEGORY_ID} must be absent`);
    }
  });
}

function createAs(uid: string, body: Record<string, unknown>) {
  return env
    .authenticatedContext(uid)
    .firestore()
    .doc(`users/${OWNER_UID}/friend_categories/${CREATE_CATEGORY_ID}`)
    .set(body);
}

// OC1: the allow control for OC2-OC4.
test("owner can create a group whose ownerId is their own uid", async () => {
  await ensureCreateTargetAbsent();
  await assertSucceeds(createAs(OWNER_UID, validCategoryBody()));
});

// OC2: differs from OC1 only in the ownerId value.
test("owner CANNOT create a group whose ownerId names another uid", async () => {
  await ensureCreateTargetAbsent();
  await assertFails(
    createAs(OWNER_UID, validCategoryBody({ ownerId: HANDOVER_TARGET_UID }))
  );
});

// OC3: differs from OC1 only in the ownerId key being absent.
test("owner CANNOT create a group without ownerId", async () => {
  await ensureCreateTargetAbsent();
  const body = validCategoryBody();
  delete body.ownerId;
  await assertFails(createAs(OWNER_UID, body));
});

// OC4: differs from OC1 only in the actor.
test("stranger CANNOT create a group under another user's account", async () => {
  await ensureCreateTargetAbsent();
  await assertFails(createAs(STRANGER_UID, validCategoryBody()));
});

// ====================================================================
// OWNER UPDATE — ownerId is immutable; no field-only transfer (BUT-2321)
// ====================================================================

const OWNER_UPDATE_ID = "cat-owner-update";

function ownerUpdate(payload: Record<string, unknown>) {
  return env
    .authenticatedContext(OWNER_UID)
    .firestore()
    .doc(`users/${OWNER_UID}/friend_categories/${OWNER_UPDATE_ID}`)
    .update({ updatedAt: Date.now(), ...payload });
}

// OU1: the update the removed ownership-transfer limb used to allow.
test(
  "owner CANNOT hand a group over by rewriting ownerId (ownerId + updatedAt)",
  async () => {
    await seedCategory(OWNER_UPDATE_ID, {
      friendUserIds: [HANDOVER_TARGET_UID],
    });
    await assertFails(ownerUpdate({ ownerId: HANDOVER_TARGET_UID }));
  }
);

// OU2: OU1's fail-closed control; same owner, same seed, `name` instead of
// `ownerId`.
test("owner can rename the same group (name + updatedAt)", async () => {
  await seedCategory(OWNER_UPDATE_ID, {
    friendUserIds: [HANDOVER_TARGET_UID],
  });
  await assertSucceeds(ownerUpdate({ name: "Nytt namn" }));
});

async function run(): Promise<void> {
  console.log("Friend-categories rules tests (BUT-464)\n");
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
