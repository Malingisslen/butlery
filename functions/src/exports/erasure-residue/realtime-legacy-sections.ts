/**
 * BUT-2414: realtime documents and the legacy legs erasure still sweeps.
 *
 * Each section's query is the predicate of the cascade step named beside it,
 * and each row carries only the requester's own fields. The legacy legs have
 * no live writer, so their allowlists name only identifying fields (see
 * `KNOWN_GAPS`).
 */

import * as admin from "firebase-admin";
import { Collections } from "../../shared/collections";
import {
  Allowlist,
  Decline,
  Row,
  cappedDocs,
  getAllInChunks,
  project,
  scalars,
  sortRows,
} from "./project";
import { MAX_SECTION_ROWS, SectionDef } from "./account-sections";
import { RAW_READ_FACTOR } from "./social-sections";

/** The `RealtimeResource.toFirestoreMetadata` scalars an owner row exports. */
export const REALTIME_OWNER_KEYS: Allowlist = scalars(
  "type",
  "ownerId",
  "ownerDisplayName",
  "createdAt",
  "lastEditedAt",
  "editCount",
  "isActive",
);

/** The last-editor pair `scrubLastEditor` anonymises, with its time. */
export const REALTIME_EDITOR_KEYS: Allowlist = scalars(
  "lastEditedBy",
  "lastEditedByDisplayName",
  "lastEditedAt",
);

/** `presence/{uid}`: `{displayName, isActive, lastSeen}`. */
export const PRESENCE_KEYS: Allowlist = scalars("displayName", "isActive", "lastSeen");

export const LEGACY_RECIPE_KEYS: Allowlist = scalars(
  "userId",
  "title",
  "name",
  "createdAt",
  "updatedAt",
);
export const LEGACY_LIST_KEYS: Allowlist = scalars("name", "title", "createdAt", "updatedAt");
export const LEGACY_ITEM_KEYS: Allowlist = scalars(
  "name",
  "amount",
  "unit",
  "category",
  "bought",
  "note",
  "addedAt",
);
export const LEGACY_COMMENT_KEYS: Allowlist = scalars("commentedBy", "text", "createdAt", "updatedAt");
export const LEGACY_RATING_KEYS: Allowlist = scalars("ratedBy", "rating", "createdAt", "updatedAt");

type Snap = admin.firestore.QueryDocumentSnapshot;

