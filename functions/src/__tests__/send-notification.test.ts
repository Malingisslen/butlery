/**
 * Sprint C3 (2026-04-25): `sendNotification` callable respects prefs + quiet hours.
 *
 * Before this sprint, the `sendNotification` callable (and its batch sibling)
 * called `admin.messaging().sendEachForMulticast` directly, bypassing the
 * preference-aware gate introduced in BUT-438.  After this sprint, the
 * callable's core dispatch (`dispatchNotification`) routes non-silent pushes
 * through `sendPushToUserRespectingPreferences`.  Silent pushes (background
 * sync) intentionally bypass the gate — they're invisible to the user, so
 * quiet hours don't apply.
 *
 * This test exercises `dispatchNotification` directly via the test seams
 * (`preferenceAwareSend`, `silentSend`, `getTokens`).  The Firebase auth /
 * rate-limit / friendship-check layer above `dispatchNotification` is
 * unchanged and out of scope here.
 *
 * Run with: npx ts-node src/__tests__/send-notification.test.ts
 */

import * as admin from "firebase-admin";
import {
  assertBatchValid,
  dispatchNotification,
  preflightNotificationBatch,
} from "../notifications/send-notification";
import type { PreferenceAwarePushResult } from "../shared/preference-aware-push";
import { HttpsError } from "firebase-functions/v2/https";
import { __setFirestoreForTest } from "../middleware/rate_limiter";

interface PrefAwareCall {
  userId: string;
  notification: { title: string; body: string };
  category: string;
  data?: Record<string, string>;
}

interface SilentCall {
  message: admin.messaging.MulticastMessage;
}

interface TestState {
  prefAwareCalls: PrefAwareCall[];
  silentCalls: SilentCall[];
  prefAwareResult: PreferenceAwarePushResult;
}

function makeState(
  prefAwareResult: PreferenceAwarePushResult
): TestState {
  return {
    prefAwareCalls: [],
    silentCalls: [],
    prefAwareResult,
  };
}

function makeDeps(state: TestState) {
  return {
    preferenceAwareSend: async (
      userId: string,
      notification: { title: string; body: string },
      category: string,
      data?: Record<string, string>
    ): Promise<PreferenceAwarePushResult> => {
      state.prefAwareCalls.push({ userId, notification, category, data });
      return state.prefAwareResult;
    },
    silentSend: async (
      message: admin.messaging.MulticastMessage
    ): Promise<admin.messaging.BatchResponse> => {
      state.silentCalls.push({ message });
      return {
        responses: [{ success: true, messageId: "fake-msg-id" }],
        successCount: 1,
        failureCount: 0,
      };
    },
    getTokens: async (_userId: string) => ({
      tokens: ["fake-token"],
      tokenDocIds: new Map([["fake-token", "fake-doc-id"]]),
    }),
    // BUT-647 + BUT-645: stub the pre-send gate to always proceed. The
    // gate's behavior is covered by `quiet-hours.test.ts`; here we only
    // care that `dispatchNotification` reaches the prefs-aware send path.
    gate: async () =>
      ({ action: "proceed", reason: "test-stub" }) as const,
    // Stub the send-event recorder so it doesn't try to hit firestore.
    recordEvent: async () => undefined,
  };
}

interface Scenario {
  name: string;
  /** Result the prefs-aware helper would return for this user. */
  helperResult: PreferenceAwarePushResult;
  silent?: boolean;
  /** Should `preferenceAwareSend` have been called? */
  expectGated: boolean;
  /** Should the silent path have run? */
  expectSilentSend: boolean;
  /** Did the response report a successful (or non-failure) outcome? */
  expectSuccess: boolean;
  expectSuccessCount: number;
}

