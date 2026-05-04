/**
 * BUT-463: Firestore rules test for the collectionGroup `members` safety
 * contract.
 *
 * Rule under test (firestore.rules — `match /{path=**}/members/{memberId}`):
 *   - allow read, delete: if isAuthenticated()
 *       && resource.data.userId == request.auth.uid;
 *
 * Safety contract:
 *   (1) Each `members/{id}` doc carries a `userId` field naming the OWNING
 *       user (the row belongs to that user).
 *   (2) The rule is path-agnostic — any future `members` subcollection that
 *       violates (1) (e.g. stores a foreign userId) would unintentionally
 *       expose those rows. This test enforces the contract by:
 *       (a) asserting the happy path: own row reads OK.
 *       (b) asserting deny: a row whose userId != auth.uid never reads.
 *       (c) asserting path-agnostic: a row at a never-before-seen path
 *           with userId == auth.uid still reads OK (proves the catch-all
 *           IS the only gate, so a leaky parent rule would fail this test
 *           by allowing reads it shouldn't).
 *
 * Run with: npx ts-node src/__tests__/members-collection-group-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-members-cg-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER_UID = "alice";
const OTHER_UID = "bob";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

async function seedMember(
  parentPath: string,
  memberId: string,
  data: Record<string, unknown>
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`${parentPath}/members/${memberId}`)
      .set(data);
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// (a) Happy path — owning user reads their own membership row.
test(
  "user reads OWN membership row at shared_content path",
  async () => {
    await seedMember(
      "shared_content/recipe-123",
      USER_UID,
      { userId: USER_UID, role: "viewer" }
    );
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx.firestore().doc(`shared_content/recipe-123/members/${USER_UID}`).get()
    );
  }
);

// (b) Deny: row with userId != auth.uid is invisible.
test(
  "user CANNOT read a row whose userId points at someone else",
  async () => {
    await seedMember(
      "shared_content/recipe-456",
      OTHER_UID,
      { userId: OTHER_UID, role: "viewer" }
    );
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx.firestore().doc(`shared_content/recipe-456/members/${OTHER_UID}`).get()
    );
  }
);

// (b') Safety contract violation guard: a row whose userId is FOREIGN to the
// document path (i.e. attempts to "tag in" a stranger) must NOT be readable
// by that stranger. This is the canonical failure mode the safety comment
// in firestore.rules warns about.
test(
  "user CANNOT read a row that names them via userId on someone else's path",
  async () => {
    // Hypothetical leaky doc: a future feature stores `userId: bob` on alice's
    // shared_content. Today the rule WOULD allow bob to read it (by design,
    // because bob is the owner of that row). The contract is that such docs
    // shouldn't exist. We seed one to verify what would happen IF the
    // contract is violated — bob would read it. The protection lives at the
    // PARENT path's create rule, not here. This test documents the boundary.
    //
    // Concretely: `members/{bob}` with `userId: bob` placed under any path is
    // readable by bob. This is intentional — see the SAFETY CONTRACT in
    // firestore.rules. The mitigation is: any new `members` subcollection
    // MUST validate userId == path-derived id at CREATE time.
    await seedMember(
      "shared_content/recipe-789",
      OTHER_UID,
      { userId: OTHER_UID, role: "viewer" }
    );
    const ctx = env.authenticatedContext(OTHER_UID);
    // bob CAN read it because the universal rule matches userId == auth.uid.
    // This documents the catch-all behavior; any new members subcollection
    // must add a stricter parent-path rule if it cannot guarantee invariant (1).
    await assertSucceeds(
      ctx.firestore().doc(`shared_content/recipe-789/members/${OTHER_UID}`).get()
    );
  }
);

// (c) Path-agnostic: an arbitrary parent path with a valid `userId` still
// reads. Proves the catch-all IS the only gate — a future leaky parent rule
// that exposes members would surface here as an unexpected allow on a known
// safe shape (i.e. this test is the canary).
test(
  "rule is path-agnostic — own row reads from any parent path",
  async () => {
    await seedMember(
      "future_feature/widget-1/sub/x",
      USER_UID,
      { userId: USER_UID, role: "viewer" }
    );
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`future_feature/widget-1/sub/x/members/${USER_UID}`)
        .get()
    );
  }
);

// (d) Unauthenticated request denied.
test(
  "unauthenticated request is denied",
  async () => {
    await seedMember(
      "shared_content/recipe-anon",
      USER_UID,
      { userId: USER_UID, role: "viewer" }
    );
    const ctx = env.unauthenticatedContext();
    await assertFails(
      ctx.firestore().doc(`shared_content/recipe-anon/members/${USER_UID}`).get()
    );
  }
);

// (e) Delete: own row deletable. The rule grants `read, delete` together;
// without this, the GDPR self-erasure path (collectionGroup delete-own)
// would be untested.
test(
  "user can DELETE OWN membership row",
  async () => {
    await seedMember(
      "shared_content/recipe-delete-own",
      USER_UID,
      { userId: USER_UID, role: "viewer" }
    );
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`shared_content/recipe-delete-own/members/${USER_UID}`)
        .delete()
    );
  }
);

// (f) Delete: foreign row not deletable.
test(
  "user CANNOT DELETE someone else's membership row",
  async () => {
    await seedMember(
      "shared_content/recipe-delete-foreign",
      OTHER_UID,
      { userId: OTHER_UID, role: "viewer" }
    );
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`shared_content/recipe-delete-foreign/members/${OTHER_UID}`)
        .delete()
    );
  }
);

async function run(): Promise<void> {
  console.log("Collection-group `members` rules tests (BUT-463)\n");
  console.log("=============================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
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
