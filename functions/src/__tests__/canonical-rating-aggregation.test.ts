/**
 * Pooled ratings Stage A — mirror CF unit tests (Increment 2).
 *
 * Proves the acceptance criteria from tasks/pooled-ratings-plan.md plus the
 * fixes from the 2026-07-03 xhigh review:
 *   AC2  a client-written poolKey CANNOT route a vote — server recomputes it.
 *   AC3  one vote per uid per pool regardless of copy count (decision 4).
 *   AC6  the mirror is wired to recipe_ratings ONLY (decision 7) — asserted
 *        against the real index.ts registration, not a self-referential const.
 *   maturity gate rejects fresh/unverified; a transient auth error THROWS
 *        (so the retry-enabled trigger re-runs) rather than dropping the vote.
 *   #5   a rating cast while immature DOES pool once the account matures.
 *   kill switch off no-ops create/update but NEVER blocks a retraction.
 *   NaN/non-integer ratings are rejected.
 *
 * IMPORTANT: recipes are USER-SCOPED — `seedRecipe` writes
 * `users/{uid}/recipes/{id}`, the same path the code reads. (The prior fake
 * seeded a top-level `recipes/{id}` that does not exist, which hid a
 * dead-on-arrival path bug.)
 *
 * Run with: npx ts-node src/__tests__/canonical-rating-aggregation.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-pooled-ratings" });
}
import * as fs from "fs";
import * as path from "path";

import {
  mirrorRatingToPool,
  MirrorDeps,
  RatingDoc,
  CANONICAL_EVENTS_SUBCOLLECTION,
  POOL_MIRROR_TRIGGER_PATH,
  __resetMaturedMemoForTests,
} from "../ratings/canonical-rating-aggregation";
import { computePoolKey } from "../ratings/canonical-pool-key";
import {
  isPooledRatingsEnabled,
  __resetPooledFlagCacheForTests,
} from "../ratings/pooled-ratings-flag";

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

// ── Minimal Firestore stub: path-addressed docs, nested subcollections, and a
//    single-field equality .where().get() (all this module uses). ──
class FakeFirestore {
  store = new Map<string, Record<string, unknown>>();
  collection(path: string) {
    return new FakeCollection(this, path);
  }
  countAt(collectionPath: string): number {
    let n = 0;
    for (const key of this.store.keys()) {
      if (!key.startsWith(collectionPath + "/")) continue;
      if (key.slice(collectionPath.length + 1).includes("/")) continue;
      n++;
    }
    return n;
  }
}

class FakeCollection {
  constructor(private db: FakeFirestore, public path: string) {}
  doc(id: string) {
    return new FakeDoc(this.db, `${this.path}/${id}`);
  }
  where(field: string, op: string, value: unknown) {
    return new FakeQuery(this.db, this.path, field, op, value);
  }
}

class FakeDoc {
  constructor(private db: FakeFirestore, public path: string) {}
  get ref(): FakeDoc {
    return this;
  }
  get id(): string {
    return this.path.split("/").pop()!;
  }
  async get() {
    const data = this.db.store.get(this.path);
    return { exists: data !== undefined, id: this.id, data: () => data };
  }
  async set(data: Record<string, unknown>) {
    this.db.store.set(this.path, { ...data });
  }
  async delete() {
    this.db.store.delete(this.path);
  }
  collection(sub: string) {
    return new FakeCollection(this.db, `${this.path}/${sub}`);
  }
}

class FakeQuery {
  constructor(
    private db: FakeFirestore,
    private collectionPath: string,
    private field: string,
    private op: string,
    private value: unknown
  ) {}
  async get() {
    const docs: FakeDoc[] = [];
    for (const [p, data] of this.db.store) {
      if (!p.startsWith(this.collectionPath + "/")) continue;
      if (p.slice(this.collectionPath.length + 1).includes("/")) continue;
      if (this.op === "==" && data[this.field] !== this.value) continue;
      docs.push(new FakeDoc(this.db, p));
    }
    return { empty: docs.length === 0, size: docs.length, docs };
  }
}

const BASE_MS = 1_700_000_000_000;
const iso = (ms: number) => new Date(ms).toISOString();

function fakeAuth(
  users: Record<
    string,
    { emailVerified: boolean; creationTime: string } | "throw" | "not-found"
  >
): admin.auth.Auth {
  return {
    async getUser(uid: string) {
      const u = users[uid];
      if (u === "throw") throw new Error("transient auth outage");
      if (u === "not-found" || u === undefined) {
        const e = new Error(`no user ${uid}`) as Error & { code?: string };
        e.code = "auth/user-not-found";
        throw e;
      }
      return {
        emailVerified: u.emailVerified,
        metadata: { creationTime: u.creationTime },
      };
    },
  } as unknown as admin.auth.Auth;
}

/** A recipe whose content yields a real (non-null) poolKey. */
const RECIPE_CORE = {
  title: "Köttbullar med gräddsås",
  ingredients: ["500 g nötfärs", "1 dl grädde", "2 msk ströbröd"],
};

