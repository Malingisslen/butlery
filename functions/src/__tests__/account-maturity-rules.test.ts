/**
 * BUT-659: Firestore rules tests for the new-account anti-spam cooldown.
 *
 * Covers `isAccountMatured()` enforcement on:
 * - `social_requests/{requestId}` (friend requests + group invites)
 * - `messages/{messageId}` (top-level messages collection)
 *
 * The predicate considers an account "matured" when EITHER:
 *   - the auth token's `email_verified` claim is true, OR
 *   - the user's `users/{uid}.createdAt` is at least 60 minutes old.
 *
 * Prerequisite: Firestore emulator must be running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/account-maturity-rules.test.ts
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

// NOTE: seed + body timestamps use plain `Date` (stored as a Firestore
// Timestamp), NOT `admin.firestore.Timestamp`. The rules-unit-testing contexts
// expose the CLIENT SDK, which rejects firebase-admin Timestamp objects with
// `invalid-argument` — that latent setup bug kept this file from running at all
// until it was wired into `test:rules:all` (BUT-1386). `Date` round-trips to a
// Timestamp, so `isAccountMatured()`'s `createdAt.toMillis()` still works.

const PROJECT_ID = "butlery-rules-account-maturity";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const NEW_USER = "new-user-uid";
const OLD_USER = "old-user-uid";
const VERIFIED_USER = "verified-user-uid";
const OTHER_USER = "other-user-uid";

let env: RulesTestEnvironment;

// The emulator persists documents across separate `npm run` invocations
// (env.cleanup() only closes clients). The create-allow tests below use FIXED
// doc ids (req-2/req-3/msg-2); on a 2nd+ run those already exist, so the create
// is evaluated as an UPDATE and the social_requests/messages update rules deny a
// full-body re-set — a false FAIL. Clearing the namespace at setup keeps every
// create-allow target brand-new. (See firestore-rules-tester knowledge file,
// 2026-06-03 entry.)
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
      },
    );
    req.on("error", reject);
    req.end();
  });
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await clearFirestore();

  // Seed the user docs that the rule reads via `get()`. NEW_USER's
  // createdAt is "now" (fails maturity); OLD_USER's is 2h ago (passes).
  await env.withSecurityRulesDisabled(async (ctx) => {
    const now = new Date();
    const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
    await ctx.firestore().doc(`users/${NEW_USER}`).set({
      uid: NEW_USER,
      createdAt: now,
      displayName: "New",
    });
    await ctx.firestore().doc(`users/${OLD_USER}`).set({
      uid: OLD_USER,
      createdAt: twoHoursAgo,
      displayName: "Old",
    });
    await ctx.firestore().doc(`users/${VERIFIED_USER}`).set({
      uid: VERIFIED_USER,
      createdAt: now,
      displayName: "Verified",
    });
    await ctx.firestore().doc(`users/${OTHER_USER}`).set({
      uid: OTHER_USER,
      createdAt: twoHoursAgo,
      displayName: "Other",
    });
    // Conversation that messages tests use.
    await ctx.firestore().doc("conversations/conv-1").set({
      participantIds: [NEW_USER, OLD_USER, VERIFIED_USER, OTHER_USER],
      createdAt: now,
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

// BUT-1386 (ADR-0002): social_requests + messages create now ALSO require
// `isAgeCompliant()` (custom claim `ageCompliant == true`). Every authed
// context below carries `ageCompliant: true` so this suite keeps isolating the
// MATURITY gate (the variable under test), not the new age gate. Without this
// claim all 3 create-allow assertions here (AM2, AM3, AM5) fail closed — the
// pre-fix failure count for this file was 3/5.
const AGE_OK = { ageCompliant: true };

function friendRequestBody(fromUid: string, toUid: string): Record<string, unknown> {
  return {
    type: "friend_request",
    fromUserId: fromUid,
    toUserId: toUid,
    status: "pending",
    sentAt: new Date(),
  };
}

function messageBody(senderUid: string): Record<string, unknown> {
  return {
    senderId: senderUid,
    conversationId: "conv-1",
    content: "Hej!",
    sentAt: new Date(),
  };
}

// AM1: brand-new unverified account cannot create a friend request.
test(
  "social_requests: new unverified account is blocked from creating friend requests",
  async () => {
    const ctx = env.authenticatedContext(NEW_USER, {
      email_verified: false,
      ...AGE_OK,
    });
    await assertFails(
      ctx
        .firestore()
        .doc("social_requests/req-1")
        .set(friendRequestBody(NEW_USER, OTHER_USER)),
    );
  },
);

// AM2: 60min-old unverified account can create a friend request.
test(
  "social_requests: matured unverified account can create friend requests",
  async () => {
    const ctx = env.authenticatedContext(OLD_USER, {
      email_verified: false,
      ...AGE_OK,
    });
    await assertSucceeds(
      ctx
        .firestore()
        .doc("social_requests/req-2")
        .set(friendRequestBody(OLD_USER, OTHER_USER)),
    );
  },
);

// AM3: brand-new verified account passes immediately (verified email
//      bypasses the 60min wait).
test(
  "social_requests: verified-email new account can create friend requests",
  async () => {
    const ctx = env.authenticatedContext(VERIFIED_USER, {
      email_verified: true,
      ...AGE_OK,
    });
    await assertSucceeds(
      ctx
        .firestore()
        .doc("social_requests/req-3")
        .set(friendRequestBody(VERIFIED_USER, OTHER_USER)),
    );
  },
);

// AM4: brand-new unverified account cannot send DMs.
test(
  "messages: new unverified account is blocked from sending messages",
  async () => {
    const ctx = env.authenticatedContext(NEW_USER, {
      email_verified: false,
      ...AGE_OK,
    });
    await assertFails(
      ctx.firestore().doc("messages/msg-1").set(messageBody(NEW_USER)),
    );
  },
);

// AM5: matured account can send DMs.
test(
  "messages: matured account can send messages",
  async () => {
    const ctx = env.authenticatedContext(OLD_USER, {
      email_verified: false,
      ...AGE_OK,
    });
    await assertSucceeds(
      ctx.firestore().doc("messages/msg-2").set(messageBody(OLD_USER)),
    );
  },
);

async function run(): Promise<void> {
  console.log("BUT-659: account-maturity rules tests\n");
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
      (failed ? `, ${failed} failed` : ""),
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
