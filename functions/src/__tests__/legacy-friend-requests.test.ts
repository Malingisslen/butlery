/**
 * BUT-2044 — the sweep that actually closes the Art. 17 gap.
 *
 * `friend_requests` is the pre-rename spelling of `social_requests`. A row
 * carries two uids and a free-text message, and no erasure path reached it.
 * `cleanupSocialRequests` is parameterised over the collection so ONE
 * implementation carries the two-subject contract, and `onUserDeleted` calls it
 * twice.
 *
 * This file pins the FUNCTION: that passing the legacy collection sweeps both
 * directions, spares strangers, and stages the cross-user audit row.
 *
 * It does NOT pin the CALL SITE. Deleting the second call in
 * `cleanupUserSocialData` leaves every case here green, because the call site
 * uses the module-scope `db` and is only reachable through the emulator. That
 * argument is pinned in `on-user-deleted.integration.test.ts`, which no CI lane
 * runs (accepted debt, BUT-1702) — so the wiring is covered by a suite someone
 * has to run by hand. Named rather than left to be assumed from this file's
 * existence.
 */
import * as admin from "firebase-admin";

// `on-user-deleted.ts` calls `admin.firestore()` at module scope, so the app
// must exist before it is required — the same shape the cascade suite uses.
// No credentials are needed: every Firestore call in this file goes through the
// injected fake, never through this app.
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-legacy-requests" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  cleanupSocialRequestsWithDb,
} = require("../cleanup/on-user-deleted");

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean, detail = ""): void {
  if (cond) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}\n        ${detail}`);
  }
}

const UID = "victim-uid";
const OTHER = "other-uid";

/** Enough Firestore to run two where-queries and a batch of deletes. */
function fakeDb(rows: Record<string, Record<string, unknown>>): any {
  const audits: unknown[] = [];
  const db: any = {
    _rows: rows,
    _audits: audits,
    collection(name: string) {
      if (name === "audit_logs") {
        return { doc: () => ({ _audit: true }) };
      }
      return {
        where(field: string, _op: string, value: string) {
          return {
            get: async () => {
              const docs = Object.entries(rows)
                .filter(([id, d]) => id.startsWith(`${name}/`) && d[field] === value)
                .map(([id, d]) => ({
                  id: id.split("/")[1],
                  data: () => d,
                  ref: { path: id },
                }));
              return { docs, empty: docs.length === 0 };
            },
          };
        },
      };
    },
    batch() {
      const ops: string[] = [];
      return {
        delete: (ref: { path: string }) => ops.push(ref.path),
        set: () => audits.push(1),
        commit: async () => {
          for (const path of ops) delete rows[path];
        },
      };
    },
  };
  return db;
}

async function main(): Promise<void> {
  console.log("BUT-2044 legacy friend_requests sweep\n");

  const rows: Record<string, Record<string, unknown>> = {
    "friend_requests/sent": { fromUserId: UID, toUserId: OTHER, message: "hej" },
    "friend_requests/received": { fromUserId: OTHER, toUserId: UID, message: "hej" },
    "friend_requests/strangers": { fromUserId: OTHER, toUserId: "third", message: "hej" },
  };
  const db = fakeDb(rows);
  const n = await cleanupSocialRequestsWithDb(db, UID, "friend_requests"); // LEGACY-SWEEP-OK

  check("a request the user SENT is erased", rows["friend_requests/sent"] === undefined);
  check("a request the user RECEIVED is erased", rows["friend_requests/received"] === undefined);
  check(
    "…and two strangers' request is untouched",
    rows["friend_requests/strangers"] !== undefined,
    JSON.stringify(rows),
  );
  check("the count covers both directions", n === 2, String(n));
  check(
    "each delete stages a cross-user audit row (BUT-886)",
    db._audits.length === 2,
    `audits: ${db._audits.length}`,
  );

  console.log(`\nBUT-2044 legacy friend_requests sweep: ${passed}/${passed + failed} passing`);
  if (failed > 0) process.exitCode = 1;
}

main();
