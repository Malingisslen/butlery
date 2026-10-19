/**
 * BUT-2414: the requester's rows on shared surfaces that erasure deletes or
 * anonymises.
 *
 * Each section's query is the predicate of the cascade step named beside it,
 * and each row carries only the requester's own fields. On `shares_sent` the
 * recipients' uids stay, as on the received `shared_content` sections
 * (BUT-1798).
 */

import * as admin from "firebase-admin";
import { Collections } from "../../shared/collections";
import {
  MAX_CHAT_GROUPS_PER_USER,
  isSharedContentParent,
} from "../../account/account-deletion-cascade";
import {
  Allowlist,
  Decline,
  Row,
  cappedDocs,
  project,
  scalars,
  sortRows,
} from "./project";
import { MAX_SECTION_ROWS, SectionDef } from "./account-sections";

/** Bounds the owned-share read, as `exportSharedResidue` does. */
export const MAX_SHARES_SENT = 500;

/**
 * The collection-group reads below also match rows outside `shared_content`,
 * so their raw read is bounded on its own.
 */
export const RAW_READ_FACTOR = 10;

/**
 * The top-level keys the share writers set (`recipe_sharing_manager`,
 * `social_menu_operations`, `shopping_social_share_module`). The embedded
 * `listData` and `menu` copies are not exported (see `KNOWN_GAPS`), nor are
 * `blockHeldUserIds` and `blockHeld`.
 */
export const SHARE_SENT_KEYS: Allowlist = {
  ...scalars(
    "contentType",
    "recipeId",
    "title",
    "description",
    "itemCount",
    "totalRecipes",
    "sharedByUserId",
    "sharedByDisplayName",
    "sharedByAvatarUrl",
    "sharedAt",
    "isActive",
    "listType",
    "menuType",
    "imageUrl",
    "mealType",
    "createdAt",
    "updatedAt",
    "deletedAt",
  ),
  sharedToUserIds: "strings",
  groupIds: "strings",
};

/** `SharedContentMember.toFirestore`; `addedBy` only when it is the requester. */
export const SHARE_MEMBER_KEYS: Allowlist = scalars(
  "userId",
  "displayName",
  "avatarUrl",
  "addedAt",
  "addedBy",
  "role",
  "hasViewed",
);

/** `EngagementMetadata.toFirestore`. */
export const SHARE_ENGAGEMENT_KEYS: Allowlist = scalars(
  "userId",
  "timestamp",
  "action",
  "targetId",
);

/** `ConversationParticipant.toFirestore` and `rosterRow`. */
export const ROSTER_ROW_KEYS: Allowlist = scalars(
  "conversationId",
  "participantId",
  "displayName",
  "avatarUrl",
  "joinedAt",
  "lastReadAt",
  "role",
  "isMuted",
);

/**
 * The reporter's own fields of `onReportCreated`'s row. The row lives under
 * the reported person's moderation record, so its path is never exported.
 */
export const REPORT_HISTORY_KEYS: Allowlist = scalars(
  "reportId",
  "reporterId",
  "reason",
  "contentType",
  "contentId",
  "expireAt",
);

/** The presence row the two presence repositories write. */
export const ACTIVE_USER_KEYS: Allowlist = scalars(
  "userId",
  "displayName",
  "avatarUrl",
  "joinedAt",
  "lastSeen",
  "isActive",
  "expiresAt",
);

/**
 * A `shared_content` subcollection's rows naming `uid`, kept only under a
 * top-level `shared_content` parent. The document-id range keeps rows under
 * other collections with the same group id (a friend category's `members`)
 * out of the raw read, so nobody else can push it past its bound.
 */
async function sharedContentChildRows(
  database: admin.firestore.Firestore,
  group: string,
  uid: string,
  bound: string,
): Promise<admin.firestore.QueryDocumentSnapshot[]> {
  const docs = await cappedDocs(
    database
      .collectionGroup(group)
      .where("userId", "==", uid)
      .where(admin.firestore.FieldPath.documentId(), ">=", database.doc("shared_content/\u0000"))
      .where(
        admin.firestore.FieldPath.documentId(),
        "<",
        database.doc("shared_content\u0000/\u0000"),
      ),
    MAX_SECTION_ROWS * RAW_READ_FACTOR,
    `raw_${bound}`,
  );
  const kept = docs.filter((doc) => {
    const parent = doc.ref.parent.parent;
    return parent !== null && isSharedContentParent(parent);
  });
  if (kept.length > MAX_SECTION_ROWS) throw new Decline(bound, kept.length);
  return kept;
}

