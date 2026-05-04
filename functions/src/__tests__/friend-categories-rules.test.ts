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
 *
 * Test isolation: each test uses a unique MEMBER UID + unique CATEGORY ID
 * to dodge the `rateLimitWrite('friend_category_member', 5)` 5s collision
 * window that would otherwise collapse same-actor reuse into denies.
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
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "owner-uid";
const STRANGER_UID = "stranger-uid";
const FOREIGN_UID = "foreign-uid";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
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
