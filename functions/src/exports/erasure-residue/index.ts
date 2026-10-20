/**
 * BUT-2414: GDPR Article 15 export of what account erasure deletes or
 * anonymises.
 *
 * Every section reads with the predicate of the cascade step that erases it
 * (the step is named beside each section), projects through a fail-closed
 * allowlist, and returns only the requester's own fields. A section over its
 * cap DECLINES with `erasure-residue-too-large` and never truncates; a read
 * failure is `erasure-residue-read-failed`. Either is that section's
 * `error_code`, and the other sections still ship.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../../middleware/rate_limiter";
import { hashUid } from "../../shared/hash-uid";
import { ACCOUNT_SECTIONS, SectionDef } from "./account-sections";
import { SOCIAL_SECTIONS } from "./social-sections";
import { MESSAGE_SECTIONS } from "./messages-section";
import { REALTIME_LEGACY_SECTIONS } from "./realtime-legacy-sections";
import { STORAGE_SECTIONS } from "./storage-section";
import {
  FileLister,
  RESPONSE_TOO_LARGE_ERROR_CODE,
  SectionResult,
  runSection,
} from "./project";

export {
  TOO_LARGE_ERROR_CODE,
  READ_FAILED_ERROR_CODE,
  RESPONSE_TOO_LARGE_ERROR_CODE,
} from "./project";

const db = admin.firestore();

export const RATE_LIMIT_KEY = "exportErasureResidue";

/** Above this the largest sections are replaced by an `error_code`. */
export const MAX_RESPONSE_BYTES = 8 * 1024 * 1024;

export const SECTIONS: readonly SectionDef[] = [
  ...ACCOUNT_SECTIONS,
  ...SOCIAL_SECTIONS,
  ...MESSAGE_SECTIONS,
  ...REALTIME_LEGACY_SECTIONS,
  ...STORAGE_SECTIONS,
];

/** What erasure removes that these sections do not show. */
export const KNOWN_GAPS: readonly string[] = [
  "shares_sent_content_copies: the listData and menu copies embedded in a " +
    "share you sent are not exported",
  "realtime_menu_content: the content of a realtime menu you own is not " +
    "exported, only its own fields",
  "system_messages_about_you: system messages naming you in a conversation " +
    "you left are not exported",
  "legacy_rows_projected: rows in collections no current app version writes " +
    "are exported with their identifying fields only",
  "others_documents: where your user id appears on other people's recipes, " +
    "ratings and comments is not in this export; deleting your account " +
    "removes it there",
  "stored_file_contents: the files in your storage folder are listed by " +
    "name, size and dates; the files themselves are not in this export",
];

export interface ExportErasureResidueResponse {
  sections: Record<string, SectionResult>;
  known_gaps: readonly string[];
  gdprArticle: "Article 15 - Right of Access";
}

/** The two collaborators the request handler needs, injectable for tests. */
export interface ErasureResidueDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (uid: string) => Promise<ExportErasureResidueResponse>;
}

/**
 * The uid is taken from `request.auth` only; `request.data` is never read, so
 * a payload naming another user changes nothing.
 */
export async function handleExportErasureResidue(
  request: { auth?: { uid: string } | null },
  deps: ErasureResidueDeps,
): Promise<ExportErasureResidueResponse> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  await deps.rateLimit(uid, RATE_LIMIT_KEY);
  return deps.run(uid);
}

export const exportErasureResidue = onCall(
  {
    memory: "1GiB",
    timeoutSeconds: 120,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  (request) =>
    handleExportErasureResidue(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (uid) => runExportErasureResidueWithDb(db, uid),
    }),
);

/** Test seam — accepts an injected Firestore, section list and bucket. */
export async function runExportErasureResidueWithDb(
  database: admin.firestore.Firestore,
  uid: string,
  sections: readonly SectionDef[] = SECTIONS,
  bucket: () => FileLister = () => admin.storage().bucket(),
): Promise<ExportErasureResidueResponse> {
  const results = await Promise.all(
    sections.map((section) =>
      runSection(section.name, uid, () => section.read(database, uid, bucket)),
    ),
  );
  const response: ExportErasureResidueResponse = {
    sections: Object.fromEntries(sections.map((s, i) => [s.name, results[i]])),
    known_gaps: KNOWN_GAPS,
    gdprArticle: "Article 15 - Right of Access",
  };
  const replaced = fitResponse(response, uid);

  logger.info("exportErasureResidue.complete", {
    event: "export_erasure_residue.complete",
    uid_hash: hashUid(uid),
    rows: Object.fromEntries(
      Object.entries(response.sections).map(([name, r]) => [
        name,
        "rows" in r ? r.rows.length : r.error_code,
      ]),
    ),
    replacedForSize: replaced,
  });
  return response;
}

function byteLength(value: unknown): number {
  return Buffer.byteLength(JSON.stringify(value), "utf8");
}

/**
 * Replaces the largest sections with an `error_code` until the response fits
 * `MAX_RESPONSE_BYTES`. Whole sections only: a section is never cut short.
 */
function fitResponse(response: ExportErasureResidueResponse, uid: string): string[] {
  const replaced: string[] = [];
  let total = byteLength(response);
  if (total <= MAX_RESPONSE_BYTES) return replaced;
  const bySize = Object.entries(response.sections)
    .filter(([, r]) => "rows" in r)
    .map(([name, r]) => ({ name, bytes: byteLength(r) }))
    .sort((a, b) => b.bytes - a.bytes);
  for (const { name } of bySize) {
    if (total <= MAX_RESPONSE_BYTES) break;
    response.sections[name] = { error_code: RESPONSE_TOO_LARGE_ERROR_CODE };
    replaced.push(name);
    total = byteLength(response);
  }
  logger.warn("exportErasureResidue.response_too_large", {
    event: "export_erasure_residue.response_too_large",
    uid_hash: hashUid(uid),
    replaced,
  });
  return replaced;
}
