#!/usr/bin/env node
/**
 * BUT-2424: end-to-end journeys against the STAGING project with synthetic
 * accounts. Where staging-smoke.js only reads, this writes: each journey makes
 * its own throwaway account, runs real backend code against real Firestore and
 * Auth, asserts what is left, and removes everything it made.
 *
 * Journeys (server side, through the same functions the callables use):
 *   1. deletion-grace: schedule an account deletion, see the claim and the
 *      request, cancel it, see both gone.
 *   2. erasure: erase an account that owns a profile and a recipe, see the
 *      Auth user and both documents gone.
 *   3. revoke-other-sessions (BUT-2507): two real sessions for one account, the
 *      real revoke core, then the second session can no longer refresh or pass
 *      a revocation check while the fresh session works. This is the part the
 *      Auth emulator cannot show. The Google/Apple sign-in itself is the one
 *      thing synthetic accounts cannot do, so the caller's claims are supplied.
 *
 * Never production: the project gate (BUT-2419) refuses anything but
 * butlery-app-staging, and an emulator host variable is refused because it
 * would redirect the writes. Accounts are named `e2e-<runId>@staging-e2e.invalid`
 * and deleted in a `finally`, also when a journey fails.
 *
 * Usage (from functions/, after `npm ci && npm run build`):
 *   node scripts/staging-journeys.js --project butlery-app-staging
 */
"use strict";

const STAGING_PROJECT = "butlery-app-staging";
const STORAGE_BUCKET = "butlery-app-staging.firebasestorage.app";
// The web client key is public and already shipped in the app; read it from there instead of copying it.
function stagingWebApiKey() {
  const src = require("fs").readFileSync(require("path").join(__dirname, "../../lib/firebase_options_staging.dart"), "utf8");
  const m = /FirebaseOptions web = FirebaseOptions\(\s*apiKey: '([^']+)'/.exec(src);
  if (!m) throw new Error("web apiKey not found in firebase_options_staging.dart");
  return m[1];
}
const STAGING_REFERER = "https://butlery-app-staging.firebaseapp.com/";
const EMULATOR_HOST_VARS = [
  "FIRESTORE_EMULATOR_HOST",
  "FIREBASE_AUTH_EMULATOR_HOST",
  "FIREBASE_STORAGE_EMULATOR_HOST",
];

function parseArgs(argv) {
  const out = { injectFailure: false };
  for (const arg of argv) if (arg === "--inject-failure") out.injectFailure = true;
  return out;
}

function syntheticEmail(runId) {
  return `e2e-${runId}@staging-e2e.invalid`;
}

async function exists(ref) {
  return (await ref.get()).exists;
}

async function userIsGone(auth, uid) {
  try {
    await auth.getUser(uid);
    return false;
  } catch (err) {
    return err && err.code === "auth/user-not-found";
  }
}

/** Each journey returns { name, ok, detail }; an unexpected throw is a red journey. */
async function journeyDeletionGrace({ db, auth, uid, schedule, cancel, requestsCollection, claim }) {
  const name = "deletion-grace";
  const request = db.collection(requestsCollection).doc(uid);
  const { scheduledFor } = await schedule({ db, auth }, uid, "staging-e2e", Date.now());
  const claimed = (await auth.getUser(uid)).customClaims || {};
  const problems = [];
  if (claimed[claim] !== scheduledFor) problems.push("claim not set after scheduling");
  if (!(await exists(request))) problems.push("request missing after scheduling");
  const { cancelled } = await cancel({ db, auth }, uid);
  if (!cancelled) problems.push("cancel reported nothing to cancel");
  if ((((await auth.getUser(uid)).customClaims) || {})[claim] !== undefined) problems.push("claim left after cancel");
  if (await exists(request)) problems.push("request left after cancel");
  return { name, ok: problems.length === 0, detail: problems.join("; ") || "scheduled, claimed, cancelled, cleaned" };
}

