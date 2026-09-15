/**
 * BUT-1406: unit tests for `recordEmailFailure` — the durable signal written
 * when a feedback-notification email fails to deliver.
 *
 * No emulator needed: the function takes an injected Firestore (DI seam), so we
 * pass a tiny fake that captures `collection().doc().set()` calls.
 *
 * Run: npx ts-node src/__tests__/feedback-email-failure.test.ts
 */

import * as admin from "firebase-admin";
import { readFileSync } from "fs";
import { join } from "path";
import {
  buildFeedbackEmail,
  recordEmailFailure,
} from "../feedback/on-feedback-created";

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

interface CapturedWrite {
  path: string;
  data: Record<string, unknown>;
  merge: boolean;
}

function fakeDb(onSet?: () => void): {
  db: admin.firestore.Firestore;
  writes: CapturedWrite[];
} {
  const writes: CapturedWrite[] = [];
  const db = {
    collection: (c: string) => ({
      doc: (d: string) => ({
        set: async (data: Record<string, unknown>, opts?: { merge?: boolean }) => {
          if (onSet) onSet();
          writes.push({ path: `${c}/${d}`, data, merge: opts?.merge ?? false });
        },
      }),
    }),
  } as unknown as admin.firestore.Firestore;
  return { db, writes };
}

async function run_(): Promise<void> {
  console.log("BUT-1406: recordEmailFailure tests\n");
  console.log("=====================================================\n");

  // ── A failed send writes a deterministic, idempotent system_events row ──
  {
    const { db, writes } = fakeDb();
    await recordEmailFailure("fb123", "Resend 500 boom", db);

    check(
      "writes exactly one system_events doc",
      writes.length === 1,
      JSON.stringify(writes),
    );
    check(
      "deterministic doc id system_events/feedback_email_failed_{id}",
      writes[0]?.path === "system_events/feedback_email_failed_fb123",
      writes[0]?.path,
    );
    check(
      "payload: type=feedback_email_failed, severity=warning, feedbackId+reason",
      writes[0]?.data.type === "feedback_email_failed" &&
        writes[0]?.data.severity === "warning" &&
        writes[0]?.data.feedbackId === "fb123" &&
        writes[0]?.data.reason === "Resend 500 boom",
      JSON.stringify(writes[0]?.data),
    );
    check(
      "uses set(merge) so a trigger retry is idempotent",
      writes[0]?.merge === true,
    );
  }

  // ── The durable-write is itself failure-safe (never throws out of the
  //    background trigger) ──
  {
    const { db } = fakeDb(() => {
      throw new Error("firestore unavailable");
    });
    let threw = false;
    try {
      await recordEmailFailure("fb-err", "network down", db);
    } catch {
      threw = true;
    }
    check("recordEmailFailure never throws even if the write fails", !threw);
  }

  // ── The triage email carries no personal data ──
  {
    const { subject, html } = buildFeedbackEmail(
      "fb-pii",
      {
        category: "bug",
        description: "Min telefon 070-1234567 kraschar",
        email: "person@example.com",
        deviceInfo: "Pixel 8, Android 15",
        screenshotUrl: "https://storage.example/shot.png",
        userId: "uid-abc",
      },
      "https://admin.example/feedback",
    );
    const body = subject + html;
    for (const [label, value] of [
      ["description", "070-1234567"],
      ["email", "person@example.com"],
      ["deviceInfo", "Pixel 8"],
      ["screenshotUrl", "shot.png"],
      ["userId", "uid-abc"],
    ]) {
      check(`email omits ${label}`, !body.includes(value), body);
    }
    check(
      "email keeps category, dashboard link and id",
      html.includes("bug") &&
        html.includes("https://admin.example/feedback") &&
        html.includes("fb-pii"),
      html,
    );
    // notifyByEmail is not exported, so its wiring is pinned in the source: the
    // html it sends must come from buildFeedbackEmail, not from inline fields.
    const source = readFileSync(
      join(__dirname, "../feedback/on-feedback-created.ts"),
      "utf8",
    );
    const sender = source.slice(source.indexOf("async function notifyByEmail"));
    check(
      "notifyByEmail builds its email only through buildFeedbackEmail",
      sender.includes("buildFeedbackEmail(") &&
        !/data\.(description|email|deviceInfo|screenshotUrl|userId)/.test(sender),
    );
    const hostile = buildFeedbackEmail("fb-x", { category: "<b>x</b>" }, undefined);
    check(
      "category is HTML-escaped",
      !hostile.html.includes("<b>") && hostile.html.includes("&lt;b&gt;"),
      hostile.html,
    );
  }

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
