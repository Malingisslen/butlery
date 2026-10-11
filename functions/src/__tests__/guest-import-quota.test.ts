/**
 * BUT-920: the guest AI-import quota (`llm/guest-import-quota.ts`).
 *
 * Driven through `withGuestImportQuota`, the shape the structureRecipe and
 * ocrRecipeImage callables wrap, with the store being the shared in-memory
 * `FakeFirestore` (its transaction applies writes only when the callback
 * resolves, so a refused call writes nothing). The import-count refusal and
 * the call-count refusal share one reason string, so each is staged where
 * the other cannot fire: the fourth distinct id is refused with three calls
 * made, and the call ceiling is reached by reusing one id.
 *
 * Run: npx ts-node src/__tests__/guest-import-quota.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import type { CallableRequest } from "firebase-functions/v2/https";
import { FakeFirestore } from "./_fake-firestore";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  withGuestImportQuota,
  isGuestRequest,
  GUEST_CALL_LIMIT,
  GUEST_IMPORT_LIMIT,
} from "../llm/guest-import-quota";

interface Req {
  guestImportId?: string;
}
interface Res {
  success?: boolean;
  estimatedCost: number;
}

const GUEST = "guest-uid";
const OTHER_GUEST = "guest-uid-2";
const DAY1 = new Date(Date.UTC(2026, 9, 11, 23, 30));
const DAY2 = new Date(Date.UTC(2026, 9, 12, 0, 5));

function request(
  uid: string,
  provider: string | undefined,
  data: Record<string, unknown>,
): CallableRequest<Req> {
  const token: Record<string, unknown> = {};
  if (provider !== undefined) token.firebase = { sign_in_provider: provider };
  return { auth: { uid, token }, data } as unknown as CallableRequest<Req>;
}

/** A db that fails the test on ANY use. */
function untouchableDb(): never {
  return new Proxy(
    {},
    {
      get(_t, prop) {
        throw new Error(`db.${String(prop)} touched for a non-guest`);
      },
    },
  ) as never;
}

interface Harness {
  store: FakeFirestore;
  /** Paths read inside a transaction, in order. */
  txReads: string[];
  handlerCalls: number;
  now: Date;
  dailyLimit: number;
  next: () => Promise<Res>;
  call: (uid: string, id: unknown) => Promise<Res>;
}

/**
 * The shared fake records writes, not reads; this wraps its transaction so the
 * paths a transaction reads can be asserted on.
 */
function readRecordingDb(store: FakeFirestore, reads: string[]): FakeFirestore["db"] {
  return new Proxy(store, {
    get(target, prop) {
      if (prop === "runTransaction") {
        return <T>(fn: (tx: unknown) => Promise<T>) =>
          target.runTransaction((tx) => {
            const inner = tx as { get: (ref: { path: string }) => Promise<unknown> };
            return fn({
              ...inner,
              get: (ref: { path: string }) => {
                reads.push(ref.path);
                return inner.get(ref);
              },
            });
          });
      }
      const value = Reflect.get(target, prop, target);
      return typeof value === "function" ? value.bind(target) : value;
    },
  }) as unknown as FakeFirestore["db"];
}

function harness(): Harness {
  const store = new FakeFirestore();
  const txReads: string[] = [];
  const h: Harness = {
    store,
    txReads,
    handlerCalls: 0,
    now: DAY1,
    dailyLimit: 300,
    next: async () => ({ success: true, estimatedCost: 0 }),
    call: async () => ({ estimatedCost: 0 }),
  };
  const wrapped = withGuestImportQuota<Req, Res>(
    async () => {
      h.handlerCalls++;
      return h.next();
    },
    {
      db: readRecordingDb(store, txReads),
      now: () => h.now,
      loadDailyLimit: async () => h.dailyLimit,
    },
  );
  h.call = (uid, id) =>
    wrapped(request(uid, "anonymous", id === undefined ? {} : { guestImportId: id }));
  return h;
}

