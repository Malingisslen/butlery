/**
 * Firestore rules tests for `/menus/{menuId}` after the BUT-746 + BUT-747
 * GDPR hardening (sprint 2026-05-01).
 *
 * The menus collection holds shared meal-plan documents. Two new requirements
 * landed this sprint:
 *
 *  - **BUT-746** — when an account is deleted, the owner-side cleanup deletes
 *    every menu where `sharedByUserId == uid`. The existing owner-delete rule
 *    already covers this, but the test pins it down so a future rule edit
 *    cannot silently regress the cleanup path.
 *
 *  - **BUT-747** — when an account is deleted, the recipient-side scrub must
 *    remove the deleting user's UID from `sharedToUserIds` on every menu they
 *    were shared into. This required a NEW rule branch in `allow update`:
 *    a recipient may update the doc IFF (a) the only field changing is
 *    `sharedToUserIds`, and (b) they're removing themselves (in BEFORE,
 *    !in AFTER). Anything else — adding a new UID, removing someone else's
 *    UID, mutating any other field — must be denied.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rules regressed or the design intent changed — decide which.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/menus-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-menus";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "menu-owner-uid";
const RECIPIENT_UID = "menu-recipient-uid";
const OTHER_RECIPIENT_UID = "menu-other-recipient-uid";
const STRANGER_UID = "menu-stranger-uid";

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

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ----------------------------------------------------------------------------
// Builders
// ----------------------------------------------------------------------------

/** Minimal-but-valid menu doc. Required fields per `hasRequiredFields` in the
 *  create rule: sharedByUserId, menuTitle, sharedAt. Tests that exercise
 *  the recipient branch pre-seed `sharedToUserIds` so the recipient is in. */
function validMenuBody(
  ownerUid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    sharedByUserId: ownerUid,
    menuTitle: "veckomeny v18",
    sharedAt: new Date(),
    sharedToUserIds: [],
    ...extra,
  };
}

async function seedMenu(
  id: string,
  body: Record<string, unknown>
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`menus/${id}`).set(body);
  });
}

// ============================================================================
// MENUS — read access (M1–M3)
// ============================================================================

// M1: ALLOW — owner can read their own menu (sharedByUserId == auth.uid).
test("menus: owner can read own menu", async () => {
  await seedMenu("m-owner-read", validMenuBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(ctx.firestore().doc(`menus/m-owner-read`).get());
});

// M2: ALLOW — recipient (in sharedToUserIds) can read.
test("menus: recipient in sharedToUserIds can read menu", async () => {
  await seedMenu(
    "m-recipient-read",
    validMenuBody(OWNER_UID, { sharedToUserIds: [RECIPIENT_UID] })
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertSucceeds(ctx.firestore().doc(`menus/m-recipient-read`).get());
});

// M3: DENY — stranger (neither owner nor in sharedToUserIds) cannot read.
test("menus: stranger cannot read other people's menus", async () => {
  await seedMenu(
    "m-stranger-read",
    validMenuBody(OWNER_UID, { sharedToUserIds: [RECIPIENT_UID] })
  );
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(`menus/m-stranger-read`).get());
});

// M4: DENY — unauthenticated reader is denied.
test("menus: unauthenticated client cannot read", async () => {
  await seedMenu("m-anon-read", validMenuBody(OWNER_UID));
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`menus/m-anon-read`).get());
});

// ============================================================================
// MENUS — owner update / delete (M5–M8)
// ============================================================================

// M5: ALLOW — owner can update a non-immutable field (menuTitle).
test("menus: owner can update menuTitle", async () => {
  await seedMenu("m-owner-title", validMenuBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`menus/m-owner-title`).update({ menuTitle: "ny titel" })
  );
});

// M6: ALLOW — owner can delete their own menu (BUT-746 cleanup path).
test("menus: owner can delete own menu (BUT-746)", async () => {
  await seedMenu("m-owner-delete", validMenuBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(ctx.firestore().doc(`menus/m-owner-delete`).delete());
});

// M7: DENY — owner cannot mutate sharedByUserId (immutable).
test("menus: owner cannot mutate sharedByUserId", async () => {
  await seedMenu("m-owner-mut-by", validMenuBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`menus/m-owner-mut-by`)
      .update({ sharedByUserId: STRANGER_UID })
  );
});

