/**
 * Account deletion's step for admin ingredient proposals
 * (`account/cascade/ingredient-change-requests.ts`): the erased admin's uid is
 * nulled in `createdBy` and `withdrawnBy`, the proposal is kept, the residual
 * probe sees a leftover uid, and the Art. 15 section's allowlist matches what
 * `firestore.rules` lets a proposal hold.
 *
 * Run: npx ts-node src/__tests__/ingredient-change-requests-erasure.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-icr-erasure" });
}

import * as fs from "fs";
import * as path from "path";
import { FakeFirestore } from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  UID,
  asDb,
  check,
  emptyResult,
  finishSuite,
  probeAfter,
  sawResidual,
} from "./_account-deletion-cascade-test-seeds";
import { scrubIngredientChangeRequestAuthors } from "../account/cascade/ingredient-change-requests";
import {
  INGREDIENT_CHANGE_COLUMNS,
  INGREDIENT_CHANGE_REQUEST_KEYS,
} from "../exports/erasure-residue/account-sections";
import { SERVER_WRITTEN_PROPOSAL_KEYS } from "../admin/create-ingredient-change-pr";
import { APPLIED_STAMP_KEYS } from "../admin/mark-applied-core";
import { hashUid } from "../shared/hash-uid";

const RUNS = "ingredient_change_runs";

const COL = "ingredient_change_requests";
const SRC = path.join(__dirname, "..");
const RULES = path.join(SRC, "..", "..", "firestore.rules");

function auditRows(db: FakeFirestore): Record<string, unknown>[] {
  return db
    .pathsUnder("audit_logs")
    .map((p) => db.get(p) as Record<string, unknown>)
    .filter((r) => r.resourceType === COL);
}

async function scrubScenarios(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`${COL}/own`, {
    ingredientId: "tomat", status: "pending", createdBy: UID,
    changes: { swedish: { old: "Tomat", new: "Tomater" } }, note: "n",
  });
  db.set(`${COL}/self`, { ingredientId: "lok", status: "withdrawn", createdBy: UID, withdrawnBy: UID });
  db.set(`${COL}/theirs`, { ingredientId: "gurka", status: "withdrawn", createdBy: OTHER, withdrawnBy: UID });
  db.set(`${COL}/control`, { ingredientId: "x", status: "withdrawn", createdBy: OTHER, withdrawnBy: OTHER });

  const ok = await scrubIngredientChangeRequestAuthors(asDb(db), UID);
  check("scrub reports success", ok === true);
  const own = db.get(`${COL}/own`);
  check("createdBy nulled, proposal kept", own?.createdBy === null && own?.note === "n" &&
    JSON.stringify(own?.changes) === '{"swedish":{"old":"Tomat","new":"Tomater"}}', JSON.stringify(own));
  const self = db.get(`${COL}/self`);
  check("both fields nulled on a self-withdrawn proposal", self?.createdBy === null && self?.withdrawnBy === null);
  const theirs = db.get(`${COL}/theirs`);
  check("withdrawnBy nulled, the other admin's createdBy kept", theirs?.withdrawnBy === null && theirs?.createdBy === OTHER);
  const control = db.get(`${COL}/control`);
  check("another admin's proposal untouched", control?.createdBy === OTHER && control?.withdrawnBy === OTHER);
  const audits = auditRows(db);
  check("one anonymize audit row per proposal written", audits.length === 3 &&
    audits.every((r) => r.operation === "cascade_anonymize" && r.userId === UID), JSON.stringify(audits));
  const selfAudit = audits.find((r) => r.resourceId === "self");
  check("a self-withdrawn proposal is one write naming both fields",
    JSON.stringify((selfAudit?.metadata as Record<string, unknown>)?.fields) === '["createdBy","withdrawnBy"]');

  const writesBefore = db.updatedPaths.length;
  const again = await scrubIngredientChangeRequestAuthors(asDb(db), UID);
  check("a re-run succeeds and writes nothing", again === true && db.updatedPaths.length === writesBefore);
}

// The statuses createIngredientChangePr writes are scrubbed like any other.
async function serverStatusScenario(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`${COL}/review`, { ingredientId: "a", status: "inReview", prNumber: 4, createdBy: UID });
  db.set(`${COL}/conflict`, {
    ingredientId: "b", status: "conflict", reason: "csv-mismatch", csvValue: { swedish: "B" },
    createdBy: OTHER, withdrawnBy: UID,
  });
  db.set(`${COL}/rejected`, { ingredientId: "c", status: "rejected", reason: "no-change", createdBy: UID });
  const ok = await scrubIngredientChangeRequestAuthors(asDb(db), UID);
  check("inReview, conflict and rejected proposals are scrubbed", ok === true &&
    db.get(`${COL}/review`)?.createdBy === null && db.get(`${COL}/review`)?.prNumber === 4 &&
    db.get(`${COL}/conflict`)?.withdrawnBy === null && db.get(`${COL}/conflict`)?.createdBy === OTHER &&
    db.get(`${COL}/rejected`)?.createdBy === null);
}

async function runRecordScenarios(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`${RUNS}/r1`, { adminUidHash: hashUid(UID), prNumber: 4, counts: { applied: 2 } });
  db.set(`${RUNS}/r2`, { adminUidHash: hashUid(OTHER), prNumber: 5 });
  const ok = await scrubIngredientChangeRequestAuthors(asDb(db), UID);
  check("the erased admin's run record loses its hash and keeps its content",
    ok === true && db.get(`${RUNS}/r1`)?.adminUidHash === null && db.get(`${RUNS}/r1`)?.prNumber === 4);
  check("another admin's run record is untouched", db.get(`${RUNS}/r2`)?.adminUidHash === hashUid(OTHER));
  check("the run record scrub writes an anonymize audit row",
    db.pathsUnder("audit_logs").map((p) => db.get(p)).some((r) => r?.resourceType === RUNS && r?.resourceId === "r1"));

  const leftover = new FakeFirestore();
  leftover.set(`${RUNS}/r`, { adminUidHash: hashUid(UID) });
  const result = emptyResult();
  await probeAfter(leftover, result);
  check("the probe reports a leftover run-record hash", sawResidual(result), JSON.stringify(result.failedCollections));

  const clean = new FakeFirestore();
  clean.set(`${RUNS}/r`, { adminUidHash: hashUid(OTHER) });
  const cleanResult = emptyResult();
  await probeAfter(clean, cleanResult);
  check("another admin's run record leaves the probe clean", !sawResidual(cleanResult),
    JSON.stringify(cleanResult.failedCollections));
}

async function pagingScenario(): Promise<void> {
  const db = new FakeFirestore();
  for (let i = 0; i < 600; i++) db.set(`${COL}/p${i}`, { createdBy: UID, withdrawnBy: i % 2 ? UID : OTHER });
  const ok = await scrubIngredientChangeRequestAuthors(asDb(db), UID);
  const left = db.pathsUnder(COL).filter((p) => {
    const d = db.get(p);
    return d?.createdBy === UID || d?.withdrawnBy === UID;
  });
  check("more proposals than one page are all scrubbed", ok === true && left.length === 0, `left ${left.length}`);
}

async function failedChunkScenario(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`${COL}/bad`, { createdBy: UID });
  db.batchFailures.set(`${COL}/bad`, 13);
  const ok = await scrubIngredientChangeRequestAuthors(asDb(db), UID);
  check("a chunk that cannot commit: the step reports false", ok === false);
  check("the uid is still there", db.get(`${COL}/bad`)?.createdBy === UID);
  const result = emptyResult();
  await probeAfter(db, result);
  check("the probe reports the leftover createdBy", sawResidual(result), JSON.stringify(result.failedCollections));
}

async function probeScenarios(): Promise<void> {
  const clean = new FakeFirestore();
  clean.set(`${COL}/a`, { createdBy: null, withdrawnBy: OTHER });
  const cleanResult = emptyResult();
  await probeAfter(clean, cleanResult);
  check("scrubbed and foreign proposals leave the probe clean", !sawResidual(cleanResult),
    JSON.stringify(cleanResult.failedCollections));

  const withdrawn = new FakeFirestore();
  withdrawn.set(`${COL}/w`, { createdBy: OTHER, withdrawnBy: UID });
  const withdrawnResult = emptyResult();
  await probeAfter(withdrawn, withdrawnResult);
  check("the probe reports a leftover withdrawnBy", sawResidual(withdrawnResult));
}

function rulesBlock(): string {
  const rules = fs.readFileSync(RULES, "utf8").replace(/\r\n/g, "\n");
  const header = "match /ingredient_change_requests/{requestId}";
  const start = rules.indexOf(header);
  if (start < 0) throw new Error("ingredient_change_requests rules block not found");
  // The helper functions sit after the allow statements, so the slice runs to
  // the brace that closes the match block.
  let depth = 0;
  for (let i = rules.indexOf("{", start + header.length); i < rules.length; i++) {
    if (rules[i] === "{") depth++;
    if (rules[i] === "}" && --depth === 0) return rules.slice(start, i + 1);
  }
  throw new Error("ingredient_change_requests rules block is not closed");
}

function quoted(list: string): string[] {
  return [...list.matchAll(/'([a-z_A-Z]+)'/g)].map((m) => m[1]).sort();
}

function allowlistPins(): void {
  const block = rulesBlock();
  const columns = block.match(/ch\.keys\(\)\.hasOnly\(\[([^\]]*)\]/);
  check("rules column list found", columns !== null);
  check(
    "the export's change columns are the rules' columns",
    JSON.stringify(Object.keys(INGREDIENT_CHANGE_COLUMNS).sort()) === JSON.stringify(quoted(columns?.[1] ?? "")),
  );
  const kinds = [...block.matchAll(/(textOk|listOk|priceOk)\(ch\.get\('([a-z_]+)'/g)];
  check("every column has a typed rules check", kinds.length === Object.keys(INGREDIENT_CHANGE_COLUMNS).length);
  const wrong = kinds.filter(([, kind, column]) => {
    const spec = INGREDIENT_CHANGE_COLUMNS[column] as { map: Record<string, unknown> };
    const isList = spec.map.old === "strings" && spec.map.new === "strings";
    return isList !== (kind === "listOk");
  });
  check("list columns export as string lists, the rest as scalars", wrong.length === 0,
    wrong.map((w) => w[2]).join(","));

  const create = block.match(/allow create:[\s\S]*?keys\(\)\.hasOnly\(\[([^\]]*)\]/);
  const update = block.match(/allow update:[\s\S]*?affectedKeys\(\)\s*\.hasOnly\(\[([^\]]*)\]/);
  check("rules create and update key lists found", create !== null && update !== null);
  const storable = new Set([...quoted(create?.[1] ?? ""), ...quoted(update?.[1] ?? "")]);
  storable.delete("createdBy");
  storable.delete("withdrawnBy");
  for (const k of [...SERVER_WRITTEN_PROPOSAL_KEYS, ...APPLIED_STAMP_KEYS]) storable.add(k);
  check(
    "the export's proposal keys are every storable key except the two uid fields, plus the server's",
    JSON.stringify(Object.keys(INGREDIENT_CHANGE_REQUEST_KEYS).sort()) === JSON.stringify([...storable].sort()),
    `${Object.keys(INGREDIENT_CHANGE_REQUEST_KEYS).sort()} vs ${[...storable].sort()}`,
  );
}

// The shared function's tests stay green with a caller's line deleted, so each
// call site is pinned in source.
function callSitePins(): void {
  const cascade = fs.readFileSync(path.join(SRC, "account", "request-account-deletion.ts"), "utf8");
  check(
    "the account cascade runs the scrub under its step label",
    /"ingredient_change_requests",\s*\(\)\s*=>\s*scrubIngredientChangeRequestAuthors\(database, uid\)/.test(cascade),
  );
  const trigger = fs.readFileSync(path.join(SRC, "cleanup", "on-user-deleted.ts"), "utf8");
  check(
    "onUserDeleted runs the scrub",
    /await scrubIngredientChangeRequestAuthors\(db, userId\);/.test(trigger),
  );
}

async function main(): Promise<void> {
  await scrubScenarios();
  await serverStatusScenario();
  await runRecordScenarios();
  await pagingScenario();
  await failedChunkScenario();
  await probeScenarios();
  allowlistPins();
  callSitePins();
  finishSuite("ingredient_change_requests erasure");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
