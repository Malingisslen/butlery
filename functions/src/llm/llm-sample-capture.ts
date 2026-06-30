/**
 * BUT-1451: best-effort capture of paid-LLM calls (scrubbed input + raw output)
 * to the `llm_response_samples` collection, so we can mine what we already pay
 * for to improve the deterministic parser and the prompts.
 *
 * Privacy posture (the design's load-bearing constraints):
 *  - Inputs are already PII-scrubbed by `scrubPii` at the call site; the output
 *    is scrubbed again HERE before it's stored, so nothing un-scrubbed lands.
 *  - Image bytes are never stored — the OCR path stores only the model's text.
 *  - Every doc carries `expireAt`; enable a Firestore TTL policy on that field
 *    for this collection so docs are reaped. Retention defaults to 30 days
 *    (GDPR Art. 5(1)(e) data-minimisation) — DPO confirms the window.
 *  - Client access is denied in firestore.rules (Admin-SDK writes only).
 *
 * This must never throw and never fail an import: a capture error is swallowed.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { scrubPii } from "./pii-scrubber";

/** GDPR Art. 5(1)(e) data-minimisation default; DPO confirms the window. */
const RETENTION_DAYS = 30;

/** Bound stored doc size (Firestore doc limit is 1 MiB) — chars, per field. */
const MAX_FIELD_CHARS = 50_000;

const COLLECTION = "llm_response_samples";

/** `system/config.llmSampleCaptureEnabled` (default true) cached per-instance. */
const ENABLE_CACHE_MS = 5 * 60 * 1000;
let cachedEnable: { value: boolean; at: number } | undefined;

async function captureEnabled(db: admin.firestore.Firestore): Promise<boolean> {
  const now = Date.now();
  if (cachedEnable && now - cachedEnable.at < ENABLE_CACHE_MS) {
    return cachedEnable.value;
  }
  let value = true; // fail open: capture unless explicitly disabled
  try {
    const doc = await db.doc("system/config").get();
    if (doc.exists && doc.data()?.llmSampleCaptureEnabled === false) {
      value = false;
    }
  } catch {
    // Config unreachable → keep the default (on). Capture is best-effort.
  }
  cachedEnable = { value, at: now };
  return value;
}

/** Test seam: clears the per-instance enable-flag cache between cases. */
export function resetSampleCaptureCacheForTest(): void {
  cachedEnable = undefined;
}

export interface LlmSampleInput {
  /** 'extract' | 'enhance' | 'spoken' | 'ingredientLines' | 'ocr'. */
  mode: string;
  /** 'text' (URL/scrape/transcript) or 'image' (OCR — bytes NOT stored). */
  inputKind: "text" | "image";
  /** Already PII-scrubbed at the call site. Omitted for image inputs. */
  scrubbedInput?: string;
  /** Raw model text BEFORE our parse. Scrubbed again here before storing. */
  rawLlmResponse: string;
  promptVersion?: string;
  /** 'firestore' | 'default' — which prompt source produced this. */
  promptSource?: string;
  experimentBucket?: number;
  promptVariant?: string;
  /** Hostname of the (scrubbed) source URL, when known. */
  domain?: string;
  /** SHA-256 hash of the uid — never the raw uid. */
  authUidHash?: string;
  modelId: string;
  promptTokenCount?: number;
  candidatesTokenCount?: number;
}

const truncate = (s: string): string =>
  s.length > MAX_FIELD_CHARS ? s.slice(0, MAX_FIELD_CHARS) : s;

/** Firestore rejects `undefined`; coalesce optional fields to `null`. */
const orNull = <T>(v: T | undefined): T | null => (v === undefined ? null : v);

export async function captureLlmSample(
  sample: LlmSampleInput,
  // Test seam — production uses the default Admin SDK Firestore handle.
  db: admin.firestore.Firestore = admin.firestore()
): Promise<void> {
  try {
    if (!(await captureEnabled(db))) return;

    const scrubbedOutput = scrubPii(sample.rawLlmResponse);
    const expireAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + RETENTION_DAYS * 24 * 60 * 60 * 1000
    );

    await db
      .collection(COLLECTION)
      .add({
        mode: sample.mode,
        inputKind: sample.inputKind,
        // Input: already scrubbed upstream; null for image inputs.
        scrubbedInput:
          sample.scrubbedInput !== undefined
            ? truncate(sample.scrubbedInput)
            : null,
        scrubbedInputLength: sample.scrubbedInput?.length ?? null,
        // Output: scrubbed here so nothing un-scrubbed is ever persisted.
        scrubbedOutput: truncate(scrubbedOutput),
        outputLength: sample.rawLlmResponse.length,
        promptVersion: orNull(sample.promptVersion),
        promptSource: orNull(sample.promptSource),
        experimentBucket: orNull(sample.experimentBucket),
        promptVariant: orNull(sample.promptVariant),
        domain: orNull(sample.domain),
        authUidHash: orNull(sample.authUidHash),
        modelId: sample.modelId,
        promptTokenCount: orNull(sample.promptTokenCount),
        candidatesTokenCount: orNull(sample.candidatesTokenCount),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expireAt,
      });
  } catch (err) {
    // Best-effort observability — never a failure surface for an import.
    logger.warn("[llm-sample-capture] write failed (ignored)", {
      mode: sample.mode,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

/** Hostname (sans leading `www.`) from an already-scrubbed URL, else undefined. */
export function domainFromUrl(url?: string): string | undefined {
  if (!url) return undefined;
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return undefined;
  }
}
