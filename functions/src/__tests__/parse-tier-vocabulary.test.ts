/**
 * BUT-1486: Consistency tests for the canonical parse-tier vocabulary.
 *
 * Proves the server side is single-sourced: the correction callable's accepted
 * tier set comes from the shared module, the two index-aligned tier lists agree
 * with the derived mapping, and the pinned contract matches the Dart client
 * copy (guarded on the Dart side by parse_correction_uploader_test.dart). If a
 * tier name/id drifts on either side, this suite (or the Dart one) goes red.
 *
 * Run with: npx ts-node src/__tests__/parse-tier-vocabulary.test.ts
 */

import {
  DART_TIER_NAMES,
  SERVER_TIER_IDS,
  DART_TO_SERVER_TIER,
  LEGACY_CORRECTION_TIER_IDS,
  VALID_CORRECTION_TIERS,
} from "../shared/parse-tier-vocabulary";
import { VALID_TIERS } from "../events/log-parse-correction";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runTests, assertEqual } = require("./_unit-runner");

// The canonical contract, written out literally. The Dart client map
// (ParseCorrectionUploader.dartToServerTier) must equal this same set of pairs.
const CANONICAL: Record<string, string> = {
  SchemaOrg: "schema_org",
  SiteConfig: "site_config",
  RuleBased: "rule_based",
  LLM: "llm",
  SelectiveEnhance: "selective_enhance",
  StructuredExtraction: "structured_extraction",
  WebScraper: "web_scraper",
  HtmlTextParse: "html_text_parse",
  UserAssisted: "user_assisted",
};

(async () => {
  await runTests("BUT-1486: parse-tier vocabulary consistency tests", [
    {
      name: "DART_TIER_NAMES and SERVER_TIER_IDS are index-aligned (same length)",
      fn: () =>
        assertEqual(
          DART_TIER_NAMES.length,
          SERVER_TIER_IDS.length,
          "tier list lengths differ"
        ),
    },
    {
      name: "derived DART_TO_SERVER_TIER equals the canonical contract",
      fn: () =>
        assertEqual(
          JSON.stringify(DART_TO_SERVER_TIER),
          JSON.stringify(CANONICAL),
          "derived mapping mismatch"
        ),
    },
    {
      name: "no duplicate server tier ids",
      fn: () =>
        assertEqual(
          new Set(SERVER_TIER_IDS).size,
          SERVER_TIER_IDS.length,
          "duplicate server tier id"
        ),
    },
    {
      name: "correction callable VALID_TIERS is the shared VALID_CORRECTION_TIERS",
      fn: () =>
        assertEqual(
          JSON.stringify(VALID_TIERS),
          JSON.stringify(VALID_CORRECTION_TIERS),
          "log-parse-correction VALID_TIERS is not sourced from the shared module"
        ),
    },
    {
      name: "VALID_CORRECTION_TIERS accepts every canonical server id",
      fn: () => {
        const missing = SERVER_TIER_IDS.filter(
          (id) => !VALID_CORRECTION_TIERS.includes(id)
        );
        assertEqual(
          missing.length,
          0,
          `unaccepted canonical ids: ${missing.join(", ")}`
        );
      },
    },
    {
      name: "VALID_CORRECTION_TIERS is exactly the canonical ids plus legacy aliases",
      fn: () => {
        const expected = new Set<string>([
          ...SERVER_TIER_IDS,
          ...LEGACY_CORRECTION_TIER_IDS,
        ]);
        const actual = new Set(VALID_CORRECTION_TIERS);
        assertEqual(
          actual.size,
          expected.size,
          "size differs from canonical+legacy"
        );
        for (const id of actual) {
          if (!expected.has(id)) throw new Error(`unexpected accepted tier: ${id}`);
        }
      },
    },
  ]);
})();
