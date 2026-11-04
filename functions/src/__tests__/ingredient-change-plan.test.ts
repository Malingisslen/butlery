/**
 * The admin-vy change plan: which queued proposals go into the PR, which are
 * conflicts with the CSV and which are rejected, and the self-check that
 * stands in for a CI round trip on a CSV-only PR.
 *
 * Run with: npx ts-node src/__tests__/ingredient-change-plan.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { planIngredientChanges, QueuedProposal, selfCheck, SelfCheckError } from "../admin/ingredient-change-plan";
import { csvRowToDoc, parseCsvFile } from "../admin/ingredient-csv-writer";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const REAL = fs.readFileSync(
  path.resolve(__dirname, "../../../docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv"), "utf-8"
);
const NOW = new Date("2026-11-03T12:00:00Z");
const FILE = parseCsvFile(REAL);
const ID = FILE.header.indexOf("id");
const [A, B] = FILE.rows.slice(0, 2).map((r) => r.values[ID]);
const docOf = (id: string) => csvRowToDoc(FILE.header, FILE.rows.find((r) => r.values[ID] === id)!.values);

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

let seq = 0;
function q(ingredientId: string, changes: unknown, extra: Partial<QueuedProposal> = {}): QueuedProposal {
  seq++;
  return { id: `p${String(seq).padStart(3, "0")}`, ingredientId, changes, status: "pending", createdAtMs: seq, ...extra };
}

function changedLines(before: string, after: string): number[] {
  const a = before.split("\n");
  const b = after.split("\n");
  return a.map((l, i) => (l === b[i] ? -1 : i)).filter((i) => i >= 0);
}

function throwsSelfCheck(fn: () => void, code: string): void {
  try {
    fn();
  } catch (err) {
    assert(err instanceof SelfCheckError, `not a SelfCheckError: ${err}`);
    assertEqual((err as SelfCheckError).code, code, "self-check code");
    return;
  }
  throw new Error(`expected self-check ${code}`);
}

const cases: UnitCase[] = [
  {
    name: "a matching proposal is applied: only its row changes, stamped admin-vy",
    fn: () => {
      const p = q(A, { notes_sv: { old: docOf(A).notesSv ?? "", new: "Granskad anteckning." } });
      const plan = planIngredientChanges(REAL, [p], NOW);
      assertEqual(plan.outcomes.get(p.id)?.kind, "apply", "applied");
      assertEqual(JSON.stringify(plan.appliedIds), JSON.stringify([p.id]), "applied ids");
      const lines = changedLines(REAL, plan.text);
      assertEqual(lines.length, 1, "exactly one line");
      assert(plan.text.split("\n")[lines[0]].includes("admin-vy"), "verified_by stamp");
    },
  },
  {
    name: "an old value that no longer matches is a conflict carrying the CSV value; the row is untouched",
    fn: () => {
      const p = q(A, { status: { old: "something-else", new: "verified" } });
      const plan = planIngredientChanges(REAL, [p], NOW);
      const o = plan.outcomes.get(p.id)!;
      assert(o.kind === "conflict" && o.reason === "csv-mismatch", JSON.stringify(o));
      assertEqual(JSON.stringify(o.kind === "conflict" ? o.csvValue : null), JSON.stringify({ status: docOf(A).status }), "csvValue");
      assertEqual(plan.text, REAL, "file unchanged");
    },
  },
  {
    name: "a list old value matches in any order",
    fn: () => {
      const doc = docOf(A);
      const p = q(A, {
        aliases_sv: { old: [...doc.aliasesSv].reverse(), new: [...doc.aliasesSv, "nytt alias"] },
      });
      const plan = planIngredientChanges(REAL, [p], NOW);
      assertEqual(plan.outcomes.get(p.id)?.kind, "apply", JSON.stringify(plan.outcomes.get(p.id)));
    },
  },
  {
    name: "an ingredient id the CSV lacks is a conflict with no CSV value",
    fn: () => {
      const p = q("no-such-ingredient-id", { swedish: { old: "x", new: "y" } });
      const o = planIngredientChanges(REAL, [p], NOW).outcomes.get(p.id)!;
      assert(o.kind === "conflict" && o.reason === "missing-row" && o.csvValue === null, JSON.stringify(o));
    },
  },
  {
    name: "server validation rejects what the rules let through: formula prefix, unknown property, unknown column",
    fn: () => {
      const doc = docOf(A);
      const formula = q(A, { notes_sv: { old: doc.notesSv ?? "", new: "=HYPERLINK(\"http://x\")" } });
      const prop = q(A, { properties: { old: doc.properties, new: [...doc.properties, "not-a-property"] } });
      const column = q(A, { verified_by: { old: "", new: "me" } });
      const shape = q(A, ["swedish"]);
      const plan = planIngredientChanges(REAL, [formula, prop, column, shape], NOW);
      const reason = (id: string) => {
        const o = plan.outcomes.get(id)!;
        return o.kind === "rejected" ? o.reason : o.kind;
      };
      assertEqual(reason(formula.id), "formula-prefix", "formula");
      assertEqual(reason(prop.id), "unknown-property", "property");
      assertEqual(reason(column.id), "unknown-column", "column");
      assertEqual(reason(shape.id), "wrong-type", "shape");
      assertEqual(plan.text, REAL, "nothing written");
    },
  },
  {
    name: "a proposal whose new value is already the cell is rejected as no-change",
    fn: () => {
      const doc = docOf(A);
      const p = q(A, { swedish: { old: doc.swedish, new: doc.swedish } });
      const o = planIngredientChanges(REAL, [p], NOW).outcomes.get(p.id)!;
      assert(o.kind === "rejected" && o.reason === "no-change", JSON.stringify(o));
    },
  },
  {
    name: "oldest first: a later proposal on the same cell with the same old value is a conflict",
    fn: () => {
      const doc = docOf(B);
      const later = q(B, { notes_en: { old: doc.notesEn ?? "", new: "Later." } }, { createdAtMs: 200 });
      const earlier = q(B, { notes_en: { old: doc.notesEn ?? "", new: "Earlier." } }, { createdAtMs: 100 });
      const plan = planIngredientChanges(REAL, [later, earlier], NOW);
      assertEqual(plan.outcomes.get(earlier.id)?.kind, "apply", "earlier applied");
      const o = plan.outcomes.get(later.id)!;
      assert(o.kind === "conflict" && JSON.stringify(o.csvValue) === '{"notes_en":"Earlier."}', JSON.stringify(o));
      assertEqual(JSON.stringify(plan.order), JSON.stringify([earlier.id, later.id]), "decided oldest first");
    },
  },
  {
    name: "a chain of proposals on one cell applies in order, and the second builds on the first",
    fn: () => {
      const doc = docOf(B);
      const one = q(B, { typical_unit: { old: doc.typicalUnit ?? "", new: "st" } });
      const two = q(B, { typical_unit: { old: "st", new: "g" } });
      const plan = planIngredientChanges(REAL, [one, two], NOW);
      assertEqual(plan.appliedIds.length, 2, "both applied");
      const out = parseCsvFile(plan.text);
      const row = out.rows.find((r) => r.values[ID] === B)!;
      assertEqual(row.values[out.header.indexOf("typical_unit")], "g", "final value");
    },
  },
  {
    name: "a rebuild from the same CSV and queue is byte-identical",
    fn: () => {
      const doc = docOf(A);
      const make = () => [q(A, { notes_sv: { old: doc.notesSv ?? "", new: "Samma." } }, { id: "fixed", createdAtMs: 1 })];
      assertEqual(planIngredientChanges(REAL, make(), NOW).text, planIngredientChanges(REAL, make(), NOW).text, "same");
    },
  },
  {
    name: "self-check: a changed line no change named is refused",
    fn: () => {
      const lines = REAL.split("\n");
      const victim = FILE.rows[5].lineIndex;
      lines[victim] = lines[victim].replace(/,[^,]*$/, ",tampered");
      throwsSelfCheck(() => selfCheck(REAL, lines.join("\n"), [{ id: A, column: "notes_sv", newValue: "x" }]), "untouched-line");
    },
  },
  {
    name: "self-check: swapped rows, a dropped row and a value that does not read back are refused",
    fn: () => {
      const lines = REAL.split("\n");
      const [i, j] = [FILE.rows[0].lineIndex, FILE.rows[1].lineIndex];
      const swapped = [...lines];
      [swapped[i], swapped[j]] = [swapped[j], swapped[i]];
      throwsSelfCheck(() => selfCheck(REAL, swapped.join("\n"), []), "id-order");
      const dropped = [...lines];
      dropped.splice(j, 1);
      throwsSelfCheck(() => selfCheck(REAL, dropped.join("\n"), []), "row-count");
      throwsSelfCheck(() => selfCheck(REAL, REAL, [{ id: A, column: "notes_sv", newValue: "never written" }]), "value");
    },
  },
];

runTests("ingredient-change-plan (admin-vy C2)", cases);