/** Recipes are USER-SCOPED: seed at users/{uid}/recipes/{id}. */
function seedRecipe(
  db: FakeFirestore,
  uid: string,
  recipeId: string,
  core: { title: string; ingredients: string[] }
): void {
  db.store.set(`users/${uid}/recipes/${recipeId}`, { core });
}

/** Matured, verified user + flag on + fixed clock. */
function baseDeps(db: FakeFirestore, overrides: Partial<MirrorDeps> = {}): MirrorDeps {
  return {
    db: db as never,
    now: () => BASE_MS,
    isEnabled: async () => true,
    auth: fakeAuth({
      u1: { emailVerified: true, creationTime: iso(BASE_MS - 10 * 60 * 1000) },
    }),
    ...overrides,
  };
}

async function killSwitchNoopsCreate(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", RECIPE_CORE);
  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db, { isEnabled: async () => false })
  );
  record(
    "flag OFF → create no-ops (skipped_flag), no event",
    res.action === "skipped_flag" &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );
}

async function killSwitchNeverBlocksRetraction(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  const key = computePoolKey(RECIPE_CORE.title, RECIPE_CORE.ingredients)!;
  db.store.set(`users/u1/${CANONICAL_EVENTS_SUBCOLLECTION}/${key}`, {
    poolKey: key,
    ratingValue: 5,
    recipeId: "r1",
  });
  // Flag OFF, but a delete must still retract.
  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: { userId: "u1", recipeId: "r1", rating: 5 }, after: null },
    baseDeps(db, { isEnabled: async () => false })
  );
  record(
    "flag OFF → retraction STILL removes the event (not gated)",
    res.action === "deleted" &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );
}

// Production path: deps.isEnabled OMITTED, so the mirror uses the real
// isPooledRatingsEnabled() fallback. Guards the operator-precedence bug where
// `await` failed to cover the `?? fallback` and the kill switch no-op'd in prod.
function prodDeps(db: FakeFirestore): MirrorDeps {
  return {
    db: db as never,
    now: () => BASE_MS,
    auth: fakeAuth({
      u1: { emailVerified: true, creationTime: iso(BASE_MS - 10 * 60 * 1000) },
    }),
    // NO isEnabled — exercise the real module fallback.
  };
}

async function productionFlagOffDisables(): Promise<void> {
  __resetMaturedMemoForTests();
  __resetPooledFlagCacheForTests();
  // Seed the module cache to false via the loader seam, then the mirror's
  // un-injected isPooledRatingsEnabled() hits that cache.
  await isPooledRatingsEnabled({ loader: async () => false });
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", RECIPE_CORE);
  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    prodDeps(db)
  );
  record(
    "production path (no injected flag) + flag OFF → skipped_flag, no event",
    res.action === "skipped_flag" &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );
}

async function productionFlagOnEnables(): Promise<void> {
  __resetMaturedMemoForTests();
  __resetPooledFlagCacheForTests();
  await isPooledRatingsEnabled({ loader: async () => true });
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", RECIPE_CORE);
  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    prodDeps(db)
  );
  record(
    "production path (no injected flag) + flag ON → upserted",
    res.action === "upserted" &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 1,
    JSON.stringify(res)
  );
  __resetPooledFlagCacheForTests(); // don't leak the cached true into later tests
}

async function serverRecomputesKeyDefeatingTamper(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", RECIPE_CORE);
  const expectedKey = computePoolKey(RECIPE_CORE.title, RECIPE_CORE.ingredients);

  const tampered = {
    userId: "u1",
    recipeId: "r1",
    rating: 4,
    poolKey: "v1:deadbeefdeadbeef",
    ratingPoolKey: "v1:deadbeefdeadbeef",
  } as RatingDoc;

  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: tampered },
    baseDeps(db)
  );

  const serverPath = `users/u1/${CANONICAL_EVENTS_SUBCOLLECTION}/${expectedKey}`;
  const bogusPath = `users/u1/${CANONICAL_EVENTS_SUBCOLLECTION}/v1:deadbeefdeadbeef`;
  const ev = db.store.get(serverPath);
  record(
    "AC2 server recomputes key; tampered client key ignored",
    res.action === "upserted" &&
      expectedKey !== null &&
      res.poolKey === expectedKey &&
      ev?.ratingValue === 4 &&
      ev?.recipeId === "r1" &&
      db.store.get(bogusPath) === undefined,
    `res=${JSON.stringify(res)} expected=${expectedKey} ev=${JSON.stringify(ev)}`
  );
}

