/**
 * BUT-449: validateAndScrubWebError — server-side defence-in-depth
 * for the web error reporter.
 *
 * The pure validator is testable without spinning up the callable
 * runtime. This file exercises the documented contract:
 *
 *   - missing/empty message → invalid
 *   - non-web platform → invalid (future safety; today only "web"
 *     is allowed by the pipeline)
 *   - PII-heavy message → skipped (don't pollute Cloud Logging)
 *   - happy path → log payload assembled with scrubbed fields
 *
 * Run with: npx ts-node src/__tests__/log-web-error.test.ts
 */

import {
  validateAndScrubWebError,
  WebErrorValidation,
} from "../events/log-web-error";

interface AssertionResult {
  ok: boolean;
  detail?: string;
}

let totalFailed = 0;
let totalRun = 0;

function record(name: string, a: AssertionResult): void {
  totalRun++;
  if (a.ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (a.detail) console.log(`        ${a.detail}`);
  }
}

function expectKind(
  result: WebErrorValidation,
  kind: WebErrorValidation["kind"]
): AssertionResult {
  return result.kind === kind
    ? { ok: true }
    : { ok: false, detail: `expected ${kind}, got ${result.kind}` };
}

async function run(): Promise<void> {
  console.log("BUT-449: validateAndScrubWebError tests");
  console.log("=======================================");

  // Empty/missing message rejected
  record(
    "missing message → invalid(message)",
    (() => {
      const r = validateAndScrubWebError({});
      return r.kind === "invalid" && r.reason === "message"
        ? { ok: true }
        : { ok: false, detail: JSON.stringify(r) };
    })()
  );

  record(
    "non-string message → invalid(message)",
    (() => {
      const r = validateAndScrubWebError(
        { message: 123 } as unknown as Parameters<typeof validateAndScrubWebError>[0]
      );
      return r.kind === "invalid" && r.reason === "message"
        ? { ok: true }
        : { ok: false, detail: JSON.stringify(r) };
    })()
  );

  // Disallowed platform rejected
  record(
    "platform=android rejected (web-only contract)",
    (() => {
      const r = validateAndScrubWebError({
        message: "boom",
        platform: "android",
      });
      return r.kind === "invalid" && r.reason === "platform"
        ? { ok: true }
        : { ok: false, detail: JSON.stringify(r) };
    })()
  );

  // Default platform=web when omitted
  record(
    "platform omitted → defaults to web (proceeds)",
    (() => {
      const r = validateAndScrubWebError({ message: "boom" });
      return expectKind(r, "log");
    })()
  );

  // PII scrubbing works on message
  record(
    "email in message scrubbed via [EMAIL] token",
    (() => {
      const r = validateAndScrubWebError({
        message: "Failed: user alice@example.com hit 500",
      });
      if (r.kind !== "log") {
        return { ok: false, detail: `expected log, got ${r.kind}` };
      }
      const ok =
        r.payload.message.includes("[EMAIL]") &&
        !r.payload.message.includes("alice@example.com");
      return ok
        ? { ok: true }
        : { ok: false, detail: `payload.message="${r.payload.message}"` };
    })()
  );

  // PII scrubbing works on stack
  record(
    "personnummer in stack scrubbed via [PERSONNUMMER] token",
    (() => {
      const r = validateAndScrubWebError({
        message: "exception thrown",
        stack:
          "Error: at Object.lookup (file:line)\n  payload: 19900101-1234",
      });
      if (r.kind !== "log") {
        return { ok: false, detail: `expected log, got ${r.kind}` };
      }
      const ok =
        r.payload.stack !== null &&
        r.payload.stack.includes("[PERSONNUMMER]") &&
        !r.payload.stack.includes("19900101-1234");
      return ok
        ? { ok: true }
        : { ok: false, detail: `payload.stack="${r.payload.stack}"` };
    })()
  );

  // PII-heavy message dropped (>50% redacted)
  record(
    "PII-heavy message → skip(pii_heavy)",
    (() => {
      // Tiny carrier text, large embedded email — redaction ratio > 50%.
      const r = validateAndScrubWebError({
        message: "x: an.extremely.long.email.address@example.com",
      });
      return r.kind === "skip" && r.reason === "pii_heavy"
        ? { ok: true }
        : { ok: false, detail: JSON.stringify(r) };
    })()
  );

  // Truncation: oversized message clamped
  record(
    "oversized message truncated to 2000 chars",
    (() => {
      const big = "A".repeat(5000);
      const r = validateAndScrubWebError({ message: big });
      if (r.kind !== "log") {
        return { ok: false, detail: `expected log, got ${r.kind}` };
      }
      return r.payload.message.length === 2000
        ? { ok: true }
        : {
            ok: false,
            detail: `len=${r.payload.message.length}`,
          };
    })()
  );

  // Truncation: oversized stack clamped
  record(
    "oversized stack truncated to 8000 chars",
    (() => {
      const stack = "S".repeat(20000);
      const r = validateAndScrubWebError({
        message: "short",
        stack,
      });
      if (r.kind !== "log") {
        return { ok: false, detail: `expected log, got ${r.kind}` };
      }
      return r.payload.stack !== null && r.payload.stack.length === 8000
        ? { ok: true }
        : {
            ok: false,
            detail: `stackLen=${r.payload.stack?.length}`,
          };
    })()
  );

  // fatal flag round-trips
  record(
    "fatal=true preserved on payload",
    (() => {
      const r = validateAndScrubWebError({ message: "boom", fatal: true });
      return r.kind === "log" && r.payload.fatal === true
        ? { ok: true }
        : { ok: false, detail: JSON.stringify(r) };
    })()
  );

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