const scenarios: Scenario[] = [
  {
    name: "non-silent push: helper says SENT → callable reports success",
    helperResult: { sent: true, reason: "sent", successCount: 1, failureCount: 0 },
    expectGated: true,
    expectSilentSend: false,
    expectSuccess: true,
    expectSuccessCount: 1,
  },
  {
    name: "non-silent push: helper says master_disabled → callable reports 0 sends, no failure",
    helperResult: { sent: false, reason: "master_disabled" },
    expectGated: true,
    expectSilentSend: false,
    expectSuccess: true, // gate is not a failure
    expectSuccessCount: 0,
  },
  {
    name: "non-silent push: helper says quiet_hours → callable reports 0 sends, no failure",
    helperResult: { sent: false, reason: "quiet_hours" },
    expectGated: true,
    expectSilentSend: false,
    expectSuccess: true,
    expectSuccessCount: 0,
  },
  {
    name: "non-silent push: helper says opted_out → callable reports 0 sends, no failure",
    helperResult: { sent: false, reason: "opted_out" },
    expectGated: true,
    expectSilentSend: false,
    expectSuccess: true,
    expectSuccessCount: 0,
  },
  {
    name: "non-silent push: helper says no_token → callable reports 0 sends, no failure",
    helperResult: { sent: false, reason: "no_token", successCount: 0, failureCount: 1 },
    expectGated: true,
    expectSilentSend: false,
    expectSuccess: true,
    expectSuccessCount: 0,
  },
  {
    name: "silent push: BYPASSES the prefs gate (background sync)",
    helperResult: { sent: true, reason: "sent" }, // unused
    silent: true,
    expectGated: false,
    expectSilentSend: true,
    expectSuccess: true,
    expectSuccessCount: 1,
  },
];

interface Assertion {
  ok: boolean;
  detail?: string;
}

function assertScenario(
  s: Scenario,
  state: TestState,
  result: { success: boolean; successCount: number; failureCount: number }
): Assertion {
  const gateMatch =
    s.expectGated === (state.prefAwareCalls.length === 1);
  const silentMatch =
    s.expectSilentSend === (state.silentCalls.length === 1);
  const successMatch = result.success === s.expectSuccess;
  const successCountMatch = result.successCount === s.expectSuccessCount;

  if (gateMatch && silentMatch && successMatch && successCountMatch) {
    return { ok: true };
  }
  return {
    ok: false,
    detail:
      `gate-called=${state.prefAwareCalls.length}/expected=${s.expectGated ? 1 : 0}, ` +
      `silent-called=${state.silentCalls.length}/expected=${s.expectSilentSend ? 1 : 0}, ` +
      `success=${result.success}/expected=${s.expectSuccess}, ` +
      `successCount=${result.successCount}/expected=${s.expectSuccessCount}`,
  };
}

async function runScenarioTests(): Promise<number> {
  let failed = 0;
  for (const s of scenarios) {
    const state = makeState(s.helperResult);
    const deps = makeDeps(state);

    const result = await dispatchNotification({
      targetUserId: "user-callable-1",
      title: "Hej",
      body: "En vän har skickat dig ett recept",
      data: {
        type: "recipe_shared",
        route: "/recipe",
        targetId: "recipe-123",
        notificationType: "recipe_shared",
      },
      silent: s.silent,
      ...deps,
    });

    const a = assertScenario(s, state, result);
    if (!a.ok) {
      failed++;
      console.log(`  FAIL  ${s.name}`);
      if (a.detail) console.log(`        ${a.detail}`);
      continue;
    }

    // BUT-641: schema fields must arrive on the gated path.
    if (s.expectGated) {
      const call = state.prefAwareCalls[0];
      const data = call.data ?? {};
      const schemaOk =
        data.route === "/recipe" &&
        data.targetId === "recipe-123" &&
        data.notificationType === "recipe_shared";
      if (!schemaOk) {
        failed++;
        console.log(`  FAIL  ${s.name}`);
        console.log(
          `        BUT-641 schema missing: route=${data.route}, ` +
            `targetId=${data.targetId}, notificationType=${data.notificationType}`
        );
        continue;
      }
    }

    // Schema fields must also arrive on the silent (background-sync) path.
    if (s.expectSilentSend) {
      const data = state.silentCalls[0].message.data ?? {};
      const schemaOk =
        data.route === "/recipe" &&
        data.targetId === "recipe-123" &&
        data.notificationType === "recipe_shared";
      if (!schemaOk) {
        failed++;
        console.log(`  FAIL  ${s.name}`);
        console.log(
          `        BUT-641 schema missing on silent path: route=${data.route}, ` +
            `targetId=${data.targetId}, notificationType=${data.notificationType}`
        );
        continue;
      }
    }

    console.log(`  PASS  ${s.name}`);
  }
  return failed;
}