async function journeyErasure({ db, auth, storage, uid, email, erase }) {
  const name = "erasure";
  const profile = db.collection("users").doc(uid);
  const recipe = profile.collection("recipes").doc("e2e-recipe");
  await profile.set({ e2e: true, createdAt: new Date() });
  await recipe.set({ title: "E2E-recept", e2e: true });
  const res = await erase({ db, auth, storage }, uid, email, "staging-e2e");
  const problems = [];
  if (!res.success) problems.push(`erase reported failure: ${(res.errors || []).join(", ") || "no detail"}`);
  if ((res.failedCollections || []).length > 0) problems.push(`failed: ${res.failedCollections.join(", ")}`);
  if (!(await userIsGone(auth, uid))) problems.push("Auth user still exists");
  if (await exists(profile)) problems.push("profile document still exists");
  if (await exists(recipe)) problems.push("recipe document still exists");
  return { name, ok: problems.length === 0, detail: problems.join("; ") || "account, profile and recipe erased" };
}

async function restSession(fetchFn, customToken, apiKey) {
  const res = await fetchFn(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
    { method: "POST", headers: { "content-type": "application/json", referer: STAGING_REFERER },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }) },
  );
  const body = await res.json();
  if (!res.ok) throw new Error(`sign-in failed: ${(body.error && body.error.message) || res.status}`);
  return { idToken: body.idToken, refreshToken: body.refreshToken };
}

