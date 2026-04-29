/**
 * BUT-425: Validate user-supplied OCR image URLs before forwarding to Gemini.
 *
 * The OCR callable accepts a client-supplied `imageUrl` and previously passed
 * it straight into Gemini's `fileData.fileUri`. Gemini fetches that URL
 * server-side from Google's network, which makes the function an SSRF/data-
 * exfiltration vector if the URL is unbounded.
 *
 * This module enforces three guards before the URL ever reaches Gemini:
 *   1. Host allowlist — only Firebase Storage hosts pinned to *this* project's
 *      bucket. Both the legacy `firebasestorage.googleapis.com/v0/b/<bucket>/o/`
 *      shape and the newer `<bucket>.firebasestorage.app` shape are accepted.
 *   2. HEAD pre-flight — Content-Type must be in an image/PDF allowlist and
 *      Content-Length must fit our 10 MB cap. This blocks links that pivot
 *      from "image" to a 1 GB binary or an HTML phishing page after upload.
 *   3. Audit log — origin + size + content-type at INFO so operations can spot
 *      patterns of abuse without needing the full URL (which may carry tokens).
 *
 * Pure helper; no Firebase Admin / Vertex coupling so it stays testable
 * without spinning up the SDKs.
 */

import { logger } from "firebase-functions/logger";
import { isAllowedUrl } from "./url-safety";

// =============================================================================
// Constants
// =============================================================================

/** 10 MB — matches the base64 cap on the OCR callable's other input path. */
export const MAX_OCR_IMAGE_BYTES = 10 * 1024 * 1024;

/**
 * Content-Type allowlist. Lowercased, exact match against the bare media type
 * (parameters such as `; charset=utf-8` are stripped before comparison).
 */
export const ALLOWED_OCR_CONTENT_TYPES: ReadonlySet<string> = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "application/pdf",
]);

/** HEAD request timeout. Vertex itself runs with a 120s function timeout, and
 *  Firebase Storage HEAD typically returns in <500ms; 5s is a generous ceiling
 *  that still fails fast on a hung connection. */
const HEAD_TIMEOUT_MS = 5000;

/**
 * Project ID resolution mirrors `gemini-client.ts`. Cloud Functions sets
 * `GCLOUD_PROJECT`; some envs use `GOOGLE_CLOUD_PROJECT`. Fall back to the
 * known production project so unit tests don't need env wiring.
 */
function getProjectId(): string {
  return (
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    "butlery-app-1"
  );
}

/** The bucket host for the new-style Firebase Storage domain. */
function getBucketHost(): string {
  return `${getProjectId()}.firebasestorage.app`;
}

// =============================================================================
// Result type
// =============================================================================

export type OcrUrlValidationResult =
  | { ok: true; contentType: string; contentLength: number; origin: string }
  | { ok: false; reason: OcrUrlRejectionReason; detail?: string };

export type OcrUrlRejectionReason =
  | "malformed_url"
  | "disallowed_host"
  | "head_request_failed"
  | "missing_content_type"
  | "disallowed_content_type"
  | "missing_content_length"
  | "oversized";

// =============================================================================
// Host check
// =============================================================================

/**
 * Verify that `url` points at this project's Firebase Storage bucket.
 * Two accepted shapes:
 *   - https://firebasestorage.googleapis.com/v0/b/<project>.firebasestorage.app/o/...
 *   - https://firebasestorage.googleapis.com/v0/b/<project>.appspot.com/o/...   (legacy bucket name)
 *   - https://<project>.firebasestorage.app/...
 *
 * Anything else — including buckets owned by another Firebase project — is
 * rejected. The `isAllowedUrl` SSRF base check (HTTPS-only, no private IPs)
 * runs first.
 */
export function isAllowedOcrHost(url: string): boolean {
  if (!isAllowedUrl(url)) return false;

  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }

  const host = parsed.hostname.toLowerCase();
  const projectId = getProjectId();
  const bucketHost = `${projectId}.firebasestorage.app`;
  const legacyBucketHost = `${projectId}.appspot.com`;

  // Shape 2 / 3: direct bucket-host download.
  if (host === bucketHost || host === legacyBucketHost) {
    return true;
  }

  // Shape 1: googleapis-hosted download URL. Bucket name lives in the path:
  //   /v0/b/<bucket>/o/<encoded_path>
  if (host === "firebasestorage.googleapis.com") {
    const match = parsed.pathname.match(/^\/v0\/b\/([^/]+)\/o\//);
    if (!match) return false;
    const bucket = match[1].toLowerCase();
    return bucket === bucketHost || bucket === legacyBucketHost;
  }

  return false;
}

