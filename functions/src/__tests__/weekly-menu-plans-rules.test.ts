/**
 * Firestore rules tests for `/weekly_menu_plans/{planId}` and
 * `/group_weekly_menu_plans/{planId}` (BUT-1961 follow-up).
 *
 * Why this file exists, measured 2026-08-27: neither collection had a rules
 * test. Both update rules refuse a changed `createdAt`, and nothing checked it.
 *
 * That deny is what keeps a stale-read save from landing on a stored week: a
 * plan built from `WeeklyMenuPlan.empty` or `GroupWeeklyMenuPlan.empty` carries
 * a FRESH `createdAt` (both stamp `clock.now()`), `copyWith` preserves it, and
 * both repositories' `save()` writes the whole document with a non-merge `.set`.
 *
 * The protection therefore has two halves, and this file pins ONE of them.
 * W2 and G1 pin the RULE half — they build their bodies from a literal, not
 * from `empty()`, so a change to the constructor leaves them green.
 *
 * The constructor half is pinned in Dart, once per constructor:
 * `weekly_menu_plan_test.dart`'s "empty starts on a Monday with no entries
 * (clock-pinned)" and `group_weekly_menu_plan_test.dart`'s "stamps a FRESH
 * createdAt from the clock". The group one was added 2026-08-27 — until then
 * that half was unguarded, and G1 would have kept passing while pinning a
 * hazard that no longer existed.
 *
 * Mutation-probed 2026-08-27: dropping `createdAt` from either collection's
 * `cannotModify` reddens exactly that collection's test and nothing else.
 *
 * Prerequisite: Firestore emulator running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/weekly-menu-plans-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-weekly-menu-plans";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "wmp-owner-uid";
const STRANGER_UID = "wmp-stranger-uid";

/** Doc ids are `{uid}_{YYYY-Www}` — the rule matches on that prefix. */
const OWNED_ID = `${OWNER_UID}_2026-W18`;

const GROUP_ID = "wmp-group";
const GROUP_PLAN_ID = `${GROUP_ID}_2026-W18`;

const CREATED_AT = new Date("2026-04-01T10:00:00Z");
const LATER = new Date("2026-04-28T10:00:00Z");

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Without this a second local run against a warm emulator turns W1's CREATE
  // into an UPDATE, which the rule also allows — the test keeps its name and
  // stops testing it.
  await env.clearFirestore();
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function planBody(
  uid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    userId: uid,
    weekStartDate: new Date("2026-04-27T00:00:00Z"),
    entries: [],
    createdAt: CREATED_AT,
    updatedAt: CREATED_AT,
    schemaVersion: 1,
    ...extra,
  };
}

async function seed(id: string, body: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`weekly_menu_plans/${id}`).set(body);
  });
}

// W1: a week with no document yet is a CREATE, and it is allowed. This is the
// case BUT-1961 restored offline — planning a week that does not exist.
test("a week with no document can be created by its owner", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNER_UID}_2026-W19`)
      .set(planBody(OWNER_UID))
  );
});

// W2: the load-bearing one. A plan built from `WeeklyMenuPlan.empty` carries a
// FRESH createdAt, so writing it over an existing week is an update with a
// changed createdAt, and the rule refuses it.
test("an empty plan with a fresh createdAt cannot overwrite a real week", async () => {
  await seed(
    OWNED_ID,
    planBody(OWNER_UID, { entries: [{ recipeId: "r1", day: "mon" }] })
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNED_ID}`)
      .set(planBody(OWNER_UID, { createdAt: LATER, updatedAt: LATER }))
  );
});

// W3: the counterpart, so W2 is not passing because ALL writes fail. A genuine
// edit keeps createdAt and is allowed.
test("an edit that preserves createdAt is allowed", async () => {
  await seed(OWNED_ID, planBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNED_ID}`)
      .set(
        planBody(OWNER_UID, {
          entries: [{ recipeId: "r2", day: "tue" }],
          updatedAt: LATER,
        })
      )
  );
});

// W4: a userId change is denied. Note this is over-determined — the two
// `request.auth.uid == …userId` conjuncts deny it on their own, so removing
// `'userId'` from `cannotModify` leaves the whole suite green (probed).
test("an edit that changes userId is denied", async () => {
  await seed(OWNED_ID, planBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNED_ID}`)
      .set(planBody(STRANGER_UID))
  );
});