/**
 * Extra scenario: the callable receives an unknown notification category
 * via `data.type`.  The helper's contract for unknown categories is
 * "default to allowed" (see `isCategoryAllowed` — non-`reEngagement`
 * branches return `true`).  We verify that:
 *   1. The send actually happens (gate doesn't reject the call)
 *   2. The category passed to the helper is the helper's only typed
 *      literal `'reEngagement'` (because that's all the BUT-438 contract
 *      exposes), and the helper falls back to its default (allow + apply
 *      master/quiet-hours gates only).
 *
 * This is the "unknown-category fall-through" test the sprint C3 brief
 * called out.
 */
async function runUnknownCategoryFallback(): Promise<number> {
  const state = makeState({
    sent: true,
    reason: "sent",
    successCount: 1,
    failureCount: 0,
  });
  const deps = makeDeps(state);

  const result = await dispatchNotification({
    targetUserId: "user-unknown-cat",
    title: "Okänd kategori",
    body: "Test av okänd typ",
    data: {
      type: "totally_made_up_category_xyz",
      route: "/recipe",
      targetId: "recipe-xyz",
      notificationType: "totally_made_up_category_xyz",
    },
    ...deps,
  });

  let failed = 0;

  if (state.prefAwareCalls.length !== 1) {
    failed++;
    console.log(
      `  FAIL  unknown category falls through to default (allow): ` +
        `expected 1 helper call, got ${state.prefAwareCalls.length}`
    );
  } else if (state.prefAwareCalls[0].category !== "reEngagement") {
    failed++;
    console.log(
      `  FAIL  unknown category falls through to default (allow): ` +
        `expected category='reEngagement' (the only typed literal), ` +
        `got '${state.prefAwareCalls[0].category}'`
    );
  } else if (!result.success || result.successCount !== 1) {
    failed++;
    console.log(
      `  FAIL  unknown category falls through to default (allow): ` +
        `success=${result.success} successCount=${result.successCount}`
    );
  } else {
    console.log(`  PASS  unknown category falls through to default (allow)`);
  }

  return failed;
}

/**
 * BUT-1664: the batch callable's admission control.
 *
 * Two things are under test, and both are about COST rather than delivery:
 * the batch pays from its own bucket at one token per notification (it used to
 * pay a single token from the single-send bucket, making 100 pushes as cheap as
 * one), and a payload that can never be processed is rejected before it can
 * consume any of that budget.
 */
interface PreflightCase {
  name: string;
  notifications: unknown;
  /**
   * Verdict the stubbed limiter returns when it is reached. `false` means it
   * throws `resource-exhausted`, exactly as `enforceRateLimit` does.
   */
  allowed: boolean;
  /** Expected HttpsError code, or null when the call must succeed. */
  expectErrorCode: string | null;
  /** Tokens the bucket must be charged, or null when it must not be reached. */
  expectTokens: number | null;
}

function makeNotifications(count: number): unknown[] {
  return Array.from({ length: count }, (_, i) => ({
    targetUserId: `user-${i}`,
    title: "Hej",
    body: "Meddelande",
  }));
}

const preflightCases: PreflightCase[] = [
  {
    name: "charges one token PER NOTIFICATION, not one per call",
    notifications: makeNotifications(25),
    allowed: true,
    expectErrorCode: null,
    expectTokens: 25,
  },
  {
    name: "a full-size batch (100) is charged 100 and still admitted",
    notifications: makeNotifications(100),
    allowed: true,
    expectErrorCode: null,
    expectTokens: 100,
  },
  {
    name: "an empty batch still costs a token (no free no-op spam loop)",
    notifications: [],
    allowed: true,
    expectErrorCode: null,
    expectTokens: 1,
  },
  {
    name: "a non-array payload is rejected WITHOUT charging the bucket",
    notifications: "not-an-array",
    allowed: true,
    expectErrorCode: "invalid-argument",
    expectTokens: null,
  },
  {
    name: "an oversized batch is rejected WITHOUT charging the bucket",
    notifications: makeNotifications(101),
    allowed: true,
    expectErrorCode: "invalid-argument",
    expectTokens: null,
  },
  {
    name: "an exhausted bucket surfaces resource-exhausted",
    notifications: makeNotifications(10),
    allowed: false,
    expectErrorCode: "resource-exhausted",
    expectTokens: 10,
  },
];

