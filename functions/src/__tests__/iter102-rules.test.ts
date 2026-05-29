/**
 * Firestore rules tests for the iter-102 sprint diff (2026-05-28).
 *
 * Three rule branches changed in `firestore.rules`:
 *
 *  1. `/shared_content/{contentId}` `allow list` — a NEW recipient branch was
 *     added: a user in `resource.data.sharedToUserIds` may now LIST. Previously
 *     only the sharer could list. The group query filters by
 *     `sharedToUserIds arrayContains[Any]`, so recipients listing what was
 *     shared with them needed this branch. The rules engine evaluates `list`
 *     per candidate document, so a recipient can only enumerate docs whose
 *     `sharedToUserIds` actually contains their uid — it must NOT widen access
 *     to docs they were not shared into.
 *
 *  2. `/notification_delivery/{notificationId}` `allow create` — `expireAt`
 *     added to the `keys().hasOnly([...])` allowlist (90-day TTL field).
 *
 *  3. `/notification_engagement/{engagementId}` `allow create` — `expireAt`
 *     added to the `keys().hasOnly([...])` allowlist (90-day TTL field).
 *
 * For each branch we prove BOTH the allow path and the deny path. The critical
 * security question for change #1 is: does the new recipient list branch leak
 * documents a user was NOT shared into? We pin that with a per-document deny.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/iter102-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-iter102";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const SHARER_UID = "iter102-sharer-uid";
const RECIPIENT_UID = "iter102-recipient-uid";
const OTHER_RECIPIENT_UID = "iter102-other-recipient-uid";
const STRANGER_UID = "iter102-stranger-uid";

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

/** Minimal-but-valid shared_content doc. Required fields per the create rule's
 *  hasRequiredFields: sharedByUserId, contentType, sharedAt. */
function validSharedContentBody(
  sharerUid: string,
  recipients: string[],
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    sharedByUserId: sharerUid,
    contentType: "recipe",
    sharedAt: new Date(),
    sharedToUserIds: recipients,
    ...extra,
  };
}

/** notification_delivery doc. create rule pins senderId == auth.uid and
 *  keys().hasOnly([...]) — no hasRequiredFields, so a subset of the allowlist
 *  is valid as long as senderId is present. */
function validDeliveryBody(
  senderUid: string,
  targetUid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    notificationId: "n-1",
    senderId: senderUid,
    targetUserId: targetUid,
    category: "social",
    type: "comment",
    status: "sent",
    sentAt: new Date(),
    metadata: {},
    delivered: false,
    ...extra,
  };
}

/** notification_engagement doc. create rule pins userId == auth.uid and
 *  keys().hasOnly([...]). */
function validEngagementBody(
  userUid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    notificationId: "n-1",
    userId: userUid,
    action: "opened",
    timestamp: new Date(),
    ...extra,
  };
}

async function seed(
  collPath: string,
  body: Record<string, unknown>
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(collPath).set(body);
  });
}

// ============================================================================
// SHARED_CONTENT — list recipient branch (S1–S6)
// ============================================================================

// S1: ALLOW — sharer can list their own shared_content (pre-existing branch,
// pinned to guard against regression when the recipient branch was added).
test("shared_content: sharer can list docs they shared", async () => {
  await seed(
    "shared_content/sc-sharer-list",
    validSharedContentBody(SHARER_UID, [RECIPIENT_UID])
  );
  const ctx = env.authenticatedContext(SHARER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .collection("shared_content")
      .where("sharedByUserId", "==", SHARER_UID)
      .get()
  );
});

// S2: ALLOW — recipient can list docs whose sharedToUserIds contains their uid.
// This is the NEW branch. The query MUST filter by sharedToUserIds so the rule
// can be satisfied per-document.
test("shared_content: recipient can list docs shared with them (NEW branch)", async () => {
  await seed(
    "shared_content/sc-recipient-list",
    validSharedContentBody(SHARER_UID, [RECIPIENT_UID])
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .collection("shared_content")
      .where("sharedToUserIds", "array-contains", RECIPIENT_UID)
      .get()
  );
});

// S3: DENY (CRITICAL — leak check) — recipient cannot list docs they were NOT
// shared into, even with the new branch. Query that touches a doc whose
// sharedToUserIds does NOT contain the requester must be rejected. Here the
// recipient queries for OTHER_RECIPIENT_UID's shares, which they are not part
// of; the per-document list rule must deny because auth.uid is not in that
// doc's sharedToUserIds nor is auth.uid the sharer.
test("shared_content: recipient cannot list docs shared only with others (leak guard)", async () => {
  await seed(
    "shared_content/sc-other-only",
    validSharedContentBody(SHARER_UID, [OTHER_RECIPIENT_UID])
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  // Query filters for OTHER_RECIPIENT_UID — requester (RECIPIENT_UID) is not
  // the sharer and not in that array, so the list must be denied.
  await assertFails(
    ctx
      .firestore()
      .collection("shared_content")
      .where("sharedToUserIds", "array-contains", OTHER_RECIPIENT_UID)
      .get()
  );
});

// S4: DENY — stranger (not sharer, not in any sharedToUserIds) cannot list by
// filtering on the sharer's uid.
test("shared_content: stranger cannot list someone else's shared content by sharer", async () => {
  await seed(
    "shared_content/sc-stranger-list",
    validSharedContentBody(SHARER_UID, [RECIPIENT_UID])
  );
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .collection("shared_content")
      .where("sharedByUserId", "==", SHARER_UID)
      .get()
  );
});

