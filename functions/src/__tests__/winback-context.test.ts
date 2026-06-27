/**
 * BUT-934: Contextual win-back copy tests.
 *
 * Pure logic — no live Firestore. The friend-share lookup is injected via
 * the `loadRecentShare` seam; the default loader's doc-filtering is proven
 * separately against a tiny fake query snapshot.
 *
 * Run with: npx ts-node src/__tests__/winback-context.test.ts
 */

import {
  resolveContextualWinbackCopy,
  loadRecentShareDefault,
  SHARE_RECENCY_MS,
  type ContextualCopy,
} from "../analytics/winback-context";

interface TestCase {
  name: string;
  fn: () => Promise<void> | void;
}

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

function assertKey(copy: ContextualCopy | null, key: string): void {
  assert(copy != null, `expected copy, got null`);
  assert(
    copy!.contextKey === key,
    `expected contextKey ${key}, got ${copy!.contextKey} (body: ${copy?.body})`,
  );
}

const NOW = 1_700_000_000_000;

/** A user doc with everything set (no free signal would fire). */
const FULLY_SET = {
  hasCompletedOnboarding: true,
  allergenPreferences: { gluten: "free" },
  publicRecipeCount: 0,
  friendsCount: 0,
};

/** Build a fake Firestore query snapshot from raw doc data rows. */
function fakeDb(rows: Array<Record<string, unknown>>): any {
  const snap = { docs: rows.map((data) => ({ data: () => data })) };
  const query: any = {
    where: () => query,
    orderBy: () => query,
    limit: () => query,
    get: async () => snap,
  };
  return { collection: () => query };
}

const cases: TestCase[] = [
  {
    name: "friend share (recent) wins and uses the sharer's first name",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy("u1", FULLY_SET, {
        now: NOW,
        loadRecentShare: async () => ({
          sharerName: "Anna Andersson",
          sharedAtMs: NOW - 1000,
        }),
      });
      assertKey(copy, "ctx_friend_share");
      assert(
        copy!.body === "Anna delade ett recept med dig",
        `unexpected body: ${copy!.body}`,
      );
    },
  },
  {
    name: "friend share outranks an unset-prefs user (priority order)",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy(
        "u1",
        { hasCompletedOnboarding: false }, // would otherwise be setup_prefs
        {
          now: NOW,
          loadRecentShare: async () => ({
            sharerName: "Bo",
            sharedAtMs: NOW,
          }),
        },
      );
      assertKey(copy, "ctx_friend_share");
    },
  },
  {
    name: "no share + onboarding incomplete → setup_prefs",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy(
        "u1",
        { hasCompletedOnboarding: false, allergenPreferences: { x: "y" } },
        { now: NOW, loadRecentShare: async () => null },
      );
      assertKey(copy, "ctx_setup_prefs");
    },
  },
  {
    name: "no share + missing allergenPreferences → setup_prefs",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy(
        "u1",
        { hasCompletedOnboarding: true },
        { now: NOW, loadRecentShare: async () => null },
      );
      assertKey(copy, "ctx_setup_prefs");
    },
  },
  {
    name: "prefs set + has recipes → saved_recipes",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy(
        "u1",
        { ...FULLY_SET, publicRecipeCount: 4 },
        { now: NOW, loadRecentShare: async () => null },
      );
      assertKey(copy, "ctx_saved_recipes");
    },
  },
  {
    name: "prefs set + no recipes + has friends → has_friends",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy(
        "u1",
        { ...FULLY_SET, friendsCount: 2 },
        { now: NOW, loadRecentShare: async () => null },
      );
      assertKey(copy, "ctx_has_friends");
    },
  },
  {
    name: "fully-set user with nothing actionable → null (generic fallback)",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy("u1", FULLY_SET, {
        now: NOW,
        loadRecentShare: async () => null,
      });
      assert(copy === null, `expected null, got ${JSON.stringify(copy)}`);
    },
  },
  {
    name: "friend-share lookup failure degrades to the next signal",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy(
        "u1",
        { hasCompletedOnboarding: false },
        {
          now: NOW,
          loadRecentShare: async () => {
            throw new Error("firestore boom");
          },
        },
      );
      assertKey(copy, "ctx_setup_prefs");
    },
  },
  {
    name: "single-word sharer name is used as-is",
    fn: async () => {
      const copy = await resolveContextualWinbackCopy("u1", FULLY_SET, {
        now: NOW,
        loadRecentShare: async () => ({ sharerName: "Cleo", sharedAtMs: NOW }),
      });
      assert(
        copy!.body === "Cleo delade ett recept med dig",
        `unexpected body: ${copy!.body}`,
      );
    },
  },

  // ----- default loader (the costed query path) -----
  {
    name: "default loader skips the user's own seeded share",
    fn: async () => {
      const db = fakeDb([
        { sharedByUserId: "u1", sharedByDisplayName: "Me", sharedAt: NOW },
        { sharedByUserId: "friend", sharedByDisplayName: "Eva", sharedAt: NOW },
      ]);
      const share = await loadRecentShareDefault(db, "u1", NOW);
      assert(share?.sharerName === "Eva", `expected Eva, got ${share?.sharerName}`);
    },
  },
  {
    name: "default loader skips a deleted-sharer tombstone",
    fn: async () => {
      const db = fakeDb([
        {
          sharedByUserId: "ghost",
          sharedByDisplayName: "[Raderad användare]",
          sharedAt: NOW,
        },
        { sharedByUserId: "friend", sharedByDisplayName: "Eva", sharedAt: NOW },
      ]);
      const share = await loadRecentShareDefault(db, "u1", NOW);
      assert(share?.sharerName === "Eva", `expected Eva, got ${share?.sharerName}`);
    },
  },
  {
    name: "default loader returns null when the newest valid share is stale",
    fn: async () => {
      const db = fakeDb([
        {
          sharedByUserId: "friend",
          sharedByDisplayName: "Eva",
          sharedAt: NOW - SHARE_RECENCY_MS - 1,
        },
      ]);
      const share = await loadRecentShareDefault(db, "u1", NOW);
      assert(share === null, `expected null for stale share, got ${JSON.stringify(share)}`);
    },
  },
  {
    name: "default loader returns null when there are no shares",
    fn: async () => {
      const share = await loadRecentShareDefault(fakeDb([]), "u1", NOW);
      assert(share === null, `expected null, got ${JSON.stringify(share)}`);
    },
  },
];

async function runTests(): Promise<void> {
  console.log("BUT-934: Contextual win-back copy tests\n");
  console.log("==============================================\n");

  let failed = 0;
  for (const c of cases) {
    try {
      await c.fn();
      console.log(`  PASS  ${c.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(`        ${err instanceof Error ? err.message : err}`);
    }
  }

  const total = cases.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : ""),
  );
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error(err);
  process.exit(1);
});