async function oneVotePerPoolAcrossCopies(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "rA", RECIPE_CORE);
  seedRecipe(db, "u1", "rB", RECIPE_CORE);
  const key = computePoolKey(RECIPE_CORE.title, RECIPE_CORE.ingredients);

  await mirrorRatingToPool(
    { ratingId: "rA_u1", before: null, after: { userId: "u1", recipeId: "rA", rating: 3 } },
    baseDeps(db)
  );
  await mirrorRatingToPool(
    { ratingId: "rB_u1", before: null, after: { userId: "u1", recipeId: "rB", rating: 5 } },
    baseDeps(db)
  );

  const subPath = `users/u1/${CANONICAL_EVENTS_SUBCOLLECTION}`;
  const ev = db.store.get(`${subPath}/${key}`);
  record(
    "AC3 two copies of one dish → one vote (latest wins)",
    db.countAt(subPath) === 1 && ev?.ratingValue === 5 && ev?.recipeId === "rB",
    `count=${db.countAt(subPath)} ev=${JSON.stringify(ev)}`
  );
}

async function familyExclusionWiring(): Promise<void> {
  // Real guard: the constant is bound to recipe_ratings, AND index.ts actually
  // registers onDocumentWritten against that constant (not a rebound path).
  const indexSrc = fs.readFileSync(
    path.join(__dirname, "..", "index.ts"),
    "utf8"
  );
  // Two checks (comment-tolerant): the named export IS an onDocumentWritten
  // trigger, and its `document` option is the recipe_ratings constant.
  const boundToConst =
    /onRecipeRatingWrittenForPool\s*=\s*onDocumentWritten\(/.test(indexSrc) &&
    /document:\s*POOL_MIRROR_TRIGGER_PATH/.test(indexSrc);
  record(
    "AC6 trigger bound to recipe_ratings only (via index.ts registration)",
    POOL_MIRROR_TRIGGER_PATH === "recipe_ratings/{ratingId}" &&
      !POOL_MIRROR_TRIGGER_PATH.includes("family") &&
      boundToConst,
    `path=${POOL_MIRROR_TRIGGER_PATH} boundToConst=${boundToConst}`
  );
}

async function maturityGate(): Promise<void> {
  // Immature: unverified AND created 10 min ago (< 60 min window).
  __resetMaturedMemoForTests();
  const db1 = new FakeFirestore();
  seedRecipe(db1, "u1", "r1", RECIPE_CORE);
  const immature = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db1, {
      auth: fakeAuth({
        u1: { emailVerified: false, creationTime: iso(BASE_MS - 10 * 60 * 1000) },
      }),
    })
  );
  record(
    "maturity: fresh unverified account → skipped_immature, no event",
    immature.action === "skipped_immature" &&
      db1.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(immature)
  );

  // Mature by age.
  __resetMaturedMemoForTests();
  const db2 = new FakeFirestore();
  seedRecipe(db2, "u1", "r1", RECIPE_CORE);
  const byAge = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db2, {
      auth: fakeAuth({
        u1: { emailVerified: false, creationTime: iso(BASE_MS - 2 * 60 * 60 * 1000) },
      }),
    })
  );
  record("maturity: account older than 60 min → upserted", byAge.action === "upserted", JSON.stringify(byAge));

  // Mature by verification.
  __resetMaturedMemoForTests();
  const db3 = new FakeFirestore();
  seedRecipe(db3, "u1", "r1", RECIPE_CORE);
  const byVerify = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db3, {
      auth: fakeAuth({
        u1: { emailVerified: true, creationTime: iso(BASE_MS - 1 * 60 * 1000) },
      }),
    })
  );
  record("maturity: email-verified fresh account → upserted", byVerify.action === "upserted", JSON.stringify(byVerify));
}

