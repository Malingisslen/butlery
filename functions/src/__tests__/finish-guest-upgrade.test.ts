/**
 * BUT-920: `finishGuestUpgrade` (account/finish-guest-upgrade.ts).
 *
 * The callable's refusals are driven through `.run`, with `enforceRateLimit`
 * swapped on the live rate-limiter module for one that records and throws a
 * sentinel, so a refusal that let the call through to the limiter shows up as
 * the sentinel rather than the expected code. Everything past the limiter is
 * driven through `runFinishGuestUpgradeWithDeps` against hand-rolled fakes.
 *
 * Run: npx ts-node src/__tests__/finish-guest-upgrade.test.ts
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";
import { createHash } from "crypto";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-finish-guest-upgrade" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  finishGuestUpgrade,
  runFinishGuestUpgradeWithDeps,
} = require("../account/finish-guest-upgrade");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { MIN_AGE_YEARS } = require("../account/verify-signup-age");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const rateLimiter = require("../middleware/rate_limiter");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runTests, assertEqual } = require("./_unit-runner");

const CURRENT_YEAR = new Date().getFullYear();

function hashUid(uid: string): string {
  return createHash("sha256").update(uid).digest("hex").substring(0, 12);
}

function caller(uid: string, provider: string | undefined): Record<string, unknown> {
  const token: Record<string, unknown> = {};
  if (provider !== undefined) token.firebase = { sign_in_provider: provider };
  return { uid, token };
}

interface Store {
  docs: Map<string, Record<string, unknown>>;
  /** Audit rows by doc id; `add()` rows get a synthetic id. */
  audit: Map<string, Record<string, unknown>>;
  setPaths: string[];
  reads: string[];
}

function makeDb(store: Store): admin.firestore.Firestore {
  return {
    doc(p: string) {
      return {
        async get() {
          store.reads.push(p);
          const data = store.docs.get(p);
          return { exists: data !== undefined, get: (f: string) => data?.[f] };
        },
        async set(data: Record<string, unknown>, opts?: { merge?: boolean }) {
          if (opts?.merge !== true) throw new Error(`non-merge set on ${p}`);
          store.setPaths.push(p);
          store.docs.set(p, { ...(store.docs.get(p) ?? {}), ...data });
        },
      };
    },
    collection(name: string) {
      if (name !== "audit_logs") throw new Error(`unexpected collection ${name}`);
      return {
        async add(data: Record<string, unknown>) {
          store.audit.set(`auto-${store.audit.size}`, data);
        },
        doc(id: string) {
          return {
            async set(data: Record<string, unknown>) {
              store.audit.set(id, { ...(store.audit.get(id) ?? {}), ...data });
            },
          };
        },
      };
    },
  } as unknown as admin.firestore.Firestore;
}

interface AuthState {
  claims: Record<string, unknown> | undefined;
  setClaimsCalls: number;
  deleted: string[];
}

/** Claims written by setCustomUserClaims are what the next getUser returns. */
function makeAuth(state: AuthState): admin.auth.Auth {
  return {
    async getUser() {
      return { customClaims: state.claims };
    },
    async setCustomUserClaims(_uid: string, claims: Record<string, unknown>) {
      state.setClaimsCalls++;
      state.claims = claims;
    },
    async deleteUser(uid: string) {
      state.deleted.push(uid);
    },
  } as unknown as admin.auth.Auth;
}

function fixture(stored?: Record<string, unknown>, uid = "uid-up") {
  const store: Store = { docs: new Map(), audit: new Map(), setPaths: [], reads: [] };
  if (stored) store.docs.set(`users/${uid}`, stored);
  const auth: AuthState = { claims: undefined, setClaimsCalls: 0, deleted: [] };
  return { store, auth, deps: { db: makeDb(store), auth: makeAuth(auth) } };
}

async function refusal(p: Promise<unknown>): Promise<{ code?: string; message?: string } | null> {
  try {
    await p;
    return null;
  } catch (err) {
    return err as { code?: string; message?: string };
  }
}

