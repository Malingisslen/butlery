/**
 * BUT-425: OCR URL validation tests.
 *
 * The OCR callable previously forwarded any user-supplied URL straight into
 * Gemini's `fileData.fileUri`. This let attackers turn the function into an
 * SSRF/exfiltration relay. The validator (in `shared/ocr-url-validator.ts`)
 * pins the host to *this* project's Firebase Storage bucket and runs a HEAD
 * pre-flight to verify content-type + content-length.
 *
 * This file exercises both the validator directly and its integration into
 * `runOcrRecipeImage` via the `validateImageUrl` test seam.
 *
 * Run with: npx ts-node src/__tests__/ocr-validation.test.ts
 */

import {
  validateOcrImageUrl,
  isAllowedOcrHost,
  MAX_OCR_IMAGE_BYTES,
  OcrUrlValidationResult,
} from "../shared/ocr-url-validator";
import { runOcrRecipeImage } from "../llm/ocr-recipe-image";
import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";

// =============================================================================
// Reporting harness — matches the style used by ocr-retry.test.ts
// =============================================================================

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

// =============================================================================
// Logger capture
// =============================================================================
//
// The validator emits an INFO `[ocrUrlValidator] accepted` log on success and
// a WARN log on rejection. We hijack the `firebase-functions/logger` module
// surface so tests can assert structured fields without touching Cloud
// Logging.

interface CapturedLog {
  level: "info" | "warn" | "error";
  message: string;
  meta?: Record<string, unknown>;
}

const captured: CapturedLog[] = [];

const originalInfo = logger.info;
const originalWarn = logger.warn;
const originalError = logger.error;

(logger as unknown as { info: (...args: unknown[]) => void }).info = (
  ...args: unknown[]
) => {
  captured.push({
    level: "info",
    message: String(args[0] ?? ""),
    meta: (args[1] as Record<string, unknown>) ?? undefined,
  });
};
(logger as unknown as { warn: (...args: unknown[]) => void }).warn = (
  ...args: unknown[]
) => {
  captured.push({
    level: "warn",
    message: String(args[0] ?? ""),
    meta: (args[1] as Record<string, unknown>) ?? undefined,
  });
};
(logger as unknown as { error: (...args: unknown[]) => void }).error = (
  ...args: unknown[]
) => {
  captured.push({
    level: "error",
    message: String(args[0] ?? ""),
    meta: (args[1] as Record<string, unknown>) ?? undefined,
  });
};

function clearCaptured(): void {
  captured.length = 0;
}

function findLog(
  message: string,
  level?: "info" | "warn" | "error"
): CapturedLog | undefined {
  return captured.find(
    (l) =>
      l.message.includes(message) && (level === undefined || l.level === level)
  );
}

// =============================================================================
// Fake fetch helpers
// =============================================================================

interface FakeResponseInit {
  status?: number;
  contentType?: string | null;
  contentLength?: string | null;
}

function makeFakeResponse(init: FakeResponseInit = {}): Response {
  const status = init.status ?? 200;
  const headers = new Headers();
  if (init.contentType !== null && init.contentType !== undefined) {
    headers.set("content-type", init.contentType);
  }
  if (init.contentLength !== null && init.contentLength !== undefined) {
    headers.set("content-length", init.contentLength);
  }
  // Minimal Response-like object. Only the fields the validator reads are
  // populated; this avoids any runtime/Response polyfill churn.
  return {
    ok: status >= 200 && status < 300,
    status,
    headers,
  } as unknown as Response;
}

function fakeFetch(init: FakeResponseInit): typeof fetch {
  return (async () => makeFakeResponse(init)) as unknown as typeof fetch;
}

function throwingFetch(err: Error): typeof fetch {
  return (async () => {
    throw err;
  }) as unknown as typeof fetch;
}

const PROJECT_ID = process.env.GCLOUD_PROJECT
  || process.env.GOOGLE_CLOUD_PROJECT
  || "butlery-app-1";
const BUCKET_HOST = `${PROJECT_ID}.firebasestorage.app`;
const GOOD_URL =
  `https://firebasestorage.googleapis.com/v0/b/${BUCKET_HOST}` +
  `/o/users%2Fuser_abc%2Frecipes%2Fr1%2Fimage.jpg?alt=media&token=abc`;

// =============================================================================
// 1. isAllowedOcrHost — host allowlist unit
// =============================================================================

