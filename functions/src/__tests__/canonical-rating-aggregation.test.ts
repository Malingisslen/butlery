/**
 * Pooled ratings Stage A — mirror CF unit tests (Increment 2).
 *
 * Proves the acceptance criteria from tasks/pooled-ratings-plan.md:
 *   AC2  a client-written poolKey CANNOT route a vote — the server recomputes
 *        the key from recipe content (pool-poisoning defense, decision 2).
 *   AC3  one vote per uid per pool regardless of how many recipe copies map to
 *        the same dish (decision 4).
 *   AC6  a family rating never reaches a pool — structural: the mirror is bound
 *        to recipe_ratings ONLY (decision 7).
 *   maturity gate rejects a fresh/unverified account (decision 7).
 * Plus: kill switch off ⇒ no-op; fail-closed key; delete = retraction.
 *
 * Run with: npx ts-node src/__tests__/canonical-rating-aggregation.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-pooled-ratings" });
}

import {
  mirrorRatingToPool,
  MirrorDeps,
  RatingDoc,
  CANONICAL_EVENTS_SUBCOLLECTION,
  POOL_MIRROR_TRIGGER_PATH,
} from "../ratings/canonical-rating-aggregation";
import { computePoolKey } from "../ratings/canonical-pool-key";

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
    return {
      exists: data !== undefined,
      id: this.id,
      data: () => data,
    };
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
    for (const [path, data] of this.db.store) {
      if (!path.startsWith(this.collectionPath + "/")) continue;
      if (path.slice(this.collectionPath.length + 1).includes("/")) continue;
      if (this.op === "==" && data[this.field] !== this.value) continue;
      docs.push(new FakeDoc(this.db, path));
    }
    return {
      empty: docs.length === 0,
      size: docs.length,
      docs,
    };
  }
}

const BASE_MS = 1_700_000_000_000;
const iso = (ms: number) => new Date(ms).toISOString();

function fakeAuth(
  users: Record<string, { emailVerified: boolean; creationTime: string }>
): admin.auth.Auth {
  return {
    async getUser(uid: string) {
      const u = users[uid];
      if (!u) throw new Error(`no user ${uid}`);
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

function seedRecipe(
  db: FakeFirestore,
  recipeId: string,
  core: { title: string; ingredients: string[] }
): void {
  db.store.set(`recipes/${recipeId}`, { core });
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

async function killSwitchNoops(): Promise<void> {
  const db = new FakeFirestore();
  seedRecipe(db, "r1", RECIPE_CORE);
  const res = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db, { isEnabled: async () => false })
  );
  record(
    "flag OFF → skipped_flag, no event written",
    res.action === "skipped_flag" && db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );
}

async function serverRecomputesKeyDefeatingTamper(): Promise<void> {
  const db = new FakeFirestore();
  seedRecipe(db, "r1", RECIPE_CORE);
  const expectedKey = computePoolKey(RECIPE_CORE.title, RECIPE_CORE.ingredients);

  // Client tampers: puts a bogus poolKey on the rating doc. The mirror must
  // ignore it and route by the SERVER-recomputed key.
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
  const db = new FakeFirestore();
  // Two DIFFERENT recipe ids with identical content → identical poolKey.
  seedRecipe(db, "rA", RECIPE_CORE);
  seedRecipe(db, "rB", RECIPE_CORE);
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

async function unchangedRatingIsNoop(): Promise<void> {
  const db = new FakeFirestore();
  // Recipe content DIFFERS from what the original rating pooled — simulates the
  // user having edited the recipe after rating. An incidental same-star write
  // (e.g. review-text edit) must NOT fabricate a vote at the new dish's key.
  seedRecipe(db, "r1", { title: "Pannkakor", ingredients: ["2 dl mjöl", "3 ägg"] });
  const res = await mirrorRatingToPool(
    {
      ratingId: "r1_u1",
      before: { userId: "u1", recipeId: "r1", rating: 4 },
      after: { userId: "u1", recipeId: "r1", rating: 4 },
    },
    baseDeps(db)
  );
  record(
    "unchanged rating (review edit) → skipped_unchanged, no fabricated event",
    res.action === "skipped_unchanged" &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );
}

async function familyExclusionIsStructural(): Promise<void> {
  record(
    "AC6 mirror is bound to recipe_ratings only (never family_ratings)",
    POOL_MIRROR_TRIGGER_PATH === "recipe_ratings/{ratingId}" &&
      !POOL_MIRROR_TRIGGER_PATH.includes("family"),
    `path=${POOL_MIRROR_TRIGGER_PATH}`
  );
}

async function maturityGate(): Promise<void> {
  // Immature: unverified AND created 10 min ago (< 60 min window).
  const db1 = new FakeFirestore();
  seedRecipe(db1, "r1", RECIPE_CORE);
  const immature = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db1, {
      auth: fakeAuth({
        u1: { emailVerified: false, creationTime: iso(BASE_MS - 10 * 60 * 1000) },
      }),
    })
  );
  record(
    "maturity gate: fresh unverified account → skipped_immature, no event",
    immature.action === "skipped_immature" &&
      db1.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(immature)
  );

  // Mature by age: unverified but created 2 h ago.
  const db2 = new FakeFirestore();
  seedRecipe(db2, "r1", RECIPE_CORE);
  const byAge = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db2, {
      auth: fakeAuth({
        u1: { emailVerified: false, creationTime: iso(BASE_MS - 2 * 60 * 60 * 1000) },
      }),
    })
  );
  record(
    "maturity gate: account older than 60 min → upserted",
    byAge.action === "upserted",
    JSON.stringify(byAge)
  );

  // Mature by verification: fresh but email-verified.
  const db3 = new FakeFirestore();
  seedRecipe(db3, "r1", RECIPE_CORE);
  const byVerify = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: null, after: { userId: "u1", recipeId: "r1", rating: 5 } },
    baseDeps(db3, {
      auth: fakeAuth({
        u1: { emailVerified: true, creationTime: iso(BASE_MS - 1 * 60 * 1000) },
      }),
    })
  );
  record(
    "maturity gate: email-verified fresh account → upserted",
    byVerify.action === "upserted",
    JSON.stringify(byVerify)
  );
}

async function failClosedKey(): Promise<void> {
  const db = new FakeFirestore();
  // Generic anchor ("soppa") + a single trivial ingredient → computePoolKey null.
  seedRecipe(db, "r1", { title: "Soppa", ingredients: ["salt"] });
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

async function missingRecipe(): Promise<void> {
  const db = new FakeFirestore();
  const res = await mirrorRatingToPool(
    { ratingId: "gone_u1", before: null, after: { userId: "u1", recipeId: "gone", rating: 5 } },
    baseDeps(db)
  );
  record(
    "missing recipe → skipped_no_recipe",
    res.action === "skipped_no_recipe",
    JSON.stringify(res)
  );
}

async function deleteRetractsVote(): Promise<void> {
  const db = new FakeFirestore();
  seedRecipe(db, "r1", RECIPE_CORE);
  const key = computePoolKey(RECIPE_CORE.title, RECIPE_CORE.ingredients)!;
  // Pre-seed an event this rating backs.
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
    "delete → retraction removes the rater's event(s)",
    res.action === "deleted" &&
      res.deletedCount === 1 &&
      db.countAt("users/u1/" + CANONICAL_EVENTS_SUBCOLLECTION) === 0,
    JSON.stringify(res)
  );

  // Delete with nothing to remove → no-op.
  const res2 = await mirrorRatingToPool(
    { ratingId: "r1_u1", before: { userId: "u1", recipeId: "r1", rating: 5 }, after: null },
    baseDeps(db)
  );
  record("delete with no matching event → delete_noop", res2.action === "delete_noop", JSON.stringify(res2));
}

async function runAll(): Promise<void> {
  console.log("Pooled ratings Stage A — mirror CF tests\n");
  console.log("==============================================\n");
  await killSwitchNoops();
  await serverRecomputesKeyDefeatingTamper();
  await oneVotePerPoolAcrossCopies();
  await unchangedRatingIsNoop();
  await familyExclusionIsStructural();
  await maturityGate();
  await failClosedKey();
  await missingRecipe();
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
