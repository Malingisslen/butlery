/**
 * Firestore rules tests for BUT-1451: `llm_response_samples`.
 *
 * `llm_response_samples/{sampleId}` stores scrubbed, TTL'd (`expireAt`) samples
 * of paid-LLM input/output captured by Cloud Functions for parser/prompt
 * mining. Because the content is sensitive, the intended policy is to DENY ALL
 * client access (read AND write) — mirroring `deletion_audit_logs` — and rely on
 * the Admin SDK (which bypasses rules) for the Cloud Functions capture path.
 *
 * These tests pin the deny so a future wildcard, refactor, or accidental
 * widening cannot open access without turning the suite red. The matrix per the
 * ticket: unauthenticated, authenticated non-admin, and admin are ALL denied for
 * BOTH read and write.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rules regressed or the design intent changed — decide which before editing.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/llm-response-samples-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-llm-response-samples";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER_UID = "user-uid";
const ADMIN_UID = "admin-uid";

let env: RulesTestEnvironment;

const SAMPLE_PATH = "llm_response_samples/seeded-sample";

// A representative scrubbed sample doc. The rule checks nothing about the shape
// (it denies unconditionally), so this is only here to give read/update/delete
// tests an existing doc to attempt against — denying a read of an EXISTING doc
// is a stronger assertion than denying a read of a missing one.
function sampleBody(): Record<string, unknown> {
  return {
    provider: "openai",
    model: "gpt-4o-mini",
    promptHash: "sha256:deadbeef",
    inputScrubbed: "[REDACTED recipe text]",
    outputScrubbed: "[REDACTED parsed json]",
    capturedAt: new Date(),
    expireAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  };
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  // Seed the admin record (so isAdmin() resolves true for ADMIN_UID — proving
  // the deny holds even for an app admin) and an existing sample row for the
  // read/update/delete cases. Both via the rules-bypass admin context, which is
  // exactly the Cloud Functions Admin-SDK capture path that must keep working.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({ addedAt: new Date() });
    await ctx.firestore().doc(SAMPLE_PATH).set(sampleBody());
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

// ============================================================================
// LLM_RESPONSE_SAMPLES (BUT-1451) — deny-all client access, server-only capture
//
// Mirrors the deletion_audit_logs precedent (`allow read, write: if false`).
// Coverage: read + create + update + delete denied for unauthenticated,
// authenticated non-admin, and app admin; plus the Admin-SDK write still works.
// ============================================================================

// L1: read deny — unauthenticated client cannot read an existing sample.
test("llm_response_samples: unauthenticated client cannot read", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(SAMPLE_PATH).get());
});

// L2: read deny — authenticated non-admin cannot read an existing sample.
test("llm_response_samples: authenticated non-admin cannot read", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(ctx.firestore().doc(SAMPLE_PATH).get());
});

// L3: read deny — even an app admin cannot read (content sensitivity; the rule
//     intentionally does NOT relax to isAdmin() pending DPO sign-off).
test("llm_response_samples: app admin cannot read", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertFails(ctx.firestore().doc(SAMPLE_PATH).get());
});

// L4: create deny — unauthenticated client cannot create a sample.
test("llm_response_samples: unauthenticated client cannot create", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc("llm_response_samples/anon-forge").set(sampleBody())
  );
});

// L5: create deny — authenticated non-admin cannot create a sample.
test("llm_response_samples: authenticated non-admin cannot create", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx.firestore().doc("llm_response_samples/user-forge").set(sampleBody())
  );
});

// L6: create deny — even an app admin cannot create a sample from the client.
test("llm_response_samples: app admin cannot create", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertFails(
    ctx.firestore().doc("llm_response_samples/admin-forge").set(sampleBody())
  );
});

// L7: update deny — authenticated non-admin cannot mutate an existing sample.
test("llm_response_samples: authenticated non-admin cannot update", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx.firestore().doc(SAMPLE_PATH).update({ outputScrubbed: "tampered" })
  );
});

// L8: update deny — even an app admin cannot mutate an existing sample.
test("llm_response_samples: app admin cannot update", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertFails(
    ctx.firestore().doc(SAMPLE_PATH).update({ outputScrubbed: "tampered" })
  );
});

// L9: delete deny — authenticated non-admin cannot delete an existing sample.
test("llm_response_samples: authenticated non-admin cannot delete", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(ctx.firestore().doc(SAMPLE_PATH).delete());
});

// L10: delete deny — even an app admin cannot delete (TTL cleanup is server-side).
test("llm_response_samples: app admin cannot delete", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertFails(ctx.firestore().doc(SAMPLE_PATH).delete());
});

// L11: server-side / Admin-SDK write still works (rules bypass). This is the
//      Cloud Functions capture path the deny-all rule is designed to allow
//      through — proving the policy doesn't break the feature.
test("llm_response_samples: server-side write succeeds (rules bypass)", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await assertSucceeds(
      ctx.firestore().doc("llm_response_samples/server-write").set(sampleBody())
    );
  });
});

async function run(): Promise<void> {
  console.log("llm_response_samples rules tests (BUT-1451)\n");
  console.log("==========================================\n");
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
