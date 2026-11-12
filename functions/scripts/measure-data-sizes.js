/**
 * BUT-2109: read-only count of rows left in `users/{uid}/conversation_memberships`,
 * the collection BUT-1850 stopped writing.
 * BUT-1441: read-only count of `feedback` documents whose `createdAt` is a
 * string without a time zone, the shape written before BUT-1408.
 * BUT-2110: read-only conversation sizes and rows in
 * `conversations/{id}/participants`.
 *
 * Prints counts only, never a uid or a document id. Writes nothing.
 *
 * Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> \
 *     node scripts/measure-data-sizes.js --project <id>
 */

const admin = require("firebase-admin");
const { requireProject } = require("../lib/admin/require-project");

admin.initializeApp({ projectId: requireProject() });
const db = admin.firestore();

// Same test as backfill-feedback-createdat-utc.js, so a zero here means that
// script has nothing to rewrite.
function hasZoneInfo(s) {
  return /Z$/.test(s) || /[+-]\d{2}:?\d{2}$/.test(s);
}

function pct(sorted, p) {
  if (sorted.length === 0) return 0;
  return sorted[Math.floor((sorted.length - 1) * p)];
}

function spread(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return `n=${sorted.length} p50=${pct(sorted, 0.5)} p95=${pct(sorted, 0.95)} max=${pct(sorted, 1)}`;
}

async function conversationMemberships() {
  // Other collections may share the name, so only rows under `users/{uid}`.
  const rows = await db.collectionGroup("conversation_memberships").select().get();
  const userRows = rows.docs.filter(
    (d) => d.ref.parent.parent?.parent.id === "users",
  ).length;
  console.log(`conversation_memberships_rows=${userRows}`);
}

async function feedbackTimezones() {
  const snap = await db.collection("feedback").select("createdAt").get();
  let zoneless = 0;
  let zoned = 0;
  let timestamp = 0;
  let other = 0;
  for (const doc of snap.docs) {
    const v = doc.get("createdAt");
    if (typeof v === "string") {
      if (hasZoneInfo(v)) zoned++;
      else zoneless++;
    } else if (v instanceof admin.firestore.Timestamp) {
      timestamp++;
    } else {
      other++;
    }
  }
  console.log(`feedback_docs=${snap.size}`);
  console.log(`feedback_createdat_zoneless=${zoneless}`);
  console.log(`feedback_createdat_utc_string=${zoned}`);
  console.log(`feedback_createdat_timestamp=${timestamp}`);
  console.log(`feedback_createdat_missing_or_other=${other}`);
}

async function conversationSizes() {
  const snap = await db
    .collection("conversations")
    .select("participantIds", "isGroup", "usesSubcollectionParticipants")
    .get();
  const groupSizes = [];
  const directSizes = [];
  const perUser = new Map();
  let usesSubcollection = 0;
  for (const doc of snap.docs) {
    const ids = doc.get("participantIds");
    const list = Array.isArray(ids) ? ids : [];
    (doc.get("isGroup") === true ? groupSizes : directSizes).push(list.length);
    for (const uid of list) perUser.set(uid, (perUser.get(uid) || 0) + 1);
    if (doc.get("usesSubcollectionParticipants") === true) usesSubcollection++;
  }
  console.log(`conversations=${snap.size}`);
  console.log(`group_conversation_sizes ${spread(groupSizes)}`);
  console.log(`direct_conversation_sizes ${spread(directSizes)}`);
  console.log(`conversations_per_user ${spread([...perUser.values()])}`);
  console.log(`conversations_flagged_subcollection=${usesSubcollection}`);

  const rows = await db.collectionGroup("participants").select().get();
  const conversationRows = rows.docs.filter(
    (d) => d.ref.parent.parent?.parent.id === "conversations",
  ).length;
  console.log(`conversation_participants_rows=${conversationRows}`);
}

async function main() {
  await conversationMemberships();
  await feedbackTimezones();
  await conversationSizes();
}

main().catch((err) => {
  console.error(`measure-data-sizes failed: ${err.code || err.name}`);
  process.exit(1);
});
