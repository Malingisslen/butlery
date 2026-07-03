/**
 * BUT-1467: safety contracts for the ingredient master-data sync.
 *
 * What this proves:
 * 1. Sync payloads never contain `learnedAliasesSv` — the alias-learning
 *    loop owns that field, and a Sheet sync must not be able to wipe it.
 * 2. A full-document `set` against an existing doc carries learned aliases
 *    forward (update() field-patching semantics; adds never target existing docs).
 * 3. Reviving a soft-deleted row is detected and clears deletedAt/expireAt —
 *    otherwise the revived doc is TTL-reaped while looking alive.
 * 4. The diff report flags allergen-property removals and learned aliases
 *    lost on removal — the human review surface for Sheet edits.
 *
 * Run with: npx ts-node src/__tests__/sync-ingredients-diff.test.ts
 */

import * as admin from "firebase-admin";
import {
  ALLERGEN_BLOCK_PROPERTIES,
  buildSyncReport,
  buildUpdatePayload,
  calculateDiff,
  csvToFirestore,
  deriveLearnedAliasesAtRisk,
  IngredientRow,
  needsLifecycleHealing,
  VALID_PROPERTIES,
} from "../admin/sync-ingredients-core";
import { ALLERGEN_RELEVANT_PROPERTIES } from "../shared/allergen-properties";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

function row(overrides: Partial<IngredientRow>): IngredientRow {
  return {
    id: "test-ingredient",
    swedish: "testingrediens",
    english: "test ingredient",
    group: "other",
    properties: "",
    aliases_sv: "",
    aliases_en: "",
    search_terms: "",
    status: "validated",
    season_availability: "",
    price_category: "",
    carbon_footprint_category: "",
    notes_sv: "",
    notes_en: "",
    typical_storage: "",
    typical_unit: "",
    avg_price_sek: "",
    ...overrides,
  } as IngredientRow;
}