function testHostAllowlist(): void {
  console.log("\n[1] isAllowedOcrHost — host allowlist");

  // Accepted: googleapis with bucket pinned to project.
  record(
    "googleapis URL with project bucket → accepted",
    isAllowedOcrHost(GOOD_URL) ? { ok: true } : { ok: false }
  );

  // Accepted: direct bucket-host download URL.
  record(
    "direct bucket-host URL → accepted",
    isAllowedOcrHost(`https://${BUCKET_HOST}/some/path.jpg`)
      ? { ok: true }
      : { ok: false }
  );

  // Rejected: googleapis URL pointing at a DIFFERENT bucket.
  record(
    "googleapis URL with foreign bucket → rejected",
    !isAllowedOcrHost(
      "https://firebasestorage.googleapis.com/v0/b/attacker-app.firebasestorage.app/o/x.jpg"
    )
      ? { ok: true }
      : { ok: false }
  );

  // Rejected: random attacker host.
  record(
    "attacker.com → rejected",
    !isAllowedOcrHost("https://attacker.com/steal.jpg")
      ? { ok: true }
      : { ok: false }
  );

  // Rejected: HTTP (non-HTTPS).
  record(
    "http:// scheme → rejected (delegates to isAllowedUrl)",
    !isAllowedOcrHost(`http://${BUCKET_HOST}/x.jpg`)
      ? { ok: true }
      : { ok: false }
  );

  // Rejected: malformed.
  record(
    "malformed URL → rejected",
    !isAllowedOcrHost("not-a-url") ? { ok: true } : { ok: false }
  );
}

// =============================================================================
// 2. validateOcrImageUrl — happy path
// =============================================================================

async function testHappyPath(): Promise<void> {
  console.log("\n[2] validateOcrImageUrl — accepted URL emits audit log");

  clearCaptured();
  const result = await validateOcrImageUrl(GOOD_URL, "uid-hash-1", {
    fetchImpl: fakeFetch({
      contentType: "image/jpeg",
      contentLength: String(1 * 1024 * 1024), // 1 MB
    }),
  });

  const ok =
    result.ok === true &&
    (result as Extract<OcrUrlValidationResult, { ok: true }>).contentType ===
      "image/jpeg" &&
    (result as Extract<OcrUrlValidationResult, { ok: true }>).contentLength ===
      1 * 1024 * 1024;
  record(
    "accepted: 1 MB JPEG returns ok with parsed metadata",
    ok
      ? { ok: true }
      : { ok: false, detail: `result=${JSON.stringify(result)}` }
  );

  // Audit log assertion — the brief calls this out explicitly.
  const auditLog = findLog("[ocrUrlValidator] accepted", "info");
  const auditOk =
    !!auditLog &&
    auditLog.meta?.contentType === "image/jpeg" &&
    auditLog.meta?.contentLength === 1 * 1024 * 1024 &&
    typeof auditLog.meta?.origin === "string" &&
    String(auditLog.meta?.origin).includes("firebasestorage.googleapis.com") &&
    auditLog.meta?.authUidHash === "uid-hash-1";
  record(
    "audit log emitted with origin + size + content-type + uid hash",
    auditOk
      ? { ok: true }
      : {
          ok: false,
          detail: `log=${JSON.stringify(auditLog)}`,
        }
  );

  // Content-Type with charset parameter must still be accepted.
  clearCaptured();
  const withCharset = await validateOcrImageUrl(GOOD_URL, "uid-hash-1", {
    fetchImpl: fakeFetch({
      contentType: "image/png; charset=binary",
      contentLength: "2048",
    }),
  });
  record(
    "Content-Type with charset suffix → accepted (parameter stripped)",
    withCharset.ok
      ? { ok: true }
      : { ok: false, detail: JSON.stringify(withCharset) }
  );

  // PDF should be accepted.
  clearCaptured();
  const pdf = await validateOcrImageUrl(GOOD_URL, "uid-hash-1", {
    fetchImpl: fakeFetch({
      contentType: "application/pdf",
      contentLength: String(500 * 1024),
    }),
  });
  record(
    "application/pdf → accepted",
    pdf.ok ? { ok: true } : { ok: false, detail: JSON.stringify(pdf) }
  );
}

// =============================================================================
// 3. validateOcrImageUrl — non-allowlisted host
// =============================================================================

async function testRejectedHost(): Promise<void> {
  console.log("\n[3] validateOcrImageUrl — rejected: non-allowlisted host");

  clearCaptured();
  let fetchCalled = false;
  const result = await validateOcrImageUrl(
    "https://attacker.com/steal.jpg",
    "uid-hash-2",
    {
      fetchImpl: (async () => {
        fetchCalled = true;
        return makeFakeResponse({
          contentType: "image/jpeg",
          contentLength: "1024",
        });
      }) as unknown as typeof fetch,
    }
  );

  const ok =
    result.ok === false &&
    (result as Extract<OcrUrlValidationResult, { ok: false }>).reason ===
      "disallowed_host" &&
    fetchCalled === false; // Host check runs BEFORE HEAD.
  record(
    "attacker.com rejected with disallowed_host (HEAD never issued)",
    ok
      ? { ok: true }
      : {
          ok: false,
          detail: `result=${JSON.stringify(result)}, fetchCalled=${fetchCalled}`,
        }
  );
}

