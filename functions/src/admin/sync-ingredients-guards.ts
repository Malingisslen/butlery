/**
 * The unattended (`--ci`) mode of sync-ingredients.ts: argument parsing and
 * the stop decision, pure so they are testable without Firestore.
 *
 * In CI nobody answers the y/N prompt, so the dry-run numbers themselves must
 * refuse a sync a reviewed CSV diff would not explain: a mass edit, a wave of
 * property changes (each one marks recipes for retagging), a soft-delete, a
 * changed row count, or a dropped allergen property.
 */

import type * as admin from "firebase-admin";
import { IngredientRow, listEquals, SyncReport } from "./sync-ingredients-core";

export const CI_MAX_CHANGED_ROWS = 50;
export const CI_MAX_PROPERTIES_ROWS = 10;
export const GUARD_EXIT_CODE = 3;
export const USAGE_EXIT_CODE = 2;

export interface SyncOptions {
  dryRun: boolean;
  force: boolean;
  verbose: boolean;
  ci: boolean;
  allowLargeReason: string | null;
  allowAllergenRemovalReason: string | null;
}

export type ParsedSyncArgs =
  | { ok: true; options: SyncOptions }
  | { ok: false; error: string };

function reasonAfter(args: string[], flag: string): string | null | undefined {
  const at = args.indexOf(flag);
  if (at < 0) return null;
  const value = args[at + 1];
  if (value === undefined || value.startsWith("--") || !value.trim()) return undefined;
  return value.trim();
}

/** Unknown flags are ignored, as before: `--project` is read by admin-init. */
export function parseSyncArgs(args: string[]): ParsedSyncArgs {
  const ci = args.includes("--ci");
  const force = args.includes("--force");
  const allowLargeReason = reasonAfter(args, "--allow-large");
  const allowAllergenRemovalReason = reasonAfter(args, "--allow-allergen-removal");

  if (ci && force) {
    return { ok: false, error: "--force is refused with --ci: the CI guards must decide." };
  }
  for (const [flag, value] of [
    ["--allow-large", allowLargeReason],
    ["--allow-allergen-removal", allowAllergenRemovalReason],
  ] as const) {
    if (value === undefined) return { ok: false, error: `${flag} needs a written reason.` };
    if (value !== null && !ci) return { ok: false, error: `${flag} only applies with --ci.` };
  }

  return {
    ok: true,
    options: {
      dryRun: args.includes("--dry-run"),
      force,
      verbose: args.includes("--verbose") || args.includes("-v"),
      ci,
      allowLargeReason: allowLargeReason ?? null,
      allowAllergenRemovalReason: allowAllergenRemovalReason ?? null,
    },
  };
}

export type GuardCode =
  | "too-many-rows"
  | "too-many-properties-rows"
  | "soft-delete"
  | "row-count-changed"
  | "allergen-property-removed";

export interface GuardViolation {
  code: GuardCode;
  message: string;
  lifted: boolean;
}

export interface GuardCounts {
  added: number;
  updated: number;
  removed: number;
  changedRows: number;
  propertiesRows: number;
  softDeletes: number;
  csvLiveRows: number;
  firestoreLiveRows: number;
  allergenPropertyRemovals: number;
}

export interface GuardDecision {
  ok: boolean;
  counts: GuardCounts;
  violations: GuardViolation[];
}

const isDeleted = (status: unknown): boolean => status === "deleted";

/**
 * Row count compares non-deleted rows on both sides: Firestore keeps
 * soft-deleted docs for 30 days before the TTL reaper, so a raw count would
 * trip on every run in that window.
 */
export function evaluateCiGuards(
  report: SyncReport,
  csvRows: readonly IngredientRow[],
  currentData: ReadonlyMap<string, admin.firestore.DocumentData>,
  options: Pick<SyncOptions, "allowLargeReason" | "allowAllergenRemovalReason">
): GuardDecision {
  const { added, updated, removed } = report.counts;
  const statusFlipsToDeleted = report.updated.filter(
    (u) => isDeleted(u.after.status) && !isDeleted(u.before.status)
  ).length;
  const counts: GuardCounts = {
    added,
    updated,
    removed,
    changedRows: added + updated + removed,
    propertiesRows: report.updated.filter(
      (u) => !listEquals(u.before.properties, u.after.properties)
    ).length,
    softDeletes: removed + statusFlipsToDeleted,
    csvLiveRows: csvRows.filter((r) => !isDeleted(r.status?.trim() || "validated")).length,
    firestoreLiveRows: [...currentData.values()].filter((d) => !isDeleted(d.status)).length,
    allergenPropertyRemovals: report.allergenPropertyRemovals.length,
  };

  const large = options.allowLargeReason !== null;
  const violations: GuardViolation[] = [];
  if (counts.changedRows > CI_MAX_CHANGED_ROWS) {
    violations.push({
      code: "too-many-rows",
      message: `${counts.changedRows} rows change (limit ${CI_MAX_CHANGED_ROWS})`,
      lifted: large,
    });
  }
  if (counts.propertiesRows > CI_MAX_PROPERTIES_ROWS) {
    violations.push({
      code: "too-many-properties-rows",
      message: `${counts.propertiesRows} rows change properties (limit ${CI_MAX_PROPERTIES_ROWS})`,
      lifted: large,
    });
  }
  if (counts.softDeletes > 0) {
    violations.push({
      code: "soft-delete",
      message: `${counts.softDeletes} rows would be soft-deleted`,
      lifted: false,
    });
  }
  if (counts.csvLiveRows !== counts.firestoreLiveRows) {
    violations.push({
      code: "row-count-changed",
      message: `CSV has ${counts.csvLiveRows} live rows, Firestore ${counts.firestoreLiveRows}`,
      lifted: false,
    });
  }
  if (counts.allergenPropertyRemovals > 0) {
    violations.push({
      code: "allergen-property-removed",
      message: `${counts.allergenPropertyRemovals} rows drop an allergen property`,
      lifted: options.allowAllergenRemovalReason !== null,
    });
  }

  return { ok: violations.every((v) => v.lifted), counts, violations };
}

export function formatStepSummary(
  decision: GuardDecision,
  options: Pick<SyncOptions, "dryRun" | "allowLargeReason" | "allowAllergenRemovalReason">
): string {
  const c = decision.counts;
  const lines = [
    `## Ingredient sync ${options.dryRun ? "(dry run)" : ""}`.trim(),
    "",
    "| | |",
    "|---|---|",
    `| Added | ${c.added} |`,
    `| Updated | ${c.updated} |`,
    `| Soft-deleted | ${c.softDeletes} |`,
    `| Rows with changed properties | ${c.propertiesRows} |`,
    `| Allergen property removals | ${c.allergenPropertyRemovals} |`,
    `| Live rows CSV / Firestore | ${c.csvLiveRows} / ${c.firestoreLiveRows} |`,
    "",
    decision.ok ? "**Guards: pass**" : "**Guards: STOP**",
  ];
  for (const v of decision.violations) {
    lines.push(`- ${v.lifted ? "lifted" : "STOP"}: ${v.message}`);
  }
  // Inline code so a reason can form no link, mention or markup in the summary.
  const quote = (s: string): string => "`" + s.split("`").join("'") + "`";
  if (options.allowLargeReason) lines.push(`- --allow-large reason: ${quote(options.allowLargeReason)}`);
  if (options.allowAllergenRemovalReason) {
    lines.push(`- --allow-allergen-removal reason: ${quote(options.allowAllergenRemovalReason)}`);
  }
  return lines.join("\n") + "\n";
}
