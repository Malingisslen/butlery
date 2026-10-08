/**
 * Firestore rules tests for `shared_content/{id}/views/{uid}` and
 * `shared_content/{id}/engagements/{uid}` (BUT-2268).
 *
 * The allow cases write exactly what `BaseMetadataRepository.addMetadata`
 * writes: a server `timestamp`, an `expireAt`, and the engagement `action`.
 * The rules once named fields no writer sent, so every view and every
 * "Importera" was refused and the app swallowed the error.
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080.
 * Run with: npm run test:rules:shared-content-metadata
 */

import * as fs from "fs";
import * as http from "http";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { serverTimestamp } from "firebase/firestore";

// MUTATION-PROBE SEAM (same contract as poll-votes-rules.test.ts).
const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-sc-meta";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

const VIEWER_UID = "scm-viewer-uid";
const OTHER_UID = "scm-other-uid";
const CONTENT_ID = "scm-content";

const RUN = Date.now().toString(36);

let env: RulesTestEnvironment;

function clearFirestore(): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: 8080,
        method: "DELETE",
        path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
      },
      (res) => {
        res.on("data", () => undefined);
        res.on("end", resolve);
      }
    );
    req.on("error", reject);
    req.end();
  });
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // BUT-2105: the emulator is long-lived locally, and every case below turns on
  // whether the counter document exists.
  await clearFirestore();
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

type Sub = "views" | "engagements";

function rowPath(sub: Sub, uid: string): string {
  return `shared_content/${CONTENT_ID}/${sub}/${uid}`;
}

/** `addMetadata` verbatim, plus the engagement's `action`. */
function writerPayload(sub: Sub, uid: string): Record<string, unknown> {
  return {
    userId: uid,
    timestamp: serverTimestamp(),
    expireAt: new Date(Date.now() + 90 * 24 * 3600 * 1000),
    ...(sub === "engagements" ? { action: "imported" } : {}),
  };
}

function write(
  actor: string,
  sub: Sub,
  target: string,
  data: Record<string, unknown>
): Promise<void> {
  return env
    .authenticatedContext(actor)
    .firestore()
    .doc(rowPath(sub, target))
    .set(data);
}

for (const sub of ["views", "engagements"] as Sub[]) {
  test(`${sub}: the writer's own first row is allowed`, async () => {
    await assertSucceeds(
      write(VIEWER_UID, sub, VIEWER_UID, writerPayload(sub, VIEWER_UID))
    );
  });

  test(`${sub}: writing the same row again (an update) is allowed`, async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(rowPath(sub, VIEWER_UID)).set({
        userId: VIEWER_UID,
        timestamp: new Date(),
      });
    });
    await assertSucceeds(
      write(VIEWER_UID, sub, VIEWER_UID, writerPayload(sub, VIEWER_UID))
    );
  });

  test(`${sub}: someone else's row is refused`, async () => {
    await assertFails(
      write(OTHER_UID, sub, VIEWER_UID, writerPayload(sub, VIEWER_UID))
    );
  });

  test(`${sub}: a body naming another user is refused`, async () => {
    await assertFails(
      write(VIEWER_UID, sub, VIEWER_UID, writerPayload(sub, OTHER_UID))
    );
  });

  test(`${sub}: a row without timestamp is refused`, async () => {
    const data = writerPayload(sub, VIEWER_UID);
    delete data.timestamp;
    await assertFails(write(VIEWER_UID, sub, VIEWER_UID, data));
  });
}

test("engagements: a row without action is refused", async () => {
  const data = writerPayload("engagements", VIEWER_UID);
  delete data.action;
  await assertFails(write(VIEWER_UID, "engagements", VIEWER_UID, data));
});

async function run(): Promise<void> {
  console.log(`shared-content views/engagements rules tests (BUT-2268) — run ${RUN}\n`);
  console.log("========================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    // The update cases depend on a row existing, so each case starts empty.
    await clearFirestore();
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  await teardown();
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