// =============================================================================
// 4. validateOcrImageUrl — oversized Content-Length
// =============================================================================

async function testRejectedOversized(): Promise<void> {
  console.log("\n[4] validateOcrImageUrl — rejected: Content-Length 11 MB");

  clearCaptured();
  const result = await validateOcrImageUrl(GOOD_URL, "uid-hash-3", {
    fetchImpl: fakeFetch({
      contentType: "image/jpeg",
      contentLength: String(11 * 1024 * 1024), // 11 MB > 10 MB cap
    }),
  });

  const ok =
    result.ok === false &&
    (result as Extract<OcrUrlValidationResult, { ok: false }>).reason ===
      "oversized";
  record(
    "11 MB Content-Length rejected with reason=oversized",
    ok
      ? { ok: true }
      : { ok: false, detail: `result=${JSON.stringify(result)}` }
  );

  // Sanity check: also confirm exact threshold (max bytes) is accepted, max+1
  // is rejected.
  const atMax = await validateOcrImageUrl(GOOD_URL, "uid-hash-3", {
    fetchImpl: fakeFetch({
      contentType: "image/jpeg",
      contentLength: String(MAX_OCR_IMAGE_BYTES),
    }),
  });
  record(
    "Content-Length exactly at MAX_OCR_IMAGE_BYTES → accepted",
    atMax.ok
      ? { ok: true }
      : { ok: false, detail: JSON.stringify(atMax) }
  );

  const overMax = await validateOcrImageUrl(GOOD_URL, "uid-hash-3", {
    fetchImpl: fakeFetch({
      contentType: "image/jpeg",
      contentLength: String(MAX_OCR_IMAGE_BYTES + 1),
    }),
  });
  record(
    "Content-Length MAX+1 → rejected with reason=oversized",
    !overMax.ok &&
      (overMax as Extract<OcrUrlValidationResult, { ok: false }>).reason ===
        "oversized"
      ? { ok: true }
      : { ok: false, detail: JSON.stringify(overMax) }
  );
}

// =============================================================================
// 5. validateOcrImageUrl — bad Content-Type
// =============================================================================

async function testRejectedContentType(): Promise<void> {
  console.log("\n[5] validateOcrImageUrl — rejected: Content-Type text/html");

  clearCaptured();
  const result = await validateOcrImageUrl(GOOD_URL, "uid-hash-4", {
    fetchImpl: fakeFetch({
      contentType: "text/html",
      contentLength: "2048",
    }),
  });

  const ok =
    result.ok === false &&
    (result as Extract<OcrUrlValidationResult, { ok: false }>).reason ===
      "disallowed_content_type";
  record(
    "text/html rejected with reason=disallowed_content_type",
    ok
      ? { ok: true }
      : { ok: false, detail: `result=${JSON.stringify(result)}` }
  );

  // application/octet-stream is also a common SSRF disguise.
  const octet = await validateOcrImageUrl(GOOD_URL, "uid-hash-4", {
    fetchImpl: fakeFetch({
      contentType: "application/octet-stream",
      contentLength: "2048",
    }),
  });
  record(
    "application/octet-stream → rejected with reason=disallowed_content_type",
    !octet.ok &&
      (octet as Extract<OcrUrlValidationResult, { ok: false }>).reason ===
        "disallowed_content_type"
      ? { ok: true }
      : { ok: false, detail: JSON.stringify(octet) }
  );

  // Missing Content-Type entirely.
  const missing = await validateOcrImageUrl(GOOD_URL, "uid-hash-4", {
    fetchImpl: fakeFetch({
      contentType: null,
      contentLength: "2048",
    }),
  });
  record(
    "missing Content-Type → rejected with reason=missing_content_type",
    !missing.ok &&
      (missing as Extract<OcrUrlValidationResult, { ok: false }>).reason ===
        "missing_content_type"
      ? { ok: true }
      : { ok: false, detail: JSON.stringify(missing) }
  );
}

// =============================================================================
// 6. validateOcrImageUrl — HEAD network error
// =============================================================================

