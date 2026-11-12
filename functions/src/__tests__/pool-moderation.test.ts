/**
 * Pool moderation tests (BUT-1517, plan condition C9) — pure unit level.
 *
 * Verbs the SUT calls on the fake Firestore (all modelled below):
 *   db.collection("pool_quarantine").doc(key).get() / .set(data) / .delete()
 *   db.collection("audit_logs").add(row)
 *   db.collectionGroup(id).where(f, op, v)  (chained, immutable)
 *     .aggregate(spec).get()   -> {data(): {count, average}}
 *     .count().get()           -> {data(): {count}}
 *     .orderBy("createdAt", "desc").limit(n).get() -> docs with ref.parent.parent.id
 *
 * Run with: npx ts-node src/__tests__/pool-moderation.test.ts
 */

import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "butlery-test-pool-moderation" });
}

import { CallableRequest } from "firebase-functions/v2/https";
import {
  AccountFacts,
  AUDIT_OP_INSPECT,
  AUDIT_OP_LIFT,
  AUDIT_OP_QUARANTINE,
  handleInspectPool,
  handleSetPoolQuarantine,
  inspectPool,
  parsePoolKey,
  parseQuarantine,
  PoolModerationDeps,
  RISK_SAMPLE,
  YOUNG_ACCOUNT_MS,
} from "../admin/pool-moderation";
import { CANONICAL_EVENTS_SUBCOLLECTION } from "../ratings/canonical-rating-aggregation";
import { POOL_QUARANTINE_COLLECTION } from "../ratings/update-pooled-rating-stats";

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

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

const POOL = "v1:aaaabbbbccccdddd";
const OTHER_POOL = "v1:9999888877776666";
const ADMIN_UID = "adminUid-7f3k";
const NOW = Date.UTC(2026, 5, 20, 6, 0, 0);

interface Filter {
  field: string;
  op: string;
  value: unknown;
}

interface SeedEvent {
  uid: string;
  poolKey: string;
  ratingValue: number;
  createdAtMs: number;
  recipeId: string;
  title: string;
}

class Fake {
  events: SeedEvent[] = [];
  docs = new Map<string, Record<string, unknown>>();
  audit: Array<Record<string, unknown>> = [];
  limits: number[] = [];
  aggregateQueries = 0;
  writes = 0;
  /** Ordered log shared with the injected deps to prove ordering. */
  log: string[] = [];

  private matches(filters: Filter[]): SeedEvent[] {
    return this.events.filter((e) =>
      filters.every((f) => {
        const actual: unknown = f.field === "createdAt"
          ? e.createdAtMs
          : (e as unknown as Record<string, unknown>)[f.field];
        const want: unknown = f.field === "createdAt"
          ? (f.value as admin.firestore.Timestamp).toMillis()
          : f.value;
        if (f.op === "==") return actual === want;
        if (f.op === ">=") return (actual as number) >= (want as number);
        if (f.op === "<") return (actual as number) < (want as number);
        throw new Error(`unsupported op ${f.op}`);
      }),
    );
  }

  private query(id: string, filters: Filter[], order: "desc" | null, limit: number | null): unknown {
    const self = this;
    const q = {
      where(field: string, op: string, value: unknown) {
        return self.query(id, [...filters, { field, op, value }], order, limit);
      },
      orderBy(field: string, dir: string) {
        if (field !== "createdAt" || dir !== "desc") throw new Error("unsupported orderBy");
        return self.query(id, filters, "desc", limit);
      },
      limit(n: number) {
        self.limits.push(n);
        return self.query(id, filters, order, n);
      },
      count() {
        return {
          async get() {
            return { data: () => ({ count: self.matches(filters).length }) };
          },
        };
      },
      aggregate(spec: Record<string, { aggregateType: string; _field?: string }>) {
        return {
          async get() {
            self.aggregateQueries++;
            const hits = self.matches(filters);
            const out: Record<string, number | null> = {};
            for (const key of Object.keys(spec)) {
              const t = spec[key].aggregateType;
              if (t === "count") out[key] = hits.length;
              else if (t === "avg") {
                out[key] = hits.length ? hits.reduce((s, e) => s + e.ratingValue, 0) / hits.length : null;
              } else throw new Error(`unsupported aggregate ${t}`);
            }
            return { data: () => out };
          },
        };
      },
      async get() {
        if (id !== CANONICAL_EVENTS_SUBCOLLECTION) throw new Error(`unexpected group ${id}`);
        let hits = self.matches(filters);
        if (order === "desc") hits = [...hits].sort((a, b) => b.createdAtMs - a.createdAtMs);
        if (limit != null) hits = hits.slice(0, limit);
        const docs = hits.map((e) => ({
          data: () => ({
            poolKey: e.poolKey,
            ratingValue: e.ratingValue,
            recipeId: e.recipeId,
            title: e.title,
            createdAt: admin.firestore.Timestamp.fromMillis(e.createdAtMs),
          }),
          ref: { parent: { parent: { id: e.uid } } },
        }));
        return { docs, size: docs.length, empty: docs.length === 0 };
      },
    };
    return q;
  }