// S5: DENY — unfiltered list is rejected. Without a sharedToUserIds /
// sharedByUserId filter the engine cannot satisfy the per-doc rule for the
// whole collection, so an open list must fail. This proves the new branch did
// NOT make the collection openly listable.
test("shared_content: recipient cannot list the whole collection unfiltered", async () => {
  await seed(
    "shared_content/sc-unfiltered",
    validSharedContentBody(SHARER_UID, [RECIPIENT_UID])
  );
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertFails(ctx.firestore().collection("shared_content").get());
});

// S6: DENY — unauthenticated client cannot list at all.
test("shared_content: unauthenticated client cannot list", async () => {
  await seed(
    "shared_content/sc-anon-list",
    validSharedContentBody(SHARER_UID, [RECIPIENT_UID])
  );
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .collection("shared_content")
      .where("sharedToUserIds", "array-contains", RECIPIENT_UID)
      .get()
  );
});

// ============================================================================
// NOTIFICATION_DELIVERY — create expireAt allowlist (D1–D4)
// ============================================================================

// D1: ALLOW — sender can create a delivery doc INCLUDING the new expireAt field.
test("notification_delivery: sender can create with expireAt (NEW allowlisted field)", async () => {
  const ctx = env.authenticatedContext(SHARER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc("notification_delivery/nd-with-expire")
      .set(
        validDeliveryBody(SHARER_UID, RECIPIENT_UID, { expireAt: new Date() })
      )
  );
});

// D2: ALLOW — create still works WITHOUT expireAt (back-compat — the field is
// optional, hasOnly permits a subset).
test("notification_delivery: sender can create without expireAt (back-compat)", async () => {
  const ctx = env.authenticatedContext(SHARER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc("notification_delivery/nd-no-expire")
      .set(validDeliveryBody(SHARER_UID, RECIPIENT_UID))
  );
});

// D3: DENY — an UNKNOWN field outside the allowlist is still rejected (proves
// expireAt was added explicitly, not by loosening hasOnly).
test("notification_delivery: create rejects an unknown field", async () => {
  const ctx = env.authenticatedContext(SHARER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc("notification_delivery/nd-bad-field")
      .set(
        validDeliveryBody(SHARER_UID, RECIPIENT_UID, {
          expireAt: new Date(),
          maliciousField: "x",
        })
      )
  );
});

// D4: DENY — a non-sender cannot create a delivery doc impersonating another
// sender, even with a valid expireAt.
test("notification_delivery: stranger cannot create impersonating sender", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc("notification_delivery/nd-impersonate")
      .set(
        validDeliveryBody(SHARER_UID, RECIPIENT_UID, { expireAt: new Date() })
      )
  );
});

// ============================================================================
// NOTIFICATION_ENGAGEMENT — create expireAt allowlist (E1–E4)
// ============================================================================

// E1: ALLOW — owner can create an engagement doc INCLUDING the new expireAt.
test("notification_engagement: owner can create with expireAt (NEW allowlisted field)", async () => {
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc("notification_engagement/ne-with-expire")
      .set(validEngagementBody(RECIPIENT_UID, { expireAt: new Date() }))
  );
});

// E2: ALLOW — create still works WITHOUT expireAt (back-compat).
test("notification_engagement: owner can create without expireAt (back-compat)", async () => {
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc("notification_engagement/ne-no-expire")
      .set(validEngagementBody(RECIPIENT_UID))
  );
});

// E3: DENY — an unknown field outside the allowlist is rejected.
test("notification_engagement: create rejects an unknown field", async () => {
  const ctx = env.authenticatedContext(RECIPIENT_UID);
  await assertFails(
    ctx
      .firestore()
      .doc("notification_engagement/ne-bad-field")
      .set(
        validEngagementBody(RECIPIENT_UID, {
          expireAt: new Date(),
          maliciousField: "x",
        })
      )
  );
});

// E4: DENY — a user cannot create an engagement doc with someone else's userId,
// even with a valid expireAt.
test("notification_engagement: cannot create with another user's userId", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc("notification_engagement/ne-impersonate")
      .set(validEngagementBody(RECIPIENT_UID, { expireAt: new Date() }))
  );
});

async function run(): Promise<void> {
  console.log("iter-102 rules tests (shared_content list + notification expireAt)");
  console.log("==================================================================\n");
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