async function testRejectedNetworkError(): Promise<void> {
  console.log("\n[6] validateOcrImageUrl — rejected: HEAD network error");

  clearCaptured();
  const result = await validateOcrImageUrl(GOOD_URL, "uid-hash-5", {
    fetchImpl: throwingFetch(new Error("ECONNREFUSED")),
  });

  const ok =
    result.ok === false &&
    (result as Extract<OcrUrlValidationResult, { ok: false }>).reason ===
      "head_request_failed";
  record(
    "HEAD throws → rejected with reason=head_request_failed",
    ok
      ? { ok: true }
      : { ok: false, detail: `result=${JSON.stringify(result)}` }
  );

  // HEAD returns 404 / 5xx.
  const non2xx = await validateOcrImageUrl(GOOD_URL, "uid-hash-5", {
    fetchImpl: fakeFetch({ status: 404, contentType: "image/jpeg" }),
  });
  record(
    "HEAD 404 → rejected with reason=head_request_failed",
    !non2xx.ok &&
      (non2xx as Extract<OcrUrlValidationResult, { ok: false }>).reason ===
        "head_request_failed"
      ? { ok: true }
      : { ok: false, detail: JSON.stringify(non2xx) }
  );
}

// =============================================================================
// 7. runOcrRecipeImage integration — validator wired in front of performOcr
// =============================================================================

async function testIntegration(): Promise<void> {
  console.log(
    "\n[7] runOcrRecipeImage — validator runs before performOcr is invoked"
  );

  // Rejected URL must throw HttpsError("invalid-argument") and never reach
  // the OCR call.
  {
    let performOcrCalled = false;
    let thrown: unknown = null;
    try {
      await runOcrRecipeImage({
        data: { imageUrl: "https://attacker.com/steal.jpg" },
        authUidHash: "uid-hash-int-1",
        validateImageUrl: async () => ({
          ok: false,
          reason: "disallowed_host",
          detail: "https://attacker.com",
        }),
        performOcr: async () => {
          performOcrCalled = true;
          return { content: "should never run", cost: 0 };
        },
        isAiDisabled: async () => false,
        now: () => 0,
      });
    } catch (e) {
      thrown = e;
    }

    const ok =
      thrown instanceof HttpsError &&
      thrown.code === "invalid-argument" &&
      performOcrCalled === false;
    record(
      "rejected URL → HttpsError(invalid-argument), performOcr never invoked",
      ok
        ? { ok: true }
        : {
            ok: false,
            detail:
              `thrown=${thrown instanceof Error ? thrown.message : String(thrown)}, ` +
              `performOcrCalled=${performOcrCalled}`,
          }
    );
  }

  // Accepted URL passes through to performOcr.
  {
    let performOcrCalled = false;
    let validatorCalled = false;
    const resp = await runOcrRecipeImage({
      data: { imageUrl: GOOD_URL },
      authUidHash: "uid-hash-int-2",
      validateImageUrl: async () => {
        validatorCalled = true;
        return {
          ok: true,
          contentType: "image/jpeg",
          contentLength: 1024,
          origin: "https://firebasestorage.googleapis.com",
        };
      },
      performOcr: async () => {
        performOcrCalled = true;
        return {
          content: JSON.stringify({
            title: "Pannkakor",
            description: null,
            portions: 4,
            prepTimeMinutes: 5,
            cookTimeMinutes: 10,
            ingredients: [
              { amount: 2, unit: "dl", name: "mjöl", preparation: null },
            ],
            instructions: ["Vispa ihop.", "Stek."],
            tags: [],
            difficulty: "easy",
            source: null,
          }),
          cost: 0.012,
        };
      },
      isAiDisabled: async () => false,
      now: () => 0,
    });

    const ok =
      validatorCalled &&
      performOcrCalled &&
      resp.success === true &&
      resp.recipe?.title === "Pannkakor";
    record(
      "accepted URL → validator + performOcr both run, recipe returned",
      ok
        ? { ok: true }
        : {
            ok: false,
            detail:
              `validator=${validatorCalled}, ocr=${performOcrCalled}, ` +
              `success=${resp.success}, title=${resp.recipe?.title}`,
          }
    );
  }
}

// =============================================================================
// Driver
// =============================================================================

async function main(): Promise<void> {
  console.log("BUT-425: OCR URL validation tests");
  console.log("=================================");

  testHostAllowlist();
  await testHappyPath();
  await testRejectedHost();
  await testRejectedOversized();
  await testRejectedContentType();
  await testRejectedNetworkError();
  await testIntegration();

  // Restore loggers (defensive — process exits anyway).
  (logger as unknown as { info: typeof originalInfo }).info = originalInfo;
  (logger as unknown as { warn: typeof originalWarn }).warn = originalWarn;
  (logger as unknown as { error: typeof originalError }).error = originalError;

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