  db(): admin.firestore.Firestore {
    const self = this;
    return {
      collection(name: string) {
        if (name === "audit_logs") {
          return {
            async add(row: Record<string, unknown>) {
              self.audit.push(row);
              self.log.push("audit");
              return { id: `a${self.audit.length}` };
            },
          };
        }
        if (name === POOL_QUARANTINE_COLLECTION) {
          return {
            doc(id: string) {
              const path = `${name}/${id}`;
              return {
                async get() {
                  const data = self.docs.get(path);
                  return { exists: data !== undefined, data: () => data };
                },
                async set(data: Record<string, unknown>) {
                  self.writes++;
                  self.log.push("set");
                  self.docs.set(path, data);
                },
                async delete() {
                  self.writes++;
                  self.log.push("delete");
                  self.docs.delete(path);
                },
              };
            },
          };
        }
        throw new Error(`unexpected collection ${name}`);
      },
      collectionGroup(id: string) {
        return self.query(id, [], null, null);
      },
    } as unknown as admin.firestore.Firestore;
  }
}

interface Probe {
  fake: Fake;
  deps: PoolModerationDeps;
  rateLimitCalls: Array<[string, string]>;
  aggregateCalls: string[];
  lookups: string[][];
}

function makeProbe(facts: Map<string, AccountFacts> = new Map()): Probe {
  const fake = new Fake();
  const probe: Probe = {
    fake,
    rateLimitCalls: [],
    aggregateCalls: [],
    lookups: [],
    deps: {
      db: fake.db(),
      nowMs: () => NOW,
      lookupAccounts: async (uids) => {
        probe.lookups.push(uids);
        return facts;
      },
      aggregate: async (poolKey) => {
        probe.aggregateCalls.push(poolKey);
        fake.log.push("aggregate");
      },
      rateLimit: async (uid, op) => {
        probe.rateLimitCalls.push([uid, op]);
      },
    },
  };
  return probe;
}

function req(auth: CallableRequest<unknown>["auth"], data: unknown): CallableRequest<unknown> {
  return { auth, data } as unknown as CallableRequest<unknown>;
}

const adminAuth = { uid: ADMIN_UID, token: { admin: true } } as unknown as CallableRequest<unknown>["auth"];
const roleAdminAuth = { uid: ADMIN_UID, token: { role: "admin" } } as unknown as CallableRequest<unknown>["auth"];
const plainAuth = { uid: "plainUser", token: {} } as unknown as CallableRequest<unknown>["auth"];
const falseAdminAuth = { uid: "plainUser", token: { admin: false, role: "user" } } as unknown as CallableRequest<unknown>["auth"];

async function codeOf(p: Promise<unknown>): Promise<string> {
  try {
    await p;
    return "no-throw";
  } catch (err) {
    return (err as { code?: string }).code ?? `other:${String(err)}`;
  }
}

function untouched(p: Probe): boolean {
  return (
    p.rateLimitCalls.length === 0 &&
    p.aggregateCalls.length === 0 &&
    p.fake.audit.length === 0 &&
    p.fake.writes === 0 &&
    p.fake.aggregateQueries === 0
  );
}

