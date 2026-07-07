/**
 * Pure logic for the ingredient sync (BUT-1467).
 *
 * Extracted from sync-ingredients.ts so the safety contracts are unit-testable:
 * the script itself calls admin.initializeApp() + main() at import time and
 * cannot be imported by tests.
 *
 * Safety contracts encoded here (see sync-ingredients-diff.test.ts):
 * 1. Sync payloads NEVER contain `learnedAliasesSv` — the field is owned by
 *    the alias-learning loop (analyze-corrections.ts), and update() therefore
 *    cannot wipe it. `mergePreservedFields` carries it forward on the one
 *    path that replaces whole documents (set on a doc that still exists).
 * 2. Resurrecting a soft-deleted row (removed from the Sheet, re-added before
 *    the 30-day reap) must clear `deletedAt`/`expireAt`, or the revived doc
 *    keeps its scheduled TTL death and silently disappears later.
 * 3. Every sync produces a diff report that highlights allergen-property
 *    removals and learned aliases at risk — a Sheet cell edit must never
 *    reach production allergen verdicts unreviewed.
 */

import * as admin from "firebase-admin";
import { ALLERGEN_RELEVANT_PROPERTIES } from "../shared/allergen-properties";
import { stripDiacritics } from "../shared/swedish-normalize";

// Allergen block of the property vocabulary. Every entry MUST also be in
// ALLERGEN_RELEVANT_PROPERTIES (pinned by sync-ingredients-diff.test.ts) so
// a new allergen property can never silently bypass the review gates.
export const ALLERGEN_BLOCK_PROPERTIES = [
  "contains-gluten", "contains-lactose", "peanut", "sesame", "soy", "tree-nut",
  "crustacean", "mollusc", "celery", "mustard", "lupin", "sulfites",
] as const;

// Valid properties from Butlery_Ingredients_PROPERTIES.csv
export const VALID_PROPERTIES = new Set<string>([
  // Diet base
  "animal-product", "dairy", "egg", "meat", "plant-based", "seafood", "vegan-friendly",
  // Meat detail
  "beef", "fish", "game", "lamb", "pork", "poultry", "shellfish",
  // Allergens
  ...ALLERGEN_BLOCK_PROPERTIES,
  // Special diet
  "contains-alcohol", "high-mercury", "nightshade",
  // Practical
  "needs-cooking", "processed", "is-spicy", "doesnt-freeze-well",
]);

// Valid group prefixes from Butlery_Ingredients_GROUPS.csv
export const VALID_GROUP_PREFIXES = [
  "protein", "vegetable", "fruit", "grain", "fat", "other", "spice",
];

export interface IngredientRow {
  id: string;
  swedish: string;
  english: string;
  group: string;
  properties: string;
  aliases_sv: string;
  aliases_en: string;
  search_terms: string;
  status: string;
  season_availability: string;
  price_category: string;
  carbon_footprint_category: string;
  notes_sv: string;
  notes_en: string;
  typical_storage: string;
  typical_unit: string;
  avg_price_sek: string;
  [key: string]: string;
}

export interface IngredientDoc {
  id: string;
  swedish: string;
  english: string;
  group: string;
  properties: string[];
  aliasesSv: string[];
  aliasesEn: string[];
  searchTerms: string[];
  normalizedNames: string[];
  status: string;
  updatedAt: admin.firestore.FieldValue;
  seasonAvailability?: string[];
  priceCategory?: string;
  carbonFootprintCategory?: string;
  notesSv?: string;
  notesEn?: string;
  typicalStorage?: string;
  typicalUnit?: string;
  avgPriceSek?: number;
  // Only ever set by mergePreservedFields — csvToFirestore must not produce it.
  learnedAliasesSv?: string[];
}

export interface Diff {
  toAdd: string[];
  toUpdate: string[];
  toRemove: string[];
  newData: Map<string, IngredientDoc>;
  unchanged: number;
}

export interface SyncReportEntry {
  id: string;
  before: { properties: string[]; aliasesSv: string[]; status: string };
  after: { properties: string[]; aliasesSv: string[]; status: string };
}

export interface SyncReport {
  generatedAt: string;
  dryRun: boolean;
  counts: { added: number; updated: number; removed: number; unchanged: number };
  added: string[];
  updated: SyncReportEntry[];
  removed: Array<{ id: string; learnedAliasesSv: string[] }>;
  /** Any update that DROPS an allergen-relevant property — review these first. */
  allergenPropertyRemovals: Array<{ id: string; removedProperties: string[] }>;
  /** toUpdate ids reviving a soft-deleted doc (deletedAt/expireAt get cleared). */
  resurrections: string[];
  /** toUpdate ids whose broken TTL state gets repaired (see needsLifecycleHealing). */
  healed: string[];
}

