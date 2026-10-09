/**
 * P6-U09 — MFA backup codes, unit level (no emulator).
 *
 * Covers the security properties the module header promises: hashes only,
 * a wrong code fails, a used code fails, the lock after five failures, the
 * first factor proven before any code is looked at, the same refusal for a
 * wrong password, a wrong code and an account without MFA, check-and-count in
 * one transaction (parallel requests cannot pass the cap), wrong passwords
 * never touching the account's code lock, the per-IP and global throttles,
 * peppered keys with a TTL field, the fail-closed pepper, the server-side
 * clean-up after MFA is switched off, and an audit row for each outcome.
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
  CODES_BEFORE_ENROLLMENT_MAX_MS,
  GLOBAL_ATTEMPT_KEY,
  MAX_IP_ATTEMPTS,
  MAX_RECOVERY_FAILURES,
  NO_ATTEMPTS,
  RECOVERY_ATTEMPTS_COLLECTION,
  RECOVERY_LOCKOUT_MS,
  RECOVERY_WINDOW_MS,
  FirstFactor,
  RecoveryDeps,
  buildStoredCodes,
  clearMfaBackupCodes,
  codesBelongToEnrollment,
  generateMfaBackupCodes,
  recoverWithMfaBackupCode,
  ipAttemptKey,
  pepperedKey,
  runClearBackupCodes,
  uidAttemptKey,
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
const PEPPER = "test-pepper-not-a-secret";
const T0 = 1_700_000_000_000;

/**
 * The shared fake runs every transaction callback without isolation, so two
 * interleaved transactions can both read the same counter. Real Firestore
 * transactions are serialisable (contention aborts and retries the loser), and
 * that is exactly the property the attempt counter relies on. This wrapper
 * runs transactions one at a time — nothing more — so the parallel cases
 * below measure the CODE's use of transactions: a counter read outside a
 * transaction (the reviewed bug) still races here and would fail them.
 */
class SerialFirestore extends FakeFirestore {
  private queue: Promise<unknown> = Promise.resolve();
  async runTransaction<T>(fn: (tx: unknown) => Promise<T>): Promise<T> {
    const run = this.queue.then(() => super.runTransaction(fn));
    this.queue = run.catch(() => undefined);
    return run;
  }
}

interface Harness {
  fake: FakeFirestore;
  deps: RecoveryDeps;
  removed: string[];
  revoked: string[];
  audits: Record<string, unknown>[];
  notified: string[];
  firstFactorCalls: number;
  setNow(ms: number): void;
  setFirstFactor(f: FirstFactor): void;
  setEnrollmentTimes(times: number[]): void;
}

/** When [seedCodes] says the set was created, and the phone enrolled after it. */
const CODES_CREATED_AT = 1;
const ENROLLED_AT = CODES_CREATED_AT + 2 * 60 * 1000;

function harness(): Harness {
  const fake = new SerialFirestore();
  let now = T0;
  let first: FirstFactor = { outcome: "mfa-required", uid: UID };
  let enrollmentTimes = [ENROLLED_AT];
  const h: Harness = {
    fake,
    removed: [],
    revoked: [],
    audits: [],
    notified: [],
    firstFactorCalls: 0,
    setNow: (ms) => (now = ms),
    setFirstFactor: (f) => (first = f),
    setEnrollmentTimes: (times) => (enrollmentTimes = times),
    deps: undefined as unknown as RecoveryDeps,
  };
  h.deps = {
    db: fake.db,
    pepper: PEPPER,
    verifyFirstFactor: async (email, password) => {
      h.firstFactorCalls++;
      // A real network round trip: lets parallel requests interleave here.
      await new Promise((r) => setImmediate(r));
      if (email !== EMAIL || password !== PASSWORD) return { outcome: "invalid" };
      return first;
    },
    enrollmentTimes: async () => enrollmentTimes,
    removeSecondFactors: async (uid) => void h.removed.push(uid),
    revokeSessions: async (uid) => void h.revoked.push(uid),
    notify: async (uid, event) => void h.notified.push(`${uid}:${event}`),
    audit: async (entry) => void h.audits.push(entry),
    now: () => now,
  };
  return h;
}

