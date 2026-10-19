/**
 * Firestore rules tests for the BUT-612 acquisition attribution path.
 *
 * Rules contract under test (users/{uid}/acquisition/current):
 *   - Owner can READ.
 *   - Owner can CREATE with required fields {source, medium, campaign,
 *     firstSeenAt} where firstSeenAt == request.time (server timestamp).
 *   - UPDATE is rejected for everyone (first-write-wins; admin/server only).
 *   - DELETE is rejected for everyone (admin/server only — GDPR Art. 17
 *     erasure runs through dedicated tooling).
 *   - Other users cannot read or write your acquisition.
 *   - BUT-1997: CREATE only on the doc id `current`, only the four keys, and
 *     the three strings are strings of at most 100 characters. No client may
 *     write `analytics/acquisition/daily/*`; only an admin reads it.
 *
 * Prerequisite: Firestore emulator must be running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/acquisition-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
// Use the CLIENT-SDK serverTimestamp sentinel, not firebase-admin's. The
// rules-unit-testing context's `firestore()` is the `firebase` client SDK,
// which only recognizes its own sentinel; an admin-SDK FieldValue.serverTimestamp()
// is rejected at .set() time with `invalid-argument` before any rule runs.
import { serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-acquisition-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER_UID = "user-a";
const OTHER_UID = "user-b";
const ACQUISITION_DOC = (uid: string): string =>
  `users/${uid}/acquisition/current`;

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Suites share one long-lived emulator; fixed doc ids left by an earlier
  // run turn a create-only `set` into a denied update.
  await env.clearFirestore();
}

const valid = () => ({
  source: "instagram",
  medium: "social",
  campaign: "spring2026",
  firstSeenAt: serverTimestamp(),
});

/** An owner create of [payload] at [docId], expected to be refused. */
async function ownerCreateFails(
  payload: Record<string, unknown>,
  docId = "current",
): Promise<void> {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx.firestore().doc(`users/${USER_UID}/acquisition/${docId}`).set(payload)
  );
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// Test 1: owner can create acquisition with serverTimestamp.
test(
  "owner can create acquisition with required fields and serverTimestamp",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(ACQUISITION_DOC(USER_UID))
        .set({
          source: "instagram",
          medium: "social",
          campaign: "spring2026",
          firstSeenAt: serverTimestamp(),
        })
    );
  }
);

// Test 2: missing required field -> rejected.
test(
  "create without firstSeenAt is rejected",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(ACQUISITION_DOC(USER_UID))
        .set({
          source: "instagram",
          medium: "social",
          campaign: "spring2026",
        })
    );
  }
);

// Test 3: client-supplied firstSeenAt (not serverTimestamp) -> rejected.
test(
  "create with client-supplied firstSeenAt is rejected",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(ACQUISITION_DOC(USER_UID))
        .set({
          source: "instagram",
          medium: "social",
          campaign: "spring2026",
          firstSeenAt: new Date(2020, 0, 1),
        })
    );
  }
);

// Test 4: owner can read their own acquisition.
test("owner can read their own acquisition", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(ACQUISITION_DOC(USER_UID)).set({
      source: "instagram",
      medium: "social",
      campaign: "spring2026",
      firstSeenAt: new Date(),
    });
  });
  const ctx = env.authenticatedContext(USER_UID);
  await assertSucceeds(
    ctx.firestore().doc(ACQUISITION_DOC(USER_UID)).get()
  );
});

// Test 5: another user cannot read.
test("another user cannot read someone else's acquisition", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(ACQUISITION_DOC(USER_UID)).set({
      source: "instagram",
      medium: "social",
      campaign: "spring2026",
      firstSeenAt: new Date(),
    });
  });
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(
    ctx.firestore().doc(ACQUISITION_DOC(USER_UID)).get()
  );
});

// Test 6: another user cannot create.
test("another user cannot create another user's acquisition", async () => {
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(ACQUISITION_DOC(USER_UID))
      .set({
        source: "instagram",
        medium: "social",
        campaign: "spring2026",
        firstSeenAt: serverTimestamp(),
      })
  );
});

// Test 7: client cannot UPDATE existing acquisition (first-write-wins).
test("owner cannot update existing acquisition (first-write-wins)", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(ACQUISITION_DOC(USER_UID)).set({
      source: "instagram",
      medium: "social",
      campaign: "spring2026",
      firstSeenAt: new Date(),
    });
  });
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(ACQUISITION_DOC(USER_UID))
      .update({ source: "tiktok" })
  );
});

// Test 8: client cannot DELETE.
test("owner cannot delete acquisition (admin-only)", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(ACQUISITION_DOC(USER_UID)).set({
      source: "instagram",
      medium: "social",
      campaign: "spring2026",
      firstSeenAt: new Date(),
    });
  });
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx.firestore().doc(ACQUISITION_DOC(USER_UID)).delete()
  );
});

// Test 9: unauthenticated client cannot read or create.
test("unauthenticated user cannot read or create acquisition", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(ACQUISITION_DOC(USER_UID)).get()
  );
  await assertFails(
    ctx
      .firestore()
      .doc(ACQUISITION_DOC(USER_UID))
      .set({
        source: "instagram",
        medium: "social",
        campaign: "spring2026",
        firstSeenAt: serverTimestamp(),
      })
  );
});

// BUT-1997 — the create limb.
//
// Every create-DENY below runs on an empty emulator (the runner clears before
// each test), so `set` on `current` is evaluated as a CREATE; with a stored
// doc it would be an UPDATE and `update: if false` would deny it whatever the
// create conjuncts say. Test 1 is the ALLOW each deny differs from.
test("create carrying a fifth key (countedAt) is rejected", async () => {
  await ownerCreateFails({ ...valid(), countedAt: serverTimestamp() });
});

test("create on a doc id other than `current` is rejected", async () => {
  await ownerCreateFails(valid(), "other");
});

for (const field of ["source", "medium", "campaign"]) {
  test(`create with a 100-character ${field} is allowed`, async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(ACQUISITION_DOC(USER_UID))
        .set({ ...valid(), [field]: "x".repeat(100) })
    );
  });

  test(`create with a 101-character ${field} is rejected`, async () => {
    await ownerCreateFails({ ...valid(), [field]: "x".repeat(101) });
  });

  // A one-element list, not a number: `size()` accepts a list and stays under
  // the bound, so only the `is string` conjunct refuses it.
  test(`create with a non-string ${field} is rejected`, async () => {
    await ownerCreateFails({ ...valid(), [field]: ["x"] });
  });
}

// BUT-1997 — the aggregate is server-written and admin-read.
const DAY_DOC = "analytics/acquisition/daily/2026-10-20";

test("no client can write the acquisition day document", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(ctx.firestore().doc(DAY_DOC).set({ total: 1 }));
});

test("an admin client cannot write the acquisition day document", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`admins/${OTHER_UID}`).set({ role: "admin" });
  });
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(ctx.firestore().doc(DAY_DOC).set({ total: 1 }));
});

test("a non-admin cannot read the acquisition day document", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(DAY_DOC).set({ total: 1 });
  });
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(ctx.firestore().doc(DAY_DOC).get());
});

test("an admin can read the acquisition day document", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(DAY_DOC).set({ total: 1 });
    await admin.firestore().doc(`admins/${OTHER_UID}`).set({ role: "admin" });
  });
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertSucceeds(ctx.firestore().doc(DAY_DOC).get());
});

async function run(): Promise<void> {
  console.log("Acquisition rules tests (BUT-612)\n");
  console.log("=================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    try {
      await env.clearFirestore();
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
