/**
 * BUT-2414: the projection and section plumbing every `exportErasureResidue`
 * section uses.
 *
 * A projection is a fail-closed ALLOWLIST: a key the spec does not name never
 * reaches the response, at any depth.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../../shared/hash-uid";

export const TOO_LARGE_ERROR_CODE = "erasure-residue-too-large";
export const READ_FAILED_ERROR_CODE = "erasure-residue-read-failed";
export const RESPONSE_TOO_LARGE_ERROR_CODE = "erasure-residue-response-too-large";

/** How one allowlisted field is exported. */
export type FieldSpec =
  /** A string, number, boolean or null; a Timestamp becomes ISO-8601. */
  | "scalar"
  /** An array whose string elements are kept. */
  | "strings"
  /** A nested map, itself allowlisted. */
  | { map: Allowlist }
  /** A map keyed by ids, each value allowlisted. */
  | { mapOf: Allowlist }
  /** An array of maps, each allowlisted. */
  | { list: Allowlist };

export type Allowlist = Readonly<Record<string, FieldSpec>>;

export type Row = Record<string, unknown>;

export type SectionResult = { rows: Row[] } | { error_code: string };

/** One object a Storage listing returns, as far as a section reads it. */
export interface ListedFile {
  name: string;
  metadata: {
    size?: string | number;
    contentType?: string;
    timeCreated?: string;
    updated?: string;
  };
}

/** The one Storage call a section makes, so tests can stage a bucket. */
export interface FileLister {
  getFiles(query: {
    prefix: string;
    autoPaginate: false;
    maxResults: number;
    pageToken?: string;
  }): Promise<[ListedFile[], { pageToken?: string } | null | undefined, ...unknown[]]>;
}

/** Thrown by a section that is over one of its bounds. */
export class Decline extends Error {
  constructor(
    readonly bound: string,
    readonly observed: number,
  ) {
    super(`erasure residue declined: ${bound}`);
  }
}

export function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    !(value instanceof admin.firestore.Timestamp)
  );
}

/**
 * Scalars pass as stored and a Timestamp becomes an ISO-8601 string. Anything
 * else is `undefined`, which drops the key, so a reference or a container
 * never reaches the response unspecified.
 */
export function exportValue(value: unknown): unknown {
  if (value === null || value === undefined) return null;
  if (
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return value;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  return undefined;
}

function exportField(value: unknown, spec: FieldSpec): unknown {
  if (spec === "scalar") return exportValue(value);
  if (spec === "strings") {
    return Array.isArray(value)
      ? value.filter((v): v is string => typeof v === "string")
      : undefined;
  }
  if ("map" in spec) {
    return isPlainObject(value) ? project(value, spec.map) : undefined;
  }
  if ("mapOf" in spec) {
    if (!isPlainObject(value)) return undefined;
    const out: Row = {};
    for (const [key, entry] of Object.entries(value)) {
      if (isPlainObject(entry)) out[key] = project(entry, spec.mapOf);
    }
    return out;
  }
  return Array.isArray(value)
    ? value.filter(isPlainObject).map((entry) => project(entry, spec.list))
    : undefined;
}

/** The allowlisted keys of `raw`, each exported by its spec. */
export function project(raw: Record<string, unknown>, spec: Allowlist): Row {
  const out: Row = {};
  for (const [key, fieldSpec] of Object.entries(spec)) {
    if (!Object.prototype.hasOwnProperty.call(raw, key)) continue;
    const value = exportField(raw[key], fieldSpec);
    if (value !== undefined) out[key] = value;
  }
  return out;
}

/** Every key named `scalar`. */
export function scalars(...keys: string[]): Allowlist {
  return Object.fromEntries(keys.map((key) => [key, "scalar" as const]));
}

/**
 * The query's documents, or a [Decline] when it holds more than `cap`. The
 * read asks for one more than the cap so the decline never truncates.
 */
export async function cappedDocs(
  query: admin.firestore.Query,
  cap: number,
  bound: string,
): Promise<admin.firestore.QueryDocumentSnapshot[]> {
  const snap = await query.limit(cap + 1).get();
  if (snap.size > cap) throw new Decline(bound, snap.size);
  return snap.docs;
}

/** `getAll` in slices, so one call never carries an unbounded argument list. */
export async function getAllInChunks(
  database: admin.firestore.Firestore,
  refs: admin.firestore.DocumentReference[],
  fieldMask?: string[],
): Promise<admin.firestore.DocumentSnapshot[]> {
  const out: admin.firestore.DocumentSnapshot[] = [];
  for (let i = 0; i < refs.length; i += 100) {
    const slice = refs.slice(i, i + 100);
    const snaps = fieldMask
      ? await database.getAll(...slice, { fieldMask })
      : await database.getAll(...slice);
    out.push(...snaps);
  }
  return out;
}

/** Rows sorted by `key` so the response is deterministic. */
export function sortRows(rows: Row[], key: string): Row[] {
  return rows.sort((a, b) => String(a[key]).localeCompare(String(b[key])));
}

/**
 * Runs one section. A decline or a failure becomes that section's
 * `error_code`, and the other sections are unaffected.
 */
export async function runSection(
  name: string,
  uid: string,
  read: () => Promise<Row[]>,
): Promise<SectionResult> {
  try {
    return { rows: await read() };
  } catch (err) {
    if (err instanceof Decline) {
      logger.warn("exportErasureResidue.section_declined", {
        event: "export_erasure_residue.section_declined",
        uid_hash: hashUid(uid),
        section: name,
        bound: err.bound,
        observed: err.observed,
      });
      return { error_code: TOO_LARGE_ERROR_CODE };
    }
    logger.error("exportErasureResidue.section_failed", {
      event: "export_erasure_residue.section_failed",
      uid_hash: hashUid(uid),
      section: name,
      errCode: (err as { code?: number | string } | null)?.code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return { error_code: READ_FAILED_ERROR_CODE };
  }
}