/** `deleteRealtimeMenus`' three handles, merged per menu. */
async function realtimeMenuDocs(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<{ owned: Snap[]; edited: Snap[]; joined: Snap[] }> {
  const menus = database.collection(Collections.realtimeMenus);
  const [owned, edited, joined] = await Promise.all([
    cappedDocs(menus.where("ownerId", "==", uid), MAX_SECTION_ROWS, "realtime_menus_owned"),
    cappedDocs(menus.where("lastEditedBy", "==", uid), MAX_SECTION_ROWS, "realtime_menus_edited"),
    cappedDocs(
      menus.where("participantIds", "array-contains", uid),
      MAX_SECTION_ROWS,
      "realtime_menus_joined",
    ),
  ]);
  return { owned, edited, joined };
}

function permissionOf(doc: Snap, uid: string): unknown {
  const participants = doc.get("participants");
  if (participants === null || typeof participants !== "object") return null;
  const value = (participants as Record<string, unknown>)[uid];
  return typeof value === "string" ? value : null;
}

async function realtimeMenus(database: admin.firestore.Firestore, uid: string): Promise<Row[]> {
  const { owned, edited, joined } = await realtimeMenuDocs(database, uid);
  const rows = new Map<string, Row>();
  const rowFor = (doc: Snap): Row => {
    const row = rows.get(doc.id) ?? { menuId: doc.id, relation: [] as string[] };
    rows.set(doc.id, row);
    return row;
  };
  for (const doc of owned) {
    const row = rowFor(doc);
    (row.relation as string[]).push("owner");
    Object.assign(row, project(doc.data(), REALTIME_OWNER_KEYS));
  }
  // scrubLastEditor leaves the user's own menus to the owned leg.
  for (const doc of edited.filter((d) => d.get("ownerId") !== uid)) {
    const row = rowFor(doc);
    (row.relation as string[]).push("last_editor");
    Object.assign(row, project(doc.data(), REALTIME_EDITOR_KEYS));
  }
  // removeRealtimeParticipation, likewise not on owned menus.
  for (const doc of joined.filter((d) => d.get("ownerId") !== uid)) {
    const row = rowFor(doc);
    (row.relation as string[]).push("participant");
    row.permission = permissionOf(doc, uid);
  }
  return sortRows([...rows.values()], "menuId");
}

/**
 * `removeVoteEntries`: the `votes.<uid>` key on the vote documents of menus the
 * user joined and does not own.
 */
async function realtimeMenuVotes(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<Row[]> {
  const joined = await cappedDocs(
    database.collection(Collections.realtimeMenus).where("participantIds", "array-contains", uid),
    MAX_SECTION_ROWS,
    "realtime_menus_joined",
  );
  const rows: Row[] = [];
  let scanned = 0;
  for (const menu of joined.filter((d) => d.get("ownerId") !== uid)) {
    const votes = await cappedDocs(menu.ref.collection("votes"), MAX_SECTION_ROWS, "menu_votes");
    // Other people's menus set how many vote documents there are to read.
    scanned += votes.length;
    if (scanned > MAX_SECTION_ROWS * RAW_READ_FACTOR) {
      throw new Decline("raw_realtime_menu_votes", scanned);
    }
    for (const vote of votes) {
      const ballot = vote.get("votes");
      if (ballot === null || typeof ballot !== "object" || !(uid in ballot)) continue;
      const choice = (ballot as Record<string, unknown>)[uid];
      rows.push({
        menuId: menu.id,
        voteId: vote.id,
        optionId: typeof choice === "string" ? choice : null,
      });
      if (rows.length > MAX_SECTION_ROWS) throw new Decline("realtime_menu_votes", rows.length);
    }
  }
  return sortRows(rows, "menuId");
}

/**
 * `presence/{uid}` under each realtime document the cascade erases it from:
 * owned ones (all children go) and joined ones it does not own.
 */
async function realtimePresence(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<Row[]> {
  const parents: Array<{ collection: string; doc: Snap }> = [];
  for (const collection of [Collections.realtimeMenus, Collections.realtimeResources]) {
    const ref = database.collection(collection);
    const [owned, joined] = await Promise.all([
      cappedDocs(ref.where("ownerId", "==", uid).select(), MAX_SECTION_ROWS, `${collection}_owned`),
      cappedDocs(
        ref.where("participantIds", "array-contains", uid).select("ownerId"),
        MAX_SECTION_ROWS,
        `${collection}_joined`,
      ),
    ]);
    const seen = new Set<string>();
    for (const doc of [...owned, ...joined.filter((d) => d.get("ownerId") !== uid)]) {
      if (seen.has(doc.id)) continue;
      seen.add(doc.id);
      parents.push({ collection, doc });
    }
  }
  const snaps = await getAllInChunks(
    database,
    parents.map(({ doc }) => doc.ref.collection("presence").doc(uid)),
  );
  const rows: Row[] = [];
  snaps.forEach((presence, i) => {
    const data = presence.data();
    if (!presence.exists || data === undefined) return;
    const { collection, doc } = parents[i];
    rows.push({ collection, resourceId: doc.id, ...project(data, PRESENCE_KEYS) });
  });
  return sortRows(rows, "resourceId");
}

/** `deleteShoppingLists`' legacy leg: every `users/{uid}/shopping_lists` ref and its items. */
async function legacyShoppingLists(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<Row[]> {
  const refs = await database
    .collection(Collections.users)
    .doc(uid)
    .collection("shopping_lists")
    .listDocuments();
  if (refs.length > MAX_SECTION_ROWS) throw new Decline("legacy_shopping_lists", refs.length);
  const rows: Row[] = [];
  let items = 0;
  for (const ref of refs) {
    const [list, children] = await Promise.all([
      ref.get(),
      cappedDocs(ref.collection("items"), MAX_SECTION_ROWS, "legacy_list_items"),
    ]);
    items += children.length;
    if (items > MAX_SECTION_ROWS) throw new Decline("legacy_list_items", items);
    rows.push({
      listId: ref.id,
      ...project(list.data() ?? {}, LEGACY_LIST_KEYS),
      items: sortRows(
        children.map((doc) => ({ itemId: doc.id, ...project(doc.data(), LEGACY_ITEM_KEYS) })),
        "itemId",
      ),
    });
  }
  return sortRows(rows, "listId");
}

function idRows(docs: Snap[], idKey: string, keys: Allowlist): Row[] {
  return sortRows(
    docs.map((doc) => ({ [idKey]: doc.id, ...project(doc.data(), keys) })),
    idKey,
  );
}

export const REALTIME_LEGACY_SECTIONS: readonly SectionDef[] = [
  // deleteRealtimeMenus
  { name: "realtime_menus", read: realtimeMenus },
  { name: "realtime_menu_votes", read: realtimeMenuVotes },
  // deleteRealtimeMenus and deleteRealtimeResources, the presence children
  { name: "realtime_presence", read: realtimePresence },
  {
    // deleteRealtimeResources, via scrubLastEditor
    name: "realtime_resources_last_edited",
    read: async (database, uid) =>
      idRows(
        (
          await cappedDocs(
            database.collection(Collections.realtimeResources).where("lastEditedBy", "==", uid),
            MAX_SECTION_ROWS,
            "realtime_resources_last_edited",
          )
        ).filter((doc) => doc.get("ownerId") !== uid),
        "resourceId",
        REALTIME_EDITOR_KEYS,
      ),
  },
  {
    // deleteRecipes, the top-level leg
    name: "legacy_recipes",
    read: async (database, uid) =>
      idRows(
        await cappedDocs(
          database.collection(Collections.recipes).where("userId", "==", uid),
          MAX_SECTION_ROWS,
          "legacy_recipes",
        ),
        "recipeId",
        LEGACY_RECIPE_KEYS,
      ),
  },
  { name: "legacy_shopping_lists", read: legacyShoppingLists },
  {
    // deleteCommentsAndRatings, the collection-group comments leg
    name: "legacy_comments",
    read: async (database, uid) =>
      idRows(
        await cappedDocs(
          database.collectionGroup("comments").where("commentedBy", "==", uid),
          MAX_SECTION_ROWS,
          "legacy_comments",
        ),
        "commentId",
        LEGACY_COMMENT_KEYS,
      ),
  },
  {
    // deleteCommentsAndRatings, the collection-group ratings leg
    name: "legacy_ratings",
    read: async (database, uid) =>
      idRows(
        await cappedDocs(
          database.collectionGroup("ratings").where("ratedBy", "==", uid),
          MAX_SECTION_ROWS,
          "legacy_ratings",
        ),
        "ratingId",
        LEGACY_RATING_KEYS,
      ),
  },
  {
    // deleteMenus, the inbound `sharedToUserIds` leg; the menu is the sharer's
    name: "legacy_menus_received",
    read: async (database, uid) =>
      idRows(
        await cappedDocs(
          database.collection("menus").where("sharedToUserIds", "array-contains", uid).select(),
          MAX_SECTION_ROWS,
          "legacy_menus_received",
        ),
        "menuId",
        {},
      ),
  },
  {
    // onUserDeleted's cleanupLegacySharedWithArraysWithDb; the share is the sharer's
    name: "legacy_shared_with",
    read: async (database, uid) =>
      idRows(
        await cappedDocs(
          database
            .collection(Collections.sharedContent)
            .where("sharedWith", "array-contains", uid)
            .select(),
          MAX_SECTION_ROWS,
          "legacy_shared_with",
        ),
        "shareId",
        {},
      ),
  },
];