async function expectRefusal(
  p: Promise<unknown>,
  code: string,
  reason: string,
): Promise<void> {
  let caught: unknown = null;
  try {
    await p;
  } catch (err) {
    caught = err;
  }
  if (caught === null) throw new Error(`expected ${code}/${reason}, call succeeded`);
  const e = caught as { code?: string; details?: { reason?: string } };
  assertEqual(e.code, code, "error code");
  assertEqual(e.details?.reason, reason, "error reason");
}

function quota(h: Harness, uid = GUEST): { importIds?: string[]; calls?: number } {
  return (h.store.read(`guest_quotas/${uid}`) ?? {}) as {
    importIds?: string[];
    calls?: number;
  };
}

/** Resolves once `cond` holds, letting pending microtasks and I/O run. */
async function until(cond: () => boolean): Promise<void> {
  for (let i = 0; i < 100 && !cond(); i++) {
    await new Promise((r) => setImmediate(r));
  }
  if (!cond()) throw new Error("condition never held");
}

function deferred<T>(): { promise: Promise<T>; resolve: (v: T) => void; reject: (e: unknown) => void } {
  let resolve!: (v: T) => void;
  let reject!: (e: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

function daily(h: Harness): { dailyCount?: number; dayKey?: string } {
  return (h.store.read("system/guestImportLimits") ?? {}) as {
    dailyCount?: number;
    dayKey?: string;
  };
}

const cases: UnitCase[] = [
  {
    name: "isGuestRequest is true only for an anonymous sign-in",
    fn: () => {
      assertEqual(isGuestRequest(request("u", "anonymous", {}).auth), true, "anonymous");
      assertEqual(isGuestRequest(request("u", "password", {}).auth), false, "password");
      assertEqual(isGuestRequest(request("u", undefined, {}).auth), false, "no firebase field");
      assertEqual(isGuestRequest(undefined), false, "no auth");
    },
  },
  {
    name: "a non-guest passes straight through without touching Firestore, even with no guestImportId",
    fn: async () => {
      let calls = 0;
      const wrapped = withGuestImportQuota<Req, Res>(
        async () => {
          calls++;
          return { success: false, estimatedCost: 0 };
        },
        {
          db: untouchableDb(),
          loadDailyLimit: async () => {
            throw new Error("daily limit loaded for a non-guest");
          },
        },
      );
      for (const provider of ["password", "google.com", undefined]) {
        const res = await wrapped(request("full-user", provider, {}));
        assertEqual(res.success, false, `handler result returned (${provider})`);
      }
      assertEqual(calls, 3, "handler ran once per call");
    },
  },
  {
    name: "a guest call with a missing or malformed guestImportId is refused failed-precondition and writes nothing",
    fn: async () => {
      const h = harness();
      for (const bad of [undefined, "", "a/b", "x".repeat(65), 42, "has space", "__x__"]) {
        await expectRefusal(h.call(GUEST, bad), "failed-precondition", "guest-import-id-required");
      }
      assertEqual(h.handlerCalls, 0, "handler never ran");
      assertEqual(h.store.writes.length, 0, "no writes");
    },
  },
  {
    name: "the first three distinct imports are allowed and the fourth is refused guest-import-limit",
    fn: async () => {
      const h = harness();
      assertEqual(GUEST_IMPORT_LIMIT, 3, "premise: limit is 3");
      for (const id of ["imp-a", "imp-b", "imp-c"]) await h.call(GUEST, id);
      assertEqual(h.handlerCalls, 3, "three imports ran");
      await expectRefusal(h.call(GUEST, "imp-d"), "resource-exhausted", "guest-import-limit");
      assertEqual(h.handlerCalls, 3, "the fourth never reached the handler");
      const q = quota(h);
      assertEqual(JSON.stringify(q.importIds), JSON.stringify(["imp-a", "imp-b", "imp-c"]), "ids");
      assertEqual(q.calls, 3, "calls (well under the call ceiling, so only the import branch refused)");
    },
  },
  {
    name: "reusing an import id does not open a new slot, even after all three are taken",
    fn: async () => {
      const h = harness();
      for (const id of ["imp-a", "imp-b", "imp-c"]) await h.call(GUEST, id);
      await h.call(GUEST, "imp-b");
      await h.call(GUEST, "imp-a");
      assertEqual(h.handlerCalls, 5, "reused ids ran");
      const q = quota(h);
      assertEqual(q.importIds?.length, 3, "still three ids");
      assertEqual(q.calls, 5, "every call counted");
      assertEqual(daily(h).dailyCount, 3, "daily count moves only for new imports");
    },
  },
  {
    name: "the lifetime call ceiling refuses the 13th call on a single reused id",
    fn: async () => {
      const h = harness();
      assertEqual(GUEST_CALL_LIMIT, 12, "premise: ceiling is 12");
      for (let i = 0; i < GUEST_CALL_LIMIT; i++) await h.call(GUEST, "only-one");
      assertEqual(h.handlerCalls, 12, "twelve calls ran");
      await expectRefusal(h.call(GUEST, "only-one"), "resource-exhausted", "guest-import-limit");
      assertEqual(h.handlerCalls, 12, "13th never reached the handler");
      assertEqual(quota(h).importIds?.length, 1, "one id, so the import branch could not refuse");
      assertEqual(quota(h).calls, 12, "the refused call wrote nothing");
    },
  },
  {
    name: "the shared daily ceiling refuses a new import with guest-capacity, and resets on a new UTC day",
    fn: async () => {
      const h = harness();
      h.dailyLimit = 2;
      await h.call(GUEST, "imp-a");
      await h.call(GUEST, "imp-b");
      assertEqual(daily(h).dailyCount, 2, "two new imports counted");
      await expectRefusal(h.call(OTHER_GUEST, "imp-x"), "resource-exhausted", "guest-capacity");
      assertEqual(quota(h, OTHER_GUEST).calls, undefined, "the refused guest got no quota doc");
      // An already-open import is not a new one, so the daily ceiling does not apply.
      await h.call(GUEST, "imp-a");
      assertEqual(h.handlerCalls, 3, "reused id still ran at the ceiling");

      h.now = DAY2;
      await h.call(OTHER_GUEST, "imp-x");
      assertEqual(h.handlerCalls, 4, "allowed on the next UTC day");
      assertEqual(daily(h).dailyCount, 1, "count restarted at 1 for the new day");
    },
  },
  {
    name: "a handler that throws is refunded: the new id is removed, an earlier id is kept, and the error propagates",
    fn: async () => {
      const h = harness();
      await h.call(GUEST, "imp-a");
      h.next = async () => {
        throw new Error("model failed");
      };
      let msg = "";
      try {
        await h.call(GUEST, "imp-b");
      } catch (err) {
        msg = (err as Error).message;
      }
      assertEqual(msg, "model failed", "original error rethrown");
      const q = quota(h);
      assertEqual(JSON.stringify(q.importIds), JSON.stringify(["imp-a"]), "imp-b refunded, imp-a kept");
      assertEqual(q.calls, 1, "call refunded");
      assertEqual(daily(h).dailyCount, 1, "daily count refunded: a throw spent nothing");

      // A failing call on the earlier id gives back the call but keeps the id.
      try {
        await h.call(GUEST, "imp-a");
      } catch {
        /* expected */
      }
      assertEqual(JSON.stringify(quota(h).importIds), JSON.stringify(["imp-a"]), "earlier id kept");
      assertEqual(quota(h).calls, 1, "call refunded");
      assertEqual(daily(h).dailyCount, 1, "a reused id charged no daily count, so none comes back");
    },
  },
  {
    name: "success:false with estimatedCost 0 is refunded like a throw; success:true is not",
    fn: async () => {
      const h = harness();
      await h.call(GUEST, "imp-a");
      h.next = async () => ({ success: false, estimatedCost: 0 });
      const res = await h.call(GUEST, "imp-b");
      assertEqual(res.success, false, "result passed back");
      assertEqual(JSON.stringify(quota(h).importIds), JSON.stringify(["imp-a"]), "imp-b refunded");
      assertEqual(quota(h).calls, 1, "call refunded");
      assertEqual(daily(h).dailyCount, 1, "daily count refunded: nothing was spent");

      h.next = async () => ({ success: true, estimatedCost: 0 });
      await h.call(GUEST, "imp-b");
      assertEqual(JSON.stringify(quota(h).importIds), JSON.stringify(["imp-a", "imp-b"]), "kept on success");
      assertEqual(quota(h).calls, 2, "call kept on success");
    },
  },
  {
    name: "success:false with estimatedCost > 0 gives the import slot back but keeps the call and the daily count",
    fn: async () => {
      const h = harness();
      await h.call(GUEST, "imp-a");
      h.next = async () => ({ success: false, estimatedCost: 0.002 });
      const res = await h.call(GUEST, "imp-b");
      assertEqual(res.success, false, "result passed back");
      const q = quota(h);
      assertEqual(JSON.stringify(q.importIds), JSON.stringify(["imp-a"]), "imp-b slot given back");
      assertEqual(q.calls, 2, "the paid call still counts");
      assertEqual(daily(h).dailyCount, 2, "the paid import still counts toward the shared day");
    },
  },
  {
    name: "a refund leaves the daily count alone once the day it was charged on has rolled over",
    fn: async () => {
      const h = harness();
      h.next = async () => {
        // Another guest opened the next day's first imports while this call ran.
        h.store.seed("system/guestImportLimits", { dayKey: "another-day", dailyCount: 5 });
        throw new Error("model failed");
      };
      try {
        await h.call(GUEST, "imp-a");
      } catch {
        /* expected */
      }
      assertEqual(quota(h).calls, 0, "call refunded");
      assertEqual(daily(h).dailyCount, 5, "the new day's count is not decremented");
      assertEqual(daily(h).dayKey, "another-day", "the new day's key stands");
    },
  },
  {
    name: "a reused id never reads the shared daily document, on the charge or on its refund",
    fn: async () => {
      const h = harness();
      await h.call(GUEST, "imp-a");
      assertEqual(
        JSON.stringify(h.txReads),
        JSON.stringify([`guest_quotas/${GUEST}`, "system/guestImportLimits"]),
        "control: a new id reads both",
      );
      h.txReads.length = 0;
      await h.call(GUEST, "imp-a");
      h.next = async () => ({ success: false, estimatedCost: 0 });
      await h.call(GUEST, "imp-a");
      assertEqual(
        JSON.stringify(h.txReads),
        JSON.stringify([`guest_quotas/${GUEST}`, `guest_quotas/${GUEST}`, `guest_quotas/${GUEST}`]),
        "charge, charge, refund: only the guest's own doc",
      );
    },
  },
  {
    name: "an import another call joined stays held and charged when its opener fails first",
    fn: async () => {
      const h = harness();
      const opener = deferred<Res>();
      const joiner = deferred<Res>();
      const gates = [opener, joiner];
      h.next = () => gates[h.handlerCalls - 1].promise;

      const first = h.call(GUEST, "imp-a").catch((err: Error) => err.message);
      await until(() => h.handlerCalls === 1);
      const second = h.call(GUEST, "imp-a");
      await until(() => h.handlerCalls === 2);
      assertEqual(quota(h).calls, 2, "premise: both calls charged");

      opener.reject(new Error("model failed"));
      assertEqual(await first, "model failed", "opener's error propagates");
      assertEqual(JSON.stringify(quota(h).importIds), JSON.stringify(["imp-a"]), "the joiner still holds the id");
      assertEqual(daily(h).dailyCount, 1, "the daily charge stays while the joiner runs");

      joiner.resolve({ success: true, estimatedCost: 0.002 });
      assertEqual((await second).success, true, "joiner's result returned");
      const q = quota(h);
      assertEqual(JSON.stringify(q.importIds), JSON.stringify(["imp-a"]), "the completed import counts");
      assertEqual(q.calls, 1, "only the joiner's call is charged");
      assertEqual(daily(h).dailyCount, 1, "the completed import stays on the shared count");
    },
  },
  {
    name: "an import another call joined stays held and charged when its opener fails last",
    fn: async () => {
      const h = harness();
      const opener = deferred<Res>();
      const joiner = deferred<Res>();
      const gates = [opener, joiner];
      h.next = () => gates[h.handlerCalls - 1].promise;

      const first = h.call(GUEST, "imp-a").catch((err: Error) => err.message);
      await until(() => h.handlerCalls === 1);
      const second = h.call(GUEST, "imp-a");
      await until(() => h.handlerCalls === 2);

      joiner.resolve({ success: true, estimatedCost: 0.002 });
      assertEqual((await second).success, true, "joiner's result returned");
      opener.reject(new Error("model failed"));
      assertEqual(await first, "model failed", "opener's error propagates");

      const q = quota(h);
      assertEqual(JSON.stringify(q.importIds), JSON.stringify(["imp-a"]), "the completed import counts");
      assertEqual(q.calls, 1, "only the joiner's call is charged");
      assertEqual(daily(h).dailyCount, 1, "the completed import stays on the shared count");
    },
  },
  {
    name: "a paid failure on a joined import keeps the shared daily count when the last call closes it unpaid",
    fn: async () => {
      const h = harness();
      const opener = deferred<Res>();
      const joiner = deferred<Res>();
      const gates = [opener, joiner];
      h.next = () => gates[h.handlerCalls - 1].promise;
      const first = h.call(GUEST, "imp-a").catch((err: Error) => err.message);
      await until(() => h.handlerCalls === 1);
      const second = h.call(GUEST, "imp-a");
      await until(() => h.handlerCalls === 2);
      joiner.resolve({ success: false, estimatedCost: 0.002 });
      assertEqual((await second).success, false, "joiner's paid failure returned");
      opener.reject(new Error("model failed"));
      assertEqual(await first, "model failed", "opener's error propagates");
      const q = quota(h);
      assertEqual(JSON.stringify(q.importIds), JSON.stringify([]), "the failed import's slot comes back");
      assertEqual(q.calls, 1, "the paid call stays charged");
      assertEqual(daily(h).dailyCount, 1, "a model was paid on this import, so the shared count stays");
    },
  },
  {
    name: "a successful call on an id already held neither duplicates it nor drops the guest's other ids",
    fn: async () => {
      const h = harness();
      await h.call(GUEST, "imp-a");
      await h.call(GUEST, "imp-b");
      await h.call(GUEST, "imp-a");
      assertEqual(JSON.stringify(quota(h).importIds), JSON.stringify(["imp-a", "imp-b"]), "ids unchanged");
    },
  },
  {
    name: "a refunded import slot can be used again, so three failures do not lock a guest out",
    fn: async () => {
      const h = harness();
      h.next = async () => ({ success: false, estimatedCost: 0 });
      for (const id of ["f1", "f2", "f3", "f4"]) await h.call(GUEST, id);
      h.next = async () => ({ success: true, estimatedCost: 0 });
      for (const id of ["imp-a", "imp-b", "imp-c"]) await h.call(GUEST, id);
      assertEqual(quota(h).importIds?.length, 3, "three real imports");
      assertEqual(h.handlerCalls, 7, "every call ran");
    },
  },
  {
    // The onCall bodies cannot be reached without an app, so the wiring is
    // pinned on source; testing the wrapper alone leaves deleting it green.
    name: "structureRecipe and ocrRecipeImage wrap withRateLimit in withGuestImportQuota, inside withCostLedger",
    fn: () => {
      for (const [file, op] of [
        ["structure-recipe.ts", "structureRecipe"],
        ["ocr-recipe-image.ts", "ocrRecipeImage"],
      ]) {
        const src = fs.readFileSync(path.resolve(__dirname, "..", "llm", file), "utf8");
        const wired = `withCostLedger(withGuestImportQuota(withRateLimit("${op}",`;
        assertEqual(src.split(wired).length - 1, 1, `${file}: ${wired}`);
      }
    },
  },
];

runTests("BUT-920 guest import quota", cases).catch((err) => {
  console.error(err);
  process.exit(1);
});
