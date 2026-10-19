/**
 * BUT-2414: `exportErasureResidue` — the Art. 15 export of what erasure
 * deletes or anonymises.
 *
 * Per section: the cascade predicate (a matching row is exported, the
 * non-matching ones are not), the allowlist (a stray key is dropped), the
 * decline above the cap, and error isolation (a failed section is that
 * section's `error_code` and the others still ship).
 *
 * What this file cannot prove: `_fake-firestore` answers queries without
 * indexes. The query shapes are checked against `firestore.indexes.json`
 * below, and the collection-group legs also run on the emulator lane
 * (`erasure-residue.integration.test.ts`).
 *
 * Run: npx ts-node src/__tests__/erasure-residue.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-erasure-residue" });
}

import * as fs from "fs";
import * as path from "path";
import { HttpsError } from "firebase-functions/v2/https";
import { FakeFirestore } from "./_fake-firestore";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import { makeRecordingDb, servingComposite, RecordedQuery } from "./_query-index-coverage";
import { CASES, OTHER, SectionCase, UID } from "./_erasure-residue-cases";
import { CASES_2 } from "./_erasure-residue-cases-2";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const residue = require("../exports/erasure-residue") as typeof import("../exports/erasure-residue");
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { MAX_SECTION_ROWS } = require("../exports/erasure-residue/account-sections") as typeof import("../exports/erasure-residue/account-sections");
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { RAW_READ_FACTOR } = require("../exports/erasure-residue/social-sections") as typeof import("../exports/erasure-residue/social-sections");

const ALL_CASES: SectionCase[] = [...CASES, ...CASES_2];
const SECTION_NAMES = residue.SECTIONS.map((s) => s.name);
type Row = Record<string, unknown>;

function assertTrue(condition: boolean, msg: string): void {
  if (!condition) throw new Error(msg);
}

/**
 * The fake has no `listDocuments`; this one returns every direct child id
 * under the collection, including a missing parent that still has children,
 * as the Admin SDK does.
 */
function fakeDb(): FakeFirestore {
  const fake = new FakeFirestore();
  const internals = fake as unknown as { colRef: (p: string) => Record<string, unknown> };
  const colRef = internals.colRef.bind(fake);
  internals.colRef = (p: string) => ({
    ...colRef(p),
    listDocuments: async () => {
      const ids = new Set<string>();
      for (const key of fake.docs.keys()) {
        if (key.startsWith(`${p}/`)) ids.add(key.slice(p.length + 1).split("/")[0]);
      }
      return [...ids].sort().map((id) => fake.doc(`${p}/${id}`));
    },
  });
  return fake;
}

function sectionDef(name: string) {
  const def = residue.SECTIONS.find((s) => s.name === name);
  if (!def) throw new Error(`no section ${name}`);
  return def;
}

async function runOne(db: FakeFirestore, name: string) {
  const out = await residue.runExportErasureResidueWithDb(db.db, UID, [sectionDef(name)]);
  return out.sections[name];
}

function rowsOf(result: unknown, name: string): Row[] {
  const r = result as { rows?: Row[]; error_code?: string };
  assertTrue(Array.isArray(r.rows), `${name}: expected rows, got ${JSON.stringify(r)}`);
  return r.rows as Row[];
}

const coverage: UnitCase[] = [
  {
    name: "every section has a fixture, and every fixture a section",
    fn: async () => {
      assertEqual(
        JSON.stringify(ALL_CASES.map((c) => c.section).sort()),
        JSON.stringify([...SECTION_NAMES].sort()),
        "fixtures vs SECTIONS",
      );
    },
  },
  {
    name: "only the three single-document sections have no cap",
    fn: async () => {
      assertEqual(
        ALL_CASES.filter((c) => !c.overCap).map((c) => c.section).sort().join(","),
        "account_deletion_request,guest_quota,mfa_recovery_attempts",
        "uncapped sections",
      );
    },
  },
];

