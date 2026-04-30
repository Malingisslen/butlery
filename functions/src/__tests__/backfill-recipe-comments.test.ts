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

/**
 * In-memory firestore stub matching only the surface used by runBackfill.
 * The shape mirrors `admin.firestore.Firestore` for the methods we call.
 */
function makeFakeDb(comments: FakeComment[], recipes: FakeRecipe[]) {
  // Track writes for assertions.
  const writes: Array<{ id: string; update: Record<string, unknown> }> = [];

  function buildCommentDocSnap(c: FakeComment) {
    return {
      id: c.id,
      ref: {
        update: async (_data: Record<string, unknown>) => {
          // Real firestore would write directly; we only inspect via batch.
        },
      },
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
          const found = recipes.filter((r) => r.id === targetId);
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
          // Reverse-look up the comment id from the snapshot ref by searching
          // the comments array for an entry whose ref matches. We piggy-back
          // identity on the ref reference; simplest is to record by data only.
          writes.push({ id: "<batch>", update: data });
          // Mutate in-place so a subsequent run sees the new state (idempotency
          // test). We need to find which comment doc was passed. Since our
          // fake snapshot's `ref` is a fresh object, we instead match on the
          // recipeId in the update payload — but the update doesn't carry it.
          // So: find the first comment without recipeOwnerId and stamp it.
          // The tests sequence calls so there's always a deterministic target.
          const target = comments.find(
            (c) => c.recipeOwnerId === undefined && c.recipeId !== "__migrated__"
          );
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

async function runAll(): Promise<void> {
  console.log("BUT-458: backfill-recipe-comments-denorm tests\n");
  console.log("==============================================\n");
  await migratesCollabRecipeComment();
  await migratesPersonalRecipeComment();
  await idempotentRerunSkips();
  await orphanedRecipeStampsAuthorOnly();
  await dryRunDoesNotMutate();
  await requireAdminRejectsNonAdmin();
  await requireAdminAllowsAdmin();
  await requireAdminRejectsUnauthenticated();

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
