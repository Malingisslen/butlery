/**
 * BUT-2481 — revokeOtherSessions, DI-core tests against fakes (no emulator).
 *
 * Run: npx ts-node src/__tests__/revoke-other-sessions.test.ts
 */

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import {
  REVOKE_OPERATION,
  RevokeCaller,
  RevokeDeps,
  revokeOtherSessions,
  runRevokeOtherSessions,
} from "../account/revoke-other-sessions";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-revoke-other-sessions" });
}

const SECRET_TOKEN = "SECRET.CUSTOM.TOKEN";
const NOW_MS = 1_800_000_000_000;
const NOW_SEC = NOW_MS / 1000;

const logged: unknown[] = [];
for (const level of ["info", "warn", "error"] as const) {
  (logger as unknown as Record<string, unknown>)[level] = (...a: unknown[]) => {
    logged.push(a);
  };
}

interface Fake {
  deps: RevokeDeps;
  calls: string[];
  audits: Array<Record<string, unknown>>;
}

function fake(over: Partial<RevokeDeps> = {}, factors = 0, providers = ["google.com"]): Fake {
  const calls: string[] = [];
  const audits: Array<Record<string, unknown>> = [];
  const deps: RevokeDeps = {
    getAccount: async () => ({ providerIds: providers, enrolledFactorCount: factors }),
    createCustomToken: async () => {
      calls.push("createCustomToken");
      return SECRET_TOKEN;
    },
    revokeRefreshTokens: async () => {
      calls.push("revoke");
    },
    enforceRateLimit: async () => {
      calls.push("rateLimit");
    },
    markRevoked: async () => {
      calls.push("markRevoked");
    },
    audit: async (e) => {
      audits.push(e);
    },
    now: () => NOW_MS,
    ...over,
  };
  return { deps, calls, audits };
}

function caller(over: {
  provider?: string;
  authTime?: unknown;
  secondFactor?: string;
} = {}): RevokeCaller {
  return {
    uid: "u1",
    token: {
      auth_time: "authTime" in over ? over.authTime : NOW_SEC - 10,
      firebase: {
        sign_in_provider: over.provider ?? "google.com",
        sign_in_second_factor: over.secondFactor,
      },
    },
  };
}

async function refusal(p: Promise<unknown>): Promise<HttpsError> {
  try {
    await p;
  } catch (e) {
    if (e instanceof HttpsError) return e;
    throw e;
  }
  throw new Error("expected a refusal");
}

const detailsCode = (e: HttpsError) => (e.details as { code?: string } | undefined)?.code;

