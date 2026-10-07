/**
 * BUT-1747: GDPR Article 15 export of what a user left behind in shared
 * shopping data the client SDK cannot read.
 *
 * Two places hold the requester's identity where their own client is refused:
 *  - a `unified_shared_shopping_lists` document they have LEFT. The read rule
 *    admits only the owner and `memberPermissions` keys, yet their uid stays on the
 *    embedded items they touched, in `contributorUserIds` and possibly in
 *    `lastActivityByUserId`.
 *  - `shared_content/{id}/items`, which `firestore.rules` has no block for.
 *
 * The projection is a fail-closed ALLOWLIST, the shape BUT-2062 uses: a key the
 * client model does not write never reaches the bundle. On a row it returns,
 * another person's uid field is removed, and a display name survives only
 * beside a uid that is the requester's own (BUT-1732's pairing rule). A left
 * list contributes only the rows naming the requester, because the requester no
 * longer has access to the rest of it.
 *
 * Above any bound it DECLINES with `shared-residue-too-large` and never
 * truncates: a truncated Art. 15 answer reads as complete.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { enforceRateLimit } from "../middleware/rate_limiter";
import {
  ITEM_UID_FIELDS,
  isSharedContentParent,
} from "../account/account-deletion-cascade";

const db = admin.firestore();

export const RATE_LIMIT_KEY = "exportSharedResidue";
export const TOO_LARGE_ERROR_CODE = "shared-residue-too-large";

/** BUT-1747 panel condition 5. */
export const MAX_LEFT_LISTS = 500;
/** BUT-1747 panel condition 5, counted AFTER the `shared_content` path filter. */
export const MAX_ITEM_ROWS = 2000;
/**
 * The list and `items` queries also match documents this export discards
 * (lists the requester still belongs to, personal-list rows), so their raw read
 * is bounded on its own rather than by the export caps.
 */
export const RAW_READ_FACTOR = 10;
export const MAX_RAW_LIST_READS = MAX_LEFT_LISTS * RAW_READ_FACTOR;
export const MAX_RAW_ITEM_READS = MAX_ITEM_ROWS * RAW_READ_FACTOR;
/** Bounds the owned-share walk, whose per-share reads run one at a time. */
export const MAX_OWNED_SHARES = MAX_LEFT_LISTS;
/** BUT-1747 panel condition 5. */
export const MAX_RESPONSE_BYTES = 8 * 1024 * 1024;

/**
 * Every key `UnifiedShoppingItem.toFirestore` writes
 * (`lib/models/unified/unified_shopping_item.dart`). The suite pins this set
 * against that source, so a key added in Dart reddens it instead of being
 * silently dropped from the export.
 */
export const ITEM_EXPORT_KEYS: readonly string[] = [
  "id",
  "name",
  "amount",
  "unit",
  "category",
  "bought",
  "addedByUserId",
  "addedByDisplayName",
  "addedAt",
  "purchasedByUserId",
  "purchasedByDisplayName",
  "purchasedAt",
  "lastModifiedByUserId",
  "lastModifiedByDisplayName",
  "lastModifiedAt",
  "note",
  "estimatedPrice",
  "priority",
  "assignedToUserId",
  "assignedToDisplayName",
  "assignedAt",
];

type ItemUidField = (typeof ITEM_UID_FIELDS)[number];

export const DISPLAY_NAME_OF: Readonly<Record<ItemUidField, string>> = {
  addedByUserId: "addedByDisplayName",
  lastModifiedByUserId: "lastModifiedByDisplayName",
  assignedToUserId: "assignedToDisplayName",
  purchasedByUserId: "purchasedByDisplayName",
};

export type ExportedItem = Record<string, unknown>;

export interface LeftListExport {
  id: string;
  name: unknown;
  ownerId: unknown;
  createdAt: unknown;
  updatedAt: unknown;
  /** Stands in for `contributorUserIds`, which is an erasure handle. */
  recorded_as_contributor: boolean;
  /** Present only when the requester is the list's last actor. */
  lastActivityByUserId?: string;
  lastActivityByDisplayName?: unknown;
  lastActivityAt?: unknown;
  items: ExportedItem[];
}

export interface SharedContentItemExport {
  shareId: string;
  itemId: string;
  item: ExportedItem;
}

/** Places a row naming the requester can sit that these finders do not reach. */
export const KNOWN_GAPS: readonly string[] = [
  "left_list_not_on_trail: a list the requester left is found only through " +
    "contributorUserIds or lastActivityByUserId, so one whose trail never " +
    "recorded them (written before the trail, or by a client that skipped " +
    "it) and where someone else acted last is not found",
  "shared_content_list_data: the listData copy on a shared_content document " +
    "is not searched",
];