const predicateCases: UnitCase[] = ALL_CASES.map((c) => ({
  name: `${c.section}: the cascade predicate's rows only, allowlisted`,
  fn: async () => {
    const db = fakeDb();
    c.seed(db);
    const rows = rowsOf(await runOne(db, c.section), c.section);
    assertEqual(
      JSON.stringify(rows.map((r) => String(r[c.idKey]))),
      JSON.stringify(c.rows),
      `${c.section} rows`,
    );
    const text = JSON.stringify(rows);
    assertEqual(text.includes("strayKey") || text.includes("stray-value"), false, "stray key dropped");
    if (!c.allowOther) assertEqual(text.includes(OTHER), false, "no other person's uid");
    c.check?.(rows);
  },
}));

const declineCases: UnitCase[] = ALL_CASES.filter((c) => c.overCap).map((c) => ({
  name: `${c.section}: one row over the cap declines, never truncates`,
  fn: async () => {
    const db = fakeDb();
    c.overCap?.(db);
    assertEqual(
      JSON.stringify(await runOne(db, c.section)),
      JSON.stringify({ error_code: residue.TOO_LARGE_ERROR_CODE }),
      `${c.section} result`,
    );
  },
}));

const isolationCases: UnitCase[] = ALL_CASES.map((c) => ({
  name: `${c.section}: ships while every other section fails, and fails alone`,
  fn: async () => {
    const db = fakeDb();
    c.seed(db);
    const failing = async (): Promise<Row[]> => {
      throw Object.assign(new Error("boom"), { code: 14 });
    };
    const othersFail = residue.SECTIONS.map((s) =>
      s.name === c.section ? s : { name: s.name, read: failing },
    );
    const out = await residue.runExportErasureResidueWithDb(db.db, UID, othersFail);
    assertEqual(rowsOf(out.sections[c.section], c.section).length, c.rows.length, "own rows");
    for (const name of SECTION_NAMES.filter((n) => n !== c.section)) {
      assertEqual(
        JSON.stringify(out.sections[name]),
        JSON.stringify({ error_code: residue.READ_FAILED_ERROR_CODE }),
        `${name} failed`,
      );
    }
    const onlyThisFails = residue.SECTIONS.map((s) =>
      s.name === c.section ? { name: s.name, read: failing } : s,
    );
    const second = await residue.runExportErasureResidueWithDb(db.db, UID, onlyThisFails);
    assertEqual(
      second.sections[c.section] && "error_code" in second.sections[c.section],
      true,
      "this section failed",
    );
    const failed = Object.entries(second.sections).filter(([, r]) => "error_code" in r);
    assertEqual(failed.map(([n]) => n).join(","), c.section, "no other section failed");
  },
}));

