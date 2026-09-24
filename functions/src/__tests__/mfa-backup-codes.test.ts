/**
 * P6-U09 — MFA backup codes, unit level (no emulator).
 *
 * Covers the security properties the module header promises: hashes only,
 * a wrong code fails, a used code fails, the lock after five failures, the
 * first factor proven before any code is looked at, the same refusal for a
 * wrong password and a wrong code, and an audit row for each outcome.
 *
 * Run: npx ts-node src/__tests__/mfa-backup-codes.test.ts
 */

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import { FakeFirestore } from "./_fake-firestore";
import {
  BACKUP_CODE_COUNT,
  BACKUP_CODES_COLLECTION,
  CODE_ALPHABET,
  MAX_RECOVERY_FAILURES,
  NO_ATTEMPTS,
  RECOVERY_ATTEMPTS_COLLECTION,
  RECOVERY_LOCKOUT_MS,
  RECOVERY_WINDOW_MS,
  FirstFactor,
  RecoveryDeps,
  attemptKey,
  buildStoredCodes,
  evaluateAttempt,
  generateCodes,
  matchCode,
  normalizeCode,
  recordFailure,
  runGenerateBackupCodes,
  runMfaRecovery,
  verifyFirstFactorWithIdentityToolkit,
} from "../account/mfa-backup-codes";

if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-mfa" });

const EMAIL = "anna@example.com";
const PASSWORD = "correct horse";
const UID = "uid-anna";

interface Harness {
  fake: FakeFirestore;
  deps: RecoveryDeps;
  removed: string[];
  revoked: string[];
  audits: Record<string, unknown>[];
  firstFactorCalls: number;
  setNow(ms: number): void;
  setFirstFactor(f: FirstFactor): void;
}

function harness(): Harness {
  const fake = new FakeFirestore();
  let now = 1_700_000_000_000;
  let first: FirstFactor = { outcome: "mfa-required", uid: UID };
  const h: Harness = {
    fake,
    removed: [],
    revoked: [],
    audits: [],
    firstFactorCalls: 0,
    setNow: (ms) => (now = ms),
    setFirstFactor: (f) => (first = f),
    deps: undefined as unknown as RecoveryDeps,
  };
  h.deps = {
    db: fake.db,
    verifyFirstFactor: async (email, password) => {
      h.firstFactorCalls++;
      if (email !== EMAIL || password !== PASSWORD) return { outcome: "invalid" };
      return first;
    },
    removeSecondFactors: async (uid) => void h.removed.push(uid),
    revokeSessions: async (uid) => void h.revoked.push(uid),
    audit: async (entry) => void h.audits.push(entry),
    now: () => now,
  };
  return h;
}

async function seedCodes(h: Harness, codes: string[], usedIndex: number[] = []) {
  const stored = await buildStoredCodes(codes);
  usedIndex.forEach((i) => (stored[i].usedAt = 1));
  h.fake.seed(`${BACKUP_CODES_COLLECTION}/${UID}`, {
    codes: stored,
    createdAt: 1,
  });
}

async function expectRefusal(
  p: Promise<unknown>,
  code: string,
  msg: string,
): Promise<HttpsError> {
  try {
    await p;
  } catch (e) {
    if (e instanceof HttpsError) {
      assertEqual(e.code, code, msg);
      return e;
    }
    throw new Error(`${msg}: threw a non-HttpsError ${String(e)}`);
  }
  throw new Error(`${msg}: resolved instead of refusing`);
}