async function runPreflightTests(): Promise<number> {
  let failed = 0;

  for (const c of preflightCases) {
    const charges: { operationType: string; tokens: number }[] = [];
    // BUT-1692: the seam is `enforceRateLimit`-shaped now (void, throws on
    // denial) rather than `checkRateLimit`-shaped, because production must go
    // through the enforcer to get the `system_events` audit row written.
    const enforce = async (
      _userId: string,
      operationType: string,
      tokensRequired: number = 1
    ): Promise<void> => {
      charges.push({ operationType, tokens: tokensRequired });
      if (!c.allowed) {
        throw new HttpsError(
          "resource-exhausted",
          `Rate limit exceeded for ${operationType}.`
        );
      }
    };

    let thrownCode: string | null = null;
    try {
      await preflightNotificationBatch({
        callerUid: "caller-1",
        notifications: c.notifications,
        enforce,
      });
    } catch (err) {
      thrownCode = (err as { code?: string }).code ?? String(err);
    }

    const problems: string[] = [];
    if (thrownCode !== c.expectErrorCode) {
      problems.push(
        `error=${thrownCode ?? "none"}/expected=${c.expectErrorCode ?? "none"}`
      );
    }
    if (c.expectTokens === null) {
      if (charges.length !== 0) {
        problems.push(
          `bucket charged ${charges[0].tokens} token(s) but must not be reached`
        );
      }
    } else if (charges.length !== 1) {
      problems.push(`bucket calls=${charges.length}/expected=1`);
    } else {
      if (charges[0].tokens !== c.expectTokens) {
        problems.push(`tokens=${charges[0].tokens}/expected=${c.expectTokens}`);
      }
      // The dedicated bucket is the whole point — the old code billed the
      // single-send bucket, so a regression here is invisible from token
      // count alone.
      if (charges[0].operationType !== "sendNotificationBatch") {
        problems.push(
          `bucket='${charges[0].operationType}'/expected='sendNotificationBatch'`
        );
      }
    }

    if (problems.length > 0) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(`        ${problems.join(", ")}`);
    } else {
      console.log(`  PASS  ${c.name}`);
    }
  }

  return failed;
}

/**
 * BUT-1692 acceptance #2: the DEFAULT `enforce` must resolve to the real
 * enforcer, and a rate-limit denial must leave a `system_events` audit row.
 *
 * Why this exists on top of the seam-injected cases above: those pass `enforce`
 * explicitly, so they pin the seam's SIGNATURE and nothing else. The seam type
 * is `typeof enforceRateLimit`, i.e. `(string, string, number?) =>
 * Promise<void>` — so replacing the default with a lambda that calls
 * `checkRateLimit` and throws locally (precisely the pre-BUT-1692 bug) still
 * type-checks and keeps every injected case green, while silently dropping the
 * audit row that is the entire reason for routing through the enforcer.
 *
 * This case passes NO `enforce`, drives the real `enforceRateLimit` against an
 * exhausted bucket through the `__setFirestoreForTest` seam, and asserts the
 * row itself rather than just the thrown code.
 *
 * Mutation test: put `checkRateLimit` + a local `throw new
 * HttpsError("resource-exhausted", ...)` back into
 * `preflightNotificationBatch` — this case reddens on the missing
 * `system_events` write while the other 18 stay green.
 */