const handlerCases: UnitCase[] = [
  {
    // The in-memory parent filter rejects these rows too, so only a count past
    // the raw bound tells the query's documentId range apart from its absence.
    name: "share_memberships: rows planted outside shared_content cannot push the raw read past its bound",
    fn: async () => {
      const db = fakeDb();
      db.seed(`shared_content/S1/members/${UID}`, { userId: UID });
      for (let i = 0; i <= MAX_SECTION_ROWS * RAW_READ_FACTOR; i++) {
        db.seed(`users/${OTHER}/friend_categories/c${i}/members/${UID}`, { userId: UID });
      }
      const rows = rowsOf(await runOne(db, "share_memberships"), "share_memberships");
      assertEqual(JSON.stringify(rows.map((r) => r.shareId)), '["S1"]', "planted rows kept out");
    },
  },
  {
    name: "a Firestore failure in one leg fails that section only",
    fn: async () => {
      const db = fakeDb();
      db.seed("tag_overrides_log/t1", { userId: UID, tag: "gluten" });
      const group = db.collectionGroup.bind(db);
      (db as unknown as { collectionGroup: (n: string) => unknown }).collectionGroup = (n) => {
        if (n !== "participants") return group(n);
        throw Object.assign(new Error("FAILED_PRECONDITION"), { code: 9 });
      };
      const out = await residue.runExportErasureResidueWithDb(db.db, UID);
      assertEqual(
        JSON.stringify(out.sections.conversation_roster_rows),
        JSON.stringify({ error_code: residue.READ_FAILED_ERROR_CODE }),
        "roster section",
      );
      assertEqual(rowsOf(out.sections.tag_overrides_log, "tag").length, 1, "other section ships");
    },
  },
  {
    name: "over the byte bound the largest section is replaced whole, the rest ship",
    fn: async () => {
      const db = fakeDb();
      db.seed("tag_overrides_log/t1", { userId: UID, tag: "x".repeat(residue.MAX_RESPONSE_BYTES) });
      db.seed(`guest_quotas/${UID}`, { calls: 2 });
      const out = await residue.runExportErasureResidueWithDb(db.db, UID);
      assertEqual(
        JSON.stringify(out.sections.tag_overrides_log),
        JSON.stringify({ error_code: residue.RESPONSE_TOO_LARGE_ERROR_CODE }),
        "large section replaced",
      );
      assertEqual(rowsOf(out.sections.guest_quota, "guest").length, 1, "small section kept");
      assertTrue(Buffer.byteLength(JSON.stringify(out)) <= residue.MAX_RESPONSE_BYTES, "fits");
    },
  },
  {
    name: "no log line carries the uid",
    fn: async () => {
      const db = fakeDb();
      CASES[0].overCap?.(db);
      const lines: string[] = [];
      // The logger keeps its own references to the console methods, so the
      // capture sits below it, on the two streams.
      const streams = [process.stdout, process.stderr];
      const saved = streams.map((s) => s.write);
      const failing = async (): Promise<Row[]> => {
        throw new Error("boom");
      };
      try {
        for (const s of streams) {
          s.write = ((chunk: unknown) => {
            lines.push(String(chunk));
            return true;
          }) as typeof s.write;
        }
        await residue.runExportErasureResidueWithDb(db.db, UID, [
          sectionDef("tag_overrides_log"),
          sectionDef("guest_quota"),
          { name: "fails", read: failing },
        ]);
      } finally {
        streams.forEach((s, i) => (s.write = saved[i]));
      }
      const text = lines.join("\n");
      assertTrue(text.includes("uid_hash") && text.includes("section_declined"), `logged: ${text}`);
      assertEqual(text.includes(UID) || text.includes(UID.slice(0, 6)), false, "uid absent from logs");
    },
  },
  {
    name: "unauthenticated: refused before rate limit or reads",
    fn: async () => {
      const calls: string[] = [];
      try {
        await residue.handleExportErasureResidue(
          { auth: null },
          {
            rateLimit: async () => void calls.push("rateLimit"),
            run: async () => {
              calls.push("run");
              throw new Error("must not run");
            },
          },
        );
        throw new Error("expected unauthenticated");
      } catch (err) {
        assertTrue(err instanceof HttpsError, `got ${String(err)}`);
        assertEqual((err as HttpsError).code, "unauthenticated", "code");
      }
      assertEqual(calls.join(","), "", "nothing called");
    },
  },
  {
    name: "a forged payload uid is ignored; the rate limit uses the right key first",
    fn: async () => {
      const calls: string[] = [];
      await residue.handleExportErasureResidue(
        { auth: { uid: UID }, data: { uid: OTHER } } as { auth: { uid: string } },
        {
          rateLimit: async (uid, op) => void calls.push(`rateLimit:${uid}:${op}`),
          run: async (uid) => {
            calls.push(`run:${uid}`);
            return residue.runExportErasureResidueWithDb(fakeDb().db, uid, []);
          },
        },
      );
      assertEqual(calls.join(","), `rateLimit:${UID}:exportErasureResidue,run:${UID}`, "order");
    },
  },
  {
    name: "a rate-limit refusal stops the export",
    fn: async () => {
      let ran = false;
      try {
        await residue.handleExportErasureResidue(
          { auth: { uid: UID } },
          {
            rateLimit: async () => {
              throw new HttpsError("resource-exhausted", "slow down");
            },
            run: async () => {
              ran = true;
              return residue.runExportErasureResidueWithDb(fakeDb().db, UID, []);
            },
          },
        );
        throw new Error("expected resource-exhausted");
      } catch (err) {
        assertEqual((err as HttpsError).code, "resource-exhausted", "code");
      }
      assertEqual(ran, false, "no reads after a refusal");
    },
  },
  {
    name: "callable options: 1 GiB, 120 s, App Check enforced",
    fn: async () => {
      const endpoint = (residue.exportErasureResidue as unknown as {
        __endpoint: { availableMemoryMb?: number; timeoutSeconds?: number };
      }).__endpoint;
      assertEqual(endpoint.availableMemoryMb, 1024, "memory");
      assertEqual(endpoint.timeoutSeconds, 120, "timeout");
      const source = fs.readFileSync(
        path.join(__dirname, "..", "exports", "erasure-residue", "index.ts"),
        "utf8",
      );
      assertTrue(/enforceAppCheck:\s*true/.test(source), "enforceAppCheck: true");
    },
  },
];

