/**
 * BUT-2425: tests for the staging smoke script. Plain Node + node:assert, run by
 * `npm run test:script-staging-smoke`. No network: fetch, Cloud Run and
 * Firestore are fakes.
 */
const assert = require("assert");
const { spawnSync } = require("child_process");
const path = require("path");
const smoke = require("../staging-smoke.js");

const results = [];
async function test(name, fn) {
  try {
    await fn();
    results.push({ name, ok: true });
  } catch (err) {
    results.push({ name, ok: false, err });
  }
}

const ready = (name) => ({ metadata: { name }, status: { conditions: [{ type: "Ready", status: "True" }] } });
const broken = (name) => ({ metadata: { name }, status: { conditions: [{ type: "Ready", status: "False" }] } });
const reply = (status, body) => ({ status, json: async () => body });
const callableOk = reply(401, { error: { status: "UNAUTHENTICATED" } });
const fakeDb = ({ config = true, count = 5 } = {}) => ({
  doc: () => ({ get: async () => ({ exists: config }) }),
  collection: () => ({ count: () => ({ get: async () => ({ data: () => ({ count }) }) }) }),
});
const healthyFetch = async (url) => (url.includes("firestore.googleapis.com") ? reply(403, {}) : callableOk);

(async () => {
  await test("refuses any project but staging before contacting anything", () => {
    assert.throws(() => smoke.requireStaging("butlery-prod"), /REFUSED/);
    assert.throws(() => smoke.requireStaging(""), /REFUSED/);
    const r = spawnSync(process.execPath, [path.resolve(__dirname, "../staging-smoke.js"), "--project", "butlery-prod"], {
      encoding: "utf8",
    });
    assert.notStrictEqual(r.status, 0);
    assert.match(r.stderr, /REFUSED/);
  });

  await test("all green when everything is healthy", async () => {
    const out = await smoke.runChecks({
      project: "butlery-app-staging",
      listServices: async () => [ready("a"), ready("b")],
      fetchFn: healthyFetch,
      db: fakeDb(),
    });
    assert.ok(out.every((r) => r.ok), JSON.stringify(out));
  });

  await test("a Cloud Run service that is not Ready is red and named", async () => {
    const r = await smoke.checkCloudRun(async () => [ready("a"), broken("structurerecipe")]);
    assert.strictEqual(r.ok, false);
    assert.match(r.detail, /structurerecipe/);
  });

  await test("no services at all is red", async () => {
    assert.strictEqual((await smoke.checkCloudRun(async () => [])).ok, false);
  });

  await test("a callable answered with 404 or 500 is red", async () => {
    for (const status of [404, 500, 503]) {
      const r = await smoke.checkCallable(async () => reply(status, {}), "p", "fn");
      assert.strictEqual(r.ok, false, `status ${status}`);
    }
  });

  await test("a callable answered with a 200 is red", async () => {
    const r = await smoke.checkCallable(async () => reply(200, { result: {} }), "p", "fn");
    assert.strictEqual(r.ok, false);
  });

  await test("a callable that cannot be reached is red, not thrown", async () => {
    const r = await smoke.checkCallable(async () => { throw new Error("ECONNRESET"); }, "p", "fn");
    assert.strictEqual(r.ok, false);
  });

  await test("an anonymous Firestore read that succeeds is red", async () => {
    const r = await smoke.checkAnonymousReadDenied(async () => reply(200, {}), "p");
    assert.strictEqual(r.ok, false);
  });

  await test("an empty ingredient database or missing config is red", async () => {
    assert.strictEqual((await smoke.checkSeedData(fakeDb({ count: 0 }))).ok, false);
    assert.strictEqual((await smoke.checkSeedData(fakeDb({ config: false }))).ok, false);
  });

  await test("--inject-failure ends red even when everything else is green", async () => {
    const out = await smoke.runChecks({
      project: "butlery-app-staging",
      injectFailure: true,
      listServices: async () => [ready("a")],
      fetchFn: healthyFetch,
      db: fakeDb(),
    });
    assert.ok(out.some((r) => !r.ok));
  });

  const failed = results.filter((r) => !r.ok);
  for (const r of results) {
    console.log(`${r.ok ? "PASS" : "FAIL"} ${r.name}`);
    if (!r.ok) console.log(r.err);
  }
  console.log(`${results.length - failed.length}/${results.length} passed`);
  process.exit(failed.length ? 1 : 0);
})();