async function accessControl(): Promise<void> {
  const inspectData = { poolKey: POOL };
  const setData = { poolKey: POOL, quarantined: true, reasonCode: "brigading" };

  for (const [label, run] of [
    ["inspect", (p: Probe, a: CallableRequest<unknown>["auth"], d: unknown) => handleInspectPool(req(a, d), p.deps)],
    ["quarantine", (p: Probe, a: CallableRequest<unknown>["auth"], d: unknown) => handleSetPoolQuarantine(req(a, d), p.deps)],
  ] as const) {
    const data = label === "inspect" ? inspectData : setData;
    for (const [who, auth] of [
      ["empty token", plainAuth],
      ["admin:false role:user", falseAdminAuth],
    ] as const) {
      const p = makeProbe();
      const code = await codeOf(run(p, auth, data));
      record(`${label}: non-admin (${who}) -> permission-denied, nothing touched`, code === "permission-denied" && untouched(p), code);
    }
    const p = makeProbe();
    const code = await codeOf(run(p, undefined, data));
    record(`${label}: unauthenticated -> unauthenticated, nothing touched`, code === "unauthenticated" && untouched(p), code);

    const q = makeProbe();
    const bad = await codeOf(run(q, plainAuth, { poolKey: "garbage" }));
    record(`${label}: non-admin with an invalid body is still permission-denied (auth first)`, bad === "permission-denied" && untouched(q), bad);
  }

  const viaRole = makeProbe();
  const roleCode = await codeOf(handleInspectPool(req(roleAdminAuth, inspectData), viaRole.deps));
  record("inspect: token.role === 'admin' is accepted", roleCode === "no-throw", roleCode);
}

async function validation(): Promise<void> {
  const invalidKeys: Array<[string, unknown]> = [
    ["missing", undefined],
    ["number", 42],
    ["empty string", ""],
    ["no version prefix", "aaaabbbbccccdddd"],
    ["uppercase hex", "v1:AAAABBBBCCCCDDDD"],
    ["15 hex chars", "v1:aaaabbbbccccddd"],
    ["17 hex chars", "v1:aaaabbbbccccddddd"],
    ["non-hex char", "v1:aaaabbbbccccddgd"],
    ["trailing newline", "v1:aaaabbbbccccdddd\n"],
    ["path injection", "v1:aaaabbbbccccdddd/../x"],
  ];
  for (const [label, key] of invalidKeys) {
    const p = makeProbe();
    const code = await codeOf(handleInspectPool(req(adminAuth, { poolKey: key }), p.deps));
    record(`inspect: invalid poolKey (${label}) -> invalid-argument, nothing touched`, code === "invalid-argument" && untouched(p), code);
  }
  const noBody = await codeOf(handleInspectPool(req(adminAuth, undefined), makeProbe().deps));
  record("inspect: undefined request body -> invalid-argument", noBody === "invalid-argument", noBody);

  let ok1 = false;
  let ok2 = false;
  try {
    ok1 = parsePoolKey({ poolKey: "v1:0123456789abcdef" }) === "v1:0123456789abcdef";
    ok2 = parsePoolKey({ poolKey: "v12:0123456789abcdef" }) === "v12:0123456789abcdef";
  } catch (err) {
    record("parsePoolKey accepts v1 and v12 keys", false, String(err));
  }
  record("parsePoolKey accepts v1 and v12 keys with 16 lowercase hex chars", ok1 && ok2);

  const badQuarantine: Array<[string, unknown]> = [
    ["reasonCode missing", { poolKey: POOL, quarantined: true }],
    ["reasonCode unknown", { poolKey: POOL, quarantined: true, reasonCode: "spam" }],
    ["reasonCode wrong type", { poolKey: POOL, quarantined: true, reasonCode: 1 }],
    ["reasonCode null", { poolKey: POOL, quarantined: true, reasonCode: null }],
    ["reasonCode free text", { poolKey: POOL, quarantined: true, reasonCode: "brigading!" }],
    ["quarantined missing", { poolKey: POOL, reasonCode: "other" }],
    ["quarantined string", { poolKey: POOL, quarantined: "true", reasonCode: "other" }],
    ["invalid poolKey", { poolKey: "nope", quarantined: true, reasonCode: "other" }],
  ];
  for (const [label, data] of badQuarantine) {
    const p = makeProbe();
    const code = await codeOf(handleSetPoolQuarantine(req(adminAuth, data), p.deps));
    record(`quarantine: ${label} -> invalid-argument, no rate limit, no write`, code === "invalid-argument" && untouched(p), code);
  }

  const lift = parseQuarantine({ poolKey: POOL, quarantined: false, reasonCode: "brigading" });
  record(
    "parseQuarantine: lift ignores a supplied reasonCode (null) and needs none",
    lift.quarantined === false && lift.reasonCode === null && parseQuarantine({ poolKey: POOL, quarantined: false }).reasonCode === null,
  );
  for (const code of ["brigading", "bad_merge", "other"]) {
    const parsed = parseQuarantine({ poolKey: POOL, quarantined: true, reasonCode: code });
    record(`parseQuarantine: reasonCode ${code} accepted`, parsed.reasonCode === code && parsed.quarantined === true);
  }
}

