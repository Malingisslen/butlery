/**
 * Firestore rules tests for `users/{uid}/notifications` (BUT-1957).
 *
 * Rules contract under test:
 *   - READ is owner-only (`isAuthenticated() && request.auth.uid == userId`),
 *     and the shape production issues is an ORDERED LIST QUERY, not a `get()`:
 *     `.orderBy('createdAt', descending: true).limit(n)` from
 *     `FirebaseDataExportRepository.exportDeliveredNotifications`. Rules are not
 *     filters — a list query is refused unless the rule proves every returnable
 *     document is readable — so the single-doc `get()` case does NOT stand in
 *     for it and both are pinned separately.
 *   - WRITE is closed to every client, the OWNER INCLUDED. These rows record
 *     what the SERVER sent (the win-back job in analytics/detect-lapsed-users.ts
 *     and the weekly digest in analytics/send-activity-digest.ts, both Admin
 *     SDK); a client that could write one could fabricate a notification it
 *     never received, and that record is now reachable through the Art. 15
 *     export. No client writer exists today (`grep` for the collection constant
 *     `FirestoreCollections.userDeliveredNotifications` in `lib/` finds only the
 *     export's read), so the closure breaks nothing.
 *
 * Non-vacuity: every deny below is paired with a fail-closed control that
 * differs in exactly ONE variable and must ALLOW — the actor for the read
 * denies (owner runs the identical query), the privilege for the write denies
 * (the identical payload, path and doc id succeed under the Admin SDK). A
 * `PERMISSION_DENIED` string fingerprints the rule LINE, not the actor, so it
 * can never discriminate on its own.
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080
 *   (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npm run test:rules:delivered-notifications
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

// Probe hooks: a mutation run points these at a mutated COPY of the rules file
// under a fresh (lowercase) project id, so the real firestore.rules stays
// byte-identical by construction and mutant writes never touch this namespace.
// A BARE LITERAL, deliberately. `scripts/rules-coverage-report.js` discovers
// which emulator projects to fetch coverage from with
// its word-boundary + literal-string regex — an expression after the `=`
// matches nothing, and `PROBE_PROJECT_ID` has no word boundary before
// `PROJECT_ID` either, so
// the suite becomes invisible to it. That matters here specifically: this
// commit adds a new CONDITIONAL match block, and the coverage gate exits 1 on a
// new block no discovered project exercises. The probe hook moved to the call
// site below, where it does not sit between `PROJECT_ID` and its literal.
const PROJECT_ID = "butlery-delivered-notifications-test";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ?? path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "notif-owner-uid";
const STRANGER_UID = "notif-stranger-uid";

const NOTIFICATIONS = (uid: string): string => `users/${uid}/notifications`;
const NOTIFICATION_DOC = (uid: string, id: string): string =>
  `${NOTIFICATIONS(uid)}/${id}`;

// The emulator persists across `npm run` invocations, so a create-deny test
// re-run would land on UPDATE instead of CREATE and prove the wrong limb.
const RUN = `r${Date.now()}`;

/** The win-back job's row shape (detect-lapsed-users.ts). */
function winBackRow(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    type: "winback_7d",
    message: "Vi saknar dig i köket!",
    bodyShown: "Vi saknar dig i köket!",
    variant: "warm",
    contextKey: "winback_7d",
    createdAt: new Date("2026-08-01T10:00:00Z"),
    read: false,
    ...extra,
  };
}

/** The weekly digest's row shape (send-activity-digest.ts). */
function digestRow(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    type: "activity_digest",
    newRecipeCount: 3,
    newCommentCount: 1,
    newRatingCount: 2,
    newShareCount: 0,
    period: "weekly",
    createdAt: new Date("2026-08-08T10:00:00Z"),
    read: false,
    ...extra,
  };
}

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: process.env.PROBE_PROJECT_ID ?? PROJECT_ID,
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

/** Seeds both writers' row shapes for `uid` the way the Admin SDK does. */
async function seedRows(uid: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(NOTIFICATION_DOC(uid, "winback-1")).set(winBackRow());
    await ctx.firestore().doc(NOTIFICATION_DOC(uid, "digest-1")).set(digestRow());
  });
}

