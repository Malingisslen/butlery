#!/usr/bin/env node
/**
 * BUT-2425: proves that the STAGING project is alive and enforcing what
 * production must also enforce, before anything is deployed to production.
 *
 * It runs in CI after the staging deploy (staging-verify.yml) with the
 * Workload Identity credential of the `staging` environment. The production
 * deploy refuses to start unless the latest run of that workflow is green for
 * the same backend code.
 *
 * Every check reads at most one document or one count, so a run costs a handful
 * of Firestore reads. Nothing is written and no LLM is called.
 *
 *   1. Cloud Run: every function service is Ready.
 *   2. Callables: a bare call is answered by the function itself (a 4xx JSON
 *      body), not by a 404/5xx from a function that failed to start.
 *   3. Rules: an anonymous Firestore read is denied, so the deployed ruleset is
 *      closed by default.
 *   4. Seed data: `system/config` exists and the ingredient database is not
 *      empty (a staging wiped by mistake would otherwise pass every test).
 *
 * Usage (from functions/, after `npm ci && npm run build`):
 *   node scripts/staging-smoke.js --project butlery-app-staging
 * `--inject-failure` makes the run end red on purpose; it exists to prove that
 * the production gate stops on a red run.
 */
"use strict";

const STAGING_PROJECT = "butlery-app-staging";
const REGION = "europe-west1";

// Callables from the post-deploy smoke gate in deploy-firebase.yml, one per family.
const PROBE_CALLABLES = [
  "structureRecipe",
  "requestAccountDeletion",
  "verifySignupAge",
  "sendNotification",
];

const CALLABLE_STATUSES = new Set([
  "UNAUTHENTICATED",
  "INVALID_ARGUMENT",
  "PERMISSION_DENIED",
  "FAILED_PRECONDITION",
]);

function parseArgs(argv) {
  const out = { project: "", injectFailure: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--project") out.project = argv[++i] || "";
    else if (argv[i].startsWith("--project=")) out.project = argv[i].slice("--project=".length);
    else if (argv[i] === "--inject-failure") out.injectFailure = true;
  }
  return out;
}

function serviceIsReady(service) {
  const conditions = (service.status && service.status.conditions) || [];
  const ready = conditions.find((c) => c.type === "Ready");
  return !!ready && ready.status === "True";
}

/** Each check returns { name, ok, detail }; none throws for an expected failure. */
async function checkCloudRun(listServices) {
  const services = await listServices();
  if (services.length === 0) {
    return { name: "cloud-run", ok: false, detail: "no Cloud Run services found" };
  }
  const notReady = services.filter((s) => !serviceIsReady(s)).map((s) => s.metadata.name);
  return {
    name: "cloud-run",
    ok: notReady.length === 0,
    detail:
      notReady.length === 0
        ? `${services.length} services Ready`
        : `not Ready: ${notReady.join(", ")}`,
  };
}

async function checkCallable(fetchFn, project, name) {
  const url = `https://${REGION}-${project}.cloudfunctions.net/${name}`;
  let res;
  try {
    res = await fetchFn(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ data: {} }),
    });
  } catch (err) {
    return { name: `callable:${name}`, ok: false, detail: `request failed: ${err.message}` };
  }
  let body = null;
  try {
    body = await res.json();
  } catch (_) {
    // A non-JSON answer is not the callable runtime talking.
  }
  const status = body && body.error && body.error.status;
  const ok = (res.status === 400 || res.status === 401 || res.status === 403) && CALLABLE_STATUSES.has(status);
  return {
    name: `callable:${name}`,
    ok,
    detail: ok ? `HTTP ${res.status} ${status}` : `HTTP ${res.status} ${status || "no callable error body"}`,
  };
}

async function checkAnonymousReadDenied(fetchFn, project) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${project}` +
    "/databases/(default)/documents/system/config";
  let res;
  try {
    res = await fetchFn(url);
  } catch (err) {
    return { name: "rules-anonymous-read", ok: false, detail: `request failed: ${err.message}` };
  }
  return {
    name: "rules-anonymous-read",
    ok: res.status === 403,
    detail: `HTTP ${res.status} (403 expected)`,
  };
}

async function checkSeedData(db) {
  const config = await db.doc("system/config").get();
  const ingredients = await db.collection("ingredients").count().get();
  const count = ingredients.data().count;
  const problems = [];
  if (!config.exists) problems.push("system/config is missing");
  if (count === 0) problems.push("ingredients is empty");
  return {
    name: "seed-data",
    ok: problems.length === 0,
    detail: problems.length === 0 ? `system/config present, ${count} ingredients` : problems.join("; "),
  };
}

async function runChecks({ project, injectFailure, listServices, fetchFn, db }) {
  const results = [];
  results.push(await checkCloudRun(listServices));
  for (const name of PROBE_CALLABLES) {
    results.push(await checkCallable(fetchFn, project, name));
  }
  results.push(await checkAnonymousReadDenied(fetchFn, project));
  results.push(await checkSeedData(db));
  if (injectFailure) {
    results.push({ name: "injected-failure", ok: false, detail: "requested with --inject-failure" });
  }
  return results;
}

async function main() {
  const { injectFailure } = parseArgs(process.argv.slice(2));
  const { requireProject } = require("../lib/admin/require-project");
  const project = requireProject({ allowed: [STAGING_PROJECT] });

  const admin = require("firebase-admin");
  admin.initializeApp({ projectId: project });

  const listServices = async () => {
    const { access_token: token } = await admin.credential.applicationDefault().getAccessToken();
    const url = `https://${REGION}-run.googleapis.com/apis/serving.knative.dev/v1/namespaces/${project}/services`;
    const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });
    if (!res.ok) throw new Error(`Cloud Run list failed: HTTP ${res.status}`);
    return (await res.json()).items || [];
  };

  const results = await runChecks({
    project,
    injectFailure,
    listServices,
    fetchFn: (url, init) => fetch(url, init),
    db: admin.firestore(),
  });

  for (const r of results) console.log(`${r.ok ? "PASS" : "FAIL"} ${r.name}: ${r.detail}`);
  const failed = results.filter((r) => !r.ok);
  console.log(`${results.length - failed.length}/${results.length} checks passed`);
  process.exit(failed.length ? 1 : 0);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}

module.exports = {
  serviceIsReady,
  checkCloudRun,
  checkCallable,
  checkAnonymousReadDenied,
  checkSeedData,
  runChecks,
  parseArgs,
  PROBE_CALLABLES,
};
