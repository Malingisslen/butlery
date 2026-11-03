/**
 * The unattended `--ci` mode of the ingredient sync: each stop trips on its
 * own, `--force` is refused, and each lift flag lifts only its own stop.
 *
 * Run with: npx ts-node src/__tests__/sync-ingredients-guards.test.ts
 */

import type * as admin from "firebase-admin";
import { IngredientRow, SyncReport, SyncReportEntry } from "../admin/sync-ingredients-core";
import {
  CI_MAX_CHANGED_ROWS,
  CI_MAX_PROPERTIES_ROWS,
  evaluateCiGuards,
  formatStepSummary,
  GuardCode,
  GuardDecision,
  parseSyncArgs,
  SyncOptions,
} from "../admin/sync-ingredients-guards";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const LIVE = 100;

function csvRows(n = LIVE): IngredientRow[] {
  return Array.from({ length: n }, (_, i) => ({ id: `i${i}`, status: "validated" } as IngredientRow));
}

function firestore(n = LIVE, deleted = 0): Map<string, admin.firestore.DocumentData> {
  const m = new Map<string, admin.firestore.DocumentData>();
  for (let i = 0; i < n; i++) m.set(`i${i}`, { status: "validated" });
  for (let i = 0; i < deleted; i++) m.set(`d${i}`, { status: "deleted" });
  return m;
}

function entry(id: string, beforeProps: string[], afterProps: string[], afterStatus = "validated"): SyncReportEntry {
  return {
    id,
    before: { properties: beforeProps, aliasesSv: [], status: "validated" },
    after: { properties: afterProps, aliasesSv: [], status: afterStatus },
  };
}

function report(overrides: Partial<SyncReport> = {}): SyncReport {
  const updated = overrides.updated ?? [];
  const removed = overrides.removed ?? [];
  const added = overrides.added ?? [];
  return {
    generatedAt: "2026-11-03T00:00:00.000Z",
    dryRun: true,
    counts: { added: added.length, updated: updated.length, removed: removed.length, unchanged: 0 },
    added,
    updated,
    removed,
    allergenPropertyRemovals: [],
    resurrections: [],
    healed: [],
    ...overrides,
  };
}

const noLift = { allowLargeReason: null, allowAllergenRemovalReason: null };

function codes(d: GuardDecision, onlyBlocking = false): GuardCode[] {
  return d.violations.filter((v) => !onlyBlocking || !v.lifted).map((v) => v.code);
}

function options(args: string[]): SyncOptions {
  const r = parseSyncArgs(args);
  if (!r.ok) throw new Error(`refused: ${r.error}`);
  return r.options;
}

function refused(args: string[]): string {
  const r = parseSyncArgs(args);
  if (r.ok) throw new Error(`accepted: ${args.join(" ")}`);
  return r.error;
}

const textEdits = (n: number): SyncReportEntry[] =>
  Array.from({ length: n }, (_, i) => entry(`i${i}`, ["dairy"], ["dairy"]));
const propEdits = (n: number): SyncReportEntry[] =>
  Array.from({ length: n }, (_, i) => entry(`i${i}`, ["dairy"], ["dairy", "egg"]));