/**
 * Learned aliases about to leave the register: removal-by-omission (30-day
 * TTL then gone) and Sheet-side status flips to deleted. Derived from the
 * report instead of stored in it, so the two views can't contradict.
 */
export function deriveLearnedAliasesAtRisk(
  report: SyncReport,
  currentData: Map<string, admin.firestore.DocumentData>
): Array<{ id: string; aliases: string[] }> {
  const atRisk: Array<{ id: string; aliases: string[] }> = [];
  for (const r of report.removed) {
    if (r.learnedAliasesSv.length > 0) {
      atRisk.push({ id: r.id, aliases: r.learnedAliasesSv });
    }
  }
  for (const u of report.updated) {
    if (u.after.status === "deleted" && u.before.status !== "deleted") {
      const aliases = asStringArray(currentData.get(u.id)?.learnedAliasesSv);
      if (aliases.length > 0) {
        atRisk.push({ id: u.id, aliases });
      }
    }
  }
  return atRisk;
}

/**
 * CRIT-6: Converts CSV row to Firestore document with validation.
 * Throws if required fields are missing or empty, preventing corrupt documents.
 * Contract: the produced doc NEVER contains `learnedAliasesSv` — see header.
 */
export function csvToFirestore(row: IngredientRow): IngredientDoc {
  const parseList = (str: string, separator: string | RegExp): string[] =>
    str
      .split(separator)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

  const id = row.id?.trim();
  const swedish = row.swedish?.trim();
  const english = row.english?.trim();
  const group = row.group?.trim();

  if (!id) {
    throw new Error(`CRIT-6: Row missing required 'id' field (swedish: ${swedish || "unknown"})`);
  }
  if (!swedish) {
    throw new Error(`CRIT-6: Row ${id} missing required 'swedish' field`);
  }

  const seasonAvailability = parseList(row.season_availability || "", ";");
  const priceCategory = row.price_category?.trim() || undefined;
  const carbonFootprintCategory = row.carbon_footprint_category?.trim() || undefined;
  const notesSv = row.notes_sv?.trim() || undefined;
  const notesEn = row.notes_en?.trim() || undefined;
  const typicalStorage = row.typical_storage?.trim() || undefined;
  const typicalUnit = row.typical_unit?.trim() || undefined;
  // Swedish-locale Sheets export decimal commas ("12,50") — parseFloat would
  // silently truncate to 12, so normalize the separator first.
  const avgPriceSekStr = row.avg_price_sek?.trim().replace(",", ".");
  const avgPriceSek = avgPriceSekStr ? parseFloat(avgPriceSekStr) : undefined;

  // BUT-1495: the Sheet convention is ';' but humans type ','; a comma-typed
  // list must not survive as one blob alias (it poisons normalizedNames, the
  // diacritics-stripped allergen-lookup surface).
  // BUT-1571: a comma immediately followed by a digit is a Swedish decimal
  // comma ("lättmjölk 0,5%"), not a separator — splitting there fragments the
  // alias into junk that degrades its verdict to hidden-UNKNOWN.
  const aliasesSv = parseList(row.aliases_sv || "", /;|,(?!\d)/);

  const doc: IngredientDoc = {
    id,
    swedish,
    english: english || swedish, // Fallback to Swedish name if English missing
    group: group || "other", // Fallback to "other" category
    properties: parseList(row.properties || "", ","),
    aliasesSv,
    aliasesEn: parseList(row.aliases_en || "", ";"),
    searchTerms: parseList(row.search_terms || "", ";"),
    // Diacritics-stripped lookup forms. The alias hold-for-review gate
    // (analyze-corrections.ts, BUT-1468) queries this to catch allergen words
    // submitted WITHOUT umlauts ("jordnotter" for "jordnötter") — the
    // client's _normalize matching is diacritics-stripped, so the server
    // gate must match on the same form or it can be trivially bypassed.
    normalizedNames: dedupe(
      [swedish, ...aliasesSv].map((n) => stripDiacritics(n.toLowerCase().trim()))
    ),
    status: row.status?.trim() || "validated",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Only add new fields if they have values (sparse storage)
  if (seasonAvailability.length > 0) doc.seasonAvailability = seasonAvailability;
  if (priceCategory) doc.priceCategory = priceCategory;
  if (carbonFootprintCategory) doc.carbonFootprintCategory = carbonFootprintCategory;
  if (notesSv) doc.notesSv = notesSv;
  if (notesEn) doc.notesEn = notesEn;
  if (typicalStorage) doc.typicalStorage = typicalStorage;
  if (typicalUnit) doc.typicalUnit = typicalUnit;
  if (avgPriceSek !== undefined && !isNaN(avgPriceSek)) doc.avgPriceSek = avgPriceSek;

  return doc;
}

export function listEquals(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false;
  const setA = new Set(a);
  const setB = new Set(b);
  return [...setA].every((x) => setB.has(x)) && [...setB].every((x) => setA.has(x));
}

export function hasChanges(
  current: admin.firestore.DocumentData,
  newData: IngredientDoc
): boolean {
  const stringFieldsToCompare = [
    "swedish", "english", "group", "status",
    "priceCategory", "carbonFootprintCategory", "notesSv", "notesEn",
    "typicalStorage", "typicalUnit",
  ];
  for (const field of stringFieldsToCompare) {
    if (String(current[field] || "") !== String(newData[field as keyof IngredientDoc] || "")) {
      return true;
    }
  }

  const currentAvgPrice = current.avgPriceSek as number | undefined;
  if (currentAvgPrice !== newData.avgPriceSek) {
    return true;
  }

  const currentProps = (current.properties as string[]) || [];
  if (!listEquals(currentProps, newData.properties)) {
    return true;
  }

  const currentAliases = (current.aliasesSv as string[]) || [];
  if (!listEquals(currentAliases, newData.aliasesSv)) {
    return true;
  }

  // aliasesEn and searchTerms were historically not compared — Sheet edits
  // touching only those columns never synced (xhigh review 2026-07-03).
  const currentAliasesEn = (current.aliasesEn as string[]) || [];
  if (!listEquals(currentAliasesEn, newData.aliasesEn)) {
    return true;
  }

  const currentSearchTerms = (current.searchTerms as string[]) || [];
  if (!listEquals(currentSearchTerms, newData.searchTerms)) {
    return true;
  }

  // normalizedNames backfill (BUT-1468 gate): first sync after this ships
  // updates every doc once to stamp the field; steady state compares equal.
  const currentNormalized = (current.normalizedNames as string[]) || [];
  if (!listEquals(currentNormalized, newData.normalizedNames)) {
    return true;
  }

  const currentSeasons = (current.seasonAvailability as string[]) || [];
  if (!listEquals(currentSeasons, newData.seasonAvailability || [])) {
    return true;
  }

  return false;
}

/**
 * True when a stored doc is in a broken lifecycle state that content
 * comparison can't see and the sync must repair:
 * - "zombie-alive": status is alive but deletedAt/expireAt linger from a
 *   pre-BUT-1467 resurrection → TTL would reap a live doc.
 * - "unreapable-deleted": status is deleted but expireAt was never stamped
 *   (soft-deleted via the Sheet's status column) → doc lives forever and its
 *   learned aliases are stranded outside every report.
 */
export function needsLifecycleHealing(
  current: admin.firestore.DocumentData,
  incoming: IngredientDoc
): boolean {
  if (incoming.status !== "deleted") {
    return current.deletedAt != null || current.expireAt != null;
  }
  return current.expireAt == null;
}

/** Days a soft-deleted doc survives before the TTL reaper takes it. */
export const SOFT_DELETE_TTL_DAYS = 30;

/**
 * Builds the update() payload for a changed or healing-needed doc. On top of
 * the CSV-derived fields it adds the lifecycle repairs update() would
 * otherwise miss:
 * - transition to alive (or lingering TTL fields): clear deletedAt/expireAt
 * - transition to deleted via the Sheet's status column: stamp
 *   deletedAt/expireAt exactly like removal-by-omission does
 */
export function buildUpdatePayload(
  current: admin.firestore.DocumentData,
  incoming: IngredientDoc,
  now: Date = new Date()
): Record<string, unknown> {
  const payload: Record<string, unknown> = { ...incoming };

  if (incoming.status !== "deleted") {
    if (current.deletedAt != null || current.expireAt != null) {
      payload.deletedAt = admin.firestore.FieldValue.delete();
      payload.expireAt = admin.firestore.FieldValue.delete();
    }
  } else if (current.expireAt == null) {
    payload.deletedAt = admin.firestore.FieldValue.serverTimestamp();
    payload.expireAt = admin.firestore.Timestamp.fromDate(
      new Date(now.getTime() + SOFT_DELETE_TTL_DAYS * 24 * 60 * 60 * 1000)
    );
  }

  // Optional sparse fields: csvToFirestore omits blanked cells entirely, so a
  // cleared Sheet cell must become an explicit delete or the stale value
  // survives and the row re-churns as "updated" on every future sync.
  const clearable: Array<keyof IngredientDoc> = [
    "priceCategory", "carbonFootprintCategory", "notesSv", "notesEn",
    "typicalStorage", "typicalUnit", "avgPriceSek", "seasonAvailability",
  ];
  for (const field of clearable) {
    if (!(field in payload) && current[field] !== undefined) {
      payload[field] = admin.firestore.FieldValue.delete();
    }
  }

  return payload;
}

export function calculateDiff(
  csvData: IngredientRow[],
  currentData: Map<string, admin.firestore.DocumentData>
): Diff {
  const toAdd: string[] = [];
  const toUpdate: string[] = [];
  const toRemove: string[] = [];
  const newData = new Map<string, IngredientDoc>();
  let unchanged = 0;

  for (const row of csvData) {
    const id = row.id;
    if (!id) continue;

    const firestoreData = csvToFirestore(row);
    newData.set(id, firestoreData);

    if (!currentData.has(id)) {
      toAdd.push(id);
    } else {
      const current = currentData.get(id)!;
      // Lifecycle healing: content-identical docs can still carry broken
      // TTL state (zombie-alive / unreapable-deleted) that must be repaired.
      if (hasChanges(current, firestoreData) || needsLifecycleHealing(current, firestoreData)) {
        toUpdate.push(id);
      } else {
        unchanged++;
      }
    }
  }

  for (const [id, data] of currentData) {
    if (!newData.has(id) && data.status !== "deleted") {
      toRemove.push(id);
    }
  }

  return { toAdd, toUpdate, toRemove, newData, unchanged };
}

/** True when this update revives a soft-deleted doc. */
export function isResurrection(
  current: admin.firestore.DocumentData,
  incoming: IngredientDoc
): boolean {
  return current.status === "deleted" && incoming.status !== "deleted";
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? (value as string[]) : [];
}

function dedupe(values: string[]): string[] {
  return [...new Set(values.filter((v) => v.length > 0))];
}

export function buildSyncReport(
  diff: Diff,
  currentData: Map<string, admin.firestore.DocumentData>,
  options: { dryRun: boolean; now?: Date }
): SyncReport {
  const updated: SyncReportEntry[] = [];
  const allergenPropertyRemovals: SyncReport["allergenPropertyRemovals"] = [];
  const resurrections: string[] = [];
  const healed: string[] = [];

  for (const id of diff.toUpdate) {
    const before = currentData.get(id);
    const after = diff.newData.get(id);
    if (!before || !after) continue;

    const beforeProps = asStringArray(before.properties);
    updated.push({
      id,
      before: {
        properties: beforeProps,
        aliasesSv: asStringArray(before.aliasesSv),
        status: String(before.status ?? ""),
      },
      after: {
        properties: after.properties,
        aliasesSv: after.aliasesSv,
        status: after.status,
      },
    });

    const removedAllergenProps = beforeProps.filter(
      (p) => ALLERGEN_RELEVANT_PROPERTIES.has(p) && !after.properties.includes(p)
    );
    if (removedAllergenProps.length > 0) {
      allergenPropertyRemovals.push({ id, removedProperties: removedAllergenProps });
    }

    if (isResurrection(before, after)) {
      resurrections.push(id);
    } else if (needsLifecycleHealing(before, after)) {
      healed.push(id);
    }
  }

  const removed: SyncReport["removed"] = diff.toRemove.map((id) => ({
    id,
    learnedAliasesSv: asStringArray(currentData.get(id)?.learnedAliasesSv),
  }));

  return {
    generatedAt: (options.now ?? new Date()).toISOString(),
    dryRun: options.dryRun,
    counts: {
      added: diff.toAdd.length,
      updated: diff.toUpdate.length,
      removed: diff.toRemove.length,
      unchanged: diff.unchanged,
    },
    added: [...diff.toAdd],
    updated,
    removed,
    allergenPropertyRemovals,
    resurrections,
    healed,
  };
}
