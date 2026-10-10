/**
 * BUT-417 / BUT-548: Firestore rules tests for the moderation pipeline.
 *
 * Each test name states the behavior it proves. If a test fails, either
 * the rules changed or the product contract changed — decide which before
 * editing the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/reports-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const ADMIN_UID = "admin-uid";
const USER_A_UID = "user-a";
const USER_B_UID = "user-b";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Suites share one long-lived emulator; leftovers from an earlier run
  // turn a create-only write into a denied update.
  await env.clearFirestore();

  // Seed the admin doc with the security-rules-bypassing context.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({
      addedAt: new Date(),
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

// Test 1: non-admin update to reports.*.status -> permission-denied.
test(
  "non-admin cannot update a report's status",
  async () => {
    const reportId = "r1";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`reports/${reportId}`).set({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c1",
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      });
    });
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      userCtx.firestore().doc(`reports/${reportId}`).update({
        status: "in_review",
      })
    );
  }
);

// Test 2: admin update new -> in_review is allowed.
test(
  "admin can advance a report from new to in_review",
  async () => {
    const reportId = "r2";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`reports/${reportId}`).set({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c2",
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      });
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx.firestore().doc(`reports/${reportId}`).update({
        status: "in_review",
      })
    );
  }
);

// Test 3: admin can delete a reported comment; non-admin cannot delete someone else's comment.
test(
  "admin deletes a reported comment; non-admin cannot delete another user's comment",
  async () => {
    const commentId = "comment-authored-by-A";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`recipe_comments/${commentId}`).set({
        authorId: USER_A_UID,
        recipeId: "recipe-x",
        text: "hello",
        createdAt: new Date(),
      });
    });
    // User B (non-admin, non-author) cannot delete.
    const userBCtx = env.authenticatedContext(USER_B_UID);
    await assertFails(
      userBCtx.firestore().doc(`recipe_comments/${commentId}`).delete()
    );
    // Admin can delete.
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx.firestore().doc(`recipe_comments/${commentId}`).delete()
    );
  }
);

// Test 4: forward-only state machine — admin cannot move closed -> new.
test(
  "admin cannot move a closed report back to new (forward-only)",
  async () => {
    const reportId = "r3";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`reports/${reportId}`).set({
        reporterId: USER_A_UID,
        contentType: "message",
        contentId: "m1",
        reason: "harassment",
        status: "closed",
        createdAt: new Date(),
      });
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertFails(
      adminCtx.firestore().doc(`reports/${reportId}`).update({
        status: "new",
      })
    );
  }
);

// Test 5: admins collection is rules-locked — no client write, even by admin.
test(
  "admins collection is rules-locked — no client can write",
  async () => {
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertFails(
      adminCtx.firestore().doc("admins/new-admin").set({ addedAt: new Date() })
    );
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      userCtx.firestore().doc("admins/self-promote").set({ addedAt: new Date() })
    );
  }
);

// ----- BUT-781: brigade rate-limit + reason enum + self-report block -----

// Test 6: BUT-781 — invalid `reason` is rejected at create time. Without the
// enum constraint, typo values pollute analytics and the admin dispatcher
// can't trust the field.
test(
  "BUT-781: report with non-enum reason is rejected",
  async () => {
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      userCtx.firestore().collection("reports").add({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c-bad-reason",
        contentOwnerId: USER_B_UID,
        reason: "smap",  // typo — not in enum
        status: "new",
        createdAt: new Date(),
      })
    );
  }
);

// Test 7: BUT-781 — self-report blocked. A user crafting a report against
// themselves (contentOwnerId == reporter) is denied so attackers can't
// manufacture a paper trail of "complaints" against their own target.
test(
  "BUT-781: self-report (contentOwnerId == reporter) is rejected",
  async () => {
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      userCtx.firestore().collection("reports").add({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c-self",
        contentOwnerId: USER_A_UID,  // self
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      })
    );
  }
);

// Test 8: BUT-781 — missing contentOwnerId rejected. The cascade in
// on-user-deleted.ts can't anonymize a report it can't query for, so the
// rule requires the field at create time (reverses the previously-nullable
// schema position).
test(
  "BUT-781: report without contentOwnerId is rejected",
  async () => {
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      userCtx.firestore().collection("reports").add({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c-missing-owner",
        // contentOwnerId omitted
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      })
    );
  }
);

// Test 9: BUT-781 — valid first report (no throttle yet) is accepted.
// Pins the create path: with all four new constraints satisfied, the rule
// must still allow legitimate reports through.
test(
  "BUT-781: valid report with no throttle is accepted",
  async () => {
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertSucceeds(
      userCtx.firestore().collection("reports").add({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c-first-valid",
        contentOwnerId: USER_B_UID,
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      })
    );
  }
);

// Test 10: BUT-781 — brigade rate-limit. After a fresh throttle sentinel is
// in place, a second report against the same target inside 24h is rejected.
// This is the core of CRIT-TS1: an attacker can no longer file arbitrary-
// many reports to amplify a complaint against one target.
test(
  "BUT-781: report rejected when fresh throttle exists (rate limit)",
  async () => {
    // Seed a fresh throttle sentinel via admin context.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`users/${USER_A_UID}/report_throttle/${USER_B_UID}`)
        .set({ lastReportAt: new Date() });
    });
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      userCtx.firestore().collection("reports").add({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c-second-blocked",
        contentOwnerId: USER_B_UID,
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      })
    );
  }
);

// Test 11: BUT-781 — stale (>24h) throttle does NOT block a new report.
// Without this carve-out the rate limit would be a permanent ban after the
// first report.
test(
  "BUT-781: report accepted when throttle is older than 24h",
  async () => {
    const stale = new Date(Date.now() - 25 * 60 * 60 * 1000); // 25h ago
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`users/${USER_A_UID}/report_throttle/${USER_B_UID}`)
        .set({ lastReportAt: stale });
    });
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertSucceeds(
      userCtx.firestore().collection("reports").add({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c-stale-throttle",
        contentOwnerId: USER_B_UID,
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      })
    );
  }
);

// Test 13 (gap fill): admin can delete a report; non-admin cannot.
// Pins the `allow delete: if isAdmin()` clause — without coverage, a regression
// that broadened delete to reporters or removed the gate altogether would slip
// through CI silently.
test(
  "BUT-781 (gap): admin deletes a report; non-admin denied",
  async () => {
    const reportId = "r-delete-test";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`reports/${reportId}`).set({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c1",
        contentOwnerId: USER_B_UID,
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      });
    });
    const reporterCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      reporterCtx.firestore().doc(`reports/${reportId}`).delete()
    );
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx.firestore().doc(`reports/${reportId}`).delete()
    );
  }
);

// Test 14 (gap fill): admin update cannot mutate immutable identity fields.
// Pins `cannotModify(['reporterId','contentType','contentId','createdAt'])`.
// A regression here would let an admin (or a future role expansion) rewrite
// who reported what — destroying the audit trail.
test(
  "BUT-781 (gap): admin update cannot rewrite immutable identity fields",
  async () => {
    const reportId = "r-immutable-test";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`reports/${reportId}`).set({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c-orig",
        contentOwnerId: USER_B_UID,
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      });
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    // Forward state-machine transition is allowed (covered by Test 2),
    // so test the mutation-of-immutable-field deny path explicitly.
    await assertFails(
      adminCtx.firestore().doc(`reports/${reportId}`).update({
        status: "in_review",
        reporterId: USER_B_UID, // immutable — must be rejected
      })
    );
  }
);

// Test 12: BUT-781 — report_throttle subcollection allows owner writes
// with serverTimestamp; foreign UID writes are denied. This pins the
// throttle-doc rules so a future change can't accidentally make the
// throttle world-writable (which would let an attacker pre-seed throttles
// against another reporter to silence them).
test(
  "BUT-781: report_throttle accepts owner write, denies foreign write",
  async () => {
    const ownerCtx = env.authenticatedContext(USER_A_UID);
    await assertSucceeds(
      ownerCtx
        .firestore()
        .doc(`users/${USER_A_UID}/report_throttle/${USER_B_UID}`)
        .set({ lastReportAt: serverTimestamp() })
    );
    // Foreign UID cannot seed a throttle under another user's account.
    const foreignCtx = env.authenticatedContext(USER_B_UID);
    await assertFails(
      foreignCtx
        .firestore()
        .doc(`users/${USER_A_UID}/report_throttle/${USER_B_UID}`)
        .set({ lastReportAt: serverTimestamp() })
    );
    // Self-throttle (ownerId == reporter) is rejected — keeps the
    // collection clean (no orphan self-throttles).
    await assertFails(
      ownerCtx
        .firestore()
        .doc(`users/${USER_A_UID}/report_throttle/${USER_A_UID}`)
        .set({ lastReportAt: serverTimestamp() })
    );
  }
);

// BUT-1842: the text copy of reported content is the moderator's alone.
async function seedEvidence(id: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`report_evidence/${id}`).set({
      reportId: id,
      contentType: "message",
      contentId: "m1",
      contentOwnerId: USER_B_UID,
      outcome: "captured",
      text: { content: "hej" },
    });
  });
}

test("an admin can read a report's text copy", async () => {
  await seedEvidence("ev-admin");
  await assertSucceeds(
    env.authenticatedContext(ADMIN_UID).firestore().doc("report_evidence/ev-admin").get(),
  );
});

test("neither the reported person nor anyone else can read a text copy", async () => {
  await seedEvidence("ev-read");
  for (const uid of [USER_A_UID, USER_B_UID]) {
    await assertFails(
      env.authenticatedContext(uid).firestore().doc("report_evidence/ev-read").get(),
    );
  }
  await assertFails(env.unauthenticatedContext().firestore().doc("report_evidence/ev-read").get());
});

test("no client writes a text copy, an admin included", async () => {
  await seedEvidence("ev-write");
  for (const uid of [ADMIN_UID, USER_A_UID]) {
    const db = env.authenticatedContext(uid).firestore();
    await assertFails(db.doc(`report_evidence/new-${uid}`).set({ outcome: "captured" }));
    await assertFails(db.doc("report_evidence/ev-write").update({ outcome: "missing" }));
    await assertFails(db.doc("report_evidence/ev-write").delete());
  }
});

// ----- BUT-2154: the app's reason ids, and a retry under the same id -----

// The ids `ReportReason.offered` sends (lib/models/social/report_reason.dart).
// Before BUT-2154 the dialog sent its Swedish label, which this rule refused
// for every reason, so no report from the app could be filed.
const APP_REASON_IDS = ["abuse", "spam", "harassment", "copyright", "other"];

// Same two writes in one batch as FirebaseReportRepository.submitReport.
function appReportBatch(
  db: ReturnType<ReturnType<RulesTestEnvironment["authenticatedContext"]>["firestore"]>,
  reportId: string,
  ownerId: string,
  reason: string
) {
  const batch = db.batch();
  batch.set(db.doc(`reports/${reportId}`), {
    reporterId: USER_A_UID,
    contentType: "recipe",
    contentId: `c-${reportId}`,
    contentOwnerId: ownerId,
    reason,
    description: null,
    status: "new",
    createdAt: new Date(),
    guidelineVersion: "2026-02-28",
  });
  batch.set(db.doc(`users/${USER_A_UID}/report_throttle/${ownerId}`), {
    lastReportAt: serverTimestamp(),
  });
  return batch;
}

test(
  "BUT-2154: every reason id the app offers is accepted in the app's batch",
  async () => {
    const db = env.authenticatedContext(USER_A_UID).firestore();
    for (const reason of APP_REASON_IDS) {
      await assertSucceeds(
        appReportBatch(db, `r2154-${reason}`, `owner-2154-${reason}`, reason).commit()
      );
    }
  }
);

test(
  "BUT-2154: a visible Swedish label as reason is refused",
  async () => {
    const db = env.authenticatedContext(USER_A_UID).firestore();
    await assertFails(
      appReportBatch(db, "r2154-label", "owner-2154-label", "Olämpligt innehåll").commit()
    );
  }
);

// The repository's read-back after a refused retry depends on both halves:
// the retry under the same id is refused, and the reporter can read the
// report the first attempt filed.
test(
  "BUT-2154: a retry under the same id is refused and the first report is readable",
  async () => {
    const db = env.authenticatedContext(USER_A_UID).firestore();
    await assertSucceeds(
      appReportBatch(db, "r2154-retry", "owner-2154-retry", "spam").commit()
    );
    await assertFails(
      appReportBatch(db, "r2154-retry", "owner-2154-retry", "spam").commit()
    );
    await assertSucceeds(db.doc("reports/r2154-retry").get());
  }
);

// A report names who reported whom; only the reporter and admins may read it.
// The retry test above reads the reporter's own report, so this is the deny
// side of the same read rule.
test(
  "BUT-2154: another user cannot read someone else's report",
  async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("reports/r2154-private").set({
        reporterId: USER_A_UID,
        contentType: "recipe",
        contentId: "c-private",
        contentOwnerId: "owner-2154-private",
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      });
    });
    await assertFails(
      env.authenticatedContext(USER_B_UID).firestore().doc("reports/r2154-private").get()
    );
    await assertSucceeds(
      env.authenticatedContext(USER_A_UID).firestore().doc("reports/r2154-private").get()
    );
  }
);

// ----- BUT-2339: a dish in a shared menu -----

type ClientDb = ReturnType<ReturnType<RulesTestEnvironment["authenticatedContext"]>["firestore"]>;

function dishReport(
  db: ClientDb,
  reportId: string,
  fields: Record<string, unknown>,
  throttleOwner: string | null = null,
) {
  const batch = db.batch();
  batch.set(db.doc(`reports/${reportId}`), {
    reporterId: USER_A_UID,
    contentType: "menu_dish",
    contentId: `menu-${reportId}`,
    contentOwnerId: `sharer-${reportId}`,
    dishId: "dish_1-A",
    reason: "misattribution",
    description: null,
    status: "new",
    createdAt: new Date(),
    guidelineVersion: "2026-10-10",
    ...fields,
  });
  if (throttleOwner) {
    batch.set(db.doc(`users/${USER_A_UID}/report_throttle/${throttleOwner}`), {
      lastReportAt: serverTimestamp(),
    });
  }
  return batch;
}

function plainReport(db: ClientDb, reportId: string, fields: Record<string, unknown>) {
  const batch = db.batch();
  batch.set(db.doc(`reports/${reportId}`), {
    reporterId: USER_A_UID,
    contentOwnerId: `owner-${reportId}`,
    contentId: `c-${reportId}`,
    status: "new",
    createdAt: new Date(),
    ...fields,
  });
  return batch;
}

test("BUT-2339: a misattribution report on a dish is accepted without the throttle", async () => {
  const db = env.authenticatedContext(USER_A_UID).firestore();
  await assertSucceeds(dishReport(db, "d-ok", {}).commit());
});

test("BUT-2339: an ordinary report on a dish is accepted in the app's batch", async () => {
  const db = env.authenticatedContext(USER_A_UID).firestore();
  await assertSucceeds(dishReport(db, "d-abuse", { reason: "abuse" }, "sharer-d-abuse").commit());
});

test("BUT-2339: a dish report without dishId is refused", async () => {
  const db = env.authenticatedContext(USER_A_UID).firestore();
  await assertFails(
    plainReport(db, "d-nodish", { contentType: "menu_dish", reason: "misattribution" }).commit()
  );
});

test("BUT-2339: dishId is refused on any other type", async () => {
  const db = env.authenticatedContext(USER_A_UID).firestore();
  await assertFails(dishReport(db, "d-onrecipe", { contentType: "recipe", reason: "abuse" }).commit());
  await assertFails(dishReport(db, "d-oncomment", { contentType: "comment", reason: "spam" }).commit());
});

test("BUT-2339: a dishId that is not a plain key is refused", async () => {
  const db = env.authenticatedContext(USER_A_UID).firestore();
  const bad: unknown[] = ["", "a/b", "a.b", "x".repeat(129), 7, null];
  for (const [i, dishId] of bad.entries()) {
    await assertFails(dishReport(db, `d-bad-${i}`, { dishId }).commit());
  }
  await assertSucceeds(dishReport(db, "d-max", { dishId: "x".repeat(128) }).commit());
});

test("BUT-2339: misattribution is refused on any other type", async () => {
  const db = env.authenticatedContext(USER_A_UID).firestore();
  await assertFails(
    plainReport(db, "d-mis-recipe", { contentType: "recipe", reason: "misattribution" }).commit()
  );
  await assertSucceeds(
    plainReport(db, "d-spam-recipe", { contentType: "recipe", reason: "spam" }).commit()
  );
});

test("BUT-2339: an unknown content type is refused", async () => {
  const db = env.authenticatedContext(USER_A_UID).firestore();
  await assertFails(plainReport(db, "d-rating", { contentType: "rating", reason: "spam" }).commit());
});

test("BUT-2339: a fresh throttle stops an ordinary report but not a misattribution", async () => {
  const owner = "sharer-throttled";
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`users/${USER_A_UID}/report_throttle/${owner}`).set({
      lastReportAt: new Date(),
    });
  });
  const db = env.authenticatedContext(USER_A_UID).firestore();
  await assertFails(
    dishReport(db, "d-thr-abuse", { reason: "abuse", contentOwnerId: owner }).commit()
  );
  await assertSucceeds(dishReport(db, "d-thr-mis", { contentOwnerId: owner }).commit());
});

test("BUT-2339: an admin cannot repoint a report's dish", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("reports/d-admin").set({
      reporterId: USER_A_UID,
      contentType: "menu_dish",
      contentId: "menu-a",
      contentOwnerId: "sharer-a",
      dishId: "dish1",
      reason: "misattribution",
      status: "new",
      createdAt: new Date(),
    });
  });
  const adminDb = env.authenticatedContext(ADMIN_UID).firestore();
  await assertFails(adminDb.doc("reports/d-admin").update({ dishId: "dish2" }));
  await assertSucceeds(adminDb.doc("reports/d-admin").update({ status: "in_review" }));
});

test("BUT-2339: an admin may read a menu and change its menuSnapshot and nothing else", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const base = { sharedByUserId: USER_B_UID, sharedAt: new Date(), sharedToUserIds: [] };
    await ctx.firestore().doc("shared_content/menu-admin").set({
      ...base,
      contentType: "menu",
      title: "Veckan",
      menuSnapshot: { Middag: [{ id: "dish1", title: "Gryta" }] },
    });
    await ctx.firestore().doc("shared_content/list-admin").set({
      ...base,
      contentType: "shopping_list",
      title: "Handla",
      menuSnapshot: {},
    });
  });
  const adminDb = env.authenticatedContext(ADMIN_UID).firestore();
  const menu = adminDb.doc("shared_content/menu-admin");
  // The shape ReportService sends: read the menu, then write the snapshot.
  await assertSucceeds(adminDb.runTransaction(async (tx) => {
    await tx.get(menu);
    tx.update(menu, { menuSnapshot: { Middag: [] } });
  }));
  await assertFails(menu.update({ title: "Annat" }));

  const list = adminDb.doc("shared_content/list-admin");
  await assertFails(list.get());
  await assertFails(list.update({ menuSnapshot: { Middag: [] } }));

  const stranger = env.authenticatedContext(USER_A_UID).firestore();
  await assertFails(stranger.doc("shared_content/menu-admin").get());
  await assertFails(stranger.doc("shared_content/menu-admin").update({ menuSnapshot: {} }));
});

async function run(): Promise<void> {
  console.log("BUT-417/548: moderation rules tests\n");
  console.log("===================================\n");
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