function shareRow(
  doc: admin.firestore.QueryDocumentSnapshot,
  idKey: string,
  keys: Allowlist,
): Row {
  return {
    shareId: doc.ref.parent.parent?.id ?? "",
    [idKey]: doc.id,
    ...project(doc.data(), keys),
  };
}

/** The two `clearUnreachableChatGroupResiduals` legs, merged per group. */
async function chatGroupsLeft(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<Row[]> {
  const groups = database.collection(Collections.chatGroups);
  const [departed, sourced] = await Promise.all([
    cappedDocs(
      groups.where("departedUserIds", "array-contains", uid).select(),
      MAX_CHAT_GROUPS_PER_USER,
      "chat_groups_departed",
    ),
    cappedDocs(
      groups.where("sourceCategoryOwnerId", "==", uid).select("sourceCategoryId"),
      MAX_CHAT_GROUPS_PER_USER,
      "chat_groups_source_category",
    ),
  ]);
  const rows = new Map<string, Row>();
  for (const doc of departed) {
    rows.set(doc.id, { groupId: doc.id, recorded_as_departed: true });
  }
  for (const doc of sourced) {
    const row = rows.get(doc.id) ?? { groupId: doc.id, recorded_as_departed: false };
    row.sourceCategoryOwnerId = uid;
    row.sourceCategoryId = project(doc.data(), scalars("sourceCategoryId")).sourceCategoryId ?? null;
    rows.set(doc.id, row);
  }
  return sortRows([...rows.values()], "groupId");
}

export const SOCIAL_SECTIONS: readonly SectionDef[] = [
  {
    // removeFromSharedContent, the owned-share leg
    name: "shares_sent",
    read: async (database, uid) =>
      sortRows(
        (
          await cappedDocs(
            database.collection(Collections.sharedContent).where("sharedByUserId", "==", uid),
            MAX_SHARES_SENT,
            "shares_sent",
          )
        ).map((doc) => ({ shareId: doc.id, ...project(doc.data(), SHARE_SENT_KEYS) })),
        "shareId",
      ),
  },
  {
    // removeFromSharedContent, the `members` leg
    name: "share_memberships",
    read: async (database, uid) =>
      sortRows(
        (await sharedContentChildRows(database, "members", uid, "share_memberships")).map(
          (doc) => {
            const row = shareRow(doc, "memberId", SHARE_MEMBER_KEYS);
            if (doc.get("addedBy") !== uid) delete row.addedBy;
            return row;
          },
        ),
        "shareId",
      ),
  },
  {
    // removeFromSharedContent, the `engagements` leg
    name: "share_engagements",
    read: async (database, uid) =>
      sortRows(
        (await sharedContentChildRows(database, "engagements", uid, "share_engagements")).map(
          (doc) => shareRow(doc, "engagementId", SHARE_ENGAGEMENT_KEYS),
        ),
        "shareId",
      ),
  },
  // deleteChatGroupMemberships, via clearUnreachableChatGroupResiduals
  { name: "chat_groups_left", read: chatGroupsLeft },
  {
    // deleteMessages, via deleteOwnRosterRows
    name: "conversation_roster_rows",
    read: async (database, uid) =>
      sortRows(
        (
          await cappedDocs(
            database
              .collectionGroup(Collections.participants)
              .where("participantId", "==", uid),
            MAX_SECTION_ROWS,
            "conversation_roster_rows",
          )
        ).map((doc) => project(doc.data(), ROSTER_ROW_KEYS)),
        "conversationId",
      ),
  },
  {
    // deleteReportHistoryByReporter
    name: "report_history_as_reporter",
    read: async (database, uid) =>
      sortRows(
        (
          await cappedDocs(
            database.collectionGroup("report_history").where("reporterId", "==", uid),
            MAX_SECTION_ROWS,
            "report_history_as_reporter",
          )
        ).map((doc) => ({ reportId: doc.id, ...project(doc.data(), REPORT_HISTORY_KEYS) })),
        "reportId",
      ),
  },
  {
    // onUserDeleted's cleanupPresenceRowsWithDb
    name: "active_users",
    read: async (database, uid) =>
      sortRows(
        (
          await cappedDocs(
            database.collectionGroup("activeUsers").where("userId", "==", uid),
            MAX_SECTION_ROWS,
            "active_users",
          )
        ).map((doc) => {
          const parent = doc.ref.parent.parent;
          return {
            parentCollection: parent?.parent.id ?? null,
            parentId: parent?.id ?? null,
            ...project(doc.data(), ACTIVE_USER_KEYS),
          };
        }),
        "parentId",
      ),
  },
];
