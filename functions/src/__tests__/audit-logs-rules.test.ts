/**
 * Firestore rules tests for the BUT-424 hardening of `audit_logs`.
 *
 * Before BUT-424: any authenticated user could read their own audit_logs.
 * That contradicted the design intent ("users CANNOT read their own audit
 * logs — prevents tampering detection") documented in
 * `lib/repositories/firebase/firebase_audit_repository.dart`. The new rule
 * restricts read access to admins only; client-side fire-and-forget create
 * remains intact (with rate limit + self-uid pinning).
 *
 * Each test name states the behavior it proves. If a test fails, either
 * the rules regressed or the design intent changed — decide which before
 * editing the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/audit-logs-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-audit-logs";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER_UID = "user-uid";
const OTHER_UID = "other-uid";
const ADMIN_UID = "admin-uid";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  // Admin record + a sample audit log seeded server-side. The /admins/
  // collection is rules-locked, and we want a row in audit_logs that
  // already exists for the read-side cases.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({
      addedAt: new Date(),
    });
    await ctx.firestore().doc(`audit_logs/al-existing`).set({
      userId: USER_UID,
      operation: "read",
      resourceType: "recipe",
      resourceId: "recipe-1",
      granted: true,
      timestamp: new Date(),
    });
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

// Body that satisfies the create rule's hasRequiredFields + self-uid pin.
function validAuditBody(uid: string): Record<string, unknown> {
  return {
    userId: uid,
    operation: "read",
    resourceType: "recipe",
    resourceId: "recipe-1",
    granted: true,
    // The rule requires the field to be present. Server timestamp would
    // be `serverTimestamp()` in a real client; we use a literal Date here
    // because the rule doesn't check that this one is server-stamped.
    timestamp: new Date(),
  };
}

// ============================================================================
// AUDIT LOGS — BUT-424 read tightening + create regression coverage
// ============================================================================

// A1.1: admin can read any audit log row (replaces the old "user reads own").
//       This is the only allowed read path post-BUT-424.
test("audit_logs: admin can read any audit log", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`audit_logs/al-existing`).get());
});

// A1.2: a regular user can NOT read their own audit log row. Design intent
//       is that exposing the audit trail to the user defeats tamper
//       detection — a compromised account would otherwise enumerate gaps.
test("audit_logs: regular user cannot read their own audit log", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(ctx.firestore().doc(`audit_logs/al-existing`).get());
});

// A1.3: anonymous (unauthenticated) reads are denied — base case, but
//       worth pinning so a future refactor of `isAdmin()` can't accidentally
//       short-circuit to true on null auth.
test("audit_logs: unauthenticated client cannot read", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`audit_logs/al-existing`).get());
});

// A1.4a: anonymous client cannot create — `isAuthenticated()` gate.
test("audit_logs: unauthenticated client cannot create", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`audit_logs/al-anon-attempt`).set(validAuditBody(USER_UID))
  );
});

// A1.4b: server-side / admin-SDK writes still work — confirmed by
//        running the same write through the security-rules-disabled context.
//        This is what the GDPR export Cloud Function (follow-up) will use.
test("audit_logs: server-side write succeeds (rules bypass)", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`audit_logs/al-server`)
        .set(validAuditBody(USER_UID))
    );
  });
});

// regression: an authenticated user CAN still create an audit row for
// themselves — the create path is the intentional client write path
// (fire-and-forget). This guards against over-tightening the create rule.
test("audit_logs: authenticated user can create their own audit log", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`audit_logs/al-self-create`).set(validAuditBody(USER_UID))
  );
});

// regression: a user CANNOT forge an audit log under another user's id.
// The create rule pins `request.resource.data.userId == request.auth.uid`.
test("audit_logs: user cannot create a log under another user's id", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`audit_logs/al-forged`)
      .set(validAuditBody(OTHER_UID))
  );
});

// regression: updates and deletes are immutable per the rule.
test("audit_logs: nobody can update or delete an existing row", async () => {
  const userCtx = env.authenticatedContext(USER_UID);
  const adminCtx = env.authenticatedContext(ADMIN_UID);
  await assertFails(
    userCtx
      .firestore()
      .doc(`audit_logs/al-existing`)
      .update({ granted: false })
  );
  await assertFails(adminCtx.firestore().doc(`audit_logs/al-existing`).delete());
});

// ============================================================================
// SPRINT G — top-level /audit and /_internal defence-in-depth deny blocks
//
// /audit/{document=**} (BUT-627) and /_internal/{document=**} (BUT-482) are
// admin-SDK-only namespaces written by Cloud Functions (ping rate-limit
// audit ledger; rating-aggregation debounce markers). The rules pin every
// client operation to `false`; the admin SDK bypasses rules. These tests
// pin the deny so a future wildcard or refactor cannot widen access.
// ============================================================================

// Seed both deny-only paths via the rules-bypass admin context so the read
// tests have an existing row to attempt to fetch (assertFails on the read
// of an existing doc is a stronger assertion than reading a missing one —
// missing reads can pass for the wrong reason).
async function seedDenyOnlyPaths(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`audit/ping_rate_limit/entries/seeded-entry`)
      .set({ userId: USER_UID, exceededAt: new Date(), reason: "ping-burst" });
    await ctx
      .firestore()
      .doc(`_internal/rating_debounce/markers/recipe-1`)
      .set({ recipeId: "recipe-1", scheduledAt: new Date() });
  });
}

// D1: read deny — authenticated user cannot read an existing audit/ entry.
test("audit/**: authenticated user cannot read ping_rate_limit entry", async () => {
  await seedDenyOnlyPaths();
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`audit/ping_rate_limit/entries/seeded-entry`)
      .get()
  );
});

// D2: create deny — authenticated user cannot create at audit/.../entries.
test("audit/**: authenticated user cannot create a ping_rate_limit entry", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`audit/ping_rate_limit/entries/forged-entry`)
      .set({ userId: USER_UID, exceededAt: new Date(), reason: "spoof" })
  );
});

// D3: update deny — authenticated user cannot mutate an existing entry.
test("audit/**: authenticated user cannot update an existing entry", async () => {
  await seedDenyOnlyPaths();
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`audit/ping_rate_limit/entries/seeded-entry`)
      .update({ reason: "rewritten" })
  );
});

// D4: delete deny — authenticated user cannot delete an existing entry.
test("audit/**: authenticated user cannot delete an existing entry", async () => {
  await seedDenyOnlyPaths();
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`audit/ping_rate_limit/entries/seeded-entry`)
      .delete()
  );
});

// D5: read deny — unauthenticated client cannot read.
test("audit/**: unauthenticated client cannot read", async () => {
  await seedDenyOnlyPaths();
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`audit/ping_rate_limit/entries/seeded-entry`)
      .get()
  );
});

// D6: read deny — authenticated user cannot read an existing _internal marker.
test("_internal/**: authenticated user cannot read rating_debounce marker", async () => {
  await seedDenyOnlyPaths();
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`_internal/rating_debounce/markers/recipe-1`)
      .get()
  );
});

// D7: create deny — authenticated user cannot create a marker.
test("_internal/**: authenticated user cannot create a marker", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`_internal/rating_debounce/markers/recipe-2`)
      .set({ recipeId: "recipe-2", scheduledAt: new Date() })
  );
});

// D8: update deny — authenticated user cannot update an existing marker.
test("_internal/**: authenticated user cannot update an existing marker", async () => {
  await seedDenyOnlyPaths();
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`_internal/rating_debounce/markers/recipe-1`)
      .update({ scheduledAt: new Date() })
  );
});

// D9: delete deny — authenticated user cannot delete an existing marker.
test("_internal/**: authenticated user cannot delete an existing marker", async () => {
  await seedDenyOnlyPaths();
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`_internal/rating_debounce/markers/recipe-1`)
      .delete()
  );
});

// D10: read deny — unauthenticated client cannot read _internal.
test("_internal/**: unauthenticated client cannot read", async () => {
  await seedDenyOnlyPaths();
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`_internal/rating_debounce/markers/recipe-1`)
      .get()
  );
});

// D11: regression — admin can STILL write+read existing /audit_logs/{logId},
//      proving the new top-level /audit/{document=**} wildcard does NOT
//      shadow the more-specific /audit_logs/{logId} match. Firestore picks
//      the most-specific match, but a refactor that renamed the wildcard
//      could silently swap behavior. This test pins the precedence.
test("regression: /audit_logs still works after /audit wildcard added", async () => {
  // Self-create as the user (allowed by audit_logs rule).
  const userCtx = env.authenticatedContext(USER_UID);
  await assertSucceeds(
    userCtx
      .firestore()
      .doc(`audit_logs/al-precedence-check`)
      .set(validAuditBody(USER_UID))
  );
  // Admin can still read (allowed by audit_logs rule).
  const adminCtx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(
    adminCtx.firestore().doc(`audit_logs/al-precedence-check`).get()
  );
});

async function run(): Promise<void> {
  console.log("audit_logs rules tests (BUT-424)\n");
  console.log("================================\n");
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
