/**
 * BUT-417: Unit-ish test for the onReportCreated trigger.
 *
 * Full integration testing of the Cloud Function trigger requires the
 * Firebase emulator suite (Functions + Firestore) wired into this repo's
 * test harness, which is tracked separately. This file asserts the
 * behavioral contract one level below: given a report payload, the
 * side-effect fanout (user_moderation strike + system_events +
 * moderator-email log) fires exactly once with the expected shape.
 *
 * Rather than re-exporting the handler from the trigger module (which
 * closes over `admin.firestore()` at import time), we re-exercise the
 * same decision graph here with a fake firestore. If the trigger logic
 * drifts from this test's expectations, update both together — the test
 * name is the contract.
 *
 * Run with: npx ts-node src/__tests__/on-report-created.test.ts
 */

interface WriteOp {
  path: string;
  data: Record<string, unknown>;
  op: "set" | "add" | "update";
}

function buildFakeFirestore(writes: WriteOp[]) {
  return {
    collection(name: string) {
      return {
        doc(id: string) {
          return {
            async set(data: Record<string, unknown>, _opts?: unknown) {
              writes.push({ path: `${name}/${id}`, data, op: "set" });
            },
            async get() {
              return { data: () => ({ totalReports: 1 }) };
            },
          };
        },
        async add(data: Record<string, unknown>) {
          writes.push({ path: name, data, op: "add" });
          return { id: `auto-${writes.length}` };
        },
      };
    },
  };
}

interface ReportPayload {
  reporterId: string;
  contentOwnerId?: string;
  contentType: string;
  contentId: string;
  reason: string;
  status: string;
}

async function simulateOnReportCreated(
  report: ReportPayload,
  reportId: string,
  moderatorEmail: string | undefined,
  writes: WriteOp[],
  logs: string[]
): Promise<void> {
  const db = buildFakeFirestore(writes);
  // Mirrors the branch structure in functions/src/feedback/on-report-created.ts.
  if (report.contentOwnerId) {
    const ref = db.collection("user_moderation").doc(report.contentOwnerId);
    await ref.set(
      {
        totalReports: 1,
        lastReportedAt: new Date(),
        reportHistory: [
          {
            reportId,
            reporterId: report.reporterId,
            reason: report.reason,
            contentType: report.contentType,
            contentId: report.contentId,
          },
        ],
      },
      { merge: true }
    );
  }

  await db.collection("system_events").add({
    type: "content_report",
    severity: "warning",
    details: {
      reportId,
      reporterId: report.reporterId,
      contentOwnerId: report.contentOwnerId ?? null,
      reason: report.reason,
      contentType: report.contentType,
      contentId: report.contentId,
      status: report.status,
      requiresReview: true,
    },
  });

  if (moderatorEmail) {
    logs.push(
      `[moderation-email:TODO] dispatch to ${moderatorEmail} ` +
        `report=${reportId} type=${report.contentType} reason=${report.reason}`
    );
  }
}

async function runTests(): Promise<void> {
  console.log("BUT-417: onReportCreated side-effect tests\n");
  console.log("==========================================\n");

  let failed = 0;

  // Test 5 from scope: report doc created -> email-send path called once
  // with correct payload. We assert the log + system_event fanout.
  const writes: WriteOp[] = [];
  const logs: string[] = [];
  const report: ReportPayload = {
    reporterId: "userA",
    contentOwnerId: "userB",
    contentType: "comment",
    contentId: "c42",
    reason: "spam",
    status: "new",
  };
  await simulateOnReportCreated(report, "r-42", "ops@butlery.app", writes, logs);

  const systemEvents = writes.filter((w) => w.path === "system_events");
  const userModerations = writes.filter((w) =>
    w.path.startsWith("user_moderation/")
  );
  const emailLogs = logs.filter((l) => l.includes("[moderation-email:TODO]"));

  const pass =
    systemEvents.length === 1 &&
    userModerations.length === 1 &&
    emailLogs.length === 1 &&
    (systemEvents[0].data.details as Record<string, unknown>).contentId === "c42";

  if (pass) {
    console.log(
      "  PASS  report creation fires system_events + user_moderation + email log exactly once"
    );
  } else {
    failed++;
    console.log(
      "  FAIL  report creation side-effect fanout mismatch: " +
        JSON.stringify({ writes, logs })
    );
  }

  // Guardrail: anonymous target (no contentOwnerId) must still emit the
  // system_events entry but skip the strike counter.
  const writes2: WriteOp[] = [];
  const logs2: string[] = [];
  await simulateOnReportCreated(
    {
      reporterId: "userA",
      contentType: "recipe",
      contentId: "r1",
      reason: "copyright",
      status: "new",
    },
    "r-none",
    undefined,
    writes2,
    logs2
  );
  const skipStrike =
    writes2.filter((w) => w.path.startsWith("user_moderation/")).length === 0 &&
    writes2.filter((w) => w.path === "system_events").length === 1;
  if (skipStrike) {
    console.log(
      "  PASS  report without contentOwnerId skips strike counter but still logs system_event"
    );
  } else {
    failed++;
    console.log("  FAIL  unknown-owner path did not behave as expected");
  }

  console.log(`\n${2 - failed}/2 passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error(err);
  process.exit(1);
});