/** Runs the callable with the limiter replaced by a recorder that throws. */
async function runCallable(auth: Record<string, unknown> | undefined) {
  const real = rateLimiter.enforceRateLimit;
  const limiterCalls: string[] = [];
  rateLimiter.enforceRateLimit = async (_uid: string, op: string) => {
    limiterCalls.push(op);
    throw new Error("sentinel: reached the rate limiter");
  };
  try {
    const err = await refusal(
      finishGuestUpgrade.run({ auth, data: { birthYear: 1990 } }),
    );
    return { err, limiterCalls };
  } finally {
    rateLimiter.enforceRateLimit = real;
  }
}

function stripComments(src: string): string {
  return src.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
}

const cases = [
  {
    name: "the callable refuses an anonymous caller before the rate limiter",
    fn: async () => {
      const { err, limiterCalls } = await runCallable(caller("g", "anonymous"));
      assertEqual(err?.code, "permission-denied", "code");
      assertEqual(err?.message, "guest-not-allowed", "message");
      assertEqual(limiterCalls.length, 0, "limiter not reached");
    },
  },
  {
    name: "the callable refuses a provider other than password, and no auth at all",
    fn: async () => {
      for (const provider of ["google.com", "apple.com", "custom", undefined]) {
        const { err, limiterCalls } = await runCallable(caller("u", provider));
        assertEqual(err?.message, "upgrade-provider-not-supported", `message (${provider})`);
        assertEqual(limiterCalls.length, 0, `limiter not reached (${provider})`);
      }
      const { err } = await runCallable(undefined);
      assertEqual(err?.code, "unauthenticated", "no auth");
    },
  },
  {
    name: "control: a password caller reaches the limiter under the finishGuestUpgrade key",
    fn: async () => {
      const { err, limiterCalls } = await runCallable(caller("u", "password"));
      assertEqual(err?.message, "sentinel: reached the rate limiter", "sentinel");
      assertEqual(JSON.stringify(limiterCalls), JSON.stringify(["finishGuestUpgrade"]), "key");
    },
  },
  {
    name: "the core refuses an anonymous caller without reading or writing anything",
    fn: async () => {
      const f = fixture({ birthYear: 1990 }, "g");
      const err = await refusal(runFinishGuestUpgradeWithDeps(f.deps, caller("g", "anonymous")));
      assertEqual(err?.message, "guest-not-allowed", "message");
      assertEqual(f.store.reads.length, 0, "no reads");
      assertEqual(f.auth.setClaimsCalls, 0, "no claim");
    },
  },
  {
    name: "a password caller with a stored year gets the claim, the artefacts and an upgrade audit row",
    fn: async () => {
      const f = fixture({ birthYear: CURRENT_YEAR - 16 });
      f.auth.claims = { premium: true };
      const res = await runFinishGuestUpgradeWithDeps(f.deps, caller("uid-up", "password"));
      assertEqual(res.compliant, true, "compliant");
      assertEqual(res.isMinor, true, "isMinor from the stored year");
      assertEqual(f.auth.setClaimsCalls, 1, "claim set once");
      assertEqual(f.auth.claims?.ageCompliant, true, "ageCompliant");
      assertEqual(f.auth.claims?.premium, true, "existing claims kept");
      assertEqual(
        f.store.docs.get("users/uid-up/settings/preferences")?.birthYear,
        CURRENT_YEAR - 16,
        "preferences birthYear",
      );
      const h = hashUid("uid-up");
      const signup = f.store.audit.get(`consent_age_verification_${h}`);
      const upgrade = f.store.audit.get(`consent_guest_upgrade_${h}`);
      assertEqual(signup?.operation, "consent_age_verification", "age row");
      assertEqual(upgrade?.operation, "consent_age_verification", "upgrade row keeps the consent operation");
      assertEqual(upgrade?.event, "guest_upgrade", "upgrade row event");
      assertEqual(upgrade?.userIdHash, h, "upgrade row hashed uid");
      assertEqual("birthYear" in (upgrade ?? {}), false, "no raw birthYear in the upgrade row");
      assertEqual(f.store.audit.size, 2, "two audit rows");
    },
  },
  {
    name: "a retry sets the claim once and rewrites the same two audit rows",
    fn: async () => {
      const f = fixture({ birthYear: 1990 });
      for (let i = 0; i < 2; i++) {
        const res = await runFinishGuestUpgradeWithDeps(f.deps, caller("uid-up", "password"));
        assertEqual(res.compliant, true, `attempt ${i}`);
      }
      assertEqual(f.auth.setClaimsCalls, 1, "claim set on the first attempt only");
      assertEqual(f.store.audit.size, 2, "no duplicate audit rows");
    },
  },
  {
    name: "a missing or invalid stored year is refused failed-precondition with nothing written",
    fn: async () => {
      const bad: Array<Record<string, unknown> | undefined> = [
        undefined,
        {},
        { birthYear: null },
        { birthYear: "1990" },
        { birthYear: 1990.5 },
        { birthYear: 1899 },
        { birthYear: CURRENT_YEAR + 1 },
      ];
      for (const stored of bad) {
        const f = fixture(stored);
        const err = await refusal(runFinishGuestUpgradeWithDeps(f.deps, caller("uid-up", "password")));
        const label = JSON.stringify(stored);
        assertEqual(err?.code, "failed-precondition", `code (${label})`);
        assertEqual(err?.message, "no-stored-birth-year", `message (${label})`);
        assertEqual(f.auth.setClaimsCalls, 0, `no claim (${label})`);
        assertEqual(f.store.setPaths.length + f.store.audit.size, 0, `no writes (${label})`);
      }
    },
  },
  {
    name: "an under-15 stored year takes the signup deletion path and writes no upgrade row",
    fn: async () => {
      const f = fixture({ birthYear: CURRENT_YEAR - (MIN_AGE_YEARS - 1) });
      const res = await runFinishGuestUpgradeWithDeps(f.deps, caller("uid-up", "password"));
      assertEqual(res.compliant, false, "not compliant");
      assertEqual(JSON.stringify(f.auth.deleted), JSON.stringify(["uid-up"]), "account deleted");
      assertEqual(f.auth.setClaimsCalls, 0, "no claim");
      assertEqual(f.store.setPaths.length, 0, "no artefacts");
      const rows = [...f.store.audit.values()];
      assertEqual(rows.length, 1, "one audit row");
      assertEqual(rows[0].operation, "age_verification_rejected", "the rejection row");
      assertEqual("userIdHash" in rows[0], false, "rejection row is not linkable");
    },
  },
  {
    name: "finish-guest-upgrade.ts never reads the request payload",
    fn: () => {
      const src = stripComments(
        fs.readFileSync(path.resolve(__dirname, "..", "account", "finish-guest-upgrade.ts"), "utf8"),
      );
      assertEqual(src.includes("request.data"), false, "request.data in source");
    },
  },
  {
    // An unknown key falls back to the default bucket in silence.
    name: "every account/ rate-limit key is defined in RATE_LIMIT_CONFIGS",
    fn: () => {
      const dir = path.resolve(__dirname, "..", "account");
      let seen = 0;
      for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".ts"))) {
        const src = stripComments(fs.readFileSync(path.join(dir, file), "utf8"));
        for (const m of src.matchAll(/(?:check|enforce)RateLimit\(\s*[^,]+,\s*"([^"]+)"/g)) {
          seen++;
          assertEqual(
            Object.prototype.hasOwnProperty.call(rateLimiter.RATE_LIMIT_CONFIGS, m[1]),
            true,
            `${file}: RATE_LIMIT_CONFIGS defines "${m[1]}"`,
          );
        }
      }
      if (seen < 2) throw new Error(`premise: expected the two age callables' keys, saw ${seen}`);
    },
  },
];

runTests("BUT-920 finishGuestUpgrade", cases).catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