const cases: UnitCase[] = [
  {
    name: "generates ten distinct codes from the unambiguous alphabet",
    fn: () => {
      const codes = generateCodes();
      assertEqual(codes.length, BACKUP_CODE_COUNT, "count");
      assertEqual(new Set(codes).size, BACKUP_CODE_COUNT, "distinct");
      for (const c of codes) {
        assertEqual(/^[A-Z0-9]{5}-[A-Z0-9]{5}$/.test(c), true, `shape of ${c}`);
        for (const ch of normalizeCode(c)) {
          assertEqual(CODE_ALPHABET.includes(ch), true, `alphabet ${ch}`);
        }
      }
    },
  },
  {
    name: "stores salted hashes only — no code in the stored document",
    fn: async () => {
      const h = harness();
      const { codes } = await runGenerateBackupCodes(h.deps, UID);
      const doc = h.fake.read(`${BACKUP_CODES_COLLECTION}/${UID}`)!;
      const text = JSON.stringify(doc);
      for (const c of codes) {
        assertEqual(text.includes(c), false, "plain code stored");
        assertEqual(text.includes(normalizeCode(c)), false, "normalized code stored");
      }
      const stored = doc.codes as { salt: string }[];
      assertEqual(new Set(stored.map((s) => s.salt)).size, BACKUP_CODE_COUNT, "unique salts");
      assertEqual(h.audits[0].action, "mfa_backup_codes_generated", "audited");
      assertEqual(JSON.stringify(h.audits).includes(codes[0]), false, "code in audit");
    },
  },
  {
    name: "a new set is refused within 30 s of the last",
    fn: async () => {
      const h = harness();
      await runGenerateBackupCodes(h.deps, UID);
      await expectRefusal(
        runGenerateBackupCodes(h.deps, UID),
        "resource-exhausted",
        "regenerate too soon",
      );
    },
  },
  {
    name: "matching tolerates case, spaces and dashes; a wrong code does not match",
    fn: async () => {
      const stored = await buildStoredCodes(["ABCDE-FGHJK"]);
      assertEqual((await matchCode(stored, "abcde fghjk"))?.index, 0, "loose input");
      assertEqual(await matchCode(stored, "ABCDE-FGHJM"), null, "wrong code");
    },
  },
  {
    name: "a right code with the right password recovers once",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK", "KLMNP-QRSTU"]);
      const result = await runMfaRecovery(h.deps, {
        email: EMAIL,
        password: PASSWORD,
        code: "abcde-fghjk",
      });
      assertEqual(result.recovered, true, "recovered");
      assertEqual(h.removed.join(), UID, "second factor removed");
      assertEqual(h.revoked.join(), UID, "sessions revoked");
      assertEqual(h.fake.has(`${BACKUP_CODES_COLLECTION}/${UID}`), false, "set retired");
      assertEqual(h.audits.at(-1)?.action, "mfa_backup_code_used", "audited");
    },
  },
  {
    name: "a used code fails, and a spent set cannot be replayed",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK", "KLMNP-QRSTU"], [0]);
      await expectRefusal(
        runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "permission-denied",
        "used code",
      );
      assertEqual(h.removed.length, 0, "nothing removed on a used code");

      // The other code works once; replaying it fails.
      await runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD, code: "KLMNP-QRSTU" });
      await expectRefusal(
        runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD, code: "KLMNP-QRSTU" }),
        "permission-denied",
        "replayed code",
      );
      assertEqual(h.removed.length, 1, "removed exactly once");
    },
  },
  {
    name: "a wrong code fails, counts, and is audited without the code",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      await expectRefusal(
        runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD, code: "ZZZZZ-ZZZZZ" }),
        "permission-denied",
        "wrong code",
      );
      const attempts = h.fake.read(`${RECOVERY_ATTEMPTS_COLLECTION}/${attemptKey(EMAIL)}`);
      assertEqual(attempts?.failures, 1, "failure counted");
      assertEqual(h.audits[0].action, "mfa_backup_code_rejected", "rejection audited");
      assertEqual(JSON.stringify(h.audits).includes("ZZZZZ"), false, "code in audit");
      assertEqual(h.removed.length, 0, "nothing removed");
    },
  },
  {
    name: "the password is proven before any code; a wrong password gives the same refusal",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      const wrongPassword = await expectRefusal(
        runMfaRecovery(h.deps, { email: EMAIL, password: "guess", code: "ABCDE-FGHJK" }),
        "permission-denied",
        "wrong password",
      );
      const wrongCode = await expectRefusal(
        runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD, code: "ZZZZZ-ZZZZZ" }),
        "permission-denied",
        "wrong code",
      );
      assertEqual(wrongPassword.message, wrongCode.message, "no oracle: same words");
      assertEqual(
        JSON.stringify(wrongPassword.details),
        JSON.stringify(wrongCode.details),
        "no oracle: same details",
      );
      // The right code with a wrong password never spent it.
      const stored = h.fake.read(`${BACKUP_CODES_COLLECTION}/${UID}`)!.codes as {
        usedAt: number | null;
      }[];
      assertEqual(stored[0].usedAt, null, "code untouched after a wrong password");
    },
  },
  {
    name: "five failures lock recovery, even for the right code, until the lock ends",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      for (let i = 0; i < MAX_RECOVERY_FAILURES; i++) {
        await expectRefusal(
          runMfaRecovery(h.deps, { email: EMAIL, password: "guess", code: "ABCDE-FGHJK" }),
          "permission-denied",
          `failure ${i + 1}`,
        );
      }
      const calls = h.firstFactorCalls;
      const lockedErr = await expectRefusal(
        runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "resource-exhausted",
        "locked",
      );
      assertEqual(h.firstFactorCalls, calls, "a locked request never reaches the password check");
      assertEqual(
        (lockedErr.details as { code?: string }).code,
        "recovery-locked",
        "lock reason",
      );
      assertEqual(h.removed.length, 0, "nothing removed while locked");

      h.setNow(1_700_000_000_000 + RECOVERY_LOCKOUT_MS + 1);
      await runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" });
      assertEqual(h.removed.length, 1, "recovers after the lock");
      assertEqual(
        h.fake.has(`${RECOVERY_ATTEMPTS_COLLECTION}/${attemptKey(EMAIL)}`),
        false,
        "counter cleared on success",
      );
    },
  },
  {
    name: "the failure window resets after an hour",
    fn: () => {
      let s = NO_ATTEMPTS;
      s = recordFailure(s, 1000);
      s = recordFailure(s, 2000);
      assertEqual(s.failures, 2, "two in window");
      s = recordFailure(s, 1000 + RECOVERY_WINDOW_MS + 1);
      assertEqual(s.failures, 1, "window restarted");
      assertEqual(evaluateAttempt(s, 0).allowed, true, "not locked");
    },
  },
  {
    name: "an account without two-step verification is not a failure",
    fn: async () => {
      const h = harness();
      h.setFirstFactor({ outcome: "no-mfa" });
      await expectRefusal(
        runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "failed-precondition",
        "no mfa",
      );
      assertEqual(
        h.fake.has(`${RECOVERY_ATTEMPTS_COLLECTION}/${attemptKey(EMAIL)}`),
        false,
        "not counted",
      );
    },
  },
  {
    name: "missing fields are rejected before anything is read",
    fn: async () => {
      const h = harness();
      await expectRefusal(
        runMfaRecovery(h.deps, { email: EMAIL, password: PASSWORD }),
        "invalid-argument",
        "no code",
      );
      assertEqual(h.firstFactorCalls, 0, "no password check");
    },
  },
  {
    name: "Identity Toolkit: a pending MFA credential proves the first factor",
    fn: async () => {
      const respond = (body: unknown) =>
        (async () => ({ json: async () => body })) as unknown as typeof fetch;
      const mfa = await verifyFirstFactorWithIdentityToolkit(
        EMAIL,
        PASSWORD,
        "key",
        respond({ mfaPendingCredential: "x", mfaInfo: [{}] }),
        async () => UID,
      );
      assertEqual(mfa.outcome, "mfa-required", "mfa");
      assertEqual((mfa as { uid: string }).uid, UID, "uid looked up");
      const plain = await verifyFirstFactorWithIdentityToolkit(
        EMAIL,
        PASSWORD,
        "key",
        respond({ idToken: "t", localId: UID }),
      );
      assertEqual(plain.outcome, "no-mfa", "no mfa");
      const bad = await verifyFirstFactorWithIdentityToolkit(
        EMAIL,
        "guess",
        "key",
        respond({ error: { message: "INVALID_LOGIN_CREDENTIALS" } }),
      );
      assertEqual(bad.outcome, "invalid", "invalid");
      const noKey = await verifyFirstFactorWithIdentityToolkit(EMAIL, PASSWORD, "");
      assertEqual(noKey.outcome, "unavailable", "missing key never unlocks");
    },
  },
];

void runTests("mfa-backup-codes (P6-U09)", cases);
