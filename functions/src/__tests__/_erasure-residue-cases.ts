/**
 * BUT-2414: one fixture per `exportErasureResidue` section, read by
 * `erasure-residue.test.ts`.
 *
 * `seed` writes rows the section's cascade predicate matches, rows it does not
 * match, and on every exported row a `strayKey` no allowlist names. `rows` is
 * the ids the section must return, in order. `overCap` seeds one row past the
 * section's cap, where it has one.
 */

import * as admin from "firebase-admin";
import { FakeFirestore } from "./_fake-firestore";

export const UID = "requester-uid";
export const OTHER = "other-uid";
export const THIRD = "third-uid";
export const T0 = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);
export const T0_ISO = new Date(1_700_000_000_000).toISOString();
export const STRAY = { strayKey: "stray-value" };

export interface SectionCase {
  section: string;
  seed: (db: FakeFirestore) => void;
  /** The id field each returned row is identified by. */
  idKey: string;
  rows: string[];
  /** Set where a decision keeps another person's uid on the row (BUT-1798). */
  allowOther?: boolean;
  check?: (rows: Record<string, unknown>[]) => void;
  overCap?: (db: FakeFirestore) => void;
}

function many(db: FakeFirestore, n: number, path: (i: number) => string, data: object): void {
  for (let i = 0; i < n; i++) db.seed(path(i), { ...data });
}