async function transientAuthErrorThrows(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", RECIPE_CORE);
  let threw = false;
  try {
    await mirrorRatingToPool(
      { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
      baseDeps(db, { auth: fakeAuth({ u1: "throw" }) })
    );
  } catch {
    threw = true;
  }
  record(
    "maturity: transient auth error THROWS (trigger retries, vote not dropped)",
    threw && db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    `threw=${threw}`
  );
}

async function immatureThenMaturedPools(): Promise<void> {
  // #5 fix: a rating first cast while immature must pool once the account
  // matures, even on a same-value re-save (no skipped_unchanged gate).
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", RECIPE_CORE);
  const authAcct = fakeAuth({
    u1: { emailVerified: false, creationTime: iso(BASE_MS - 10 * 60 * 1000) },
  });

  // Create while immature (now = BASE, account 10 min old).
  const first = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 4 } },
    baseDeps(db, { auth: authAcct, now: () => BASE_MS })
  );
  // Same-value re-save 2 h later — now matured by age.
  const later = await mirrorRatingToPool(
    {
      ratingId: "r1_u1",
      before: { userId: "u1", recipeId: "r1", rating: 4 },
      after: { userId: "u1", recipeId: "r1", rating: 4 },
    },
    baseDeps(db, { auth: authAcct, now: () => BASE_MS + 2 * 60 * 60 * 1000 })
  );
  record(
    "#5 immature-then-matured same-value re-save → pools (was permanently skipped)",
    first.action === "skipped_immature" &&
      later.action === "upserted" &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 1,
    `first=${first.action} later=${later.action}`
  );
}

async function rejectsNaNRating(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", RECIPE_CORE);
  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: NaN } },
    baseDeps(db)
  );
  record(
    "NaN rating → skipped_invalid, no event (NaN slips < / > guards)",
    res.action === "skipped_invalid" &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );
}

async function allowsHalfStarRating(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", RECIPE_CORE);
  const key = computePoolKey(RECIPE_CORE.title, RECIPE_CORE.ingredients)!;
  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 3.5 } },
    baseDeps(db)
  );
  const ev = db.store.get(`users/u1/${CANONICAL_EVENTS_SUBCOLLECTION}/${key}`);
  record(
    "fractional (half-star) rating 3.5 → upserted (finite, in range)",
    res.action === "upserted" && ev?.ratingValue === 3.5,
    JSON.stringify(res)
  );
}

async function failClosedKey(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  seedRecipe(db, "u1", "r1", { title: "Soppa", ingredients: ["salt"] });
  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db)
  );
  record(
    "fail-closed: generic/no-anchor recipe → skipped_no_key, no event",
    res.action === "skipped_no_key" &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );
}

async function missingOwnRecipe(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  // No seedRecipe → rater's own copy absent.
  const res = await mirrorRatingToPool(
    { ratingId: "gone_u1", before: null, after: { userId: "u1", recipeId: "gone", rating: 5 } },
    baseDeps(db)
  );
  record(
    "rater's own recipe copy missing → skipped_no_recipe",
    res.action === "skipped_no_recipe",
    JSON.stringify(res)
  );
}

async function deleteRetractsVote(): Promise<void> {
  __resetMaturedMemoForTests();
  const db = new FakeFirestore();
  const key = computePoolKey(RECIPE_CORE.title, RECIPE_CORE.ingredients)!;
  db.store.set(`users/u1/${CANONICAL_EVENTS_SUBCOLLECTION}/${key}`, {
    poolKey: key,
    ratingValue: 5,
    recipeId: "r1",
  });

  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: { userId: "u1", recipeId: "r1", rating: 5 }, after: null },
    baseDeps(db)
  );
  record(
    "delete → retraction removes the rater's event(s) by recipeId",
    res.action === "deleted" &&
      res.deletedCount === 1 &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );

  const res2 = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: { userId: "u1", recipeId: "r1", rating: 5 }, after: null },
    baseDeps(db)
  );
  record("delete with no matching event → delete_noop", res2.action === "delete_noop", JSON.stringify(res2));
}

async function runAll(): Promise<void> {
  console.log("Pooled ratings Stage A — mirror CF tests\n");
  console.log("==============================================\n");
  await killSwitchNoopsCreate();
  await killSwitchNeverBlocksRetraction();
  await productionFlagOffDisables();
  await productionFlagOnEnables();
  await serverRecomputesKeyDefeatingTamper();
  await oneVotePerPoolAcrossCopies();
  await familyExclusionWiring();
  await maturityGate();
  await transientAuthErrorThrows();
  await immatureThenMaturedPools();
  await rejectsNaNRating();
  await allowsHalfStarRating();
  await failClosedKey();
  await missingOwnRecipe();
  await deleteRetractsVote();

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