/** Asserts a doc id is unwritten, so a create-deny lands on CREATE. */
async function assertAbsent(docPath: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await ctx.firestore().doc(docPath).get();
    if ((snap as { exists: boolean }).exists) {
      throw new Error(
        `fixture precondition failed: ${docPath} already exists, so the ` +
          "create-deny below would land on the UPDATE limb"
      );
    }
  });
}

/** Non-empty premise: an empty result would let a broken read pass an ALLOW. */
function requireNonEmpty(snap: unknown, what: string): void {
  if ((snap as { empty: boolean }).empty) {
    throw new Error(
      `${what} returned nothing — an empty result would let a broken query ` +
        "pass this test vacuously"
    );
  }
}

// ====================================================================
// DELIVERED NOTIFICATIONS — READ (owner-only)
// ====================================================================

// DN1: the one that matters — the exact query production issues.
test(
  "notifications: owner CAN run the export's ordered list query (createdAt desc)",
  async () => {
    await seedRows(OWNER_UID);
    const ctx = env.authenticatedContext(OWNER_UID);
    const snap = await assertSucceeds(
      ctx
        .firestore()
        .collection(NOTIFICATIONS(OWNER_UID))
        .orderBy("createdAt", "desc")
        .limit(500)
        .get()
    );
    requireNonEmpty(snap, "the owner's ordered list query");
  }
);

// DN2: the unordered list of the same collection, so a future change to the
// export's ordering is not the only thing this suite would notice.
test("notifications: owner CAN run an unordered list query", async () => {
  await seedRows(OWNER_UID);
  const ctx = env.authenticatedContext(OWNER_UID);
  const snap = await assertSucceeds(
    ctx.firestore().collection(NOTIFICATIONS(OWNER_UID)).limit(500).get()
  );
  requireNonEmpty(snap, "the owner's unordered list query");
});

// DN3: single-document read. Not a substitute for DN1 in either direction.
test("notifications: owner CAN get() a single row", async () => {
  await seedRows(OWNER_UID);
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(NOTIFICATION_DOC(OWNER_UID, "winback-1")).get()
  );
});

// DN4: a different signed-in user is denied the SAME list query DN1 allows.
// Single-variable control pair: only the actor differs.
test(
  "notifications: a different signed-in user CANNOT list another user's notifications",
  async () => {
    await seedRows(OWNER_UID);
    const ctx = env.authenticatedContext(STRANGER_UID);
    await assertFails(
      ctx
        .firestore()
        .collection(NOTIFICATIONS(OWNER_UID))
        .orderBy("createdAt", "desc")
        .limit(500)
        .get()
    );
  }
);

// DN5: and the same actor is denied the single-doc read DN3 allows.
test(
  "notifications: a different signed-in user CANNOT get() another user's row",
  async () => {
    await seedRows(OWNER_UID);
    const ctx = env.authenticatedContext(STRANGER_UID);
    await assertFails(
      ctx.firestore().doc(NOTIFICATION_DOC(OWNER_UID, "winback-1")).get()
    );
  }
);

// DN6: the stranger's fail-closed control — the identical query against their
// OWN path succeeds, so DN4/DN5 measure ownership, not a broken query or a
// collection nobody can read.
test("notifications: the same stranger CAN list their OWN notifications", async () => {
  await seedRows(STRANGER_UID);
  const ctx = env.authenticatedContext(STRANGER_UID);
  const snap = await assertSucceeds(
    ctx
      .firestore()
      .collection(NOTIFICATIONS(STRANGER_UID))
      .orderBy("createdAt", "desc")
      .limit(500)
      .get()
  );
  requireNonEmpty(snap, "the stranger's own ordered list query");
});

// DN7: unauthenticated is denied both read shapes.
test("notifications: an unauthenticated client CANNOT list or get()", async () => {
  await seedRows(OWNER_UID);
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .collection(NOTIFICATIONS(OWNER_UID))
      .orderBy("createdAt", "desc")
      .limit(500)
      .get()
  );
  await assertFails(
    ctx.firestore().doc(NOTIFICATION_DOC(OWNER_UID, "winback-1")).get()
  );
});