async function refreshOutcome(fetchFn, refreshToken, apiKey) {
  const res = await fetchFn(
    `https://securetoken.googleapis.com/v1/token?key=${apiKey}`,
    { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", referer: STAGING_REFERER },
      body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}` },
  );
  const body = await res.json();
  return res.ok ? "refreshed" : (body.error && body.error.message) || `http ${res.status}`;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function journeyRevokeOtherSessions({ db, auth, uid, revoke, fetchFn, pauseMs, apiKey }) {
  const name = "revoke-other-sessions";
  const problems = [];
  await db.collection("users").doc(uid).set({ e2e: true, createdAt: new Date() });
  const a = await restSession(fetchFn, await auth.createCustomToken(uid), apiKey);
  const b = await restSession(fetchFn, await auth.createCustomToken(uid), apiKey);
  if ((await refreshOutcome(fetchFn, b.refreshToken, apiKey)) !== "refreshed") problems.push("second session could not refresh before the revoke");
  // Token validity is counted in whole seconds, so the sign-ins must predate the revoke.
  await sleep(pauseMs);
  const nowMs = Date.now();
  const { customToken } = await revoke(
    {
      getAccount: async () => ({ providerIds: ["google.com"], enrolledFactorCount: 0 }),
      createCustomToken: (id) => auth.createCustomToken(id),
      revokeRefreshTokens: (id) => auth.revokeRefreshTokens(id),
      enforceRateLimit: async () => {},
      markRevoked: (id) => db.collection("users").doc(id).update({ sessionsRevokedAt: new Date() }),
      audit: async () => {},
      now: () => nowMs,
    },
    { uid, token: { auth_time: Math.floor(nowMs / 1000), firebase: { sign_in_provider: "google.com" } } },
  );
  await sleep(pauseMs);
  const bAfter = await refreshOutcome(fetchFn, b.refreshToken, apiKey);
  if (bAfter === "refreshed") problems.push("second session still refreshes after the revoke");
  if ((await refreshOutcome(fetchFn, a.refreshToken, apiKey)) === "refreshed") problems.push("first session's old refresh token still works");
  const checked = await auth.verifyIdToken(b.idToken, true).then(() => "accepted", (e) => e.code);
  if (checked !== "auth/id-token-revoked") problems.push(`revocation check on second session said ${checked}`);
  const fresh = await restSession(fetchFn, customToken, apiKey);
  if ((await refreshOutcome(fetchFn, fresh.refreshToken, apiKey)) !== "refreshed") problems.push("the new session cannot refresh");
  if (!(((await db.collection("users").doc(uid).get()).data() || {}).sessionsRevokedAt)) problems.push("notice not written");
  return { name, ok: problems.length === 0, detail: problems.join("; ") || `second session ends with "${bAfter}", new session works, notice written` };
}

async function withSyntheticAccount({ auth, db, runId, suffix }, body) {
  const email = syntheticEmail(`${runId}-${suffix}`);
  const user = await auth.createUser({ email, emailVerified: true, disabled: false });
  try {
    return await body(user.uid, email);
  } finally {
    await auth.deleteUser(user.uid).catch(() => {});
    await db.recursiveDelete(db.collection("users").doc(user.uid)).catch(() => {});
    await db.collection("account_deletion_requests").doc(user.uid).delete().catch(() => {});
  }
}

async function runJourneys({ db, auth, storage, runId, injectFailure, deletion, erasure, sessions }) {
  const results = [];
  const run = async (suffix, journey) => {
    try {
      results.push(await withSyntheticAccount({ auth, db, runId, suffix }, journey));
    } catch (err) {
      results.push({ name: suffix, ok: false, detail: `threw: ${err.message}` });
    }
  };
  await run("deletion-grace", (uid) =>
    journeyDeletionGrace({
      db,
      auth,
      uid,
      schedule: deletion.schedule,
      cancel: deletion.cancel,
      requestsCollection: deletion.requestsCollection,
      claim: deletion.claim,
    }),
  );
  await run("erasure", (uid, email) =>
    journeyErasure({ db, auth, storage, uid, email, erase: erasure.erase }),
  );
  if (sessions) {
    await run("revoke-other-sessions", (uid) =>
      journeyRevokeOtherSessions({ db, auth, uid, revoke: sessions.revoke, fetchFn: sessions.fetchFn, pauseMs: sessions.pauseMs, apiKey: sessions.apiKey }),
    );
  }
  if (injectFailure) {
    results.push({ name: "injected-failure", ok: false, detail: "requested with --inject-failure" });
  }
  return results;
}

async function main() {
  const { injectFailure } = parseArgs(process.argv.slice(2));
  const emulators = EMULATOR_HOST_VARS.filter((n) => process.env[n]);
  if (emulators.length > 0) {
    throw new Error(`REFUSED: ${emulators.join(", ")} is set; the journeys would hit an emulator, not staging.`);
  }
  const { requireProject } = require("../lib/admin/require-project");
  const project = requireProject({ allowed: [STAGING_PROJECT] });

  const admin = require("firebase-admin");
  admin.initializeApp({ projectId: project, storageBucket: STORAGE_BUCKET });
  const sched = require("../lib/account/account-deletion-schedule");
  const del = require("../lib/account/request-account-deletion");
  const { Collections } = require("../lib/shared/collections");

  const results = await runJourneys({
    db: admin.firestore(),
    auth: admin.auth(),
    storage: admin.storage(),
    runId: `${Date.now().toString(36)}`,
    injectFailure,
    deletion: {
      schedule: sched.scheduleAccountDeletionWithDeps,
      cancel: sched.cancelAccountDeletionWithDeps,
      requestsCollection: Collections.accountDeletionRequests,
      claim: sched.DELETION_CLAIM,
    },
    erasure: { erase: del.runAccountDeletionWithDeps },
    sessions: {
      revoke: require("../lib/account/revoke-other-sessions").runRevokeOtherSessions,
      fetchFn: fetch,
      apiKey: stagingWebApiKey(),
      pauseMs: 1500,
    },
  });

  for (const r of results) console.log(`${r.ok ? "PASS" : "FAIL"} ${r.name}: ${r.detail}`);
  const failed = results.filter((r) => !r.ok);
  console.log(`${results.length - failed.length}/${results.length} journeys passed`);
  process.exit(failed.length ? 1 : 0);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}

module.exports = { runJourneys, journeyDeletionGrace, journeyErasure, journeyRevokeOtherSessions, syntheticEmail, parseArgs };
