/**
 * deploy-manifest tests — pure unit level, no emulator.
 *
 * These assert the object the Firebase CLI actually ships. A v2 export carries
 * a `__endpoint` property that IS the deploy manifest, readable at import time,
 * so this suite imports `../index` (the real entry point, not a module) and
 * reads what would be uploaded.
 *
 * Importing the entry point is the whole point. Both invariants below are
 * produced mainly by the `setGlobalOptions(...)` call at the top of `index.ts`,
 * and a test that imported the individual trigger modules would never execute
 * that call — every assertion would then read an unconfigured endpoint and pass
 * or fail for reasons unrelated to what ships. Not ONLY that call, though: six
 * gen2 exports pin their own region (`moderateUpload`,
 * `syncConversationLastMessage`, `purgeExpiredAuditLogs` and the three
 * `migrations/` backfills), so a global region change moves 64 of the 70, and
 * the other six are held by their own options objects.
 *
 * 1. REGION. `onSchedule`/`onDocument*`/`onCall` read `getGlobalOptions()`
 *    EAGERLY at module-eval time, and `export … from` compiles to a `require`
 *    at its source position. So an export hoisted above the `setGlobalOptions`
 *    call silently deploys to us-central1 — reachable, billable, and wrong.
 *    Until now that hazard was guarded by a comment in `index.ts` and nothing
 *    else; a comment does not redden.
 *
 * 2. MAX INSTANCES. Cloud Run admits a new revision only if the sum of
 *    `cpu x maxInstances` across every service in the region fits the project's
 *    CPU quota, and an UNSET ceiling is not "no reservation" — it is the
 *    platform default of 100 per function. On 2026-08-17 that reserved ~7000
 *    vCPU across 70 services and a deploy failed on 53 of them, reporting
 *    `Container Healthcheck failed`, which reads like broken code and is not.
 *    Deleting `maxInstances` from `index.ts` keeps `tsc` and every other suite
 *    green and breaks only the next deploy, at the worst possible moment.
 *
 * Deliberately NOT asserted: that the count of endpoints equals some number.
 * Adding a function is routine and a hard-coded total would fail on every new
 * one, which trains people to edit the expected value rather than read it.
 * What matters is that EVERY endpoint carries both settings, whatever the
 * count.
 *
 * `onUserDeleted` is excluded by the `gcfv2` filter, not by name: it is a gen1
 * auth trigger, which v2 `setGlobalOptions` cannot configure. Filtering on the
 * platform field means a future gen1 export is excluded automatically, and —
 * more importantly — a gen1 function that is ever migrated to gen2 starts being
 * checked without anyone remembering to.
 *
 * That filter is also this suite's real vacuity surface, which is why
 * `gen2Endpoints()` asserts it found some. If the SDK ever renames `platform`,
 * all 71 endpoints still read, the filter silently returns an EMPTY list, and
 * every check below passes over nothing — a green run that measures nothing is
 * worse than a red one. `testManifestIsReadable` guards the layer above it
 * (`__endpoint` itself) and does NOT cover this.
 *
 * Mutation-tested 2026-08-17, six ways, each reddening exactly one check and
 * nothing else. A healthy tree is 7/7.
 *
 *   maxInstances deleted from `setGlobalOptions` -> the PRESENCE check, via its
 *     summary branch (all 70 uncapped, so no list is printed)          -> 6/7
 *   global ceiling raised to 100                 -> the VALUE pin      -> 6/7
 *   region changed                               -> the region check,
 *     naming the 64 it moves (six exports pin their own)               -> 6/7
 *   the `gcfv2` filter changed to a non-matching string -> `gen2Endpoints()`,
 *     twice, once per caller                                           -> 5/7
 *   `concurrency: 1` deleted from either ingredient cascade -> the cascade
 *     check, naming that one endpoint (two separate mutants)           -> 6/7
 *
 * Every mutated file was restored byte-identical afterwards, md5 compared.
 *
 * Run with: npx ts-node src/__tests__/deploy-manifest.test.ts
 */