// ====================================================================
// DELIVERED NOTIFICATIONS — WRITE (closed to every client, owner included)
// ====================================================================

// DN8: the owner cannot CREATE a row — i.e. cannot fabricate a notification
// the server never sent them. The doc id is per-run and asserted absent first,
// so this lands on the CREATE limb rather than silently on UPDATE.
test("notifications: owner CANNOT create a notification row", async () => {
  const docPath = NOTIFICATION_DOC(OWNER_UID, `owner-create-${RUN}`);
  await assertAbsent(docPath);
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(ctx.firestore().doc(docPath).set(winBackRow()));
});

// DN9: the owner cannot UPDATE a server-written row — including the innocuous
// `read: true` flip, which is the edit a client would plausibly attempt.
test("notifications: owner CANNOT update a server-written row", async () => {
  await seedRows(OWNER_UID);
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(NOTIFICATION_DOC(OWNER_UID, "winback-1"))
      .update({ read: true })
  );
  // The message text itself is equally frozen — the row must keep saying what
  // was actually sent, because the export ships it.
  await assertFails(
    ctx
      .firestore()
      .doc(NOTIFICATION_DOC(OWNER_UID, "winback-1"))
      .update({ message: "något helt annat" })
  );
});

// DN10: the owner cannot DELETE a row (erasure runs through the cascade).
test("notifications: owner CANNOT delete a notification row", async () => {
  await seedRows(OWNER_UID);
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx.firestore().doc(NOTIFICATION_DOC(OWNER_UID, "digest-1")).delete()
  );
});

// DN11: a stranger cannot write into someone else's notifications either.
test("notifications: a different signed-in user CANNOT write another user's row", async () => {
  const docPath = NOTIFICATION_DOC(OWNER_UID, `stranger-create-${RUN}`);
  await assertAbsent(docPath);
  await seedRows(OWNER_UID);
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(docPath).set(digestRow()));
  await assertFails(
    ctx
      .firestore()
      .doc(NOTIFICATION_DOC(OWNER_UID, "digest-1"))
      .update({ read: true })
  );
  await assertFails(
    ctx.firestore().doc(NOTIFICATION_DOC(OWNER_UID, "digest-1")).delete()
  );
});

// DN12: unauthenticated writes are denied too.
test("notifications: an unauthenticated client CANNOT write a row", async () => {
  const docPath = NOTIFICATION_DOC(OWNER_UID, `unauth-create-${RUN}`);
  await assertAbsent(docPath);
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(docPath).set(winBackRow()));
});

// DN13: fail-closed control for DN8-DN12. The SAME payloads at the SAME paths
// go through under the Admin SDK, which is how the two analytics jobs write
// them — so those denies measure the rule, not a malformed payload, a bad doc
// id or an unreachable path. `allow write: if false` cannot be probed by
// deleting a conjunct (there is none), so this control plus the mutation probe
// that OPENS the rule is what proves the cluster is load-bearing.
test("notifications: the Admin SDK CAN write the same rows the client cannot", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const created = NOTIFICATION_DOC(OWNER_UID, `admin-create-${RUN}`);
    await ctx.firestore().doc(created).set(winBackRow());
    await ctx.firestore().doc(created).update({ read: true });
    await ctx.firestore().doc(created).delete();
  });
});

// DN14: the block is a SPECIFIC path, not a `{path=**}/notifications/{id}`
// wildcard, so it authorizes nothing for a collection-group query — the owner
// is refused one over their own rows just as a stranger is. Pinned because the
// export could plausibly be refactored to `collectionGroup('notifications')`,
// which would fail for every user; the path-scoped query DN1 pins is the only
// shape this rule can serve.
test("notifications: NOBODY can run a collectionGroup query, owner included", async () => {
  await seedRows(OWNER_UID);
  await assertFails(
    env.authenticatedContext(OWNER_UID).firestore().collectionGroup("notifications").get()
  );
  await assertFails(
    env
      .authenticatedContext(STRANGER_UID)
      .firestore()
      .collectionGroup("notifications")
      .get()
  );
});

async function run(): Promise<void> {
  console.log("Delivered notifications rules tests (BUT-1957)\n");
  console.log("=============================================\n");
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