async function quarantineSet(): Promise<void> {
  const p = makeProbe();
  const res = await handleSetPoolQuarantine(
    req(adminAuth, { poolKey: POOL, quarantined: true, reasonCode: "bad_merge" }),
    p.deps,
  );
  const doc = p.fake.docs.get(`${POOL_QUARANTINE_COLLECTION}/${POOL}`);
  const keys = Object.keys(doc ?? {}).sort().join(",");
  record("quarantine set: returns { ok: true }", res.ok === true);
  record(
    "quarantine set: doc holds exactly poolKey, quarantined, reasonCode, updatedAt",
    keys === "poolKey,quarantined,reasonCode,updatedAt" &&
      doc?.poolKey === POOL &&
      doc?.quarantined === true &&
      doc?.reasonCode === "bad_merge" &&
      doc?.updatedAt != null,
    keys,
  );
  record(
    "quarantine set: doc carries no admin uid anywhere",
    !JSON.stringify(doc).includes(ADMIN_UID),
  );
  record(
    "quarantine set: aggregate called once with the pool key, after the write and the audit row",
    p.aggregateCalls.length === 1 &&
      p.aggregateCalls[0] === POOL &&
      p.fake.log.join(",") === "set,audit,aggregate",
    `${JSON.stringify(p.aggregateCalls)} ${p.fake.log.join(",")}`,
  );
  const row = p.fake.audit[0];
  const meta = (row?.metadata ?? {}) as Record<string, unknown>;
  record(
    "quarantine set: exactly one audit row, pool_quarantine_set, naming admin, pool and reason",
    p.fake.audit.length === 1 &&
      AUDIT_OP_QUARANTINE === "pool_quarantine_set" &&
      row.operation === "pool_quarantine_set" &&
      row.userId === ADMIN_UID &&
      row.resourceId === POOL &&
      row.resourceType === "canonical_recipe_stats" &&
      meta.actor === ADMIN_UID &&
      meta.reasonCode === "bad_merge",
    JSON.stringify(row),
  );
  record(
    "quarantine set: rate limit called once as (admin, adminSetPoolQuarantine) before any write",
    p.rateLimitCalls.length === 1 &&
      p.rateLimitCalls[0][0] === ADMIN_UID &&
      p.rateLimitCalls[0][1] === "adminSetPoolQuarantine",
    JSON.stringify(p.rateLimitCalls),
  );
}

async function quarantineLift(): Promise<void> {
  const p = makeProbe();
  p.fake.docs.set(`${POOL_QUARANTINE_COLLECTION}/${POOL}`, { poolKey: POOL, quarantined: true, reasonCode: "other" });
  p.fake.docs.set(`${POOL_QUARANTINE_COLLECTION}/${OTHER_POOL}`, { poolKey: OTHER_POOL, quarantined: true, reasonCode: "other" });
  await handleSetPoolQuarantine(req(roleAdminAuth, { poolKey: POOL, quarantined: false }), p.deps);
  const row = p.fake.audit[0];
  const meta = (row?.metadata ?? {}) as Record<string, unknown>;
  record(
    "quarantine lift: deletes only that pool's doc, aggregate called once, order delete,audit,aggregate",
    !p.fake.docs.has(`${POOL_QUARANTINE_COLLECTION}/${POOL}`) &&
      p.fake.docs.has(`${POOL_QUARANTINE_COLLECTION}/${OTHER_POOL}`) &&
      p.aggregateCalls.length === 1 &&
      p.aggregateCalls[0] === POOL &&
      p.fake.log.join(",") === "delete,audit,aggregate",
    p.fake.log.join(","),
  );
  record(
    "quarantine lift: one audit row pool_quarantine_lift without a reason code",
    p.fake.audit.length === 1 &&
      AUDIT_OP_LIFT === "pool_quarantine_lift" &&
      row.operation === "pool_quarantine_lift" &&
      row.userId === ADMIN_UID &&
      row.resourceId === POOL &&
      !("reasonCode" in meta),
    JSON.stringify(row),
  );
  record(
    "quarantine lift: rate limit operation is adminSetPoolQuarantine",
    p.rateLimitCalls.length === 1 && p.rateLimitCalls[0][1] === "adminSetPoolQuarantine",
  );

  // Lifting a pool that was never quarantined is harmless and still audited.
  const q = makeProbe();
  const code = await codeOf(handleSetPoolQuarantine(req(adminAuth, { poolKey: POOL, quarantined: false }), q.deps));
  record(
    "quarantine lift: of a pool with no doc succeeds, still aggregates and audits",
    code === "no-throw" && q.aggregateCalls.length === 1 && q.fake.audit.length === 1,
    code,
  );
}

