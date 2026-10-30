/**
 * BUT-2452 — guest-list blocking functions, DI-core tests against hand-rolled
 * fakes (no emulator). The transactional consume against real Firestore is in
 * `signup-allowlist.integration.test.ts`.
 *
 * Run: npx ts-node src/__tests__/signup-allowlist.test.ts
 */

import * as assert from "assert";
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-signup-allowlist" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { logger } = require("firebase-functions/logger");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const gate = require("../account/signup-allowlist");
type InviteState = "valid" | "missing" | "expired";

const logged: unknown[] = [];
for (const level of ["info", "warn", "error"]) {
  logger[level] = (...args: unknown[]) => {
    logged.push(args);
  };
}

interface FakeState {
  enabled: boolean | Error;
  invites: Map<string, InviteState>;
  inviteError?: Error;
  consumed: string[];
  checked: string[];
}

function fakeDeps(state: FakeState) {
  return {
    async gateEnabled() {
      if (state.enabled instanceof Error) throw state.enabled;
      return state.enabled;
    },
    async checkInvite(email: string, consume: boolean) {
      state.checked.push(email);
      if (state.inviteError) throw state.inviteError;
      const s = state.invites.get(email) ?? "missing";
      if (s === "valid" && consume) {
        state.invites.delete(email);
        state.consumed.push(email);
      }
      return s;
    },
  };
}

function freshState(over: Partial<FakeState> = {}): FakeState {
  return {
    enabled: true,
    invites: new Map([["anna@example.com", "valid" as InviteState]]),
    consumed: [],
    checked: [],
    ...over,
  };
}

async function refusalOf(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (err) {
    const e = err as { code?: string; message?: string };
    assert.strictEqual(e.code, "permission-denied");
    logged.push(e.message);
    return e.message ?? "";
  }
  throw new Error("expected a refusal, got allowed");
}

const tests: Array<{ name: string; fn: () => Promise<void> }> = [];
const test = (name: string, fn: () => Promise<void>) => tests.push({ name, fn });

const google = { uid: "u1", email: "anna@example.com", emailVerified: true };
const password = { uid: "u2", email: "anna@example.com", emailVerified: false };

test("switch: missing doc, missing field, null, string 'false' keep the gate ON", async () => {
  assert.strictEqual(gate.readGateSwitch(null), true);
  assert.strictEqual(gate.readGateSwitch(undefined), true);
  assert.strictEqual(gate.readGateSwitch({}), true);
  assert.strictEqual(gate.readGateSwitch({ signupAllowlistEnabled: null }), true);
  assert.strictEqual(gate.readGateSwitch({ signupAllowlistEnabled: "false" }), true);
  assert.strictEqual(gate.readGateSwitch({ signupAllowlistEnabled: 0 }), true);
});

test("switch: exact false turns the gate OFF", async () => {
  assert.strictEqual(gate.readGateSwitch({ signupAllowlistEnabled: false }), false);
});

test("inviteState: missing, expired, non-timestamp, valid", async () => {
  const now = Date.now();
  const ts = admin.firestore.Timestamp;
  assert.strictEqual(gate.inviteState(null, now), "missing");
  assert.strictEqual(gate.inviteState({ expireAt: ts.fromMillis(now - 1) }, now), "expired");
  assert.strictEqual(gate.inviteState({ expireAt: now + 1000 }, now), "expired");
  assert.strictEqual(gate.inviteState({}, now), "expired");
  assert.strictEqual(gate.inviteState({ expireAt: ts.fromMillis(now + 1000) }, now), "valid");
});

test("normalizeEmail: trim + lower-case, plus-tags and dots kept", async () => {
  assert.strictEqual(gate.normalizeEmail("  Anna.B+Test@Example.COM "), "anna.b+test@example.com");
  assert.strictEqual(gate.normalizeEmail(undefined), "");
});

test("create: invited Google/Apple user is allowed and the invite consumed", async () => {
  const s = freshState();
  await gate.runSignupAllowlistWithDeps(fakeDeps(s), google);
  assert.deepStrictEqual(s.consumed, ["anna@example.com"]);
});

test("create: mixed-case address matches the invite", async () => {
  const s = freshState();
  await gate.runSignupAllowlistWithDeps(fakeDeps(s), { ...google, email: " Anna@Example.com" });
  assert.deepStrictEqual(s.checked, ["anna@example.com"]);
});

test("create: invited password sign-up is allowed and KEEPS the invite", async () => {
  const s = freshState();
  await gate.runSignupAllowlistWithDeps(fakeDeps(s), password);
  assert.deepStrictEqual(s.consumed, []);
  assert.strictEqual(s.invites.get("anna@example.com"), "valid");
});

test("create: uninvited address is refused NOT_INVITED", async () => {
  const msg = await refusalOf(gate.runSignupAllowlistWithDeps(
    fakeDeps(freshState()), { ...google, email: "eve@example.com" }));
  assert.ok(msg.startsWith(gate.SIGNUP_NOT_INVITED), msg);
});

test("create: expired invite is refused NOT_INVITED", async () => {
  const s = freshState({ invites: new Map([["anna@example.com", "expired"]]) });
  const msg = await refusalOf(gate.runSignupAllowlistWithDeps(fakeDeps(s), google));
  assert.ok(msg.startsWith(gate.SIGNUP_NOT_INVITED), msg);
});

