/**
 * BUT-1486: Single source of truth for parse-tier identifiers.
 *
 * Three copies of the tier vocabulary were hand-synced before this module:
 *   1. the client map `_dartToServerTier` (Dart CamelCase → server snake_case)
 *      in lib/services/parsing/feedback/parse_correction_uploader.dart
 *   2. `VALID_TIERS` in functions/src/events/log-parse-correction.ts (snake_case)
 *   3. `VALID_TIERS` in functions/src/events/log-parse-event.ts (CamelCase)
 *
 * This module is the canonical server-side definition. Copy #2 imports from
 * here (see log-parse-correction.ts). Copy #3 (the parse-event path, which
 * validates the raw CamelCase Dart names) is a separate file not migrated in
 * BUT-1486 — its follow-up folds it in via DART_TIER_NAMES below. The Dart
 * client map (#1) cannot import TypeScript; it is pinned against DART→server
 * drift by a mapping test
 * (test/unit/services/parsing/feedback/parse_correction_uploader_test.dart),
 * and this module keeps the two forms side by side so the contract is visible
 * in one place.
 */

/**
 * Canonical Dart tier names (CamelCase) — one per real parsing tier, in the
 * order the tiers run. This is the vocabulary log-parse-event.ts validates,
 * because the parse-event logger sends the raw Dart tier name.
 */
export const DART_TIER_NAMES = [
  "SchemaOrg",
  "SiteConfig",
  "RuleBased",
  "LLM",
  "SelectiveEnhance",
  "StructuredExtraction",
  "WebScraper",
  "HtmlTextParse",
  "UserAssisted",
] as const;

/**
 * Canonical server tier ids (snake_case) — the value each Dart tier name maps
 * to on the correction path. Index-aligned with DART_TIER_NAMES.
 */
export const SERVER_TIER_IDS = [
  "schema_org",
  "site_config",
  "rule_based",
  "llm",
  "selective_enhance",
  "structured_extraction",
  "web_scraper",
  "html_text_parse",
  "user_assisted",
] as const;

/**
 * The canonical Dart→server mapping, derived from the two index-aligned lists.
 * Mirrors `_dartToServerTier` on the client; the Dart test pins the same pairs.
 */
export const DART_TO_SERVER_TIER: Readonly<Record<string, string>> =
  Object.fromEntries(DART_TIER_NAMES.map((name, i) => [name, SERVER_TIER_IDS[i]]));

/**
 * Legacy server tier id accepted on the correction path only. No live client
 * emits it — the Dart tier map has no "regex" entry — but the correction
 * callable has historically accepted it, so it stays in the accept set to
 * avoid narrowing the server contract under BUT-1486. Remove once telemetry
 * confirms zero "regex" correction traffic.
 */
export const LEGACY_CORRECTION_TIER_IDS = ["regex"] as const;

/**
 * Every `sourceTier` value the correction callable accepts: the canonical
 * server ids plus the legacy alias. Order is irrelevant (membership test only).
 */
export const VALID_CORRECTION_TIERS: string[] = [
  ...SERVER_TIER_IDS,
  ...LEGACY_CORRECTION_TIER_IDS,
];