function seedInspectionPool(p: Probe): string[] {
  // Ten votes; ratings give distribution [2,1,2,2,3] (4.5 -> star 4, 2.5 -> star 2).
  const spec: Array<[string, number, number]> = [
    // uid, rating, age
    ["uidAlpha01", 5, HOUR_MS],
    ["uidAlpha02", 4.5, HOUR_MS],
    ["uidAlpha03", 4, HOUR_MS],
    ["uidAlpha04", 3, DAY_MS], // exactly 24 h: inside votes24h
    ["uidAlpha05", 3, DAY_MS + 1], // 1 ms past 24 h: 7 d only
    ["uidAlpha06", 2.5, 3 * DAY_MS],
    ["uidAlpha07", 1, 3 * DAY_MS],
    ["uidAlpha08", 1, 7 * DAY_MS], // exactly 7 d: inside votes7d
    ["uidAlpha09", 5, 7 * DAY_MS + 1], // 1 ms past 7 d: outside
    ["uidAlpha10", 5, 10 * DAY_MS],
  ];
  spec.forEach(([uid, ratingValue, age], i) => {
    p.fake.events.push({
      uid,
      poolKey: POOL,
      ratingValue,
      createdAtMs: NOW - age,
      recipeId: `recipe-secret-${i}`,
      title: `Hemlig Lasagne ${i}`,
    });
  });
  p.fake.events.push({
    uid: "uidOtherPool",
    poolKey: OTHER_POOL,
    ratingValue: 1,
    createdAtMs: NOW - HOUR_MS,
    recipeId: "recipe-other",
    title: "Annan Rätt",
  });
  return spec.map(([uid]) => uid);
}

async function inspection(): Promise<void> {
  const facts = new Map<string, AccountFacts>([
    ["uidAlpha01", { createdMs: NOW - DAY_MS, emailVerified: true }], // young
    ["uidAlpha02", { createdMs: NOW - YOUNG_ACCOUNT_MS, emailVerified: true }], // exactly 7 d: not young
    ["uidAlpha03", { createdMs: NOW - YOUNG_ACCOUNT_MS + 1, emailVerified: false }], // young, unverified
    ["uidAlpha04", { createdMs: NOW - 30 * DAY_MS, emailVerified: false }], // unverified
    ["uidAlpha05", { createdMs: NOW - 30 * DAY_MS, emailVerified: false }], // unverified
    ["uidAlpha06", { createdMs: null, emailVerified: true }], // unknown age: not young
    // uidAlpha07 missing: deleted account, in the denominator, in neither share
    ["uidAlpha08", { createdMs: NOW - 100 * DAY_MS, emailVerified: true }],
    ["uidAlpha09", { createdMs: NOW - 2 * DAY_MS, emailVerified: false }], // young, unverified
    ["uidAlpha10", { createdMs: NOW - 400 * DAY_MS, emailVerified: true }],
  ]);
  const p = makeProbe(facts);
  const uids = seedInspectionPool(p);

  const res = await handleInspectPool(req(adminAuth, { poolKey: POOL }), p.deps);

  record(
    "inspect: count 10 and average 3.4 come from the aggregate over this pool only",
    res.count === 10 && res.average === 3.4 && p.fake.aggregateQueries === 1,
    `${res.count} ${res.average} aggregates=${p.fake.aggregateQueries}`,
  );
  record(
    "inspect: distribution counts per whole star ([2,1,2,2,3]; 4.5 -> 4, 2.5 -> 2, 5 only at 5)",
    JSON.stringify(res.distribution) === "[2,1,2,2,3]",
    JSON.stringify(res.distribution),
  );
  record(
    "inspect: votes24h 4 (24 h edge in) and votes7d 8 (7 d edge in, 1 ms past out)",
    res.votes24h === 4 && res.votes7d === 8,
    `${res.votes24h} ${res.votes7d}`,
  );
  record(
    "inspect: young share 0.3 and unverified share 0.4 over 10 sampled, deleted account in neither",
    res.sampled === 10 && res.youngAccountShare === 0.3 && res.unverifiedShare === 0.4,
    `${res.sampled} ${res.youngAccountShare} ${res.unverifiedShare}`,
  );
  record(
    "inspect: lookupAccounts called once with the 10 voter uids, newest vote first, limit RISK_SAMPLE",
    p.lookups.length === 1 &&
      p.lookups[0].length === 10 &&
      p.lookups[0][0] === "uidAlpha01" &&
      p.lookups[0][9] === "uidAlpha10" &&
      p.fake.limits.length === 1 &&
      p.fake.limits[0] === RISK_SAMPLE,
    JSON.stringify(p.lookups),
  );

  const json = JSON.stringify(res);
  const leakedUids = uids.filter((u) => json.includes(u));
  const leakedRecipes = p.fake.events.filter((e) => json.includes(e.recipeId) || json.includes(e.title));
  record(
    "inspect: response JSON holds no voter uid, no recipe id, no title (and no such keys)",
    leakedUids.length === 0 &&
      leakedRecipes.length === 0 &&
      !json.includes("recipeId") &&
      !json.includes("title") &&
      !json.includes("uid") &&
      !json.includes(ADMIN_UID),
    json,
  );

  const row = p.fake.audit[0];
  const rowJson = JSON.stringify(row);
  record(
    "inspect: exactly one audit row pool_inspect for the admin and pool, voters absent from it",
    p.fake.audit.length === 1 &&
      AUDIT_OP_INSPECT === "pool_inspect" &&
      row.operation === "pool_inspect" &&
      row.userId === ADMIN_UID &&
      row.resourceId === POOL &&
      uids.every((u) => !rowJson.includes(u)),
    rowJson,
  );
  record(
    "inspect: rate limit called once as (admin, adminInspectPool); nothing written or aggregated",
    p.rateLimitCalls.length === 1 &&
      p.rateLimitCalls[0][0] === ADMIN_UID &&
      p.rateLimitCalls[0][1] === "adminInspectPool" &&
      p.aggregateCalls.length === 0 &&
      p.fake.writes === 0,
    JSON.stringify(p.rateLimitCalls),
  );
}