test("create: no email (anonymous, hidden relay) is refused without a lookup", async () => {
  const s = freshState();
  const msg = await refusalOf(gate.runSignupAllowlistWithDeps(
    fakeDeps(s), { uid: "u3", email: undefined, emailVerified: false }));
  assert.ok(msg.startsWith(gate.SIGNUP_NOT_INVITED), msg);
  assert.deepStrictEqual(s.checked, []);
});

test("create: config read error refuses GATE_UNAVAILABLE", async () => {
  const s = freshState({ enabled: new Error("unavailable") });
  const msg = await refusalOf(gate.runSignupAllowlistWithDeps(fakeDeps(s), google));
  assert.ok(msg.startsWith(gate.SIGNUP_GATE_UNAVAILABLE), msg);
});

test("create: transaction error refuses GATE_UNAVAILABLE", async () => {
  const s = freshState({ inviteError: new Error("aborted") });
  const msg = await refusalOf(gate.runSignupAllowlistWithDeps(fakeDeps(s), google));
  assert.ok(msg.startsWith(gate.SIGNUP_GATE_UNAVAILABLE), msg);
});

test("create: switch off lets an uninvited address through", async () => {
  const s = freshState({ enabled: false });
  await gate.runSignupAllowlistWithDeps(fakeDeps(s), { ...google, email: "eve@example.com" });
  assert.deepStrictEqual(s.checked, []);
});

test("sign-in: unverified, not new → refused EMAIL_UNVERIFIED", async () => {
  const msg = await refusalOf(gate.runSignInAllowlistWithDeps(fakeDeps(freshState()), password, false));
  assert.ok(msg.startsWith(gate.SIGNUP_EMAIL_UNVERIFIED), msg);
});

test("sign-in: unverified, sign-up session → allowed", async () => {
  await gate.runSignInAllowlistWithDeps(fakeDeps(freshState()), password, true);
});

test("sign-in: unverified + config read error → refused (gate treated as on)", async () => {
  const s = freshState({ enabled: new Error("unavailable") });
  const msg = await refusalOf(gate.runSignInAllowlistWithDeps(fakeDeps(s), password, false));
  assert.ok(msg.startsWith(gate.SIGNUP_EMAIL_UNVERIFIED), msg);
});

test("sign-in: unverified + switch off → allowed", async () => {
  await gate.runSignInAllowlistWithDeps(fakeDeps(freshState({ enabled: false })), password, false);
});

test("sign-in: verified → allowed and a leftover invite consumed", async () => {
  const s = freshState();
  await gate.runSignInAllowlistWithDeps(fakeDeps(s), google, false);
  assert.deepStrictEqual(s.consumed, ["anna@example.com"]);
});

test("sign-in: verified + read errors → still allowed", async () => {
  await gate.runSignInAllowlistWithDeps(
    fakeDeps(freshState({ enabled: new Error("x") })), google, false);
  await gate.runSignInAllowlistWithDeps(
    fakeDeps(freshState({ inviteError: new Error("y") })), google, false);
});

test("isInvitableAddress: refuses what cannot be a document id", async () => {
  assert.strictEqual(gate.isInvitableAddress("anna@example.com"), true);
  for (const bad of ["", "a/b@example.com", ".", "..", "__x__"]) {
    assert.strictEqual(gate.isInvitableAddress(bad), false, bad);
  }
});

test("create: an address with a slash is refused NOT_INVITED without a lookup", async () => {
  const s = freshState();
  const msg = await refusalOf(gate.runSignupAllowlistWithDeps(
    fakeDeps(s), { ...google, email: "a/b@example.com" }));
  assert.ok(msg.startsWith(gate.SIGNUP_NOT_INVITED), msg);
  assert.deepStrictEqual(s.checked, []);
});

test("sign-in: verified address with a slash is allowed without a lookup", async () => {
  const s = freshState();
  await gate.runSignInAllowlistWithDeps(
    fakeDeps(s), { ...google, email: "a/b@example.com" }, false);
  assert.deepStrictEqual(s.checked, []);
});

test("sign-in: verified + switch off → allowed, no invite consumed", async () => {
  const s = freshState({ enabled: false });
  await gate.runSignInAllowlistWithDeps(fakeDeps(s), google, false);
  assert.deepStrictEqual(s.consumed, []);
});

test("an error whose message repeats the address is logged without it", async () => {
  const leaky = new Error('Value "anna@example.com" is not a valid document path');
  const s = freshState({ inviteError: leaky });
  await refusalOf(gate.runSignupAllowlistWithDeps(fakeDeps(s), google));
  await refusalOf(gate.runSignupAllowlistWithDeps(
    fakeDeps(freshState({ enabled: leaky })), google));
  await gate.runSignInAllowlistWithDeps(fakeDeps(freshState({ inviteError: leaky })), google, false);
  await refusalOf(gate.runSignInAllowlistWithDeps(
    fakeDeps(freshState({ enabled: leaky })), password, false));
});

test("no log line or error message carries an email address", async () => {
  // Every case above has run by now; assert over everything they logged.
  const text = JSON.stringify(logged);
  assert.ok(!/@example\.com/i.test(text), "an email reached the logger");
  assert.ok(logged.length > 0, "nothing was logged — the check proves nothing");
});

async function run(): Promise<void> {
  console.log("BUT-2452: signup allowlist DI-core tests\n");
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(`        ${(err as Error).message}`);
    }
  }
  console.log(`\n${tests.length - failed}/${tests.length} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
