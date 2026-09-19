/**
 * Firestore rules tests for `users/{uid}/counters/shared_content` (BUT-2100).
 *
 * THE ONE THING THIS SUITE EXISTS TO GUARANTEE: a stranger may step somebody
 * else's unread badge UP by one, and may do nothing else to it. The limb has to stay open to
 * a stranger at all, because the person who SHARES content is the one who
 * increments the RECIPIENT's counter (`incrementUnreadCounter`), and it has to
 * stay open to the owner's absolute write, because `recalculateUnreadCount` is
 * the documented repair path and a recomputed total is not a step.
 *
 * An integer literal would pass a rule that production cannot satisfy — the
 * BUT-1482 failure, where the write was denied on every share and the
 * repository's best-effort catch swallowed it, so the badge silently never
 * moved. So the allow cases send what their writer sends: `FieldValue`
 * sentinels for the share and read paths, literals for the owner's repair.
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080.
 * Run with: npm run test:rules:shared-content-counters
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
import { serverTimestamp, increment } from "firebase/firestore";

// MUTATION-PROBE SEAM (same contract as poll-votes-rules.test.ts).
const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-counters";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

// The recipient. Owns the counter document.
const OWNER_UID = "ctr-owner-uid";
// The sharer. Not the owner, and the limb exists for this account.
const SHARER_UID = "ctr-sharer-uid";

const RUN = Date.now().toString(36);

function counterPath(uid: string): string {
  return `users/${uid}/counters/shared_content`;
}

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

/** Seeds an existing counter row with rules disabled. */
async function seedCounter(
  uid: string,
  data: Record<string, unknown>
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(counterPath(uid)).set(data);
  });
}

/** `incrementUnreadCounter` verbatim: merge-set, two increments, server stamp. */
function shareIncrement(
  actor: string,
  target: string,
  field = "unreadSharedRecipes"
): Promise<void> {
  return env
    .authenticatedContext(actor)
    .firestore()
    .doc(counterPath(target))
    .set(
      {
        [field]: increment(1),
        totalSharedContent: increment(1),
        lastUpdated: serverTimestamp(),
      },
      { merge: true }
    );
}

/** `decrementUnreadCounter` verbatim: update, one -1, no totalSharedContent. */
function readDecrement(
  actor: string,
  target: string,
  field = "unreadSharedRecipes"
): Promise<void> {
  return env
    .authenticatedContext(actor)
    .firestore()
    .doc(counterPath(target))
    .update({ [field]: increment(-1), lastUpdated: serverTimestamp() });
}

// ============================================================================
// The writers production actually has
// ============================================================================

test("the FIRST share creates the counter document", async () => {
  await assertSucceeds(shareIncrement(SHARER_UID, OWNER_UID));
});

test("a later share steps the existing counter", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 3,
    totalSharedContent: 3,
    lastUpdated: new Date(),
  });
  await assertSucceeds(shareIncrement(SHARER_UID, OWNER_UID));
});

test("clearing one badge (-1, no total) is allowed", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 2,
    totalSharedContent: 2,
    lastUpdated: new Date(),
  });
  await assertSucceeds(readDecrement(OWNER_UID, OWNER_UID));
});

test("the owner may write an absolute recomputed value (repair path)", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 9,
    totalSharedContent: 9,
    lastUpdated: new Date(),
  });
  await assertSucceeds(
    env
      .authenticatedContext(OWNER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: 2,
          totalSharedContent: 2,
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

// ============================================================================
// What BUT-2100 closes. Each DENY differs from an ALLOW above in one variable.
// ============================================================================

test("a stranger setting an arbitrary value is DENIED", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: 99,
          totalSharedContent: 99,
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

test("a stranger stepping by TWO is DENIED", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: increment(2),
          totalSharedContent: increment(2),
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

test("a stranger CREATING the row at an arbitrary value is DENIED", async () => {
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: 50,
          totalSharedContent: 50,
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

test("a stranger CREATING the row with a high MENUS value is DENIED", async () => {
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedMenus: 50,
          totalSharedContent: 1,
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

test("a stranger CREATING the row with a high SHOPPING-LIST value is DENIED", async () => {
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedShoppingLists: 50,
          totalSharedContent: 1,
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

test("a stranger zeroing somebody's badge from a high value is DENIED", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 7,
    totalSharedContent: 7,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: 0,
          totalSharedContent: 0,
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

test("a stranger driving a counter below zero is DENIED", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 0,
    totalSharedContent: 0,
    lastUpdated: new Date(),
  });
  await assertFails(readDecrement(SHARER_UID, OWNER_UID));
});

test("a stranger cannot step a STORED negative back up", async () => {
  // This case is what pins the `>= 0` floor. With the `-1` disjunct gone,
  // `unchanged || +1` already refuses a below-zero post-state, so the floor
  // does its work from a STORED negative — reachable because the pre-BUT-2100
  // rule accepted any value on these keys, and -3 + 1 = -2 satisfies `+1`.
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: -3,
    totalSharedContent: -3,
    lastUpdated: new Date(),
  });
  await assertFails(shareIncrement(SHARER_UID, OWNER_UID));
});

test("a stranger stepping a counter DOWN is DENIED", async () => {
  // The twin of the case above, one variable changed: the seed is
  // above zero, so the floor is not what refuses this. `decrementUnreadCounter`
  // runs as the counter's owner, so no shipped writer needs a stranger -1.
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 2,
    totalSharedContent: 2,
    lastUpdated: new Date(),
  });
  await assertFails(readDecrement(SHARER_UID, OWNER_UID));
});

test("a stranger setting the MENUS badge to an arbitrary value is DENIED", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    unreadSharedMenus: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        { unreadSharedMenus: 99, lastUpdated: serverTimestamp() },
        { merge: true }
      )
  );
});

test("a stranger setting the SHOPPING-LIST badge to an arbitrary value is DENIED", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    unreadSharedShoppingLists: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        { unreadSharedShoppingLists: 99, lastUpdated: serverTimestamp() },
        { merge: true }
      )
  );
});

test("a stranger stepping the TOTAL by five is DENIED", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: increment(1),
          totalSharedContent: increment(5),
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

test("the OWNER carrying an undeclared key is DENIED", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(OWNER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: 2,
          featured: true,
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

// ============================================================================
// The conjuncts that were already there, kept under test by this suite
// ============================================================================

test("an undeclared key is DENIED", async () => {
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: increment(1),
          totalSharedContent: increment(1),
          featured: true,
          lastUpdated: serverTimestamp(),
        },
        { merge: true }
      )
  );
});

test("a client-supplied lastUpdated is DENIED", async () => {
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .set(
        {
          unreadSharedRecipes: increment(1),
          totalSharedContent: increment(1),
          lastUpdated: new Date(),
        },
        { merge: true }
      )
  );
});

test("a stranger cannot READ the counter", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .get()
  );
});

test("the owner can read their own counter", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertSucceeds(
    env
      .authenticatedContext(OWNER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .get()
  );
});

test("a stranger cannot DELETE the counter", async () => {
  await seedCounter(OWNER_UID, {
    unreadSharedRecipes: 1,
    totalSharedContent: 1,
    lastUpdated: new Date(),
  });
  await assertFails(
    env
      .authenticatedContext(SHARER_UID)
      .firestore()
      .doc(counterPath(OWNER_UID))
      .delete()
  );
});

async function run(): Promise<void> {
  console.log(`shared-content counters rules tests (BUT-2100) — run ${RUN}\n`);
  console.log("========================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    // Every case seeds its own starting state, and the step rules read the
    // PREVIOUS value, so a leftover row from the case before would decide the
    // outcome.
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
