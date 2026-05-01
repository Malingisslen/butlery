/**
 * BUT-458: Backfill recipe_comments denorm tests.
 *
 * Coverage:
 *   1. Migrates a comment missing recipeOwnerId — stamps owner from
 *      socialData.ownerId and shared list from memberPermissions
 *      (excluding the owner).
 *   2. Migrates a personal-recipe comment — stamps owner from createdBy
 *      and empty shared list.
 *   3. Idempotency: re-running skips already-migrated docs.
 *   4. Orphan handling: comment whose recipe doc is gone gets stamped
 *      with `recipeOwnerId = authorId, sharedWithUserIds = []` (graceful
 *      degradation; row stays author-only-readable).
 *   5. requireAdmin gate: non-admin caller is rejected with permission-denied.
 *   6. requireAdmin gate: admin caller is allowed through.
 *
 * Run with: npx ts-node src/__tests__/backfill-recipe-comments.test.ts
 */

import { runBackfill } from "../migrations/backfill-recipe-comments-denorm";
import { requireAdmin } from "../shared/require-admin";

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

interface FakeRecipe {
  /** Path-derived owner uid (the `users/{uid}/recipes/{recipeId}` parent uid). */
  ownerUid: string;
  /** Recipe id segment. */
  id: string;
  /** Stored core data; `socialData.ownerId` overrides path-derived uid when set. */
  data: Record<string, unknown>;
}

interface FakeComment {
  id: string;
  recipeId: string;
  authorId: string;
  /** Pre-migration: undefined; post-migration: stamped value. */
  recipeOwnerId?: string;
  sharedWithUserIds?: string[];
}

/** Optional hooks for per-test instrumentation (BUT-741 parallelism asserts). */
interface FakeDbHooks {
  /** Called every time `collectionGroup('recipes').get()` is invoked. */
  onResolveStart?: (recipeId: string) => void;
  /** Called when that resolve completes (after the artificial delay, if any). */
  onResolveEnd?: (recipeId: string) => void;
  /** Per-resolve artificial delay in ms (forces parallelism windows). */
  resolveDelayMs?: number;
}

/**
 * In-memory firestore stub matching only the surface used by runBackfill.
 * The shape mirrors `admin.firestore.Firestore` for the methods we call.
 */
function makeFakeDb(
  comments: FakeComment[],
  recipes: FakeRecipe[],
  hooks: FakeDbHooks = {}
) {
  // Track writes for assertions.
  const writes: Array<{ id: string; update: Record<string, unknown> }> = [];

  // Symbol-keyed back-pointer: each commentDoc.ref carries an opaque
  // pointer to its FakeComment so `batch.update(ref, data)` can mutate
  // the right entry even when the loop runs out of declaration order.
  const COMMENT_REF = Symbol("commentRef");

  function buildCommentDocSnap(c: FakeComment) {
    const ref: Record<string | symbol, unknown> = {
      update: async (_data: Record<string, unknown>) => {
        // Real firestore would write directly; we only inspect via batch.
      },
    };
    ref[COMMENT_REF] = c;
    return {
      id: c.id,
      ref,
      data() {
        const d: Record<string, unknown> = {
          recipeId: c.recipeId,
          authorId: c.authorId,
        };
        if (c.recipeOwnerId !== undefined) d.recipeOwnerId = c.recipeOwnerId;
        if (c.sharedWithUserIds !== undefined) {
          d.sharedWithUserIds = c.sharedWithUserIds;
        }
        return d;
      },
    };
  }

  function buildRecipeDocSnap(r: FakeRecipe) {
    return {
      id: r.id,
      ref: {
        // Path: users/{ownerUid}/recipes/{id} → parent.parent is users/{ownerUid}
        parent: {
          parent: { id: r.ownerUid },
        },
      },
      data() {
        return r.data;
      },
    };
  }

  return {
    writes,

    collection(name: string) {
      if (name !== "recipe_comments") {
        throw new Error(`unexpected collection: ${name}`);
      }
      let cursor: string | null = null;
      let limitN = 1000;
      const q = {
        orderBy(_field: unknown) {
          return q;
        },
        limit(n: number) {
          limitN = n;
          return q;
        },
        startAfter(after: string) {
          cursor = after;
          return q;
        },
        async get() {
          let filtered = comments.slice().sort((a, b) =>
            a.id.localeCompare(b.id)
          );
          if (cursor) {
            filtered = filtered.filter((c) => c.id > cursor!);
          }
          filtered = filtered.slice(0, limitN);
          return {
            empty: filtered.length === 0,
            size: filtered.length,
            docs: filtered.map(buildCommentDocSnap),
          };
        },
      };
      return q;
    },

    collectionGroup(name: string) {
      if (name !== "recipes") {
        throw new Error(`unexpected collectionGroup: ${name}`);
      }
      let targetId: string | null = null;
      const q = {
        where(_field: unknown, _op: string, value: string) {
          targetId = value;
          return q;
        },
        limit(_n: number) {
          return q;
        },
        async get() {
          hooks.onResolveStart?.(targetId ?? "");
          if (hooks.resolveDelayMs && hooks.resolveDelayMs > 0) {
            await new Promise((r) => setTimeout(r, hooks.resolveDelayMs));
          } else {
            // Yield once even with no delay so parallel scheduling has
            // a chance to interleave (microtask boundary).
            await new Promise((r) => setImmediate(r));
          }
          const found = recipes.filter((r) => r.id === targetId);
          hooks.onResolveEnd?.(targetId ?? "");
          return {
            empty: found.length === 0,
            docs: found.map(buildRecipeDocSnap),
          };
        },
      };
      return q;
    },

    batch() {
      return {
        update(ref: unknown, data: Record<string, unknown>) {
          writes.push({ id: "<batch>", update: data });
          // Resolve the back-pointer the snapshot stamped onto the ref.
          const target = (ref as Record<symbol, FakeComment | undefined>)[
            COMMENT_REF
          ];
          if (target) {
            target.recipeOwnerId = data.recipeOwnerId as string;
            target.sharedWithUserIds = data.sharedWithUserIds as string[];
          }
        },
        async commit() {
          // no-op
        },
      };
    },
  };
}