async function inspectionStates(): Promise<void> {
  // Quarantine state is reported, and the numbers stay real while it is on.
  const q = makeProbe(new Map());
  seedInspectionPool(q);
  q.fake.docs.set(`${POOL_QUARANTINE_COLLECTION}/${POOL}`, { poolKey: POOL, quarantined: true, reasonCode: "brigading" });
  const quarantined = await inspectPool(ADMIN_UID, POOL, q.deps);
  record(
    "inspect: quarantined pool reports quarantined + reasonCode and still the real count",
    quarantined.quarantined === true && quarantined.reasonCode === "brigading" && quarantined.count === 10,
    JSON.stringify(quarantined),
  );

  const u = makeProbe();
  u.fake.docs.set(`${POOL_QUARANTINE_COLLECTION}/${POOL}`, { quarantined: true, reasonCode: "not-a-code" });
  const unknown = await inspectPool(ADMIN_UID, POOL, u.deps);
  record("inspect: an unknown stored reasonCode is reported as null", unknown.quarantined === true && unknown.reasonCode === null, JSON.stringify(unknown));

  const l = makeProbe();
  l.fake.docs.set(`${POOL_QUARANTINE_COLLECTION}/${POOL}`, { quarantined: false, reasonCode: "other" });
  const lifted = await inspectPool(ADMIN_UID, POOL, l.deps);
  record("inspect: quarantined:false doc is not quarantined", lifted.quarantined === false, JSON.stringify(lifted));

  // Empty pool: no accounts to look up, shares null, average null.
  const e = makeProbe();
  const empty = await inspectPool(ADMIN_UID, POOL, e.deps);
  record(
    "inspect: empty pool -> count 0, average null, zero distribution, null shares, no account lookup",
    empty.count === 0 &&
      empty.average === null &&
      JSON.stringify(empty.distribution) === "[0,0,0,0,0]" &&
      empty.sampled === 0 &&
      empty.youngAccountShare === null &&
      empty.unverifiedShare === null &&
      e.lookups.length === 0 &&
      e.fake.audit.length === 1,
    JSON.stringify(empty),
  );
}

async function main(): Promise<void> {
  console.log("pool-moderation tests\n");
  await accessControl();
  await validation();
  await quarantineSet();
  await quarantineLift();
  await inspection();
  await inspectionStates();

  console.log(`\n${totalRun - totalFailed}/${totalRun} passed`);
  if (totalFailed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
