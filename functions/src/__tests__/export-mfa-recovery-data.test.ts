/**
 * BUT-2142 (E1) — exportMfaRecoveryData unit tests.
 *
 * The Art. 15 export of the backup codes reports when the set was made, how
 * many codes it holds and how many are unused, and never a salt or a hash.
 *
 * Run: npx ts-node src/__tests__/export-mfa-recovery-data.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-export-mfa" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runExportMfaRecoveryData } = require("../exports/mfa-recovery-data");

type Docs = Record<string, Record<string, unknown>>;

function makeFakeDb(docs: Docs, reads: string[]): admin.firestore.Firestore {
  return {
    collection(name: string) {
      return {
        doc(id: string) {
          return {
            async get() {
              const path = `${name}/${id}`;
              reads.push(path);
              const data = docs[path];
              return { exists: data !== undefined, data: () => data };
            },
          };
        },
      };
    },
  } as unknown as admin.firestore.Firestore;
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}
function assert(cond: unknown, msg: string): void {
  if (!cond) throw new Error(msg);
}

const CREATED = Date.UTC(2026, 9, 1, 12, 0, 0);

function storedSet(usedCount: number): Record<string, unknown> {
  const codes = Array.from({ length: 10 }, (_, i) => ({
    salt: `salt-${i}`,
    hash: `hash-${i}`,
    usedAt: i < usedCount ? CREATED + i : null,
  }));
  return { codes, createdAt: CREATED, algorithm: "scrypt-n16384-r8-p1" };
}

test("reports the caller's own set: created, total and unused", async () => {
  const reads: string[] = [];
  const db = makeFakeDb({ "mfa_backup_codes/me": storedSet(3) }, reads);
  const out = await runExportMfaRecoveryData(db, "me");
  assert(out.hasBackupCodes === true, "hasBackupCodes");
  assert(out.createdAt === new Date(CREATED).toISOString(), `createdAt ${out.createdAt}`);
  assert(out.total === 10, `total ${out.total}`);
  assert(out.unused === 7, `unused ${out.unused}`);
  assert(out.algorithm === "scrypt-n16384-r8-p1", "algorithm");
  assert(reads.length === 1 && reads[0] === "mfa_backup_codes/me", `reads ${reads}`);
});

test("never returns a salt or a hash", async () => {
  const db = makeFakeDb({ "mfa_backup_codes/me": storedSet(0) }, []);
  const json = JSON.stringify(await runExportMfaRecoveryData(db, "me"));
  for (let i = 0; i < 10; i++) {
    assert(!json.includes(`hash-${i}`), `hash-${i} leaked`);
    assert(!json.includes(`salt-${i}`), `salt-${i} leaked`);
  }
  assert(!/"(salt|hash|codes)"/.test(json), `secret key in ${json}`);
});

test("reads only the caller's document, never another account's", async () => {
  const reads: string[] = [];
  const db = makeFakeDb({ "mfa_backup_codes/other": storedSet(0) }, reads);
  const out = await runExportMfaRecoveryData(db, "me");
  assert(out.hasBackupCodes === false, "another account's set was reported");
  assert(reads.length === 1 && reads[0] === "mfa_backup_codes/me", `reads ${reads}`);
});

test("an account without codes says so, with zero counts", async () => {
  const db = makeFakeDb({}, []);
  const out = await runExportMfaRecoveryData(db, "me");
  assert(out.hasBackupCodes === false, "hasBackupCodes");
  assert(out.createdAt === null && out.algorithm === null, "nulls");
  assert(out.total === 0 && out.unused === 0, "counts");
});

async function run(): Promise<void> {
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  console.log(`\n${tests.length - failed}/${tests.length} passed`);
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