// M8: DENY — owner cannot mutate sharedAt (immutable).
test("menus: owner cannot mutate sharedAt", async () => {
  await seedMenu("m-owner-mut-at", validMenuBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx.firestore().doc(`menus/m-owner-mut-at`).update({ sharedAt: new Date(0) })
  );
});

// ============================================================================
// MENUS — BUT-747 recipient self-scrub (M9–M13)
// ============================================================================

// M9: ALLOW — recipient removes their own UID from sharedToUserIds and
// changes nothing else. This is THE GDPR scrub path.
test("menus: recipient can scrub own UID from sharedToUserIds (BUT-747)", async () => {
  await seedMenu(
    "m-self-scrub",
    validMenuBody(OWNER_UID, {
      sharedToUserIds: [RECIPIENT_UID, OTHER_RECIPIENT_UID],
    })
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`menus/m-self-scrub`)
      .update({ sharedToUserIds: [OTHER_RECIPIENT_UID] })
  );
});

// M10: DENY — recipient mutates a non-sharedToUserIds field (menuTitle).
// hasOnly(['sharedToUserIds']) must reject this.
test("menus: recipient cannot change menuTitle even while scrubbing", async () => {
  await seedMenu(
    "m-recipient-title",
    validMenuBody(OWNER_UID, {
      sharedToUserIds: [RECIPIENT_UID, OTHER_RECIPIENT_UID],
    })
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`menus/m-recipient-title`)
      .update({
        sharedToUserIds: [OTHER_RECIPIENT_UID],
        menuTitle: "kapad",
      })
  );
});

// M11: DENY — recipient adds a NEW UID to sharedToUserIds (still in
// sharedToUserIds afterwards, plus added another). The in/!in pair on
// auth.uid (specifically the !in on request.resource.data) must reject this.
test("menus: recipient cannot ADD a new UID to sharedToUserIds", async () => {
  await seedMenu(
    "m-recipient-add",
    validMenuBody(OWNER_UID, { sharedToUserIds: [RECIPIENT_UID] })
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`menus/m-recipient-add`)
      .update({ sharedToUserIds: [RECIPIENT_UID, STRANGER_UID] })
  );
});

// M12: DENY — recipient removes SOMEONE ELSE's UID instead of their own.
// They are still in sharedToUserIds afterwards => !in on request.resource
// fails => deny.
test("menus: recipient cannot remove another user's UID from sharedToUserIds", async () => {
  await seedMenu(
    "m-recipient-remove-other",
    validMenuBody(OWNER_UID, {
      sharedToUserIds: [RECIPIENT_UID, OTHER_RECIPIENT_UID],
    })
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`menus/m-recipient-remove-other`)
      .update({ sharedToUserIds: [RECIPIENT_UID] })
  );
});

// M13: DENY — recipient cannot delete the whole menu doc. The delete rule
// is owner-only (sharedByUserId match).
test("menus: recipient cannot delete the menu doc", async () => {
  await seedMenu(
    "m-recipient-delete",
    validMenuBody(OWNER_UID, { sharedToUserIds: [RECIPIENT_UID] })
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertFails(ctx.firestore().doc(`menus/m-recipient-delete`).delete());
});

// ============================================================================
// MENUS — stranger and unauth writes (M14–M17)
// ============================================================================

// M14: DENY — stranger cannot update someone else's menu (any field).
test("menus: stranger cannot update other people's menus", async () => {
  await seedMenu("m-stranger-update", validMenuBody(OWNER_UID));
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`menus/m-stranger-update`)
      .update({ menuTitle: "hijack" })
  );
});

// M15: DENY — stranger cannot delete someone else's menu.
test("menus: stranger cannot delete other people's menus", async () => {
  await seedMenu("m-stranger-delete", validMenuBody(OWNER_UID));
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(`menus/m-stranger-delete`).delete());
});

// M16: DENY — stranger cannot create a menu pretending to be someone else
// (sharedByUserId != auth.uid).
test("menus: stranger cannot create menu impersonating another user", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`menus/m-stranger-create`).set(validMenuBody(OWNER_UID))
  );
});

// M17: DENY — unauthenticated cannot write.
test("menus: unauthenticated client cannot write", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`menus/m-anon-write`).set(validMenuBody(OWNER_UID))
  );
});

async function run(): Promise<void> {
  console.log("menus rules tests (BUT-746 + BUT-747)");
  console.log("=====================================\n");
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