export interface ExportSharedResidueResponse {
  shared_lists_left: LeftListExport[];
  shared_content_items: SharedContentItemExport[];
  known_gaps: readonly string[];
  gdprArticle: "Article 15 - Right of Access";
}

/** The two collaborators the request handler needs, injectable for tests. */
export interface SharedResidueDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (uid: string) => Promise<ExportSharedResidueResponse>;
}

/**
 * The uid is taken from `request.auth` only; `request.data` is never read, so
 * a payload naming another user changes nothing.
 */
export async function handleExportSharedResidue(
  request: { auth?: { uid: string } | null },
  deps: SharedResidueDeps,
): Promise<ExportSharedResidueResponse> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  await deps.rateLimit(uid, RATE_LIMIT_KEY);
  return deps.run(uid);
}

export const exportSharedResidue = onCall(
  {
    memory: "1GiB",
    timeoutSeconds: 120,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  (request) =>
    handleExportSharedResidue(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: runExportSharedResidue,
    }),
);

export async function runExportSharedResidue(
  uid: string,
): Promise<ExportSharedResidueResponse> {
  return runExportSharedResidueWithDb(db, uid);
}

/** Test seam — accepts an injected Firestore. */
export async function runExportSharedResidueWithDb(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<ExportSharedResidueResponse> {
  const lists = await findLeftLists(database, uid);
  const rows = await findSharedContentItemRows(database, uid);

  const response: ExportSharedResidueResponse = {
    shared_lists_left: lists
      .map((snap) => projectLeftList(snap, uid))
      .filter((list): list is LeftListExport => list !== null)
      .sort((a, b) => a.id.localeCompare(b.id)),
    shared_content_items: [...rows.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([, doc]) => ({
        shareId: doc.ref.parent.parent?.id ?? "",
        itemId: doc.id,
        item: projectItem(doc.data() ?? {}, uid),
      })),
    known_gaps: KNOWN_GAPS,
    gdprArticle: "Article 15 - Right of Access",
  };

  const bytes = Buffer.byteLength(JSON.stringify(response), "utf8");
  if (bytes > MAX_RESPONSE_BYTES) {
    decline(uid, "response_bytes", bytes);
  }

  logger.info("exportSharedResidue.complete", {
    event: "export_shared_residue.complete",
    uid_prefix: uid.slice(0, 6),
    lists: response.shared_lists_left.length,
    sharedContentItems: response.shared_content_items.length,
  });
  return response;
}

function decline(uid: string, bound: string, observed: number): never {
  logger.warn("exportSharedResidue.declined", {
    event: "export_shared_residue.declined",
    uid_prefix: uid.slice(0, 6),
    bound,
    observed,
  });
  throw new HttpsError(
    "failed-precondition",
    "Shared shopping data is too large to export in one response.",
    { error_code: TOO_LARGE_ERROR_CODE },
  );
}

/** Owner or current member: the client section already exports the list. */
function stillHeldBy(data: admin.firestore.DocumentData, uid: string): boolean {
  if (data.ownerId === uid) return true;
  const perms = data.memberPermissions;
  return isPlainObject(perms) && perms[uid] != null;
}

/**
 * The two finders `deleteShoppingLists` uses to reach a list after its member
 * key is gone. They read only the membership fields first, so the embedded
 * items of the lists the requester still holds are never loaded.
 */
async function findLeftLists(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<admin.firestore.DocumentSnapshot[]> {
  const lists = database.collection(Collections.unifiedSharedShoppingLists);
  const snaps = await Promise.all([
    lists.where("contributorUserIds", "array-contains", uid),
    lists.where("lastActivityByUserId", "==", uid),
  ].map((query) =>
    query
      .select("ownerId", "memberPermissions")
      .limit(MAX_RAW_LIST_READS + 1)
      .get(),
  ));

  const left = new Map<string, admin.firestore.DocumentReference>();
  for (const snap of snaps) {
    if (snap.size > MAX_RAW_LIST_READS) {
      decline(uid, "raw_list_reads", snap.size);
    }
    for (const doc of snap.docs) {
      if (stillHeldBy(doc.data(), uid)) continue;
      left.set(doc.id, doc.ref);
    }
  }
  if (left.size > MAX_LEFT_LISTS) decline(uid, "left_lists", left.size);
  if (left.size === 0) return [];
  return database.getAll(...left.values());
}

/**
 * The cascade's two `shared_content` item handles: the four path-scoped
 * collection-group uid queries (`scrubSharedContentItemAttribution`), and the
 * whole `items` subcollection under every share the requester made, which
 * erasure deletes with the share.
 */
async function findSharedContentItemRows(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<Map<string, admin.firestore.QueryDocumentSnapshot>> {
  const rows = new Map<string, admin.firestore.QueryDocumentSnapshot>();

  // Personal-list rows share the `items` group id and their owner may write
  // any uid into them, so without this range anyone could push the raw read
  // past its bound and make someone else's export decline. A collection-group
  // documentId bound is a full document path, compared segment by segment:
  // `shared_content\u0000` is the first collection id after `shared_content`.
  const sharedContentFrom = database.doc("shared_content/\u0000");
  const sharedContentTo = database.doc("shared_content\u0000/\u0000");
  const snaps = await Promise.all(
    ITEM_UID_FIELDS.map((field) =>
      database
        .collectionGroup("items")
        .where(field, "==", uid)
        .where(admin.firestore.FieldPath.documentId(), ">=", sharedContentFrom)
        .where(admin.firestore.FieldPath.documentId(), "<", sharedContentTo)
        .limit(MAX_RAW_ITEM_READS + 1)
        .get(),
    ),
  );
  for (const snap of snaps) {
    if (snap.size > MAX_RAW_ITEM_READS) {
      decline(uid, "raw_item_reads", snap.size);
    }
    for (const doc of snap.docs) {
      // The range also admits `items` nested deeper under a share; the
      // cascade's scrub leaves those out by this same path test.
      const parent = doc.ref.parent.parent;
      if (!parent || !isSharedContentParent(parent)) continue;
      rows.set(doc.ref.path, doc);
    }
  }
  if (rows.size > MAX_ITEM_ROWS) decline(uid, "item_rows", rows.size);

  const owned = await database
    .collection("shared_content")
    .where("sharedByUserId", "==", uid)
    .select()
    .limit(MAX_OWNED_SHARES + 1)
    .get();
  if (owned.size > MAX_OWNED_SHARES) decline(uid, "owned_shares", owned.size);

  // One share at a time so the row cap declines before the next share loads.
  for (const share of owned.docs) {
    const items = await share.ref
      .collection("items")
      .limit(MAX_ITEM_ROWS + 1)
      .get();
    for (const doc of items.docs) rows.set(doc.ref.path, doc);
    if (rows.size > MAX_ITEM_ROWS) decline(uid, "item_rows", rows.size);
  }
  return rows;
}

function projectLeftList(
  snap: admin.firestore.DocumentSnapshot,
  uid: string,
): LeftListExport | null {
  const data = snap.data();
  // Re-checked on the full read: the requester may have rejoined in between.
  if (!snap.exists || data === undefined || stillHeldBy(data, uid)) return null;

  const items = Array.isArray(data.items) ? data.items : [];
  const out: LeftListExport = {
    id: snap.id,
    name: exportValue(data.name),
    ownerId: exportValue(data.ownerId),
    createdAt: exportValue(data.createdAt),
    updatedAt: exportValue(data.updatedAt),
    recorded_as_contributor:
      Array.isArray(data.contributorUserIds) &&
      data.contributorUserIds.includes(uid),
    items: items
      .filter(
        (raw): raw is Record<string, unknown> =>
          isPlainObject(raw) && ITEM_UID_FIELDS.some((f) => raw[f] === uid),
      )
      .map((raw) => projectItem(raw, uid)),
  };
  if (data.lastActivityByUserId === uid) {
    out.lastActivityByUserId = uid;
    out.lastActivityByDisplayName = exportValue(data.lastActivityByDisplayName);
    out.lastActivityAt = exportValue(data.lastActivityAt);
  }
  return out;
}

/**
 * Allowlisted keys only; then every uid field that is not the requester's goes,
 * and with it the display name it pairs with. A display name whose uid field is
 * missing goes too, so a malformed row cannot carry a name out unpaired.
 */
export function projectItem(
  raw: Record<string, unknown>,
  uid: string,
): ExportedItem {
  const out: ExportedItem = {};
  for (const key of ITEM_EXPORT_KEYS) {
    if (Object.prototype.hasOwnProperty.call(raw, key)) {
      const value = exportValue(raw[key]);
      if (value !== undefined) out[key] = value;
    }
  }
  for (const field of ITEM_UID_FIELDS) {
    if (raw[field] !== uid) {
      delete out[field];
      delete out[DISPLAY_NAME_OF[field]];
    }
  }
  return out;
}

/**
 * Timestamps become ISO-8601 strings and scalars pass as stored. Anything
 * else is dropped, so a reference or a nested container never reaches the
 * response's JSON encoding.
 */
function exportValue(value: unknown): unknown {
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

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