// Two deliberate departures from every sibling suite, both forced by importing
// the ENTRY POINT rather than a module.
//
// 1. No `admin.initializeApp()` call here. `index.ts` calls it itself at import
//    time, and initialising first with a different configuration makes the
//    import throw `app/invalid-app-options` before a single assertion runs.
// 2. `FIREBASE_CONFIG` must be set BEFORE the entry point is loaded. The
//    Firebase CLI sets it in the deploy process; without it `onObjectFinalized`
//    in `storage/moderate-upload.ts` throws "Missing bucket name" at
//    module-eval. TypeScript's CommonJS emit keeps an import's `require` at its
//    source position (measured against this repo's own compiler options), so an
//    `import` written below these lines would also work — `require` is used
//    because it makes the ordering dependency explicit and survives both an
//    auto-import fixer and an ESM migration, where imports ARE hoisted.
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT
  || "butlery-test-deploy-manifest";
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG
  || JSON.stringify({
    projectId: "butlery-test-deploy-manifest",
    storageBucket: "butlery-test-deploy-manifest.appspot.com",
  });

// eslint-disable-next-line @typescript-eslint/no-var-requires
const entryPoint = require("../index") as Record<string, unknown>;

const EXPECTED_REGION = "europe-west1";
const EXPECTED_MAX_INSTANCES = 10;

interface Endpoint {
  platform?: string;
  region?: string[];
  // Same sentinel caveat as `maxInstances` below — unset is an object, not null.
  concurrency?: unknown;
  // `unknown`, not `number | null`. The unset value is neither — see the
  // sentinel note in `testEveryGen2EndpointCapsItsInstances`. Typing it as a
  // number invites a null check that cannot fire.
  maxInstances?: unknown;
}

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

function collectEndpoints(): Array<{ name: string; endpoint: Endpoint }> {
  const found: Array<{ name: string; endpoint: Endpoint }> = [];
  for (const [name, value] of Object.entries(entryPoint)) {
    const endpoint = (value as { __endpoint?: Endpoint } | undefined)
      ?.__endpoint;
    if (endpoint) found.push({ name, endpoint });
  }
  return found;
}

function testManifestIsReadable(): void {
  const all = collectEndpoints();
  // A guard, not a formality — but no longer the only alarm: `gen2Endpoints()`
  // below reddens too when this list comes back empty. What this check adds is
  // the DIAGNOSIS. Both fire if firebase-functions renames `__endpoint`; only
  // the gen2 guard fires if it renames `platform`. Seeing which one leads the
  // reader to the right SDK change instead of to a phantom config regression.
  record(
    "the entry point exposes deploy manifests to assert against",
    all.length > 0,
    "no export carried a `__endpoint` — firebase-functions changed its "
      + "deploy-manifest shape, NOT a configuration regression",
  );
}

// Every check below measures gen2 endpoints only, so an empty result from this
// filter would make all of them pass over nothing. `testManifestIsReadable`
// does not cover it: rename `platform` in the SDK and all 71 endpoints still
// carry a `__endpoint`, so that guard stays green while this list collapses to
// zero. Asserting here means the alarm fires in whichever check runs first
// rather than nowhere. It records one PASS per caller by design — a cheap
// duplicate line beats a silent hole.
function gen2Endpoints(): Array<{ name: string; endpoint: Endpoint }> {
  const gen2 = collectEndpoints().filter(
    ({ endpoint }) => endpoint.platform === "gcfv2",
  );
  record(
    "the manifest still identifies gen2 endpoints",
    gen2.length > 0,
    "no export carried platform === 'gcfv2' — the SDK changed the platform "
      + "field, so every check in this run measured an EMPTY list",
  );
  return gen2;
}

function testEveryGen2EndpointIsRegionPinned(): void {
  const offRegion = gen2Endpoints()
    .filter(({ endpoint }) => {
      const regions = endpoint.region;
      return (
        !Array.isArray(regions)
        || regions.length !== 1
        || regions[0] !== EXPECTED_REGION
      );
    });

  record(
    `every gen2 export deploys to ${EXPECTED_REGION}`,
    offRegion.length === 0,
    offRegion
      .map(({ name, endpoint }) => `${name}=${JSON.stringify(endpoint.region)}`)
      .join(", "),
  );
}