// =============================================================================
// HEAD pre-flight
// =============================================================================

export interface HeadCheckOptions {
  /** Test seam: override the fetch implementation. Defaults to global fetch
   *  (Node 22 native). */
  fetchImpl?: typeof fetch;
  /** Test seam: override timeout for HEAD request. */
  timeoutMs?: number;
}

/**
 * Validate a user-supplied URL before forwarding to Gemini.
 *
 * Runs three checks in order:
 *   1. Host allowlist — see {@link isAllowedOcrHost}.
 *   2. HEAD request — Content-Type and Content-Length headers must be present
 *      and pass the allowlist/size guards.
 *   3. Audit log — INFO-level entry with origin, size, content-type. The full
 *      URL is intentionally NOT logged: Firebase Storage download URLs carry
 *      `?token=` query parameters that grant read access; logging them would
 *      undo the access control.
 *
 * Returns a tagged result. Callers convert `ok: false` into a Swedish-language
 * `HttpsError("invalid-argument", ...)` to match the rest of the OCR
 * function's error surface.
 */
export async function validateOcrImageUrl(
  url: string,
  authUidHash: string,
  opts: HeadCheckOptions = {}
): Promise<OcrUrlValidationResult> {
  const fetchImpl = opts.fetchImpl ?? fetch;
  const timeoutMs = opts.timeoutMs ?? HEAD_TIMEOUT_MS;

  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return { ok: false, reason: "malformed_url" };
  }

  if (!isAllowedOcrHost(url)) {
    logger.warn("[ocrUrlValidator] rejected: disallowed host", {
      origin: parsed.origin,
      authUidHash,
    });
    return {
      ok: false,
      reason: "disallowed_host",
      detail: parsed.origin,
    };
  }

  // HEAD pre-flight. AbortController ensures we don't hang the function on a
  // wedged connection.
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  let response: Response;
  try {
    response = await fetchImpl(url, {
      method: "HEAD",
      signal: controller.signal,
      redirect: "manual", // Don't chase redirects — the allowlisted host MUST
      // resolve directly; a redirect away from it defeats the host check.
    });
  } catch (err) {
    logger.warn("[ocrUrlValidator] rejected: HEAD request failed", {
      origin: parsed.origin,
      authUidHash,
      err: err instanceof Error ? err.message : String(err),
    });
    return { ok: false, reason: "head_request_failed" };
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    logger.warn("[ocrUrlValidator] rejected: HEAD non-2xx", {
      origin: parsed.origin,
      status: response.status,
      authUidHash,
    });
    return {
      ok: false,
      reason: "head_request_failed",
      detail: `HTTP ${response.status}`,
    };
  }

  // Content-Type — strip parameters (`; charset=...`) and lowercase.
  const rawContentType = response.headers.get("content-type");
  if (!rawContentType) {
    return { ok: false, reason: "missing_content_type" };
  }
  const contentType = rawContentType.split(";")[0].trim().toLowerCase();
  if (!ALLOWED_OCR_CONTENT_TYPES.has(contentType)) {
    logger.warn("[ocrUrlValidator] rejected: disallowed content-type", {
      origin: parsed.origin,
      contentType,
      authUidHash,
    });
    return {
      ok: false,
      reason: "disallowed_content_type",
      detail: contentType,
    };
  }

  // Content-Length — must be present and within cap.
  const rawContentLength = response.headers.get("content-length");
  if (!rawContentLength) {
    return { ok: false, reason: "missing_content_length" };
  }
  const contentLength = parseInt(rawContentLength, 10);
  if (!Number.isFinite(contentLength) || contentLength < 0) {
    return { ok: false, reason: "missing_content_length" };
  }
  if (contentLength > MAX_OCR_IMAGE_BYTES) {
    logger.warn("[ocrUrlValidator] rejected: oversized", {
      origin: parsed.origin,
      contentLength,
      maxBytes: MAX_OCR_IMAGE_BYTES,
      authUidHash,
    });
    return {
      ok: false,
      reason: "oversized",
      detail: `${contentLength} bytes`,
    };
  }

  // Audit log — INFO so it shows up in normal operations, structured so it's
  // queryable. URL itself omitted to avoid leaking the download token.
  logger.info("[ocrUrlValidator] accepted", {
    origin: parsed.origin,
    contentType,
    contentLength,
    authUidHash,
  });

  return {
    ok: true,
    contentType,
    contentLength,
    origin: parsed.origin,
  };
}

// =============================================================================
// Internal exports for testing
// =============================================================================

/** @internal — exposed for unit tests. */
export const __testing = {
  getProjectId,
  getBucketHost,
};
