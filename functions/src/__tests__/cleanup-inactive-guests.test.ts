/**
 * BUT-920: the abandoned-guest sweep (`cleanup/cleanup-inactive-guests.ts`).
 *
 * Driven through `cleanupInactiveGuestsWithDeps` with a fake Auth whose
 * `getUser` answers from a map the test can change between the listing and
 * the re-fetch, so "linked or used since the page was listed" is staged at
 * the moment the sweep re-reads, not before it lists.
 *
 * Run: npx ts-node src/__tests__/cleanup-inactive-guests.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-inactive-guests" });
}
import type { UserRecord } from "firebase-admin/auth";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import { FakeFirestore } from "./_fake-firestore";

// Required after initializeApp: request-account-deletion builds a module-level
// `admin.firestore()`.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const sweep = require("../cleanup/cleanup-inactive-guests") as typeof import("../cleanup/cleanup-inactive-guests");
const {
  isAbandonedGuest,
  cleanupInactiveGuestsWithDeps,
  productionGuestSweepDeps,
  GUEST_INACTIVE_REASON,
  MAX_GUEST_ERASURES_PER_RUN,
  GUEST_RUN_BUDGET_MS,
  GUEST_INACTIVE_DAYS,
} = sweep;

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 9, 11, 12, 0);

interface UserOpts {
  providers?: string[];
  email?: string;
  phone?: string;
  claims?: Record<string, unknown>;
  idleMs?: number;
  lastRefresh?: string | null;
  lastSignIn?: string;
}

function user(uid: string, o: UserOpts = {}): UserRecord {
  const at = new Date(NOW - (o.idleMs ?? 31 * DAY)).toUTCString();
  return {
    uid,
    providerData: (o.providers ?? []).map((providerId) => ({ providerId, uid })),
    email: o.email,
    phoneNumber: o.phone,
    customClaims: o.claims,
    metadata: {
      creationTime: new Date(NOW - 400 * DAY).toUTCString(),
      lastSignInTime: o.lastSignIn ?? new Date(NOW - 400 * DAY).toUTCString(),
      lastRefreshTime: o.lastRefresh === undefined ? at : o.lastRefresh,
    },
  } as unknown as UserRecord;
}

interface FakeAuth {
  pages: UserRecord[][];
  fresh: Map<string, UserRecord>;
  pageTokensSeen: Array<string | undefined>;
  getUserCalls: string[];
  /** Runs inside getUser, before it answers: the race seam. */
  beforeGetUser?: (uid: string) => void;
  /** getUser rejects with this code for these uids. */
  getUserErrors: Map<string, string>;
}

type EraseResult = { success: boolean; failedCollections: string[] };
const OK: EraseResult = { success: true, failedCollections: [] };

function fakeAuth(pages: UserRecord[][]): FakeAuth {
  const fresh = new Map<string, UserRecord>();
  for (const page of pages) for (const u of page) fresh.set(u.uid, u);
  return { pages, fresh, pageTokensSeen: [], getUserCalls: [], getUserErrors: new Map() };
}

function depsFor(
  fa: FakeAuth,
  erase: (uid: string) => Promise<EraseResult>,
  requeued: string[] = [],
): Parameters<typeof cleanupInactiveGuestsWithDeps>[0] {
  return {
    auth: {
      listUsers: async (_max?: number, pageToken?: string) => {
        fa.pageTokensSeen.push(pageToken);
        const index = pageToken === undefined ? 0 : Number(pageToken.slice(1));
        const next = index + 1 < fa.pages.length ? `p${index + 1}` : undefined;
        return { users: fa.pages[index], pageToken: next };
      },
      getUser: async (uid: string) => {
        fa.getUserCalls.push(uid);
        fa.beforeGetUser?.(uid);
        const code = fa.getUserErrors.get(uid);
        if (code) throw Object.assign(new Error(code), { code });
        const u = fa.fresh.get(uid);
        if (!u) {
          throw Object.assign(new Error("no user"), { code: "auth/user-not-found" });
        }
        return u;
      },
    } as never,
    erase,
    requeue: async (uid: string) => {
      requeued.push(uid);
    },
  };
}

function recordingErase(): {
  erased: string[];
  fn: (uid: string) => Promise<EraseResult>;
} {
  const erased: string[] = [];
  return {
    erased,
    fn: async (uid) => {
      erased.push(uid);
      return OK;
    },
  };
}