async function migratesCollabRecipeComment(): Promise<void> {
  const comments: FakeComment[] = [
    {
      id: "c1",
      recipeId: "recipe-collab",
      authorId: "author-uid",
    },
  ];
  const recipes: FakeRecipe[] = [
    {
      ownerUid: "owner-uid",
      id: "recipe-collab",
      data: {
        core: {
          createdBy: "owner-uid",
          socialData: {
            ownerId: "owner-uid",
            memberPermissions: {
              "owner-uid": 0,
              "member-1": 1,
              "member-2": 2,
            },
          },
        },
      },
    },
  ];
  const db = makeFakeDb(comments, recipes);
  const result = await runBackfill(db as never, {
    dryRun: false,
    maxComments: 1000,
  });

  const migrated = result.migrated === 1 && result.skipped === 0;
  const stamped =
    comments[0].recipeOwnerId === "owner-uid" &&
    Array.isArray(comments[0].sharedWithUserIds) &&
    comments[0].sharedWithUserIds!.length === 2 &&
    comments[0].sharedWithUserIds!.includes("member-1") &&
    comments[0].sharedWithUserIds!.includes("member-2") &&
    !comments[0].sharedWithUserIds!.includes("owner-uid");

  record(
    "migrates collab-recipe comment with members",
    migrated && stamped,
    `migrated=${result.migrated} owner=${comments[0].recipeOwnerId} shared=${JSON.stringify(comments[0].sharedWithUserIds)}`
  );
}

async function migratesPersonalRecipeComment(): Promise<void> {
  const comments: FakeComment[] = [
    {
      id: "c1",
      recipeId: "recipe-personal",
      authorId: "author-uid",
    },
  ];
  const recipes: FakeRecipe[] = [
    {
      ownerUid: "owner-uid",
      id: "recipe-personal",
      data: {
        core: {
          createdBy: "owner-uid",
          // No socialData → personal recipe.
        },
      },
    },
  ];
  const db = makeFakeDb(comments, recipes);
  const result = await runBackfill(db as never, {
    dryRun: false,
    maxComments: 1000,
  });

  const ok =
    result.migrated === 1 &&
    comments[0].recipeOwnerId === "owner-uid" &&
    Array.isArray(comments[0].sharedWithUserIds) &&
    comments[0].sharedWithUserIds!.length === 0;

  record(
    "migrates personal-recipe comment with empty shared list",
    ok,
    `migrated=${result.migrated} owner=${comments[0].recipeOwnerId} shared=${JSON.stringify(comments[0].sharedWithUserIds)}`
  );
}