const cases: UnitCase[] = [
  {
    name: "google.com session: mints the token before revoking, returns it, audits, marks",
    fn: async () => {
      const f = fake();
      const r = await runRevokeOtherSessions(f.deps, caller());
      assertEqual(r.customToken, SECRET_TOKEN, "token");
      assertEqual(f.calls.join(","), "rateLimit,createCustomToken,revoke,markRevoked", "order");
      assertEqual(f.audits.length, 1, "one audit row");
      assertEqual(f.audits[0].outcome, "revoked", "outcome");
      assertEqual(f.audits[0].granted, true, "granted");
      assertEqual(f.audits[0].action, REVOKE_OPERATION, "operation");
    },
  },
  {
    name: "apple.com session is allowed",
    fn: async () => {
      const f = fake({}, 0, ["apple.com"]);
      await runRevokeOtherSessions(f.deps, caller({ provider: "apple.com" }));
      assertEqual(f.calls.includes("revoke"), true, "revoked");
    },
  },
  ...["custom", "password", "anonymous"].map(
    (provider): UnitCase => ({
      name: `${provider} token with a fresh auth_time is refused, nothing revoked, audited`,
      fn: async () => {
        const f = fake();
        const e = await refusal(runRevokeOtherSessions(f.deps, caller({ provider })));
        assertEqual(e.code, "permission-denied", "code");
        assertEqual(detailsCode(e), "requires-recent-login", "client prompt");
        assertEqual(f.calls.length, 0, "no side effect");
        assertEqual(f.audits[0].outcome, "denied_provider", "audit outcome");
        assertEqual(f.audits[0].granted, false, "granted");
      },
    }),
  ),
  {
    name: "google token on an account that no longer lists google.com is refused",
    fn: async () => {
      const f = fake({}, 0, ["password"]);
      const e = await refusal(runRevokeOtherSessions(f.deps, caller()));
      assertEqual(e.code, "permission-denied", "code");
      assertEqual(f.calls.length, 0, "no side effect");
    },
  },
  {
    name: "auth_time exactly REAUTH_MAX_AGE_SECONDS old is still allowed",
    fn: async () => {
      const f = fake();
      await runRevokeOtherSessions(f.deps, caller({ authTime: NOW_SEC - 300 }));
      assertEqual(f.calls.includes("revoke"), true, "revoked at the boundary");
    },
  },
  {
    name: "auth_time older than REAUTH_MAX_AGE_SECONDS gives requires-recent-login",
    fn: async () => {
      const f = fake();
      const e = await refusal(
        runRevokeOtherSessions(f.deps, caller({ authTime: NOW_SEC - 301 })),
      );
      assertEqual(e.code, "failed-precondition", "code");
      assertEqual(detailsCode(e), "requires-recent-login", "detail");
      assertEqual(f.calls.length, 0, "no side effect");
      assertEqual(f.audits[0].outcome, "denied_recent_login", "audit");
    },
  },
  {
    name: "missing auth_time is refused",
    fn: async () => {
      const f = fake();
      const e = await refusal(runRevokeOtherSessions(f.deps, caller({ authTime: undefined })));
      assertEqual(detailsCode(e), "requires-recent-login", "detail");
    },
  },
  {
    name: "account with MFA factors needs sign_in_second_factor on the token",
    fn: async () => {
      const f = fake({}, 1);
      const e = await refusal(runRevokeOtherSessions(f.deps, caller()));
      assertEqual(detailsCode(e), "requires-recent-login", "detail");
      assertEqual(f.audits[0].outcome, "denied_mfa", "audit");
      assertEqual(f.calls.length, 0, "no side effect");
      const g = fake({}, 1);
      await runRevokeOtherSessions(g.deps, caller({ secondFactor: "phone" }));
      assertEqual(g.calls.includes("revoke"), true, "allowed with second factor");
    },
  },
  {
    name: "rate limit refusal is rethrown, audited, and revokes nothing",
    fn: async () => {
      const f = fake({
        enforceRateLimit: async () => {
          throw new HttpsError("resource-exhausted", "slow down");
        },
      });
      const e = await refusal(runRevokeOtherSessions(f.deps, caller()));
      assertEqual(e.code, "resource-exhausted", "code");
      assertEqual(f.calls.length, 0, "no side effect");
      assertEqual(f.audits[0].outcome, "denied_rate_limit", "audit");
    },
  },
  {
    name: "token creation fails: nothing is revoked",
    fn: async () => {
      const f = fake({
        createCustomToken: async () => {
          throw new Error("kms down");
        },
      });
      const e = await refusal(runRevokeOtherSessions(f.deps, caller()));
      assertEqual(e.code, "internal", "code");
      assertEqual(f.calls.includes("revoke"), false, "revoke never reached");
      assertEqual(f.audits[0].outcome, "failed", "audit");
    },
  },
  {
    name: "notice write failing does not undo the revoke or lose the token",
    fn: async () => {
      const f = fake({
        markRevoked: async () => {
          throw new Error("firestore down");
        },
      });
      const r = await runRevokeOtherSessions(f.deps, caller());
      assertEqual(r.customToken, SECRET_TOKEN, "token still returned");
      assertEqual(f.audits[0].outcome, "revoked", "audit");
    },
  },
  {
    name: "the custom token never reaches a log line or an audit row",
    fn: async () => {
      logged.length = 0;
      const ok = fake();
      await runRevokeOtherSessions(ok.deps, caller());
      const bad = fake({
        markRevoked: async () => {
          throw new Error(SECRET_TOKEN);
        },
        revokeRefreshTokens: async () => {
          throw new Error(SECRET_TOKEN);
        },
      });
      await refusal(runRevokeOtherSessions(bad.deps, caller()));
      const all = JSON.stringify([logged, ok.audits, bad.audits]);
      assertEqual(all.includes(SECRET_TOKEN), false, "token leaked");
    },
  },
  {
    name: "the callable refuses a replayed App Check token",
    fn: async () => {
      const run = (revokeOtherSessions as unknown as {
        run(request: unknown): Promise<unknown>;
      }).run;
      const e = await refusal(run({ app: { alreadyConsumed: true } }));
      assertEqual(e.code, "unauthenticated", "code");
      assertEqual(e.message, "App Check token already used.", "the replay branch, not the sign-in one");
    },
  },
  {
    name: "audit rows carry no IP, e-mail or token fields",
    fn: async () => {
      const f = fake();
      await runRevokeOtherSessions(f.deps, caller());
      const keys = Object.keys(f.audits[0]).sort().join(",");
      assertEqual(keys, "action,at,granted,outcome,userId", "fields");
    },
  },
];

void runTests("revoke-other-sessions (BUT-2481)", cases);