function expect(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const ROWS = 2001;

export const CASES: SectionCase[] = [
  {
    section: "tag_overrides_log",
    idKey: "id",
    rows: ["t1"],
    seed: (db) => {
      db.seed("tag_overrides_log/t1", {
        userId: UID, recipeId: "r1", tag: "gluten", direction: "remove",
        triggeringIngredients: ["mjöl", 3], timestamp: T0, ...STRAY,
      });
      db.seed("tag_overrides_log/t2", { userId: OTHER, tag: "gluten" });
    },
    check: ([row]) => {
      expect(JSON.stringify(row.triggeringIngredients) === '["mjöl"]', "only string ingredients");
      expect(row.timestamp === T0_ISO, "timestamp as ISO");
    },
    overCap: (db) => many(db, ROWS, (i) => `tag_overrides_log/x${i}`, { userId: UID }),
  },
  {
    section: "parsing_corrections",
    idKey: "id",
    rows: ["p1"],
    seed: (db) => {
      db.seed("parsing_corrections/p1", {
        id: "p1", userId: UID, recipeId: "r1", timestamp: T0, source: "url",
        totalCorrections: 2, ...STRAY,
        titleCorrection: { original: "Pannkaka", corrected: "Pannkakor", ...STRAY },
        ingredientCorrections: [
          { type: "textModified", originalLine: "2 ägg", correctedLine: "3 ägg", ...STRAY },
        ],
        instructionCorrections: [{ type: "textModified", originalText: "a", correctedText: "b" }],
      });
      db.seed("parsing_corrections/p2", { id: "p2", userId: OTHER, source: "url" });
    },
    check: ([row]) => {
      expect(row.timestamp === T0_ISO, "timestamp as ISO");
      expect(!("strayKey" in (row.titleCorrection as object)), "stray key dropped in a nested map");
      const lines = row.ingredientCorrections as Record<string, unknown>[];
      expect(lines.length === 1 && lines[0].correctedLine === "3 ägg" && !("strayKey" in lines[0]), "nested list projected");
    },
    overCap: (db) => many(db, ROWS, (i) => `parsing_corrections/x${i}`, { userId: UID }),
  },
  {
    section: "guest_quota",
    idKey: "calls",
    rows: ["2"],
    seed: (db) => {
      db.seed(`guest_quotas/${UID}`, {
        importIds: ["i1"], calls: 2, updatedAt: T0, ...STRAY,
        imports: { i1: { open: 1, day: "2026-10-19", spent: false, ...STRAY } },
      });
      db.seed(`guest_quotas/${OTHER}`, { calls: 9 });
    },
    check: ([row]) => {
      const imports = row.imports as Record<string, Record<string, unknown>>;
      expect(imports.i1.open === 1 && imports.i1.day === "2026-10-19", "nested import kept");
    },
  },
  {
    section: "feature_retention_rows",
    idKey: "id",
    rows: [`${UID}_2026-10-01`],
    seed: (db) => {
      db.seed(`analytics/feature_retention/users/${UID}_2026-10-01`, {
        userId: UID, date: "2026-10-01", cooked: true, shopped: false, ...STRAY,
      });
      db.seed(`analytics/feature_retention/users/${OTHER}_2026-10-01`, { userId: OTHER });
    },
    overCap: (db) =>
      many(db, ROWS, (i) => `analytics/feature_retention/users/${UID}_${i}`, { userId: UID }),
  },
  {
    section: "retention_events",
    idKey: "id",
    rows: [`${UID}_d1`],
    seed: (db) => {
      db.seed(`analytics/retention/events/${UID}_d1`, {
        userId: UID, day: 1, timestamp: T0, wasActive: true, ...STRAY,
      });
      db.seed(`analytics/retention/events/${OTHER}_d1`, { userId: OTHER });
      db.seed(`analytics/lapsed_users/events/${UID}_x`, { userId: UID });
    },
    overCap: (db) => many(db, ROWS, (i) => `analytics/retention/events/e${i}`, { userId: UID }),
  },
  {
    section: "lapsed_user_events",
    idKey: "id",
    rows: [`${UID}_winback_7`],
    seed: (db) => {
      db.seed(`analytics/lapsed_users/events/${UID}_winback_7`, {
        userId: UID, daysInactive: 7, detectedAt: T0, variant: "a", ...STRAY,
      });
      db.seed(`analytics/lapsed_users/events/${OTHER}_winback_7`, { userId: OTHER });
    },
    overCap: (db) => many(db, ROWS, (i) => `analytics/lapsed_users/events/e${i}`, { userId: UID }),
  },
  {
    section: "account_deletion_request",
    idKey: "reason",
    rows: ["mitt eget skäl"],
    seed: (db) => {
      db.seed(`account_deletion_requests/${UID}`, {
        requestedAt: T0, scheduledFor: T0, reason: "mitt eget skäl", attempts: 1, ...STRAY,
      });
      db.seed(`account_deletion_requests/${OTHER}`, { reason: "theirs" });
    },
  },
  {
    section: "mfa_recovery_attempts",
    idKey: "failures",
    rows: ["2"],
    seed: (db) => {
      db.seed(`mfa_recovery_attempts/uid_${UID}`, { failures: 2, windowStart: 5, ...STRAY });
      db.seed(`mfa_recovery_attempts/uid_${OTHER}`, { failures: 9 });
      db.seed("mfa_recovery_attempts/ip_abc", { failures: 7 });
    },
  },
  {
    section: "scheduled_notifications",
    idKey: "id",
    rows: ["s1"],
    seed: (db) => {
      db.seed("scheduled_notifications/s1", {
        userId: UID, notificationType: "digest", deliverAt: T0, status: "pending", ...STRAY,
        payload: { title: "Hej", body: "Veckans meny", data: { senderId: OTHER } },
      });
      db.seed("scheduled_notifications/s2", { userId: OTHER });
    },
    check: ([row]) => {
      const payload = row.payload as Record<string, unknown>;
      expect(payload.title === "Hej" && !("data" in payload), "payload title kept, data dropped");
    },
    overCap: (db) => many(db, ROWS, (i) => `scheduled_notifications/x${i}`, { userId: UID }),
  },
  {
    section: "notification_send_events",
    idKey: "id",
    rows: ["e1"],
    seed: (db) => {
      db.seed("notification_send_events/e1", {
        userId: UID, notificationType: "digest", sentAt: T0, channel: "fcm", ...STRAY,
      });
      db.seed("notification_send_events/e2", { userId: OTHER });
    },
    overCap: (db) => many(db, ROWS, (i) => `notification_send_events/x${i}`, { userId: UID }),
  },
  {
    section: "notification_opened_events",
    idKey: "id",
    rows: [`${UID}_n1`],
    seed: (db) => {
      db.seed(`notification_opened_events/${UID}_n1`, {
        userId: UID, notificationId: "n1", openedAt: T0, ...STRAY,
      });
      db.seed(`notification_opened_events/${OTHER}_n1`, { userId: OTHER });
    },
    overCap: (db) => many(db, ROWS, (i) => `notification_opened_events/x${i}`, { userId: UID }),
  },
  {
    section: "notification_counters",
    idKey: "id",
    rows: ["2026-10-19"],
    seed: (db) => {
      db.seed(`users/${UID}/notificationCounters/2026-10-19`, { count: 3, ...STRAY });
      db.seed(`users/${OTHER}/notificationCounters/2026-10-18`, { count: 1 });
    },
    overCap: (db) => many(db, ROWS, (i) => `users/${UID}/notificationCounters/d${i}`, { count: 1 }),
  },
  {
    section: "recent_content_hashes",
    idKey: "id",
    rows: ["rolling"],
    seed: (db) => {
      db.seed(`users/${UID}/recentContentHashes/rolling`, {
        hashes: [{ hash: "h1", at: T0, eventId: "ev", ...STRAY }], ...STRAY,
      });
      db.seed(`users/${OTHER}/recentContentHashes/chat`, { hashes: [] });
    },
    check: ([row]) => {
      expect(JSON.stringify(row.hashes) === JSON.stringify([{ hash: "h1", at: T0_ISO }]), "hash list");
    },
    overCap: (db) => many(db, ROWS, (i) => `users/${UID}/recentContentHashes/d${i}`, {}),
  },
  {
    section: "deep_links",
    idKey: "id",
    rows: ["abc12345"],
    seed: (db) => {
      db.seed("deep_links/abc12345", {
        id: "abc12345", longUrl: `https://butlery.se/recipe/r1?from=${UID}`, createdAt: T0,
        createdBy: UID, clickCount: 0, ...STRAY,
        metadata: { isActive: true, expiresAt: "2026-11-27T10:00:00.000", ...STRAY },
      });
      db.seed("deep_links/abc12345/clicks/c1", { userId: OTHER, timestamp: T0 });
      db.seed("deep_links/theirs01", { createdBy: OTHER, longUrl: "x" });
    },
    check: ([row]) => {
      expect(row.createdAt === T0_ISO, "createdAt as ISO");
      expect(row.longUrl === `https://butlery.se/recipe/r1?from=${UID}`, "longUrl kept");
      expect(!("createdBy" in row) && !("clickCount" in row), "createdBy and clickCount dropped");
      const metadata = row.metadata as Record<string, unknown>;
      expect(
        JSON.stringify(metadata) === '{"isActive":true,"expiresAt":"2026-11-27T10:00:00.000"}',
        "only the metadata keys the app writes",
      );
    },
    overCap: (db) => many(db, ROWS, (i) => `deep_links/x${i}`, { createdBy: UID }),
  },
  {
    section: "shares_sent",
    idKey: "shareId",
    rows: ["S1"],
    allowOther: true,
    seed: (db) => {
      db.seed("shared_content/S1", {
        sharedByUserId: UID, sharedToUserIds: [OTHER], title: "Min lista", sharedAt: T0,
        listData: { items: [{ addedByDisplayName: "Third" }] }, blockHeldUserIds: [THIRD], ...STRAY,
      });
      db.seed("shared_content/S2", { sharedByUserId: OTHER, sharedToUserIds: [UID] });
    },
    check: ([row]) => {
      expect(JSON.stringify(row.sharedToUserIds) === JSON.stringify([OTHER]), "recipients kept (BUT-1798)");
      expect(!("listData" in row) && !JSON.stringify(row).includes(THIRD), "copy and hold dropped");
    },
    overCap: (db) => many(db, 501, (i) => `shared_content/o${i}`, { sharedByUserId: UID }),
  },
  {
    section: "share_memberships",
    idKey: "shareId",
    rows: ["S1", "S2"],
    seed: (db) => {
      db.seed(`shared_content/S1/members/${UID}`, {
        userId: UID, displayName: "Me", addedBy: OTHER, role: "viewer", addedAt: 5, ...STRAY,
      });
      db.seed(`shared_content/S2/members/${UID}`, { userId: UID, addedBy: UID });
      db.seed(`shared_content/S1/members/${OTHER}`, { userId: OTHER });
      db.seed(`users/${OTHER}/friend_categories/c/members/${UID}`, { userId: UID });
      db.seed(`shared_content/S1/x/y/members/${UID}`, { userId: UID });
    },
    check: ([first, second]) => {
      expect(!("addedBy" in first) && second.addedBy === UID, "addedBy only when it is the requester");
    },
    overCap: (db) => many(db, ROWS, (i) => `shared_content/s${i}/members/${UID}`, { userId: UID }),
  },
  {
    section: "share_engagements",
    idKey: "shareId",
    rows: ["S1"],
    seed: (db) => {
      db.seed(`shared_content/S1/engagements/${UID}`, {
        userId: UID, action: "viewed", timestamp: T0, ...STRAY,
      });
      db.seed(`shared_content/S1/engagements/${OTHER}`, { userId: OTHER });
      db.seed(`recipes/r/engagements/${UID}`, { userId: UID });
    },
    overCap: (db) => many(db, ROWS, (i) => `shared_content/s${i}/engagements/${UID}`, { userId: UID }),
  },
  {
    section: "chat_groups_left",
    idKey: "groupId",
    rows: ["G1", "G2"],
    seed: (db) => {
      db.seed("chat_groups/G1", {
        departedUserIds: [UID, OTHER], name: "Hemlig", memberIds: [OTHER],
        sourceCategoryOwnerId: UID, sourceCategoryId: "cat-0", ...STRAY,
      });
      db.seed("chat_groups/G2", {
        sourceCategoryOwnerId: UID, sourceCategoryId: "cat-1", memberIds: [OTHER], ...STRAY,
      });
      db.seed("chat_groups/G3", { departedUserIds: [OTHER] });
    },
    check: ([g1, g2]) => {
      expect(g1.recorded_as_departed === true && !("name" in g1), "departed row");
      expect(g1.sourceCategoryId === "cat-0", "a group in both legs keeps both facts");
      expect(g2.sourceCategoryId === "cat-1" && g2.recorded_as_departed === false, "pointer row");
    },
    overCap: (db) => many(db, 201, (i) => `chat_groups/d${i}`, { departedUserIds: [UID] }),
  },
  {
    section: "conversation_roster_rows",
    idKey: "conversationId",
    rows: ["C1"],
    seed: (db) => {
      db.seed(`conversations/C1/participants/${UID}`, {
        conversationId: "C1", participantId: UID, displayName: "Me", joinedAt: T0, ...STRAY,
      });
      db.seed(`conversations/C1/participants/${OTHER}`, { participantId: OTHER });
    },
    overCap: (db) =>
      many(db, ROWS, (i) => `conversations/c${i}/participants/${UID}`, { participantId: UID }),
  },
  {
    section: "report_history_as_reporter",
    idKey: "reportId",
    rows: ["R1"],
    seed: (db) => {
      db.seed(`user_moderation/${OTHER}/report_history/R1`, {
        reportId: "R1", reporterId: UID, reason: "spam", contentType: "recipe",
        contentId: "recipe-1", expireAt: T0, ...STRAY,
      });
      db.seed(`user_moderation/${OTHER}/report_history/R2`, { reporterId: THIRD });
    },
    overCap: (db) =>
      many(db, ROWS, (i) => `user_moderation/u${i}/report_history/r${i}`, { reporterId: UID }),
  },
  {
    section: "active_users",
    idKey: "parentId",
    rows: ["rec-1"],
    seed: (db) => {
      db.seed(`recipePresence/rec-1/activeUsers/${UID}`, {
        userId: UID, displayName: "Me", lastSeen: T0, ...STRAY,
      });
      db.seed(`recipePresence/rec-1/activeUsers/${OTHER}`, { userId: OTHER });
    },
    check: ([row]) => expect(row.parentCollection === "recipePresence", "parent collection"),
    overCap: (db) => many(db, ROWS, (i) => `shoppingPresence/l${i}/activeUsers/${UID}`, { userId: UID }),
  },
];