/** The collection-group legs and the field each filters on. */
const GROUP_LEGS = [
  "activeUsers.userId",
  "comments.commentedBy",
  "engagements.userId",
  "members.userId",
  "participants.participantId",
  "ratings.ratedBy",
  "report_history.reporterId",
];

interface FieldOverride {
  collectionGroup: string;
  fieldPath: string;
  indexes: Array<{ queryScope: string; order?: string; arrayConfig?: string }>;
}

function overrides(): FieldOverride[] {
  const file = path.join(__dirname, "..", "..", "..", "firestore.indexes.json");
  return JSON.parse(fs.readFileSync(file, "utf8")).fieldOverrides as FieldOverride[];
}

function stringFilters(rec: RecordedQuery) {
  return rec.filters.filter((f) => typeof f.field === "string");
}

const indexCases: UnitCase[] = [
  {
    name: "query shapes: collection scope served, each collection-group leg has its override",
    fn: async () => {
      const recording = makeRecordingDb();
      const db = { ...recording, doc: (p: string) => ({ path: p }) };
      const out = await residue.runExportErasureResidueWithDb(
        db as unknown as admin.firestore.Firestore,
        UID,
      );
      // A section that throws on the recording db records no query shape, so
      // the ones that do are named here: single-document reads and listDocuments.
      assertEqual(
        Object.entries(out.sections)
          .filter(([, r]) => "error_code" in r)
          .map(([n]) => n)
          .sort()
          .join(","),
        "account_deletion_request,guest_quota,legacy_shopping_lists,mfa_recovery_attempts",
        "sections absent from the shape check",
      );
      const all = overrides();

      const groupLegs = new Set<string>();
      for (const rec of recording.gets) {
        const group = rec.path[rec.path.length - 1];
        for (const f of stringFilters(rec)) {
          const want = f.op === "array-contains" ? "CONTAINS" : "ASCENDING";
          const scope = rec.group ? "COLLECTION_GROUP" : "COLLECTION";
          const override = all.find((o) => o.collectionGroup === group && o.fieldPath === f.field);
          if (rec.group) groupLegs.add(`${group}.${f.field}`);
          if (!rec.group && override === undefined) continue;
          assertTrue(
            override !== undefined &&
              override.indexes.some(
                (i) => i.queryScope === scope && (i.order === want || i.arrayConfig === want),
              ),
            `${scope} ${group}.${f.field} (${f.op}) has no serving fieldOverride`,
          );
        }
        if (!rec.group) {
          assertTrue(servingComposite(rec), `${rec.path.join("/")} needs a composite index`);
        }
      }
      assertEqual(JSON.stringify([...groupLegs].sort()), JSON.stringify(GROUP_LEGS), "group legs");
    },
  },
  ...GROUP_LEGS.map((leg) => ({
    name: `fieldOverrides: COLLECTION_GROUP ascending index on ${leg}`,
    fn: async () => {
      const [group, field] = leg.split(".");
      const override = overrides().find((o) => o.collectionGroup === group && o.fieldPath === field);
      assertTrue(
        override?.indexes.some((i) => i.queryScope === "COLLECTION_GROUP" && i.order === "ASCENDING") ??
          false,
        `${leg} is missing its COLLECTION_GROUP override`,
      );
    },
  })),
];

runTests("BUT-2414 exportErasureResidue", [
  ...coverage,
  ...predicateCases,
  ...declineCases,
  ...isolationCases,
  ...handlerCases,
  ...indexCases,
]);