const cases: UnitCase[] = [
  {
    name: "drift pin: every allergen-block property is allergen-relevant (review gates cover it)",
    fn: async () => {
      for (const prop of ALLERGEN_BLOCK_PROPERTIES) {
        assertEqual(
          ALLERGEN_RELEVANT_PROPERTIES.has(prop),
          true,
          `allergen-block property "${prop}" missing from ALLERGEN_RELEVANT_PROPERTIES`
        );
      }
    },
  },
  {
    name: "csvToFirestore never produces learnedAliasesSv (update path cannot wipe it)",
    fn: async () => {
      const doc = csvToFirestore(
        row({ id: "beer", swedish: "öl", properties: "contains-gluten", aliases_sv: "pilsner;lager" })
      );
      assertEqual(
        Object.prototype.hasOwnProperty.call(doc, "learnedAliasesSv"),
        false,
        "payload must not contain learnedAliasesSv"
      );
    },
  },
  {
    name: "reverse drift pin: every allergen-relevant property exists in the vocabulary",
    fn: async () => {
      // A rename in VALID_PROPERTIES ("contains-alcohol" → "alcohol") must
      // fail here, or the review gate silently stops matching that property.
      for (const prop of ALLERGEN_RELEVANT_PROPERTIES) {
        assertEqual(
          VALID_PROPERTIES.has(prop),
          true,
          `allergen-relevant property "${prop}" is not in VALID_PROPERTIES (dead gate entry)`
        );
      }
    },
  },
  {
    name: "resurrection update clears deletedAt/expireAt with the delete() sentinel",
    fn: async () => {
      const incoming = csvToFirestore(row({ id: "beer", swedish: "öl" }));
      const payload = buildUpdatePayload(
        { status: "deleted", deletedAt: "x", expireAt: "y" },
        incoming
      );
      // Pin the DELETE sentinel specifically — serverTimestamp() would also
      // pass an instanceof check but would stamp instead of clear.
      assertEqual(
        (payload.deletedAt as admin.firestore.FieldValue).isEqual(admin.firestore.FieldValue.delete()),
        true,
        "deletedAt cleared with delete() sentinel"
      );
      assertEqual(
        (payload.expireAt as admin.firestore.FieldValue).isEqual(admin.firestore.FieldValue.delete()),
        true,
        "expireAt cleared with delete() sentinel"
      );
      // A normal live-doc update must not touch the TTL fields.
      const normal = buildUpdatePayload({ status: "validated" }, incoming);
      assertEqual("deletedAt" in normal, false, "no TTL clear on plain update");
    },
  },
  {
    name: "zombie-alive doc (stale expireAt, unchanged content) is healed, not skipped",
    fn: async () => {
      const incoming = csvToFirestore(row({ id: "beer", swedish: "öl" }));
      // Pre-BUT-1467 resurrection left expireAt behind on an alive doc.
      const zombie = { status: "validated", swedish: "öl", english: incoming.english, group: "other", properties: [], aliasesSv: [], aliasesEn: [], searchTerms: [], expireAt: "stale" };
      assertEqual(needsLifecycleHealing(zombie, incoming), true, "zombie detected");
      const diff = calculateDiff([row({ id: "beer", swedish: "öl" })], new Map([["beer", zombie]]));
      assertEqual(JSON.stringify(diff.toUpdate), JSON.stringify(["beer"]), "content-identical zombie still updates");
      const report = buildSyncReport(diff, new Map([["beer", zombie]]), { dryRun: true });
      assertEqual(JSON.stringify(report.healed), JSON.stringify(["beer"]), "healing reported");
    },
  },
  {
    name: "Sheet-side status flip to deleted gets TTL-stamped like removal-by-omission",
    fn: async () => {
      const incoming = csvToFirestore(row({ id: "beer", swedish: "öl", status: "deleted" }));
      const current = { status: "validated", learnedAliasesSv: ["folköl"] };
      const payload = buildUpdatePayload(current, incoming, new Date("2026-07-03T00:00:00Z"));
      assertEqual(payload.expireAt instanceof admin.firestore.Timestamp, true, "expireAt stamped");
      assertEqual(
        (payload.expireAt as admin.firestore.Timestamp).toDate().toISOString(),
        "2026-08-02T00:00:00.000Z",
        "30-day TTL");
      // And its learned aliases show up in the at-risk derivation.
      const diff = calculateDiff([row({ id: "beer", swedish: "öl", status: "deleted" })], new Map([["beer", current]]));
      const report = buildSyncReport(diff, new Map([["beer", current]]), { dryRun: true });
      const atRisk = deriveLearnedAliasesAtRisk(report, new Map([["beer", current]]));
      assertEqual(atRisk.length, 1, "sheet-side delete flagged");
      assertEqual(JSON.stringify(atRisk[0].aliases), JSON.stringify(["folköl"]), "aliases listed");
    },
  },
  {
    name: "clearing a sparse optional cell produces an explicit field delete (no eternal churn)",
    fn: async () => {
      const incoming = csvToFirestore(row({ id: "beer", swedish: "öl" })); // no notes, no price
      const current = { status: "validated", notesSv: "gammal anteckning", avgPriceSek: 12.5 };
      const payload = buildUpdatePayload(current, incoming);
      assertEqual(
        (payload.notesSv as admin.firestore.FieldValue).isEqual(admin.firestore.FieldValue.delete()),
        true,
        "blanked notesSv explicitly deleted"
      );
      assertEqual(
        (payload.avgPriceSek as admin.firestore.FieldValue).isEqual(admin.firestore.FieldValue.delete()),
        true,
        "blanked avgPriceSek explicitly deleted"
      );
    },
  },
  {
    name: "Sheet edits to aliasesEn or searchTerms are detected as changes",
    fn: async () => {
      const current = { status: "validated", swedish: "öl", english: "beer", group: "other", properties: [], aliasesSv: [], aliasesEn: ["ale"], searchTerms: [] };
      const diff = calculateDiff(
        [row({ id: "beer", swedish: "öl", english: "beer", aliases_en: "ale;stout" })],
        new Map([["beer", current]])
      );
      assertEqual(JSON.stringify(diff.toUpdate), JSON.stringify(["beer"]), "aliasesEn edit syncs");
    },
  },
  {
    name: "Swedish decimal comma in avg_price_sek parses correctly",
    fn: async () => {
      const doc = csvToFirestore(row({ id: "beer", swedish: "öl", avg_price_sek: "12,50" }));
      assertEqual(doc.avgPriceSek, 12.5, "12,50 → 12.5 (not truncated to 12)");
    },
  },
  {
    name: "soft-deleted row re-added in CSV lands in toUpdate (not toAdd) and is reported as resurrection",
    fn: async () => {
      const current = new Map<string, admin.firestore.DocumentData>([
        ["beer", { status: "deleted", properties: ["contains-gluten"], aliasesSv: [], swedish: "öl", english: "beer", group: "other" }],
      ]);
      const diff = calculateDiff(
        [row({ id: "beer", swedish: "öl", properties: "contains-gluten" })],
        current
      );
      assertEqual(diff.toAdd.length, 0, "not treated as add");
      assertEqual(JSON.stringify(diff.toUpdate), JSON.stringify(["beer"]), "revived via update");
      const report = buildSyncReport(diff, current, { dryRun: true });
      assertEqual(JSON.stringify(report.resurrections), JSON.stringify(["beer"]), "reported");
    },
  },
  {
    name: "report flags removal of an allergen-relevant property",
    fn: async () => {
      const current = new Map<string, admin.firestore.DocumentData>([
        ["beer", { status: "validated", properties: ["contains-gluten", "processed"], aliasesSv: [], swedish: "öl", english: "beer", group: "other" }],
      ]);
      const diff = calculateDiff(
        [row({ id: "beer", swedish: "öl", properties: "processed" })],
        current
      );
      const report = buildSyncReport(diff, current, { dryRun: true });
      assertEqual(report.allergenPropertyRemovals.length, 1, "one flagged row");
      assertEqual(report.allergenPropertyRemovals[0].id, "beer", "right row");
      assertEqual(
        JSON.stringify(report.allergenPropertyRemovals[0].removedProperties),
        JSON.stringify(["contains-gluten"]),
        "the allergen property, not the practical one"
      );
    },
  },
  {
    name: "report does NOT flag removal of a non-allergen property",
    fn: async () => {
      const current = new Map<string, admin.firestore.DocumentData>([
        ["carrot", { status: "validated", properties: ["plant-based", "needs-cooking"], aliasesSv: [], swedish: "morot", english: "carrot", group: "vegetable" }],
      ]);
      const diff = calculateDiff(
        [row({ id: "carrot", swedish: "morot", group: "vegetable", properties: "plant-based" })],
        current
      );
      const report = buildSyncReport(diff, current, { dryRun: true });
      assertEqual(report.allergenPropertyRemovals.length, 0, "no allergen flag");
      assertEqual(report.counts.updated, 1, "still an update");
    },
  },
  {
    name: "report lists learned aliases at risk when a row is removed from the Sheet",
    fn: async () => {
      const current = new Map<string, admin.firestore.DocumentData>([
        ["beer", { status: "validated", properties: [], aliasesSv: [], learnedAliasesSv: ["folköl"], swedish: "öl", english: "beer", group: "other" }],
        ["carrot", { status: "validated", properties: [], aliasesSv: [], swedish: "morot", english: "carrot", group: "vegetable" }],
      ]);
      const diff = calculateDiff([], current);
      const report = buildSyncReport(diff, current, { dryRun: true });
      assertEqual(report.counts.removed, 2, "both removed");
      const atRisk = deriveLearnedAliasesAtRisk(report, current);
      assertEqual(atRisk.length, 1, "only the alias-bearing one flagged");
      assertEqual(atRisk[0].id, "beer", "right row");
      assertEqual(
        JSON.stringify(atRisk[0].aliases),
        JSON.stringify(["folköl"]),
        "aliases listed"
      );
    },
  },
  {
    name: "unchanged rows produce no report noise",
    fn: async () => {
      const incoming = csvToFirestore(row({ id: "carrot", swedish: "morot", group: "vegetable", properties: "plant-based" }));
      const current = new Map<string, admin.firestore.DocumentData>([
        ["carrot", {
          status: "validated",
          properties: ["plant-based"],
          aliasesSv: [],
          swedish: "morot",
          english: incoming.english,
          group: "vegetable",
          // Learned aliases on the doc must not make the sync see a "change"
          learnedAliasesSv: ["morötter"],
        }],
      ]);
      const diff = calculateDiff(
        [row({ id: "carrot", swedish: "morot", group: "vegetable", properties: "plant-based" })],
        current
      );
      assertEqual(diff.unchanged, 1, "learnedAliasesSv is invisible to the differ");
      assertEqual(diff.toUpdate.length, 0, "no update");
    },
  },
];

runTests("sync-ingredients-diff (BUT-1467)", cases);