// W5: the doc id's `{uid}_` prefix is its own ownership conjunct. Isolated by
// making this a CREATE at an unwritten id whose body names the STRANGER, so
// every `uid == …userId` conjunct is satisfied and only the prefix can deny.
// The earlier shape sent the OWNER's body and was denied by those conjuncts
// instead — it passed with the prefix check removed.
test("a stranger cannot create a plan under another user's id prefix", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNER_UID}_2026-W21`)
      .set(planBody(STRANGER_UID))
  );
});

// W6: the ALLOW control for W7. Without it the read rule could be `if false`
// and this file would stay fully green (probed).
test("an owner can read their own plan", async () => {
  await seed(OWNED_ID, planBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`weekly_menu_plans/${OWNED_ID}`).get()
  );
});

// W7: and a stranger cannot.
test("a stranger cannot read another user's plan", async () => {
  await seed(OWNED_ID, planBody(OWNER_UID));
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`weekly_menu_plans/${OWNED_ID}`).get()
  );
});

function groupPlanBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    groupId: GROUP_ID,
    weekStartDate: new Date("2026-04-27T00:00:00Z"),
    entries: [],
    participants: [{ userId: OWNER_UID, permission: "admin" }],
    participantUserIds: [OWNER_UID],
    memberPermissions: { [OWNER_UID]: "admin" },
    createdAt: CREATED_AT,
    lastModifiedAt: CREATED_AT,
    ...extra,
  };
}

async function seedGroup(body: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(body);
  });
}

// G1: the group collection carries the same shape — `GroupWeeklyMenuPlan.empty`
// also stamps a fresh createdAt, and the update rule also refuses a changed one.
// `GroupWeeklyMenuPlanService.readOrBuildWeek` exists for the same reason
// `readWeek` does, so the same protection needs the same proof.
test("a group plan with a fresh createdAt cannot overwrite a real week", async () => {
  await seedGroup(
    groupPlanBody({ entries: [{ recipeId: "r1", day: "mon" }] })
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(groupPlanBody({ createdAt: LATER, lastModifiedAt: LATER }))
  );
});

// G2: the counterpart, so G1 is not passing because all group writes fail.
test("a group edit that preserves createdAt is allowed", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(
        groupPlanBody({
          entries: [{ recipeId: "r2", day: "tue" }],
          lastModifiedAt: LATER,
        })
      )
  );
});

// G3: a member with only `view` cannot write at all.
test("a view-only member cannot write a group plan", async () => {
  await seedGroup(
    groupPlanBody({
      participantUserIds: [OWNER_UID, STRANGER_UID],
      memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "view" },
    })
  );
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(
        groupPlanBody({
          participantUserIds: [OWNER_UID, STRANGER_UID],
          memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "view" },
          entries: [{ recipeId: "r3", day: "wed" }],
          lastModifiedAt: LATER,
        })
      )
  );
});

// G4: the single-variable ALLOW control for G3 — the SAME stranger, promoted
// to `edit`. Without it the rule could be narrowed to admin-only and G3 would
// still pass (probed), leaving the collaborative grant unguarded.
test("an edit member can write a group plan", async () => {
  const body = groupPlanBody({
    participantUserIds: [OWNER_UID, STRANGER_UID],
    memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "edit" },
  });
  await seedGroup(body);
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set({
        ...body,
        entries: [{ recipeId: "r4", day: "thu" }],
        lastModifiedAt: LATER,
      })
  );
});

// G5/G6: the read pair, as an ALLOW/DENY couple for the same reason as W6/W7.
test("a group member can read the group plan", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`).get()
  );
});

test("a non-member cannot read the group plan", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`).get()
  );
});

async function run(): Promise<void> {
  console.log("weekly_menu_plans + group_weekly_menu_plans rules tests");
  console.log("==================================================\n");
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
