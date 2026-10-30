/**
 * BUT-2414: every step of the account-deletion cascade either has an Art. 15
 * export of what it erases or a recorded decision that it is not exported.
 *
 * The step labels are read from `request-account-deletion.ts` itself, so a
 * new erasure step with no entry below fails this test. An entry names a
 * top-level section of the app's bundle (checked to be a key in
 * `lib/services/account/data_export_service.dart`), an `exportErasureResidue`
 * section (checked against that callable's own section list), a phrase from
 * docs/architecture/ACCEPTED_DEVIATIONS.md (checked to be there), or a
 * decision still open on Linear. Whether a bundle section reads the same rows
 * the step erases is not checked here.
 *
 * Run with: npx ts-node src/__tests__/erasure-export-coverage.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-erasure-export-coverage" });
}

import * as fs from "fs";
import * as path from "path";
import { SECTIONS } from "../exports/erasure-residue";
import { assertGuardTriggersCoverItsDartInputs } from "./_dart-guard-triggers";

type Coverage =
  | { client: string }
  | { residue: string[] }
  | { decided: string }
  | { pending: string }
  | { erasesNothing: true };

const COVERAGE: Record<string, Coverage[]> = {
  erasure_hold_evaluated: [{ erasesNothing: true }],
  shared_content_block_held: [
    { decided: "A held person's Art. 15 bundle" },
  ],
  shared_content_block_held_after_tier1: [
    { decided: "A held person's Art. 15 bundle" },
  ],
  recipes: [{ client: "recipes" }, { residue: ["legacy_recipes"] }],
  menus: [{ client: "menus" }, { residue: ["legacy_menus_received"] }],
  shopping_lists: [
    { client: "shopping_lists" },
    { client: "shared_shopping_lists" },
    { client: "shared_lists_left" },
    { residue: ["legacy_shopping_lists"] },
  ],
  personal_tags: [{ client: "personal_tags" }],
  personal_tag_groups: [{ client: "personal_tag_groups" }],
  tag_overrides_log: [{ residue: ["tag_overrides_log"] }],
  parsing_corrections: [{ residue: ["parsing_corrections"] }],
  cook_snaps: [{ client: "cook_snaps" }],
  activity_events: [{ client: "activity_events" }],
  shopping_list_templates: [{ client: "shopping_list_templates" }],
  deep_links: [{ residue: ["deep_links"] }],
  ingredient_suggestions: [{ client: "ingredient_suggestions" }],
  household_allergen_shares: [{ client: "household_allergen_shares" }],
  recipe_suggestions: [{ client: "recipe_suggestions" }],
  mfa_recovery_data: [
    { client: "two_step_verification" },
    { residue: ["mfa_recovery_attempts"] },
  ],
  guest_quota: [{ residue: ["guest_quota"] }],
  feature_retention: [{ residue: ["feature_retention_rows"] }],
  retention_analytics: [
    { residue: ["retention_events", "lapsed_user_events"] },
  ],
  weekly_menu_plans: [
    { client: "weekly_menu_plans" },
    { decided: "A leaver's Art. 15 export contains a documented GAP" },
  ],
  pantry_items: [{ client: "pantry_items" }],
  family_data: [
    { client: "family" },
    { decided: "a sole remaining member's household section carries every diner profile and family rating" },
  ],
  chat_groups: [{ client: "messages" }, { residue: ["chat_groups_left"] }],
  messages: [
    { client: "messages" },
    { residue: ["messages_in_left_conversations", "conversation_roster_rows"] },
  ],
  shared_content: [
    { client: "shared_content" },
    { client: "shared_lists_left" },
    { residue: ["shares_sent", "share_memberships", "share_engagements"] },
    { residue: ["legacy_shared_with"] },
  ],
  comments_ratings: [
    { client: "comments_and_ratings" },
    { residue: ["legacy_comments", "legacy_ratings"] },
  ],
  pings: [{ client: "pings" }],
  blocks: [
    { client: "blocks" },
    { decided: "does NOT report who has blocked the requester" },
  ],
  reports: [{ client: "reports" }],
  moderation_appeals: [{ client: "moderation_appeals" }],
  moderation_system_events: [{ decided: "`system_events` is NOT in the Art. 15 export" }],
  user_moderation: [{ decided: "The REPORTERS stay" }],
  fcm_tokens: [{ client: "fcm_tokens" }],
  notification_preferences: [{ client: "notification_preferences" }],
  notifications: [{ client: "notifications" }],
  notification_analytics: [
    { client: "notification_history" },
    { client: "notification_batches" },
    { client: "notification_engagement" },
    { client: "notification_delivery" },
  ],
  notification_effectiveness: [
    { decided: "`analytics/notifications/effectiveness` is\n  erased and deliberately not exported" },
  ],
  realtime_menus: [
    { residue: ["realtime_menus", "realtime_menu_votes", "realtime_presence"] },
  ],
  realtime_resources: [
    { client: "live_menus" },
    { residue: ["realtime_resources_last_edited", "realtime_presence"] },
  ],
  storage_files: [{ residue: ["storage_files"] }],
  block_mirrors: [{ client: "blocks" }],
  report_history_as_reporter: [{ residue: ["report_history_as_reporter"] }],
  rating_recipe_owner: [{ decided: "does not show where the requester's uid sits on other people's documents" }],
  comment_recipe_owner: [{ decided: "does not show where the requester's uid sits on other people's documents" }],
  comment_shared_with: [{ decided: "does not show where the requester's uid sits on other people's documents" }],
  comment_likes: [{ client: "comment_likes" }],
  comment_reactions: [{ client: "comment_reactions" }],
  message_reactions: [{ client: "message_reactions" }],
  recipe_member_permissions: [
    { decided: "does not show where the requester's uid sits on other people's documents" },
  ],
  account_deletion_request: [{ residue: ["account_deletion_request"] }],
  preferences: [{ client: "preferences" }],
  consent_records: [{ client: "consent_records" }],
  user_subcollections: [
    { client: "account_subcollections" },
    { residue: ["notification_counters", "recent_content_hashes"] },
  ],
  profile: [{ client: "profile" }],
};

// Erased by the auth trigger `onUserDeleted`, not by a cascade step: each
// section names a collection literal that trigger's source must still carry.
const ERASED_BY_ON_USER_DELETED: Record<string, string> = {
  scheduled_notifications: '"scheduled_notifications"',
  notification_send_events: '"notification_send_events"',
  notification_opened_events: '"notification_opened_events"',
  active_users: '.collectionGroup("activeUsers")',
};

const ROOT = path.join(__dirname, "..", "..", "..");
const CASCADE = path.join(__dirname, "..", "account", "request-account-deletion.ts");
const ON_USER_DELETED = path.join(__dirname, "..", "cleanup", "on-user-deleted.ts");
const BUNDLE = path.join(ROOT, "lib", "services", "account", "data_export_service.dart");
const DEVIATIONS = path.join(ROOT, "docs", "architecture", "ACCEPTED_DEVIATIONS.md");

let total = 0;
let failed = 0;
function record(name: string, ok: boolean, detail = ""): void {
  total++;
  if (!ok) failed++;
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${name}${ok || !detail ? "" : ` — ${detail}`}`);
}

function cascadeStepLabels(): string[] {
  const source = fs.readFileSync(CASCADE, "utf8");
  const labels = new Set<string>();
  for (const m of source.matchAll(/(?:\[\s*|runStep\()"([a-z0-9_]+)"\s*,/g)) {
    labels.add(m[1]);
  }
  return [...labels];
}

/** Step labels the literal regex above cannot read, so cannot hold to an entry. */
function nonLiteralStepLabels(): string[] {
  const source = fs.readFileSync(CASCADE, "utf8");
  return [
    ...source.matchAll(/runStep\(\s*([^,]+),/g),
    ...source.matchAll(/\[\s*([^,[\]]+),\s*(?:async\s*)?\(\)\s*=>/g),
  ]
    .map((m) => m[1].trim())
    // `name` is the tier loops' own parameter; `string` is the tier arrays' tuple type.
    .filter((a) => !/^"[a-z0-9_]+"$/.test(a) && a !== "name" && a !== "string");
}

function run(): void {
  const labels = cascadeStepLabels();
  record("the cascade source yields its step labels", labels.length > 30, `${labels.length}`);
  const nonLiteral = nonLiteralStepLabels();
  record("every cascade step label is a string literal", nonLiteral.length === 0, nonLiteral.join(", "));

  const missing = labels.filter((l) => !(l in COVERAGE));
  record(
    "every erasure step has an export or a recorded decision",
    missing.length === 0,
    `no entry for: ${missing.join(", ")}`,
  );
  const stale = Object.keys(COVERAGE).filter((l) => !labels.includes(l));
  record("no entry names a step the cascade no longer has", stale.length === 0, stale.join(", "));

  const residueSections = new Set(SECTIONS.map((s) => s.name));
  // Only the `futures` map: the rest of the file has keys such as `uid` that
  // are not sections.
  const bundle = fs.readFileSync(BUNDLE, "utf8");
  const start = bundle.indexOf("final futures = <String, Future<Map<String, dynamic>>>{");
  const end = bundle.indexOf("final keys = futures.keys");
  record("the bundle's futures map was found", start >= 0 && end > start);
  const bundleKeys = new Set(
    [...bundle.slice(start, end).matchAll(/^\s+'([a-z0-9_]+)':\s/gm)].map((m) => m[1]),
  );
  const deviations = fs.readFileSync(DEVIATIONS, "utf8").replace(/\r\n/g, "\n");
  const bad: string[] = [];
  for (const [label, entries] of Object.entries(COVERAGE)) {
    for (const e of entries) {
      if ("client" in e) {
        if (!bundleKeys.has(e.client)) bad.push(`${label}: no bundle section ${e.client}`);
      } else if ("residue" in e) {
        for (const name of e.residue) {
          if (!residueSections.has(name)) bad.push(`${label}: no residue section ${name}`);
        }
      } else if ("decided" in e && !deviations.includes(e.decided)) {
        bad.push(`${label}: ACCEPTED_DEVIATIONS has no "${e.decided}"`);
      }
    }
  }
  record("every bundle section, residue section and decision an entry names exists", bad.length === 0, bad.join("; "));

  const trigger = fs.readFileSync(ON_USER_DELETED, "utf8");
  const triggerBad = Object.entries(ERASED_BY_ON_USER_DELETED).filter(
    ([name, literal]) => !residueSections.has(name) || !trigger.includes(literal),
  );
  record(
    "every onUserDeleted section exists and its collection is still erased there",
    triggerBad.length === 0,
    triggerBad.map(([name]) => name).join(", "),
  );

  const unused = [...residueSections].filter(
    (name) =>
      !(name in ERASED_BY_ON_USER_DELETED) &&
      !Object.values(COVERAGE).some((entries) =>
        entries.some((e) => "residue" in e && e.residue.includes(name)),
      ),
  );
  record(
    "every erasure-residue section belongs to an erasure step or onUserDeleted",
    unused.length === 0,
    unused.join(", "),
  );
}

run();
assertGuardTriggersCoverItsDartInputs(ROOT, [BUNDLE], record);
// The helper above takes lib/ paths only; the decisions file is checked here.
const workflow = fs.readFileSync(path.join(ROOT, ".github", "workflows", "cloud-functions-unit.yml"), "utf8");
record(
  "ACCEPTED_DEVIATIONS.md re-runs this guard on push and on pull_request",
  workflow.split('\n      - "docs/architecture/ACCEPTED_DEVIATIONS.md"\n').length - 1 === 2,
);
console.log(`\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : ""));
if (failed > 0) process.exit(1);