const cases: UnitCase[] = [
  {
    name: "isAbandonedGuest: true for an idle anonymous account, at and past the 30-day line",
    fn: () => {
      assertEqual(GUEST_INACTIVE_DAYS, 30, "premise: 30 days");
      assertEqual(isAbandonedGuest(user("g", { idleMs: 31 * DAY }), NOW), true, "31 days");
      assertEqual(isAbandonedGuest(user("g", { idleMs: 30 * DAY }), NOW), true, "exactly 30 days");
      assertEqual(isAbandonedGuest(user("g", { idleMs: 30 * DAY - 1000 }), NOW), false, "1 s short (metadata strings carry whole seconds)");
    },
  },
  {
    name: "isAbandonedGuest: a provider, an email or a phone each keep a stale account; the ageCompliant claim does not",
    fn: () => {
      const stale = 400 * DAY;
      assertEqual(isAbandonedGuest(user("u", { idleMs: stale, providers: ["password"] }), NOW), false, "provider");
      assertEqual(isAbandonedGuest(user("u", { idleMs: stale, email: "a@b.se" }), NOW), false, "email");
      assertEqual(isAbandonedGuest(user("u", { idleMs: stale, phone: "+46700000000" }), NOW), false, "phone");
      // A guest can obtain the claim itself through verifySignupAge, so it
      // must not exempt the account.
      assertEqual(
        isAbandonedGuest(user("u", { idleMs: stale, claims: { ageCompliant: true } }), NOW),
        true,
        "ageCompliant claim",
      );
    },
  },
  {
    name: "isAbandonedGuest: falls back to lastSignInTime when there is no refresh time, and never erases on an unreadable date",
    fn: () => {
      const recent = new Date(NOW - 2 * DAY).toUTCString();
      assertEqual(
        isAbandonedGuest(user("g", { lastRefresh: null, lastSignIn: recent }), NOW),
        false,
        "recent sign-in keeps it",
      );
      assertEqual(
        isAbandonedGuest(user("g", { lastRefresh: "not a date" }), NOW),
        false,
        "unparsable date keeps it",
      );
    },
  },
  {
    name: "sweep: a linked (non-empty providerData) stale account is never erased or re-fetched",
    fn: async () => {
      const fa = fakeAuth([
        [user("linked", { providers: ["google.com"], idleMs: 400 * DAY }), user("guest")],
      ]);
      const er = recordingErase();
      const s = await cleanupInactiveGuestsWithDeps(depsFor(fa, er.fn), NOW, () => NOW);
      assertEqual(JSON.stringify(er.erased), JSON.stringify(["guest"]), "only the guest erased");
      assertEqual(JSON.stringify(fa.getUserCalls), JSON.stringify(["guest"]), "only the guest re-fetched");
      assertEqual(s.scanned, 2, "scanned");
      assertEqual(s.erased, 1, "erased");
    },
  },
  {
    name: "sweep: a guest that linked a provider between listUsers and getUser is skipped",
    fn: async () => {
      const fa = fakeAuth([[user("upgrading"), user("guest")]]);
      fa.beforeGetUser = (uid) => {
        if (uid === "upgrading") {
          fa.fresh.set(uid, user(uid, { providers: ["password"], email: "x@y.se" }));
        }
      };
      const er = recordingErase();
      const s = await cleanupInactiveGuestsWithDeps(depsFor(fa, er.fn), NOW, () => NOW);
      assertEqual(JSON.stringify(er.erased), JSON.stringify(["guest"]), "upgrading account kept");
      assertEqual(s.erased, 1, "erased");
      assertEqual(s.failed, 0, "a skip is not a failure");
    },
  },
  {
    name: "sweep: a guest that opened the app since the listing, or is already gone, is skipped",
    fn: async () => {
      const fa = fakeAuth([[user("returned"), user("gone"), user("guest")]]);
      fa.beforeGetUser = (uid) => {
        if (uid === "returned") fa.fresh.set(uid, user(uid, { idleMs: DAY }));
        if (uid === "gone") fa.fresh.delete(uid);
      };
      const er = recordingErase();
      const s = await cleanupInactiveGuestsWithDeps(depsFor(fa, er.fn), NOW, () => NOW);
      assertEqual(JSON.stringify(er.erased), JSON.stringify(["guest"]), "only the still-idle guest");
      assertEqual(s.failed, 0, "no failures");
    },
  },
  {
    name: "sweep: the per-run cap erases the first MAX and defers the rest",
    fn: async () => {
      const n = MAX_GUEST_ERASURES_PER_RUN + 5;
      const fa = fakeAuth([Array.from({ length: n }, (_, i) => user(`g${i}`))]);
      const er = recordingErase();
      const s = await cleanupInactiveGuestsWithDeps(depsFor(fa, er.fn), NOW, () => NOW);
      assertEqual(er.erased.length, MAX_GUEST_ERASURES_PER_RUN, "erased up to the cap");
      assertEqual(s.erased, MAX_GUEST_ERASURES_PER_RUN, "summary erased");
      assertEqual(s.deferred, 5, "the rest deferred");
      assertEqual(fa.getUserCalls.length, MAX_GUEST_ERASURES_PER_RUN, "deferred ones are not re-fetched");
    },
  },
  {
    name: "sweep: failed erasures count against the cap",
    fn: async () => {
      const n = MAX_GUEST_ERASURES_PER_RUN + 3;
      const fa = fakeAuth([Array.from({ length: n }, (_, i) => user(`g${i}`))]);
      let calls = 0;
      const s = await cleanupInactiveGuestsWithDeps(
        depsFor(fa, async () => {
          calls++;
          return { success: false, failedCollections: ["recipes"] };
        }),
        NOW,
        () => NOW,
      );
      assertEqual(calls, MAX_GUEST_ERASURES_PER_RUN, "attempts stop at the cap");
      assertEqual(s.failed, MAX_GUEST_ERASURES_PER_RUN, "failed");
      assertEqual(s.deferred, 3, "deferred");
    },
  },
  {
    name: "sweep: no erasure starts once the time budget is spent; the rest are deferred",
    fn: async () => {
      const fa = fakeAuth([Array.from({ length: 5 }, (_, i) => user(`g${i}`))]);
      let t = NOW;
      const step = 150 * 1000;
      assertEqual(GUEST_RUN_BUDGET_MS > 2 * step && GUEST_RUN_BUDGET_MS < 3 * step, true, "premise: budget between 2 and 3 steps");
      const erased: string[] = [];
      const s = await cleanupInactiveGuestsWithDeps(
        depsFor(fa, async (uid) => {
          erased.push(uid);
          t += step;
          return OK;
        }),
        NOW,
        () => t,
      );
      // Starts at 0, 150 s, 300 s; the fourth would start at 450 s.
      assertEqual(JSON.stringify(erased), JSON.stringify(["g0", "g1", "g2"]), "erased before the budget");
      assertEqual(s.deferred, 2, "deferred after the budget");
    },
  },
  {
    name: "sweep: an erasure that throws or returns success:false is counted and the run carries on",
    fn: async () => {
      const fa = fakeAuth([[user("a"), user("throws"), user("b"), user("refused"), user("c")]]);
      const erased: string[] = [];
      const s = await cleanupInactiveGuestsWithDeps(
        depsFor(fa, async (uid) => {
          if (uid === "throws") throw new Error("cascade blew up");
          if (uid === "refused") return { success: false, failedCollections: ["recipes"] };
          erased.push(uid);
          return OK;
        }),
        NOW,
        () => NOW,
      );
      assertEqual(JSON.stringify(erased), JSON.stringify(["a", "b", "c"]), "later guests still erased");
      assertEqual(s.erased, 3, "erased");
      assertEqual(s.failed, 2, "failed");
    },
  },
  {
    name: "sweep: an incomplete erasure is re-queued for runDueAccountDeletions, unless the Auth delete itself failed",
    fn: async () => {
      const fa = fakeAuth([[user("partial"), user("auth-failed"), user("threw"), user("clean")]]);
      const requeued: string[] = [];
      const s = await cleanupInactiveGuestsWithDeps(
        depsFor(
          fa,
          async (uid) => {
            if (uid === "partial") return { success: false, failedCollections: ["recipes"] };
            if (uid === "auth-failed") {
              return { success: false, failedCollections: ["recipes", "auth_deletion"] };
            }
            if (uid === "threw") throw new Error("cascade blew up");
            return OK;
          },
          requeued,
        ),
        NOW,
        () => NOW,
      );
      // The Auth record survives a failed Auth delete, so the next sweep lists
      // it again; once it is gone, only the request doc brings it back.
      assertEqual(JSON.stringify(requeued), JSON.stringify(["partial"]), "only the Auth-deleted partial erasure");
      assertEqual(s.failed, 3, "failed");
      assertEqual(s.erased, 1, "erased");
    },
  },
  {
    name: "sweep: a failing re-queue is logged and the run carries on",
    fn: async () => {
      const fa = fakeAuth([[user("partial"), user("next")]]);
      const er = recordingErase();
      const deps = depsFor(fa, async (uid) =>
        uid === "partial" ? { success: false, failedCollections: ["recipes"] } : er.fn(uid),
      );
      deps.requeue = async () => {
        throw Object.assign(new Error("unavailable"), { code: 14 });
      };
      const s = await cleanupInactiveGuestsWithDeps(deps, NOW, () => NOW);
      assertEqual(JSON.stringify(er.erased), JSON.stringify(["next"]), "next guest still erased");
      assertEqual(s.failed, 1, "failed");
    },
  },
  {
    name: "sweep: a getUser error other than not-found counts as a failure, skips that guest, and the run carries on",
    fn: async () => {
      const fa = fakeAuth([[user("flaky"), user("gone"), user("guest")]]);
      fa.getUserErrors.set("flaky", "auth/internal-error");
      fa.getUserErrors.set("gone", "auth/user-not-found");
      const er = recordingErase();
      const s = await cleanupInactiveGuestsWithDeps(depsFor(fa, er.fn), NOW, () => NOW);
      assertEqual(JSON.stringify(er.erased), JSON.stringify(["guest"]), "only the readable guest erased");
      assertEqual(s.failed, 1, "the internal error counts; not-found does not");
      assertEqual(s.erased, 1, "erased");
    },
  },
  {
    name: "sweep: no further page is listed once the time budget is spent",
    fn: async () => {
      const fa = fakeAuth([[user("p0-guest")], [user("p1-guest")]]);
      let t = NOW;
      const erased: string[] = [];
      const s = await cleanupInactiveGuestsWithDeps(
        depsFor(fa, async (uid) => {
          erased.push(uid);
          t += GUEST_RUN_BUDGET_MS + 1;
          return OK;
        }),
        NOW,
        () => t,
      );
      assertEqual(JSON.stringify(fa.pageTokensSeen), JSON.stringify([undefined]), "page 1 never listed");
      assertEqual(JSON.stringify(erased), JSON.stringify(["p0-guest"]), "erased");
      assertEqual(s.scanned, 1, "scanned");
    },
  },
  {
    name: "productionGuestSweepDeps.requeue writes a due request runDueAccountDeletions will claim",
    fn: async () => {
      const store = new FakeFirestore();
      const deps = productionGuestSweepDeps({
        db: store.db,
        auth: {} as never,
        storage: {} as never,
      });
      await deps.requeue("guest-1", NOW);
      const doc = store.read("account_deletion_requests/guest-1") as Record<string, unknown> | undefined;
      if (!doc) throw new Error("no request written");
      const ms = (v: unknown) => (v as admin.firestore.Timestamp).toMillis();
      assertEqual(ms(doc.requestedAt), NOW, "requestedAt");
      assertEqual(ms(doc.scheduledFor), NOW, "scheduledFor is now, so it is due at once");
      assertEqual(doc.reason, GUEST_INACTIVE_REASON, "reason");
      assertEqual(doc.attempts, 1, "attempts");
      assertEqual(
        JSON.stringify(Object.keys(doc).sort()),
        JSON.stringify(["attempts", "reason", "requestedAt", "scheduledFor"]),
        "no lease field",
      );
    },
  },
  {
    name: "sweep: pagination follows pageToken to the last page",
    fn: async () => {
      const fa = fakeAuth([
        [user("p0-guest"), user("p0-full", { email: "a@b.se" })],
        [user("p1-guest")],
        [user("p2-guest", { idleMs: DAY }), user("p2-old")],
      ]);
      const er = recordingErase();
      const s = await cleanupInactiveGuestsWithDeps(depsFor(fa, er.fn), NOW, () => NOW);
      assertEqual(
        JSON.stringify(fa.pageTokensSeen),
        JSON.stringify([undefined, "p1", "p2"]),
        "tokens passed back",
      );
      assertEqual(
        JSON.stringify(er.erased),
        JSON.stringify(["p0-guest", "p1-guest", "p2-old"]),
        "guests on every page erased",
      );
      assertEqual(s.scanned, 5, "every listed user scanned");
    },
  },
  {
    name: "endpoint: 540 s timeout declared, the in-code budget sits below it, and no scheduler retry",
    fn: () => {
      const ep = (sweep.cleanupInactiveGuests as unknown as {
        __endpoint: {
          timeoutSeconds: unknown;
          scheduleTrigger: { retryConfig?: { retryCount?: unknown } };
        };
      }).__endpoint;
      assertEqual(ep.timeoutSeconds, 540, "timeoutSeconds");
      assertEqual(GUEST_RUN_BUDGET_MS < 540 * 1000, true, "budget below the timeout");
      assertEqual(ep.scheduleTrigger.retryConfig?.retryCount, 0, "retryCount");
    },
  },
];

runTests("BUT-920 cleanup inactive guests", cases).catch((err) => {
  console.error(err);
  process.exit(1);
});