async function runDefaultEnforcerAuditTest(): Promise<number> {
  const name =
    "the default enforcer denies AND writes the system_events audit row";
  const auditWrites: Record<string, unknown>[] = [];
  const bucketDocRef = {}; // identity token; the fake tracks one bucket doc
  // Bucket at zero with lastRefill = now: no refill interval has elapsed, so a
  // 10-notification batch cannot be paid for and the deny path must run.
  let bucket: Record<string, unknown> | undefined = {
    tokens: 0,
    lastRefill: admin.firestore.Timestamp.now(),
    operationType: "sendNotificationBatch",
    updatedAt: admin.firestore.Timestamp.now(),
  };
  const db = {
    collection: (collectionName: string) => ({
      doc: () => bucketDocRef,
      add: async (data: Record<string, unknown>) => {
        if (collectionName === "system_events") {
          auditWrites.push(data);
        }
        return { id: "fake-event-id" };
      },
    }),
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> =>
      fn({
        get: async () => ({
          exists: bucket !== undefined,
          data: () => bucket,
        }),
        update: (_ref: unknown, data: Record<string, unknown>) => {
          bucket = { ...bucket, ...data };
        },
        set: (_ref: unknown, data: Record<string, unknown>) => {
          bucket = { ...data };
        },
      }),
  } as unknown as admin.firestore.Firestore;

  let thrownCode: string | null = null;
  __setFirestoreForTest(db);
  try {
    await preflightNotificationBatch({
      callerUid: "caller-audit",
      notifications: makeNotifications(10),
    });
  } catch (err) {
    thrownCode = (err as { code?: string }).code ?? String(err);
  } finally {
    __setFirestoreForTest(null);
  }

  const problems: string[] = [];
  if (thrownCode !== "resource-exhausted") {
    problems.push(`error=${thrownCode ?? "none"}/expected=resource-exhausted`);
  }
  const violations = auditWrites.filter(
    (w) => w.type === "rate_limit_violation"
  );
  if (violations.length !== 1) {
    problems.push(
      `system_events rate_limit_violation rows=${violations.length}` +
        "/expected=1 — the default `enforce` is not the audited enforcer, so" +
        " batch abuse leaves no trace for monitoring"
    );
  } else if (violations[0].operationType !== "sendNotificationBatch") {
    problems.push(
      `audited operationType='${String(violations[0].operationType)}'` +
        "/expected='sendNotificationBatch'"
    );
  } else if (
    violations[0].userIdHash === "caller-audit" ||
    typeof violations[0].userIdHash !== "string" ||
    violations[0].userIdHash === ""
  ) {
    // The row lands in `system_events`, which is operator-readable. It must
    // carry the HASH, never the raw uid — asserted as an absence, because
    // "userIdHash is non-empty" alone stays green if someone assigns the uid
    // straight into it.
    problems.push(
      `userIdHash='${String(violations[0].userIdHash)}' — the audit row must` +
        " carry hashUid(uid), never the raw caller uid"
    );
  }

  if (problems.length > 0) {
    console.log(`  FAIL  ${name}`);
    console.log(`        ${problems.join(", ")}`);
    return 1;
  }
  console.log(`  PASS  ${name}`);
  return 0;
}

/**
 * The batch validator must reject EVERY malformed element as a terminal
 * `invalid-argument`, before anything dereferences it. A `null` element used
 * to slip past validation-error COLLECTION into `notifications.map((n) =>
 * n.targetUserId)`, throwing a raw TypeError → `internal` → client retry loop.
 */
const batchValidationCases: {
  name: string;
  notifications: unknown[];
  expectErrorCode: string | null;
}[] = [
  {
    name: "a valid batch passes",
    notifications: makeNotifications(3),
    expectErrorCode: null,
  },
  {
    name: "a null element is invalid-argument, never internal",
    notifications: [null],
    expectErrorCode: "invalid-argument",
  },
  {
    name: "a primitive element is invalid-argument",
    notifications: [42, "nope"],
    expectErrorCode: "invalid-argument",
  },
  {
    name: "one bad element poisons an otherwise valid batch",
    notifications: [...makeNotifications(2), undefined],
    expectErrorCode: "invalid-argument",
  },
  {
    name: "a missing targetUserId is invalid-argument",
    notifications: [{ title: "Hej", body: "Meddelande" }],
    expectErrorCode: "invalid-argument",
  },
];

function runBatchValidationTests(): number {
  let failed = 0;

  for (const c of batchValidationCases) {
    let thrownCode: string | null = null;
    try {
      assertBatchValid(c.notifications);
    } catch (err) {
      thrownCode = (err as { code?: string }).code ?? String(err);
    }

    if (thrownCode !== c.expectErrorCode) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(
        `        error=${thrownCode ?? "none"}/expected=${c.expectErrorCode ?? "none"}`
      );
    } else {
      console.log(`  PASS  ${c.name}`);
    }
  }

  return failed;
}

async function runTests(): Promise<void> {
  console.log("Sprint C3: sendNotification callable preference-aware tests\n");
  console.log("==========================================================\n");

  let failed = 0;
  failed += await runScenarioTests();
  failed += await runUnknownCategoryFallback();
  failed += await runPreflightTests();
  failed += await runDefaultEnforcerAuditTest();
  failed += runBatchValidationTests();

  const total =
    scenarios.length +
    1 +
    preflightCases.length +
    1 +
    batchValidationCases.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error(err);
  process.exit(1);
});
