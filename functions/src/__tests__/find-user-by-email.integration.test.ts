/**
 * Emulator-backed integration test for the BUT-2264 `findUserByEmail`
 * callable core (`findUserByEmailWithDeps`).
 *
 * The Auth lookup is injected (a map of address to uid), so the test needs
 * only the Firestore emulator. The Admin SDK bypasses rules, so seeding is
 * plain writes.
 *
 * Run: npx ts-node src/__tests__/find-user-by-email.integration.test.ts
 */

const PROJECT_ID = "butlery-find-user-by-email-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { findUserByEmailWithDeps } = require("../social/find-user-by-email");

const RUN = Date.now().toString(36);

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

const accounts = new Map<string, string>();
const lookup = async (email: string) => accounts.get(email) ?? null;
const caller = `caller-${RUN}`;

/** An account with [address] in Auth and the given profile and user docs. */
async function account(
  tag: string,
  profile: Record<string, unknown> | null,
  user: Record<string, unknown> = {},
): Promise<{ uid: string; email: string }> {
  const uid = `${tag}-${RUN}`;
  const email = `${tag}-${RUN}@example.se`;
  accounts.set(email, uid);
  if (profile) {
    await db.doc(`public_profiles/${uid}`).set({ displayName: tag, ...profile });
  }
  await db.doc(`users/${uid}`).set(user);
  return { uid, email };
}

async function find(email: string): Promise<string | null> {
  return (await findUserByEmailWithDeps(db, lookup, caller, email)).uid;
}

async function run_(): Promise<void> {
  const open = await account("open", { allowEmailSearch: true });
  check("finds an account that allows e-mail search",
    (await find(open.email)) === open.uid);
  check("matches the address whatever its case and surrounding spaces",
    (await find(`  ${open.email.toUpperCase()} `)) === open.uid);

  const closed = await account("closed", { allowEmailSearch: false });
  check("an account that does not allow it is not found",
    (await find(closed.email)) === null);

  const unset = await account("unset", {});
  check("an account that never chose is not found",
    (await find(unset.email)) === null);

  const hidden = await account("hidden",
    { allowEmailSearch: true, isHidden: true });
  check("a hidden account is not found", (await find(hidden.email)) === null);

  const minor = await account("minor",
    { allowEmailSearch: true, isSearchable: false }, { isMinor: true });
  check("a minor who has not opted into search is not found",
    (await find(minor.email)) === null);

  const optedMinor = await account("optedminor",
    { allowEmailSearch: true, isSearchable: true }, { isMinor: true });
  check("a minor who opted into search is found",
    (await find(optedMinor.email)) === optedMinor.uid);

  const noProfile = await account("noprofile", null);
  check("an account without a profile is not found",
    (await find(noProfile.email)) === null);

  check("an unknown address is not found",
    (await find(`nobody-${RUN}@example.se`)) === null);

  accounts.set(`self-${RUN}@example.se`, caller);
  await db.doc(`public_profiles/${caller}`).set({ allowEmailSearch: true });
  check("the caller's own address does not find the caller",
    (await find(`self-${RUN}@example.se`)) === null);

  console.log(`\n${run - failed}/${run} passed` +
    (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