const cases: UnitCase[] = [
  {
    name: "a clean run passes, with soft-deleted docs lingering in Firestore",
    fn: () => {
      const d = evaluateCiGuards(report({ updated: textEdits(3) }), csvRows(), firestore(LIVE, 7), noLift);
      assertEqual(d.ok, true, "ok");
      assertEqual(d.violations.length, 0, "no violations");
    },
  },
  {
    name: `changed rows: ${CI_MAX_CHANGED_ROWS} passes, ${CI_MAX_CHANGED_ROWS + 1} stops`,
    fn: () => {
      assertEqual(evaluateCiGuards(report({ updated: textEdits(CI_MAX_CHANGED_ROWS) }), csvRows(), firestore(), noLift).ok, true, "at cap");
      const d = evaluateCiGuards(report({ updated: textEdits(CI_MAX_CHANGED_ROWS + 1) }), csvRows(), firestore(), noLift);
      assertEqual(codes(d).join(), "too-many-rows", "over cap");
      assertEqual(d.ok, false, "stops");
    },
  },
  {
    name: `properties rows: ${CI_MAX_PROPERTIES_ROWS} passes, ${CI_MAX_PROPERTIES_ROWS + 1} stops; reorder is no change`,
    fn: () => {
      assertEqual(evaluateCiGuards(report({ updated: propEdits(CI_MAX_PROPERTIES_ROWS) }), csvRows(), firestore(), noLift).ok, true, "at cap");
      const d = evaluateCiGuards(report({ updated: propEdits(CI_MAX_PROPERTIES_ROWS + 1) }), csvRows(), firestore(), noLift);
      assertEqual(codes(d).join(), "too-many-properties-rows", "over cap");
      const reordered = Array.from({ length: 20 }, (_, i) => entry(`i${i}`, ["a", "b"], ["b", "a"]));
      assertEqual(evaluateCiGuards(report({ updated: reordered }), csvRows(), firestore(), noLift).counts.propertiesRows, 0, "reorder");
    },
  },
  {
    name: "any soft-delete stops: removal by omission and a status flip to deleted",
    fn: () => {
      const omitted = evaluateCiGuards(
        report({ removed: [{ id: "i99", learnedAliasesSv: [] }] }), csvRows(99), firestore(), noLift
      );
      assertEqual(codes(omitted).includes("soft-delete"), true, "omission");
      const flipped = evaluateCiGuards(
        report({ updated: [entry("i1", [], [], "deleted")] }),
        csvRows().map((r, i) => (i === 1 ? { ...r, status: "deleted" } : r)),
        firestore(),
        noLift
      );
      assertEqual(codes(flipped).includes("soft-delete"), true, "status flip");
    },
  },
  {
    name: "a changed live row count stops on its own",
    fn: () => {
      const d = evaluateCiGuards(report({ added: ["new"] }), csvRows(LIVE + 1), firestore(), noLift);
      assertEqual(codes(d).join(), "row-count-changed", "added row");
      assertEqual(d.ok, false, "stops");
    },
  },
  {
    name: "an allergen property removal stops on its own",
    fn: () => {
      const d = evaluateCiGuards(
        report({
          updated: [entry("i1", ["contains-gluten"], [])],
          allergenPropertyRemovals: [{ id: "i1", removedProperties: ["contains-gluten"] }],
        }),
        csvRows(), firestore(), noLift
      );
      assertEqual(codes(d).join(), "allergen-property-removed", "allergen");
      assertEqual(d.ok, false, "stops");
    },
  },
  {
    name: "--allow-large lifts only the two caps",
    fn: () => {
      const lift = { allowLargeReason: "bulk price refresh", allowAllergenRemovalReason: null };
      const big = report({ updated: propEdits(60) });
      assertEqual(evaluateCiGuards(big, csvRows(), firestore(), lift).ok, true, "caps lifted");
      const bigWithDelete = report({ updated: propEdits(60), removed: [{ id: "i99", learnedAliasesSv: [] }] });
      const d = evaluateCiGuards(bigWithDelete, csvRows(99), firestore(), lift);
      assertEqual(codes(d, true).includes("soft-delete"), true, "soft-delete still stops");
      assertEqual(codes(d, true).includes("too-many-rows"), false, "cap lifted beside it");
      const allergen = report({ allergenPropertyRemovals: [{ id: "i1", removedProperties: ["soy"] }], updated: [entry("i1", ["soy"], [])] });
      assertEqual(evaluateCiGuards(allergen, csvRows(), firestore(), lift).ok, false, "allergen still stops");
      assertEqual(evaluateCiGuards(report({ added: ["n"] }), csvRows(LIVE + 1), firestore(), lift).ok, false, "row count still stops");
    },
  },
  {
    name: "--allow-allergen-removal lifts only the allergen stop",
    fn: () => {
      const lift = { allowLargeReason: null, allowAllergenRemovalReason: "gluten was wrong" };
      const allergen = report({ allergenPropertyRemovals: [{ id: "i1", removedProperties: ["soy"] }], updated: [entry("i1", ["soy"], [])] });
      assertEqual(evaluateCiGuards(allergen, csvRows(), firestore(), lift).ok, true, "allergen lifted");
      assertEqual(evaluateCiGuards(report({ updated: textEdits(51) }), csvRows(), firestore(), lift).ok, false, "cap not lifted");
      assertEqual(evaluateCiGuards(report({ removed: [{ id: "i99", learnedAliasesSv: [] }] }), csvRows(99), firestore(), lift).ok, false, "delete not lifted");
    },
  },
  {
    name: "args: --ci with --force is refused; manual flags parse as before",
    fn: () => {
      refused(["--ci", "--force"]);
      refused(["--ci", "--dry-run", "--force", "--project", "p"]);
      const manual = options(["--project", "p", "--force", "-v"]);
      assertEqual(manual.force && manual.verbose && !manual.ci && !manual.dryRun, true, "manual");
      const ci = options(["--ci", "--dry-run", "--project", "p"]);
      assertEqual(ci.ci && ci.dryRun && !ci.force, true, "ci");
    },
  },
  {
    name: "args: lift flags need a reason and --ci",
    fn: () => {
      assertEqual(options(["--ci", "--allow-large", "bulk refresh"]).allowLargeReason, "bulk refresh", "reason");
      assertEqual(options(["--ci", "--allow-allergen-removal", "fix"]).allowAllergenRemovalReason, "fix", "reason");
      refused(["--ci", "--allow-large"]);
      refused(["--ci", "--allow-large", "--dry-run"]);
      refused(["--ci", "--allow-large", "  "]);
      refused(["--allow-large", "reason"]);
      refused(["--allow-allergen-removal", "reason"]);
    },
  },
  {
    name: "step summary carries the counts, every violation and the reasons as inline code",
    fn: () => {
      const d = evaluateCiGuards(report({ updated: textEdits(51) }), csvRows(), firestore(), {
        allowLargeReason: "see [link](x) @someone", allowAllergenRemovalReason: null,
      });
      const s = formatStepSummary(d, { dryRun: true, allowLargeReason: "see [link](x) @someone", allowAllergenRemovalReason: null });
      for (const needle of ["| Updated | 51 |", "lifted: 51 rows change", "`see [link](x) @someone`", "Guards: pass"]) {
        assertEqual(s.includes(needle), true, needle);
      }
    },
  },
];

runTests("sync-ingredients-guards (admin-vy C1)", cases);