function testEveryGen2EndpointCapsItsInstances(): void {
  const gen2 = gen2Endpoints();

  // `typeof !== "number"`, NOT `== null`. An unset `maxInstances` does not come
  // back as null or undefined: firebase-functions puts a sentinel OBJECT there
  // (`RESET_VALUE`, because `maxInstances` is in the SDK's `RESETTABLE_OPTIONS`)
  // whose `toJSON` renders as `null`, so `JSON.stringify` prints "null" while
  // `x == null` is FALSE. An earlier draft of this check used `== null` and was
  // vacuous — it stayed green under a mutant that removed the option entirely,
  // which is exactly the regression it exists to catch. Caught by mutation
  // testing, not by review, so do not "simplify" it back to a null check.
  //
  // This is the check that catches a DELETED option. The value pin below does
  // not: it drops non-numbers before comparing, so it passes green in exactly
  // that case.
  const uncapped = gen2.filter(
    ({ endpoint }) => typeof endpoint.maxInstances !== "number",
  );
  record(
    "no gen2 export ships without an instance ceiling",
    uncapped.length === 0,
    uncapped.length === gen2.length
      ? "EVERY endpoint is uncapped — the global option is not being applied "
        + "at all"
      : uncapped.map(({ name }) => name).join(", "),
  );

  // Pin the VALUE, not just its presence. Raising the global ceiling back to
  // 100 leaves every endpoint capped — the check above stays green — and
  // re-arms the exact CPU-quota wall the option exists to avoid. That mutant is
  // the reason this check exists; it does NOT also cover the deleted-option
  // mutant, per the note above.
  //
  // A function that genuinely needs a different ceiling is registered here
  // rather than silently tolerated. An empty map is the current policy: one
  // number for everything. Comparing against a lone shared constant instead
  // would mean the only way to allow one override is to raise it for all 70,
  // which is how a cap stops being a cap.
  const ALLOWED_OVERRIDES: Record<string, number> = {};
  const notAtExpected = gen2.filter(
    ({ name, endpoint }) =>
      typeof endpoint.maxInstances === "number"
      && endpoint.maxInstances
        !== (ALLOWED_OVERRIDES[name] ?? EXPECTED_MAX_INSTANCES),
  );
  record(
    `every gen2 export sits at its expected ceiling (${EXPECTED_MAX_INSTANCES} `
      + "unless registered as an override)",
    notAtExpected.length === 0,
    notAtExpected.length === gen2.length
      ? `EVERY endpoint differs — the global ceiling is no longer `
        + `${EXPECTED_MAX_INSTANCES}`
      : notAtExpected
        .map(({ name, endpoint }) => `${name}=${endpoint.maxInstances}`)
        .join(", ")
        + " (a deliberate override belongs in ALLOWED_OVERRIDES, not here)",
  );
}

// `maxInstances` and `concurrency` are two halves of one decision and only one
// of them was pinned. The instance cap is what makes a burst of cascade events
// share containers; `concurrency: 1` is what stops them sharing. Deleting it
// leaves `tsc` and every other suite green — `cascade-retry-semantics.test.ts`
// greps each cascade's source for `retry: true`, `timeoutSeconds:` and the
// event-age guard, and nothing anywhere looks at `concurrency` — while a
// 500-row admin
// ingredient sync can then OOM a 512MiB container holding several 500-document
// pages at once, and `retry: true` re-delivers into the same packing until the
// event-age guard abandons the cascade for good.
//
// Named endpoints, not a blanket rule: every other function in the repo wants
// the default concurrency of 80, so a global assertion would be wrong.
const SERIALISED_ENDPOINTS = [
  "onIngredientSoftDeleted",
  "onIngredientPropertiesChanged",
];

function testCascadeTriggersAreSerialised(): void {
  const byName = new Map(collectEndpoints().map((e) => [e.name, e.endpoint]));

  // Missing is a FAIL, not a skip. A rename would otherwise silently empty this
  // check, which is the same vacuity the gen2 filter above had.
  const wrong = SERIALISED_ENDPOINTS.map((name) => ({
    name,
    actual: byName.has(name) ? byName.get(name)?.concurrency : "NO SUCH EXPORT",
  })).filter(({ actual }) => actual !== 1);

  record(
    "the two ingredient cascades ship with concurrency 1",
    wrong.length === 0,
    wrong.map(({ name, actual }) => `${name}=${JSON.stringify(actual)}`)
      .join(", ")
      + " (an unset concurrency reads as the RESET_VALUE sentinel, i.e. the"
      + " platform default of 80 — see the note on maxInstances above)",
  );
}

function main(): void {
  console.log("deploy-manifest tests\n");
  testManifestIsReadable();
  testEveryGen2EndpointIsRegionPinned();
  testEveryGen2EndpointCapsItsInstances();
  testCascadeTriggersAreSerialised();

  console.log(`\n${totalRun - totalFailed}/${totalRun} checks passed`);
  if (totalFailed > 0) process.exit(1);
}

main();