async function idempotentRerunSkips(): Promise<void> {
  const comments: FakeComment[] = [
    {
      id: "c1",
      recipeId: "recipe-1",
      authorId: "author-uid",
      recipeOwnerId: "owner-uid",
      sharedWithUserIds: [],
    },
  ];
  const recipes: FakeRecipe[] = [
    {
      ownerUid: "owner-uid",
      id: "recipe-1",
      data: { core: { createdBy: "owner-uid" } },
    },
  ];
  const db = makeFakeDb(comments, recipes);
  const result = await runBackfill(db as never, {
    dryRun: false,
    maxComments: 1000,
  });

  const ok = result.migrated === 0 && result.skipped === 1;
  record(
    "idempotent re-run: already-migrated comment skipped",
    ok,
    `migrated=${result.migrated} skipped=${result.skipped}`
  );
}

async function orphanedRecipeStampsAuthorOnly(): Promise<void> {
  const comments: FakeComment[] = [
    {
      id: "c1",
      recipeId: "recipe-deleted",
      authorId: "author-uid",
    },
  ];
  // No recipes — orphaned comment.
  const recipes: FakeRecipe[] = [];
  const db = makeFakeDb(comments, recipes);
  const result = await runBackfill(db as never, {
    dryRun: false,
    maxComments: 1000,
  });

  const ok =
    result.migrated === 1 &&
    result.orphanedAuthorOnly === 1 &&
    comments[0].recipeOwnerId === "author-uid" &&
    Array.isArray(comments[0].sharedWithUserIds) &&
    comments[0].sharedWithUserIds!.length === 0;

  record(
    "orphaned comment (recipe gone) stamped author-only",
    ok,
    `migrated=${result.migrated} orphan=${result.orphanedAuthorOnly} owner=${comments[0].recipeOwnerId}`
  );
}

async function dryRunDoesNotMutate(): Promise<void> {
  const comments: FakeComment[] = [
    {
      id: "c1",
      recipeId: "recipe-1",
      authorId: "author-uid",
    },
  ];
  const recipes: FakeRecipe[] = [
    {
      ownerUid: "owner-uid",
      id: "recipe-1",
      data: { core: { createdBy: "owner-uid" } },
    },
  ];
  const db = makeFakeDb(comments, recipes);
  const result = await runBackfill(db as never, {
    dryRun: true,
    maxComments: 1000,
  });

  // dryRun still increments migrated counter (dry-run is a scan + count
  // mode), but the doc itself stays untouched.
  const ok =
    result.migrated === 1 &&
    comments[0].recipeOwnerId === undefined &&
    comments[0].sharedWithUserIds === undefined;

  record(
    "dry-run scans without mutating docs",
    ok,
    `migrated=${result.migrated} owner=${comments[0].recipeOwnerId}`
  );
}

async function requireAdminRejectsNonAdmin(): Promise<void> {
  const fakeRequest = {
    auth: {
      uid: "user-uid",
      token: { admin: false },
    },
    data: {},
  };
  let threw = false;
  let code = "";
  try {
    requireAdmin(fakeRequest as never);
  } catch (e: unknown) {
    threw = true;
    code = (e as { code?: string }).code ?? "";
  }
  const ok = threw && code === "permission-denied";
  record(
    "requireAdmin rejects non-admin caller",
    ok,
    `threw=${threw} code=${code}`
  );
}

async function requireAdminAllowsAdmin(): Promise<void> {
  const fakeRequest = {
    auth: {
      uid: "admin-uid",
      token: { admin: true },
    },
    data: {},
  };
  let threw = false;
  try {
    requireAdmin(fakeRequest as never);
  } catch {
    threw = true;
  }
  record("requireAdmin allows admin caller", !threw, `threw=${threw}`);
}

async function requireAdminRejectsUnauthenticated(): Promise<void> {
  const fakeRequest = { data: {} };
  let threw = false;
  let code = "";
  try {
    requireAdmin(fakeRequest as never);
  } catch (e: unknown) {
    threw = true;
    code = (e as { code?: string }).code ?? "";
  }
  const ok = threw && code === "unauthenticated";
  record(
    "requireAdmin rejects unauthenticated caller",
    ok,
    `threw=${threw} code=${code}`
  );
}

// =====================================================================
// BUT-741: parallelism + dedup tests
// =====================================================================

/**
 * Dedup pre-pass: 100 comments referencing 5 unique recipeIds should
 * trigger exactly 5 calls to resolveRecipeOwnership (via the
 * collectionGroup('recipes') stub), not 100.
 */
