/**
 * Admin-vy C3: `inReview` proposals become `applied` once Firestore holds
 * their new values, by the C1 comparison; a withdrawal is never overwritten
 * and a rerun is a no-op.
 *
 * Run with: npx ts-node src/__tests__/mark-applied-proposals.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import {
  APPLIED_RETENTION_MS,
  formatMarkAppliedSummary,
  markAppliedProposals,
  proposalIsApplied,
} from "../admin/mark-applied-core";
import { FakeFirestore } from "./_fake-firestore";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const NOW = new Date("2026-11-04T08:00:00Z");
const COL = "ingredient_change_requests";

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const ingredient = {
  swedish: "Vitlök", english: "Garlic", properties: ["plant-based", "vegan-friendly"],
  aliasesSv: ["vitlöksklyfta"], avgPriceSek: 12.5, status: "verified", notesSv: "Skarp.",
};

function store(): FakeFirestore {
  const s = new FakeFirestore({ now: admin.firestore.Timestamp.fromDate(NOW) });
  s.seed("ingredients/garlic", ingredient);
  return s;
}

function seed(s: FakeFirestore, id: string, changes: unknown, status = "inReview"): void {
  s.seed(`${COL}/${id}`, { ingredientId: "garlic", changes, status, prNumber: 101, createdBy: "admin-1" });
}

const cases: UnitCase[] = [
  {
    name: "applied when every new value is in Firestore: list order, price, trimmed text",
    fn: () => {
      assertEqual(proposalIsApplied({
        properties: { old: [], new: ["vegan-friendly", "plant-based"] },
        avg_price_sek: { old: null, new: 12.5 },
        notes_sv: { old: "", new: " Skarp. " },
      }, ingredient), true, "all in place");
    },
  },
  {
    name: "not applied while any one value differs, the doc is missing, or the changes are malformed",
    fn: () => {
      assertEqual(proposalIsApplied({
        status: { old: "draft", new: "verified" }, swedish: { old: "x", new: "Vitlöken" },
      }, ingredient), false, "one differs");
      assertEqual(proposalIsApplied({ status: { old: "draft", new: "verified" } }, undefined), false, "no doc");
      assertEqual(proposalIsApplied({}, ingredient), false, "empty");
      assertEqual(proposalIsApplied({ verified_by: { old: "", new: "x" } }, ingredient), false, "unknown column");
      assertEqual(proposalIsApplied(["status"], ingredient), false, "not a map");
    },
  },
  {
    name: "a blanked english reads as the Swedish name, as the sync stores it",
    fn: () => {
      assertEqual(proposalIsApplied({ english: { old: "Garlic", new: "" } }, { ...ingredient, english: "Vitlök" }), true, "fallback");
      assertEqual(proposalIsApplied({ english: { old: "Garlic", new: "" } }, ingredient), false, "not synced yet");
    },
  },
  {
    name: "a run marks the synced proposal applied with appliedAt and a 365-day expiry, leaves the rest",
    fn: async () => {
      const s = store();
      seed(s, "done", { status: { old: "draft", new: "verified" } });
      seed(s, "open", { swedish: { old: "Vitlök", new: "Vitlöken" } });
      seed(s, "pending", { status: { old: "draft", new: "verified" } }, "pending");
      const counts = await markAppliedProposals(s.db, NOW);
      assertEqual(JSON.stringify(counts), '{"inReview":2,"applied":1,"notYet":1,"skipped":0}', "counts");
      const done = s.read(`${COL}/done`)!;
      assertEqual(done.status, "applied", "applied");
      assertEqual((done.appliedAt as admin.firestore.Timestamp).toMillis(), NOW.getTime(), "server time");
      assertEqual((done.expireAt as admin.firestore.Timestamp).toMillis() - NOW.getTime(), APPLIED_RETENTION_MS, "expiry");
      assertEqual(done.prNumber, 101, "PR number kept");
      assertEqual(s.read(`${COL}/open`)?.status, "inReview", "not yet synced");
      assertEqual(s.read(`${COL}/pending`)?.status, "pending", "pending untouched");
    },
  },
  {
    name: "a proposal withdrawn between the read and the write is left withdrawn",
    fn: async () => {
      const s = store();
      seed(s, "gone", { status: { old: "draft", new: "verified" } });
      const real = s.db.runTransaction.bind(s.db);
      const racing = new Proxy(s.db, {
        get(target, prop, receiver) {
          if (prop === "runTransaction") {
            return (fn: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
              s.seed(`${COL}/gone`, { ...s.read(`${COL}/gone`)!, status: "withdrawn" });
              return real(fn);
            };
          }
          return Reflect.get(target, prop, receiver);
        },
      });
      const counts = await markAppliedProposals(racing, NOW);
      assertEqual(counts.skipped, 1, "skipped");
      assertEqual(s.read(`${COL}/gone`)?.status, "withdrawn", "withdrawal kept");
    },
  },
  {
    name: "a rerun writes nothing; an empty queue is a clean no-op",
    fn: async () => {
      const s = store();
      seed(s, "done", { status: { old: "draft", new: "verified" } });
      await markAppliedProposals(s.db, NOW);
      const writes = s.writes.length;
      const again = await markAppliedProposals(s.db, NOW);
      assertEqual(JSON.stringify(again), '{"inReview":0,"applied":0,"notYet":0,"skipped":0}', "nothing to do");
      assertEqual(s.writes.length, writes, "no writes");
    },
  },
  {
    name: "the summary carries the counts and no uid",
    fn: async () => {
      const s = store();
      seed(s, "done", { status: { old: "draft", new: "verified" } });
      const text = formatMarkAppliedSummary(await markAppliedProposals(s.db, NOW));
      assert(text.includes("| Marked applied | 1 |"), text);
      assert(!text.includes("admin-1"), "no uid");
    },
  },
  {
    name: "the CLI initializes through the project guard and prints counts only",
    fn: () => {
      const src = fs.readFileSync(path.resolve(__dirname, "../admin/mark-applied-proposals.ts"), "utf-8");
      assert(/^initializeAdminApp\(\);$/m.test(src), "initializeAdminApp at module scope");
      assert(!/err\.message|console\.(log|error)\([^)]*createdBy/.test(src), "no error message or uid printed");
    },
  },
];

runTests("mark-applied-proposals (admin-vy C3)", cases);