/** A distinct client address per call unless one is given. */
let ipCounter = 0;
function freshIp(): string {
  ipCounter++;
  return `203.0.113.${ipCounter % 250}`;
}

function recover(
  h: Harness,
  request: { email?: string; password?: string; code?: string },
  ip: string = freshIp(),
) {
  return runMfaRecovery(h.deps, request, { ip });
}

async function seedCodes(h: Harness, codes: string[], usedIndex: number[] = []) {
  const stored = await buildStoredCodes(codes);
  usedIndex.forEach((i) => (stored[i].usedAt = 1));
  h.fake.seed(`${BACKUP_CODES_COLLECTION}/${UID}`, {
    codes: stored,
    createdAt: CODES_CREATED_AT,
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

/** Every settled refusal, by HttpsError code. */
async function settleCodes(ps: Promise<unknown>[]): Promise<Record<string, number>> {
  const out: Record<string, number> = {};
  for (const r of await Promise.allSettled(ps)) {
    const key =
      r.status === "fulfilled"
        ? "ok"
        : r.reason instanceof HttpsError
          ? r.reason.code
          : `non-HttpsError:${String(r.reason)}`;
    out[key] = (out[key] ?? 0) + 1;
  }
  return out;
}

const UID_DOC = `${RECOVERY_ATTEMPTS_COLLECTION}/${uidAttemptKey(UID)}`;

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
    name: "creating codes e-mails the owner",
    fn: async () => {
      const h = harness();
      await runGenerateBackupCodes(h.deps, UID);
      assertEqual(h.notified.join(), `${UID}:codes-created`, "owner told by e-mail");
    },
  },
  {
    name: "every callable declares the secrets it reads",
    fn: async () => {
      const secretsOf = (fn: unknown) =>
        (
          (fn as { __endpoint: { secretEnvironmentVariables?: { key: string }[] } })
            .__endpoint.secretEnvironmentVariables ?? []
        )
          .map((s) => s.key)
          .sort()
          .join();
      assertEqual(secretsOf(generateMfaBackupCodes), "FEEDBACK_EMAIL_API_KEY", "generate");
      assertEqual(
        secretsOf(recoverWithMfaBackupCode),
        "FEEDBACK_EMAIL_API_KEY,IDENTITY_TOOLKIT_API_KEY,MFA_RECOVERY_PEPPER",
        "recover",
      );
      assertEqual(secretsOf(clearMfaBackupCodes), "", "clear");
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
      const result = await recover(h, {
        email: EMAIL,
        password: PASSWORD,
        code: "abcde-fghjk",
      });
      assertEqual(result.recovered, true, "recovered");
      assertEqual(h.removed.join(), UID, "second factor removed");
      assertEqual(h.revoked.join(), UID, "sessions revoked");
      assertEqual(h.fake.has(`${BACKUP_CODES_COLLECTION}/${UID}`), false, "set retired");
      assertEqual(h.fake.has(UID_DOC), false, "account counter released on success");
      assertEqual(h.audits.at(-1)?.action, "mfa_backup_code_used", "audited");
      assertEqual(h.notified.join(), `${UID}:recovered`, "owner told by e-mail");
    },
  },
  {
    name: "a set left over from an earlier enrollment cannot remove a later factor",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      h.setEnrollmentTimes([CODES_CREATED_AT + CODES_BEFORE_ENROLLMENT_MAX_MS + 1]);
      await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "permission-denied",
        "stale set",
      );
      assertEqual(h.removed.length, 0, "factor kept");
      assertEqual(h.notified.length, 0, "no recovery mail");
      assertEqual(h.audits.at(-1)?.action, "mfa_backup_codes_stale", "audited as stale");
      assertEqual(h.fake.has(`${BACKUP_CODES_COLLECTION}/${UID}`), true, "set untouched");
      h.setEnrollmentTimes([CODES_CREATED_AT + CODES_BEFORE_ENROLLMENT_MAX_MS]);
      const ok = await recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" });
      assertEqual(ok.recovered, true, "the last millisecond of the window still counts");
    },
  },
  {
    name: "codes count only for a factor enrolled after them, within a day",
    fn: async () => {
      const day = CODES_BEFORE_ENROLLMENT_MAX_MS;
      assertEqual(codesBelongToEnrollment(1000, [1000 + 5000]), true, "minutes after");
      assertEqual(codesBelongToEnrollment(1000, [1000 + day + 1]), false, "over a day after");
      assertEqual(codesBelongToEnrollment(10 * day, [10 * day - 61_000]), false, "factor older than the set");
      assertEqual(codesBelongToEnrollment(10 * day, [10 * day - 30_000]), true, "within clock slack");
      assertEqual(codesBelongToEnrollment(10 * day, [5, 10 * day + 5000]), true, "any enrolled factor");
      assertEqual(codesBelongToEnrollment(10 * day, [5]), false, "the old factor alone does not count");
      assertEqual(codesBelongToEnrollment(1000, []), false, "no factor");
      assertEqual(codesBelongToEnrollment(undefined, [5000]), false, "no creation time");
      assertEqual(codesBelongToEnrollment(null, [5000]), false, "null creation time");
      assertEqual(codesBelongToEnrollment("1000", [5000]), false, "string creation time");
    },
  },
  {
    name: "a used code fails, and a spent set cannot be replayed",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK", "KLMNP-QRSTU"], [0]);
      await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "permission-denied",
        "used code",
      );
      assertEqual(h.removed.length, 0, "nothing removed on a used code");

      // The other code works once; replaying it fails.
      await recover(h, { email: EMAIL, password: PASSWORD, code: "KLMNP-QRSTU" });
      await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "KLMNP-QRSTU" }),
        "permission-denied",
        "replayed code",
      );
      assertEqual(h.removed.length, 1, "removed exactly once");
    },
  },
  {
    name: "a wrong code fails, counts on the account, and is audited without the code",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ZZZZZ-ZZZZZ" }),
        "permission-denied",
        "wrong code",
      );
      const attempts = h.fake.read(UID_DOC);
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
        recover(h, { email: EMAIL, password: "guess", code: "ABCDE-FGHJK" }),
        "permission-denied",
        "wrong password",
      );
      const wrongCode = await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ZZZZZ-ZZZZZ" }),
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
    name: "finding 1: an account without MFA gets exactly the wrong-password refusal",
    fn: async () => {
      const h = harness();
      const wrongPassword = await expectRefusal(
        recover(h, { email: EMAIL, password: "guess", code: "ABCDE-FGHJK" }),
        "permission-denied",
        "wrong password",
      );
      const unknownEmail = await expectRefusal(
        recover(h, { email: "nobody@example.com", password: "x", code: "ABCDE-FGHJK" }),
        "permission-denied",
        "unknown address",
      );
      h.setFirstFactor({ outcome: "no-mfa" });
      const noMfa = await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "permission-denied",
        "no mfa must not be failed-precondition",
      );
      for (const [label, other] of [
        ["unknown address", unknownEmail],
        ["no mfa", noMfa],
      ] as const) {
        assertEqual(other.code, wrongPassword.code, `${label}: same code`);
        assertEqual(other.message, wrongPassword.message, `${label}: same words`);
        assertEqual(
          JSON.stringify(other.details),
          JSON.stringify(wrongPassword.details),
          `${label}: same details`,
        );
      }
      assertEqual(h.fake.has(UID_DOC), false, "no account counter without MFA");
      assertEqual(h.removed.length + h.revoked.length, 0, "nothing touched");
    },
  },
  {
    name: "five wrong codes lock the account; the lock answers like a wrong password and ends",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      for (let i = 0; i < MAX_RECOVERY_FAILURES; i++) {
        await expectRefusal(
          recover(h, { email: EMAIL, password: PASSWORD, code: "ZZZZZ-ZZZZZ" }),
          "permission-denied",
          `code failure ${i + 1}`,
        );
      }
      const lockedErr = await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "permission-denied",
        "locked account: same refusal as a wrong password, so no oracle",
      );
      assertEqual(
        (lockedErr.details as { code?: string }).code,
        "recovery-rejected",
        "lock reason is not revealed",
      );
      const stored = h.fake.read(`${BACKUP_CODES_COLLECTION}/${UID}`)!.codes as {
        usedAt: number | null;
      }[];
      assertEqual(stored[0].usedAt, null, "a locked request never spends the code");
      assertEqual(h.removed.length, 0, "nothing removed while locked");
      assertEqual(h.audits.at(-1)?.action, "mfa_backup_code_locked", "lock audited");

      h.setNow(T0 + RECOVERY_LOCKOUT_MS + 1);
      await recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" });
      assertEqual(h.removed.length, 1, "recovers after the lock");
      assertEqual(h.fake.has(UID_DOC), false, "counter cleared on success");
    },
  },
  {
    name: "finding 2: twenty PARALLEL wrong codes check at most five, transactionally",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      const results = await settleCodes(
        Array.from({ length: 20 }, () =>
          recover(h, { email: EMAIL, password: PASSWORD, code: "ZZZZZ-ZZZZZ" }),
        ),
      );
      assertEqual(results["permission-denied"], 20, "all refused alike");
      const checked = h.audits.filter((a) => a.action === "mfa_backup_code_rejected");
      assertEqual(checked.length, MAX_RECOVERY_FAILURES, "codes actually checked");
      assertEqual(h.fake.read(UID_DOC)?.failures, MAX_RECOVERY_FAILURES, "counter at the cap");
      // Even the right code is refused now.
      await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "permission-denied",
        "locked after the parallel burst",
      );
      assertEqual(h.removed.length, 0, "nothing removed");
    },
  },
  {
    name: "finding 2: parallel requests from one IP cannot pass the per-IP cap",
    fn: async () => {
      const h = harness();
      const ip = "198.51.100.7";
      const results = await settleCodes(
        Array.from({ length: 25 }, () =>
          recover(h, { email: EMAIL, password: "guess", code: "ABCDE-FGHJK" }, ip),
        ),
      );
      assertEqual(h.firstFactorCalls, MAX_IP_ATTEMPTS, "password checks from one IP");
      assertEqual(results["permission-denied"], MAX_IP_ATTEMPTS, "refused after the check");
      assertEqual(results["resource-exhausted"], 25 - MAX_IP_ATTEMPTS, "throttled");
    },
  },
  {
    name: "finding 3: wrong passwords never touch the account's code lock",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      // A stranger who knows only the address, from many addresses.
      for (let i = 0; i < 4 * MAX_RECOVERY_FAILURES; i++) {
        await expectRefusal(
          recover(h, { email: EMAIL, password: `guess-${i}`, code: "ZZZZZ-ZZZZZ" }),
          "permission-denied",
          `wrong password ${i + 1}`,
        );
      }
      assertEqual(h.fake.has(UID_DOC), false, "no account counter");
      // The owner still gets in at once.
      await recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" });
      assertEqual(h.removed.join(), UID, "owner recovers");
    },
  },
  {
    name: "per-IP throttle: the eleventh attempt from one IP is refused before the password check",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      const ip = "192.0.2.44";
      for (let i = 0; i < MAX_IP_ATTEMPTS; i++) {
        await expectRefusal(
          recover(h, { email: EMAIL, password: "guess", code: "ABCDE-FGHJK" }, ip),
          "permission-denied",
          `attempt ${i + 1}`,
        );
      }
      const calls = h.firstFactorCalls;
      const throttled = await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }, ip),
        "resource-exhausted",
        "throttled IP",
      );
      assertEqual(h.firstFactorCalls, calls, "no password check once throttled");
      assertEqual(
        (throttled.details as { code?: string }).code,
        "recovery-locked",
        "lock reason",
      );
      // Another address is unaffected; the owner recovers from there.
      await recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }, "192.0.2.45");
      assertEqual(h.removed.length, 1, "other IP recovers");
      // The window ends.
      h.setNow(T0 + RECOVERY_WINDOW_MS + 1);
      await expectRefusal(
        recover(h, { email: EMAIL, password: "guess", code: "ABCDE-FGHJK" }, ip),
        "permission-denied",
        "throttle lifted after the window",
      );
    },
  },
  {
    name: "the coarse global budget refuses before the password check",
    fn: async () => {
      const h = harness();
      h.fake.seed(`${RECOVERY_ATTEMPTS_COLLECTION}/${GLOBAL_ATTEMPT_KEY}`, {
        failures: 500,
        windowStart: T0,
        lockedUntil: T0 + 60_000,
      });
      await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "resource-exhausted",
        "global budget spent",
      );
      assertEqual(h.firstFactorCalls, 0, "no password check");
    },
  },
  {
    name: "counter keys are peppered HMACs with a TTL field; no address or IP is stored",
    fn: async () => {
      const h = harness();
      const ip = "192.0.2.99";
      await expectRefusal(
        recover(h, { email: EMAIL, password: "guess", code: "ABCDE-FGHJK" }, ip),
        "permission-denied",
        "wrong password",
      );
      const paths = h.fake.childPaths(RECOVERY_ATTEMPTS_COLLECTION);
      const ipPath = `${RECOVERY_ATTEMPTS_COLLECTION}/${ipAttemptKey(PEPPER, ip)}`;
      assertEqual(paths.includes(ipPath), true, "IP counter under its HMAC key");
      const everything = JSON.stringify(paths) + JSON.stringify(paths.map((p) => h.fake.read(p)));
      assertEqual(everything.includes(ip), false, "raw IP stored");
      assertEqual(everything.includes(EMAIL), false, "e-mail stored");
      assertEqual(
        ipAttemptKey("another-pepper", ip) === ipAttemptKey(PEPPER, ip),
        false,
        "key depends on the pepper",
      );
      for (const p of paths) {
        const expiresAt = h.fake.read(p)?.expiresAt;
        assertEqual(expiresAt instanceof admin.firestore.Timestamp, true, `${p} expiresAt`);
        assertEqual(
          (expiresAt as admin.firestore.Timestamp).toMillis() > T0,
          true,
          `${p} expires in the future`,
        );
      }
      let threw = false;
      try {
        pepperedKey("", "ip", ip);
      } catch {
        threw = true;
      }
      assertEqual(threw, true, "no key without a pepper");
    },
  },
  {
    name: "without the pepper recovery fails closed and writes nothing",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      h.deps.pepper = "";
      await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD, code: "ABCDE-FGHJK" }),
        "unavailable",
        "no pepper",
      );
      assertEqual(h.firstFactorCalls, 0, "no password check");
      assertEqual(h.fake.childPaths(RECOVERY_ATTEMPTS_COLLECTION).length, 0, "no counters");
      assertEqual(h.removed.length, 0, "nothing removed");
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
    name: "missing fields are rejected before anything is read",
    fn: async () => {
      const h = harness();
      await expectRefusal(
        recover(h, { email: EMAIL, password: PASSWORD }),
        "invalid-argument",
        "no code",
      );
      assertEqual(h.firstFactorCalls, 0, "no password check");
    },
  },
  {
    name: "finding 7: switching MFA off deletes the codes server-side, never while a factor remains",
    fn: async () => {
      const h = harness();
      await seedCodes(h, ["ABCDE-FGHJK"]);
      let factors = 1;
      const deps = {
        db: h.fake.db,
        enrolledFactorCount: async () => factors,
        audit: h.deps.audit,
        now: h.deps.now,
      };
      await expectRefusal(
        runClearBackupCodes(deps, UID),
        "failed-precondition",
        "factor still enrolled",
      );
      assertEqual(h.fake.has(`${BACKUP_CODES_COLLECTION}/${UID}`), true, "kept while enrolled");
      factors = 0;
      assertEqual((await runClearBackupCodes(deps, UID)).cleared, true, "cleared");
      assertEqual(h.fake.has(`${BACKUP_CODES_COLLECTION}/${UID}`), false, "codes gone");
      assertEqual(h.audits.at(-1)?.action, "mfa_backup_codes_cleared", "audited");
      assertEqual((await runClearBackupCodes(deps, UID)).cleared, false, "idempotent");
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
        respond({ idToken: "t", refreshToken: "r", localId: UID }),
      );
      assertEqual(plain.outcome, "no-mfa", "no mfa");
      assertEqual(JSON.stringify(plain), JSON.stringify({ outcome: "no-mfa" }), "no token kept");
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