async function dedupResolvesEachRecipeOnce(): Promise<void> {
  const recipeIds = ["r1", "r2", "r3", "r4", "r5"];
  const comments: FakeComment[] = [];
  for (let i = 0; i < 100; i++) {
    const recipeId = recipeIds[i % recipeIds.length];
    comments.push({
      // Zero-pad so localeCompare orders lexically with numeric id.
      id: `c${String(i).padStart(3, "0")}`,
      recipeId,
      authorId: `author-${i}`,
    });
  }
  const recipes: FakeRecipe[] = recipeIds.map((id) => ({
    ownerUid: `owner-${id}`,
    id,
    data: { core: { createdBy: `owner-${id}` } },
  }));

  const resolveCalls: string[] = [];
  const db = makeFakeDb(comments, recipes, {
    onResolveStart: (recipeId) => resolveCalls.push(recipeId),
  });
  const result = await runBackfill(db as never, {
    dryRun: false,
    maxComments: 1000,
  });

  const ok =
    result.migrated === 100 &&
    resolveCalls.length === 5 &&
    new Set(resolveCalls).size === 5;
  record(
    "dedup: 100 comments / 5 unique recipes → 5 resolve calls",
    ok,
    `migrated=${result.migrated} resolveCalls=${resolveCalls.length} unique=${new Set(resolveCalls).size}`
  );
}

/**
 * Concurrency observed: with multiple unique recipeIds and an artificial
 * delay inside the resolve, max-in-flight must exceed 1 — proving the
 * resolves are not strictly sequential.
 */
async function resolvesRunInterleaved(): Promise<void> {
  // 8 unique recipeIds, one comment each.
  const recipes: FakeRecipe[] = [];
  const comments: FakeComment[] = [];
  for (let i = 0; i < 8; i++) {
    const id = `r${i}`;
    recipes.push({
      ownerUid: `owner-${i}`,
      id,
      data: { core: { createdBy: `owner-${i}` } },
    });
    comments.push({
      id: `c${i}`,
      recipeId: id,
      authorId: `author-${i}`,
    });
  }

  let inFlight = 0;
  let maxInFlight = 0;
  const db = makeFakeDb(comments, recipes, {
    resolveDelayMs: 5,
    onResolveStart: () => {
      inFlight += 1;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
    },
    onResolveEnd: () => {
      inFlight -= 1;
    },
  });
  const result = await runBackfill(db as never, {
    dryRun: false,
    maxComments: 1000,
  });

  const ok = result.migrated === 8 && maxInFlight > 1;
  record(
    "concurrency: resolves are interleaved (max-in-flight > 1)",
    ok,
    `migrated=${result.migrated} maxInFlight=${maxInFlight}`
  );
}

/**
 * Concurrency cap: with 50 unique recipeIds, max-in-flight must stay
 * within RESOLVE_CONCURRENCY (20). Hits the p-limit guard.
 */
async function concurrencyRespectsCap(): Promise<void> {
  const recipes: FakeRecipe[] = [];
  const comments: FakeComment[] = [];
  for (let i = 0; i < 50; i++) {
    const id = `rcap${String(i).padStart(3, "0")}`;
    recipes.push({
      ownerUid: `owner-${i}`,
      id,
      data: { core: { createdBy: `owner-${i}` } },
    });
    comments.push({
      id: `ccap${String(i).padStart(3, "0")}`,
      recipeId: id,
      authorId: `author-${i}`,
    });
  }

  let inFlight = 0;
  let maxInFlight = 0;
  const db = makeFakeDb(comments, recipes, {
    resolveDelayMs: 10,
    onResolveStart: () => {
      inFlight += 1;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
    },
    onResolveEnd: () => {
      inFlight -= 1;
    },
  });
  const result = await runBackfill(db as never, {
    dryRun: false,
    maxComments: 1000,
  });

  const ok = result.migrated === 50 && maxInFlight <= 20 && maxInFlight > 1;
  record(
    "concurrency cap: max-in-flight ≤ 20 across 50 unique recipes",
    ok,
    `migrated=${result.migrated} maxInFlight=${maxInFlight}`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-458 / BUT-741: backfill-recipe-comments-denorm tests\n");
  console.log("==============================================\n");
  await migratesCollabRecipeComment();
  await migratesPersonalRecipeComment();
  await idempotentRerunSkips();
  await orphanedRecipeStampsAuthorOnly();
  await dryRunDoesNotMutate();
  await requireAdminRejectsNonAdmin();
  await requireAdminAllowsAdmin();
  await requireAdminRejectsUnauthenticated();
  await dedupResolvesEachRecipeOnce();
  await resolvesRunInterleaved();
  await concurrencyRespectsCap();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
