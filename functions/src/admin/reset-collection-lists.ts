/**
 * The three collection lists `admin/reset-user-data.ts` runs on.
 *
 * **Why they live here and not in the script.** The script calls `main()` at
 * module scope, so importing it executes a destructive run's entry point. That
 * forced every test about these lists to parse the script as TEXT, and text
 * parsing brought its own trap: the guards anchored on the LAST entry of a list,
 * with a comment telling the next person to move the anchor when they append.
 * This module is side-effect-free, so the tests import the real values and both
 * the anchors and the parsing disappear.
 *
 * `EXPORT_EXEMPT` in `account/account-deletion-cascade.ts` is the precedent for
 * the third list below, including why a reasoned exemption belongs in production
 * source rather than in a test: an exemption added here shows up in the diff a
 * reviewer reads.
 *
 * BUT-2028.
 */

export interface CollectionTarget {
  name: string;
  /**
   * Reader's inventory of the subcollections a document in [name] is expected
   * to own — it does NOT drive the deletion. `deleteDocRecursive` discovers
   * every subcollection at every depth via `listCollections()`, so a
   * subcollection missing from this list is still wiped (BUT-1724 was filed
   * believing `unified_shopping_lists/{listId}/items` survived a reset because
   * it is absent from the `users` entry below; it does not survive). Keep the
   * list honest anyway — it is what a future reader greps to learn the shape.
   */
  subcollections?: string[];
}

export const COLLECTIONS_TO_DELETE: CollectionTarget[] = [
  {
    name: "users",
    subcollections: [
      "recipes",
      "menus",
      // Pre-rename name (BUT-1697). Normally empty — the client has written
      // nothing here since the rename; swept as a safety net for accounts that
      // predate it.
      "shopping_lists",
      "friends",
      "friend_categories",
      "category_memberships",
      "personal_tags",
      "personal_tag_groups",
      "settings",
      "consent",
      "conversation_memberships",
      "user_shared_menus",
      "user_shared_shopping_lists",
      "ingredients",
      "counters",
      // Erased by a dedicated cascade step (`deletePantryItems`) rather than by
      // the `subs` sweep, so no other register names it. Listed here because
      // the unknown-collection report reads this inventory: without it the
      // report fires on every account that uses the pantry (BUT-2043).
      "pantry",
      // BOTH spellings, deliberately (BUT-2040). `rate_limits` is the live one
      // (`FirestoreCollections.userRateLimits`); `rateLimits` is the
      // pre-rename name, with no writer and rows still standing in production
      // (BUT-2040). Neither was listed here before. This inventory does not
      // drive the deletion — `deleteDocRecursive` enumerates, so it reaches
      // both — so naming them changes nothing a reset does; it stops a reader
      // learning the shape from a list that omits half of it. The ACCOUNT
      // cascade is where the gap was real, and it is closed there.
      "rate_limits",
      "rateLimits",
      "connection_tests",
      "unified_recipes",
      "conversations",
      // The LIVE personal shopping-list path (BUT-1697). Each list document
      // owns an `items` subcollection, reached one level deeper by the
      // recursive delete; this flat list cannot express that nesting.
      "unified_shopping_lists",
    ],
  },
  { name: "public_profiles" },
  { name: "recipes" },
  { name: "recipe_summaries" },
  { name: "menus" },
  {
    name: "shared_recipes",
    subcollections: [
      "members",
      "collaborators",
      "engagements",
      "dismissals",
      "views",
    ],
  },
  {
    name: "shared_menus",
    subcollections: ["members", "collaborators", "engagements"],
  },
  {
    name: "shared_shopping_lists",
    subcollections: ["members", "items"],
  },
  { name: "shared_content" },
  { name: "shared_personal_tags" },
  { name: "social_requests" },
  // BUT-2044: the PRE-RENAME spelling, merged into `social_requests` by
  // `6091b004c` (2026-03-24) with no migration. A row carries `fromUserId`,
  // `toUserId` and a free-text `message`, so it is user data by content, not
  // just by key. Swept by `cleanupSocialRequests` per account since BUT-2044;
  // this entry is the separate whole-collection sweep, which the per-uid step
  // does not cover.
  { name: "friend_requests" },
  { name: "group_invitations" },
  {
    name: "conversations",
    subcollections: ["participants", "userSettings"],
  },
  { name: "messages" },
  { name: "recipe_comments", subcollections: ["likes"] },
  { name: "recipe_ratings" },
  { name: "menu_comments", subcollections: ["comments"] },
  { name: "menu_ratings", subcollections: ["ratings"] },
  { name: "menu_templates" },
  { name: "menu_activity", subcollections: ["activities"] },
  { name: "user_notifications" },
  { name: "user_notification_preferences" },
  { name: "user_fcm_tokens" },
  {
    name: "unified_shopping_lists",
    subcollections: ["items"],
  },
  { name: "unified_shared_shopping_lists" },
  { name: "shopping_list_templates" },
  { name: "presence" },
  {
    name: "recipePresence",
    subcollections: ["activeUsers"],
  },
  { name: "realtime_recipes" },
  { name: "realtime_menus" },
  { name: "realtime_resources" },
  { name: "deep_links", subcollections: ["clicks"] },
  { name: "parsing_corrections" },
  { name: "globalRecipeCache" },
  { name: "parse_events" },
  { name: "connectivity_test" },
  { name: "audit_logs", subcollections: ["deletions"] },
  { name: "deletion_audit_logs" },
  { name: "feedback" },
  { name: "reports" },
  { name: "userFriends" },
  { name: "userSettings" },
  { name: "friend_categories" },
  {
    name: "analytics",
    // `effectiveness` and `daily` are both erased by the recursive walk; they
    // are listed so the unknown-collection report stays quiet about them.
    // `daily` holds the product's own aggregates under seven parents. The
    // accepted deviation that KEEPS `analytics/feature_retention/daily` governs
    // the ACCOUNT CASCADE, not this script, which deletes `analytics` whole —
    // a different call nobody has put side by side with it. Named, not changed.
    subcollections: ["effectiveness", "daily"],
  },
  { name: "shopping_list_invitations" },
  { name: "user_shared_menus" },
  { name: "user_shared_shopping_lists" },
  // BUT-1390: rate-limit buckets are stored at the top-level system_rate_limits
  // collection (doc id `${uid}_${operation}`), not under users/, so a full reset
  // must wipe the whole collection explicitly.
  { name: "system_rate_limits" },
  // BUT-1917: user block relationships, doc id `{blockerId}_{blockedId}`.
  // Absent until now, so a "clean slate" run left every block row standing.
  // `MAX_BLOCK_SWEEP_ROWS` names this script as the recovery when the cascade's
  // sweep declines above its cap, and membership here is NECESSARY for that.
  { name: "blocks" },
  // --- BUT-2028: added when the coverage guard first ran ------------------
  //
  // Every entry below appeared in `firestore.rules` or in `functions/src` and
  // in NO list, which is how they survived a "clean slate" run. They are
  // grouped by why they are user data, not alphabetically, so the next reader
  // can check the reasoning rather than the spelling.

  // Personal content. A reset deletes every Auth user in Phase 1, so anything
  // left here is orphaned: no authenticated callable can reach it again.
  { name: "activity_events" },
  { name: "cook_snaps" },
  { name: "households" },
  { name: "diner_profiles" },
  { name: "family_ratings" },
  { name: "weekly_menu_plans" },
  { name: "group_weekly_menu_plans" },
  { name: "chat_groups" },
  { name: "pings", subcollections: ["pings"] },
  { name: "recipe_cook_events", subcollections: ["events"] },
  { name: "shoppingPresence", subcollections: ["activeUsers"] },
  { name: "tag_overrides_log" },
  // Deleted, where `metrics` in the register below is kept. **Malin's explicit
  // call, 2026-09-07**, made with both on the table.
  //
  // The ground is CONTENT, not identifiability: the row carries the user's own
  // words. `toValue` is what she typed into the field. It and `fromValue` are
  // both truncated to `MAX_VALUE_CHARS` and scrubbed (`scrubPii`), and both are
  // still text a person wrote or edited — the same ground as
  // `llm_response_samples`. `metrics` is aggregates with no uid and no text a
  // person wrote, so a reset that takes what people wrote does not reach it.
  //
  // She was shown that this restarts the parse-quality corpus from zero.
  // She was NOT shown a measurement of how large that corpus is; nobody has
  // counted it against production.
  //
  // The uid and recipeId arrive pre-hashed and the `recipeIdHash` resolves to
  // nothing. That was the first mechanism written here, and it decides NOTHING:
  // nothing is orphaned either way, so identifiability is not what separates the
  // two collections. Do not re-argue the call from it.
  { name: "parse_corrections_v2" },
  // Doc id is the reported user's uid (`feedback/on-report-created.ts`), so
  // the collection is uid-keyed even though no field says so. Its
  // `report_history` rows carry a REPORTER's uid, i.e. a third party's
  // (BUT-2046); the recursive walk reaches them whether or not they are named
  // here, and this list is the reader's inventory.
  { name: "user_moderation", subcollections: ["report_history"] },
  // Keyed by the report's event id, one marker per report. `reports` is
  // already listed above, so these would outlive what they mark.
  { name: "report_processing_markers" },
  // Uid-carrying suggestions (`userId` field, client-creatable per
  // firestore.rules; no screen in the app produces one). The cascade reaches it
  // (`deleteIngredientSuggestions`, with a probe leg), so this script and a
  // single erasure now agree about it.
  { name: "ingredient_suggestions" },
  // Captured model input and output for QA. Both are PII-scrubbed at capture
  // and the uid is stored as `authUidHash`, never raw — so the ground for
  // deleting these is not that they are personal data but that they are a
  // 30-day capture of user-submitted content, worthless once every account
  // that produced it is gone.
  { name: "llm_response_samples" },

  // The notification pipeline. `user_notifications` — the user-facing inbox —
  // was already listed; these are the queues and event rows behind it, every
  // one of them uid-keyed. `notification_opened_events` and
  // `notification_send_events` key on `<userId>_<notificationId>` doc ids.
  { name: "notification_history" },
  { name: "notification_batches" },
  { name: "notification_delivery" },
  { name: "notification_engagement" },
  { name: "notification_opened_events" },
  { name: "notification_send_events" },
  { name: "scheduled_notifications" },

  // Derived aggregates over content this script deletes. They carry no uid,
  // but a reset that keeps them leaves ratings and social counts for recipes
  // that no longer exist — visibly wrong rather than merely stale.
  { name: "recipe_social_stats" },
  { name: "canonical_recipe_stats" },

  // The admin operations log. It was first registered as deliberately
  // untouched on the ground that it holds no uid; the commit-gate review
  // measured otherwise. `feedback/on-report-created.ts` writes a
  // `moderation_threshold_<uid>` document id and puts raw uids in
  // `details.userId`, `details.reporterId` and `details.contentOwnerId`. The
  // ingredient-sync rows beside them are clean, which is how the false
  // generalisation happened; the rate-limiter row carries a HASHED uid
  // (`userIdHash`), which is pseudonymous rather than clean.
  //
  // A single account's erasure now reaches the moderation rows —
  // `deleteModerationSystemEvents` in the cascade, BUT-2032. This entry is about
  // the whole collection on a full reset, which is a different question: the
  // rows a reset removes include every row about people it is not erasing.
  { name: "system_events" },

  // BUT-2046 follow-up: the legal-hold decisions, one document per held
  // erasure, keyed on the erased uid. `COLLECTIONS_TO_DELETE` and not
  // `COLLECTIONS_DELIBERATELY_UNTOUCHED`, deliberately: a reset removes the
  // reports and the moderation record a hold exists to protect, so a hold left
  // standing would point at nothing and would keep a person's uid past the
  // reset that erased everything it guarded. The register list has no runtime
  // teeth and would have left exactly that.
  { name: "erasure_holds" },

  // The admin console's own two collections (`admin/bulk-retag.ts`). Both key
  // on a raw admin uid — `admin_rate_limits` in BOTH the document id
  // `{adminUid}_bulkRetag_{date}` and an `adminUid` field, `admin_audit_logs`
  // in an `adminUid` field —
  // and neither has a rules block, because only the Admin SDK reaches them.
  // Found by the coverage guard's file-local-const branch: both are named
  // through module constants, so nothing before this could see them.
  //
  // Deleted rather than registered, on the same reading as `system_events`
  // above: a reset removes every Auth account including the admins, so these
  // rows describe operations by people who no longer exist, against content
  // the same run deletes. Keeping the admin trail across a reset is a
  // defensible opposite call and is Malin's to make.
  // Quota state, and therefore the opposite call to `system_ip_audit_caps` in
  // the register below — which is KEPT precisely because wiping it hands a
  // fresh quota to whoever tripped it. The difference is the KEY: this one is
  // `{adminUid}_bulkRetag_{date}` and every admin uid is deleted in Phase 1,
  // while the IP caps key on a hashed IP, which deleting an account does not
  // reach. Same
  // reading as `system_rate_limits` above.
  { name: "admin_rate_limits" },
  { name: "admin_audit_logs" },

  // BUT-2010: `tag_configs` does NOT belong here and must not come back. It is
  // SEED data: `firestore.rules` gives it `allow write: if false`, so no user
  // can write it, and `TagConfigService` reads it as runtime config — wiping it
  // would break auto-tagging rather than clean anything. It is listed in
  // `COLLECTIONS_TO_KEEP` below, which this file's header states as the
  // contract ("preserving config/seed data").
  //
  // The overlap guard caught it and exited before Phase 1 — correctly — which
  // is why this script deleted nothing between 2026-03-19 and 2026-09-05.
  // The guard worked; what was missing was anything that NOTICED it was firing.
  // `scenario_resetScriptListsDoNotOverlap` is that now.
];

export const COLLECTIONS_TO_KEEP = [
  "site_configs",
  "tag_configs",
  "ingredients",
  "ingredient_substitutions",
  "butlery_archive",
  // BUT-2028: holds the reset kill switch this script sets on itself, alongside
  // the app's existing `system/config` switches. It MUST be preserved: sweeping
  // it would delete the flag mid-run, i.e. the script would switch the guard off
  // while relying on it. Being absent from both lists — which is how it stood
  // until now — is not the same as being protected.
  "system",
  // BUT-2028: the admin allowlist. Its doc id is a uid, but it is ACCESS
  // CONFIG rather than user data — wiping it leaves nobody able to reach the
  // admin surfaces, and nothing in the app can write it back.
  "admins",
  // BUT-2028: the category lexicon menu generation reads. Seed data, with
  // `allow write: if false` in firestore.rules — the same class as
  // `tag_configs` above.
  "menu_lexicon",
];


/**
 * Collections deliberately left alone, each with the reason it is left alone.
 *
 * This is a REGISTER, not a shield. The runtime teeth are in
 * `COLLECTIONS_TO_KEEP` — that is the only list the script's overlap guard and
 * its "preserved" summary consult. Anything that must survive a reset belongs
 * there; this list is for collections the script neither deletes nor protects,
 * where that is a decision rather than an oversight.
 *
 * Shape follows `EXPORT_EXEMPT`: every value is a real reason, and the guard
 * enforces a minimum length so an empty string cannot pass for one.
 *
 * A collection that already carries a verdict in
 * `.claude/rules/accepted-deviations.md` is filed here per THAT verdict, citing
 * it — the coverage guard makes such collections visible, and visible is not the
 * same as open for re-argument.
 */
export const COLLECTIONS_DELIBERATELY_UNTOUCHED: Record<string, string> = {
  // --- Operational records that carry no personal data -------------------
  //
  // Each of these is server-written and admin-read. A reset wipes USER data;
  // deleting the operator's own record of what the system did is a separate
  // decision, and this file is where it would be made.

  metrics:
    "North-star weekly snapshots (scheduled/north-star-weekly.ts), keyed by " +
    "ISO week under metrics/weekly_north_star/snapshots. Aggregates " +
    "with no uid; a user-data reset is not a reason to lose the product's " +
    "own time series, which cannot be recomputed once the inputs are gone.",

  // --- Server-internal scratch space -------------------------------------

  _internal:
    "Debounce markers for rating and pooled-rating aggregation " +
    "(shared/debounce-queue.ts). `allow read, write: if false` for every " +
    "client, no uid, and a marker's only effect is to suppress a duplicate " +
    "recompute for a few seconds — worthless to delete and harmless to keep.",

  // --- Collections with no writer on any of the three surfaces -----------
  //
  // The evidence is the grep across `functions/src` and `lib/`. The rules
  // block beside it closes CLIENTS only — the Admin SDK bypasses rules
  // entirely, so for a server-reachable collection a deny-all block proves
  // nothing about whether a Cloud Function writes it.

  audit:
    "`allow read, write: if false` in firestore.rules and no writer in " +
    "functions/src or lib/. Nothing can put a row here, so there is nothing " +
    "for a reset to delete; the block is defence-in-depth, not a live store.",

  tagConfigs:
    "Dead pre-rename twin of `tag_configs`, from the same commit as the other " +
    "twelve camelCase renames (b9a95bd02, 2026-03-19). Identical shape minus " +
    "`uploadedAt`; `updatedBy` is an admin field written by the tag-config " +
    "tooling, not user content. So a reset of USER data has no business " +
    "deleting it — and it needs no protection either, because nothing reads " +
    "it. Clearing the duplicate is its own cleanup, not this script's job.",

  notification_metrics:
    "Client writes are `if false` in firestore.rules, and the name appears in " +
    "functions/src only in this register — no Cloud Function writes it. Named " +
    "by the notification pipeline's design and never built.",

  // --- Anti-abuse state a reset must NOT clear ---------------------------

  system_ip_audit_caps:
    "Per-IP hourly signup caps (account/verify-signup-age.ts). Deliberately " +
    "holds no uid, email or birth year — only a hashed IP and a count. " +
    "Wiping it hands a fresh quota to whoever just tripped the cap.",
};

/**
 * Registered collections the DATABASE holds and no SOURCE names.
 *
 * BUT-2044. The coverage guard derives its universe from `firestore.rules` plus
 * a scan of `functions/src`, and its staleness check reads a register entry
 * naming nothing in that universe as text describing something that no longer
 * exists. For an ORPHAN that reading is backwards: the collection is real, has
 * rows, and is invisible to source precisely because the code stopped naming it
 * — which is the class BUT-2043's report exists to surface.
 *
 * An entry here is exempt from the staleness check and from nothing else. It
 * still needs a written reason in the register, and the dry run still reports
 * it until it is registered. Membership is a claim about the DATABASE, so it is
 * only ever added after a run has measured the rows.
 */
export const DATABASE_ONLY_ORPHANS = new Set<string>([
  // Rows measured 2026-09-08.
  "tagConfigs",
]);

/**
 * Names that appear as SUBCOLLECTIONS in this codebase and are not top-level
 * collections of their own.
 *
 * The coverage guard's server-code source cannot see nesting: it collapses a
 * chain to its first `.collection(...)` link, which handles
 * `db.collection("users").doc(uid).collection("consent")`, but a
 * `collectionGroup("members")` query or a helper that receives a parent
 * `DocumentReference` and calls `.collection("items")` on it names a
 * subcollection with no parent in sight. Filtering by name is the only thing
 * left, so the set is explicit and each entry says whose child it is.
 *
 * The filter matches on NAME and checks no parent, so a genuinely new
 * top-level collection called `items`, `members` or `votes` would be dropped
 * here silently. Convention is what prevents that; the code cannot.
 *
 * `presence`, `friend_categories`, `recipes` and `conversations` are NOT here
 * even though each is also used as a subcollection name: a source discovers
 * each of them anyway, and the guard must keep seeing them.
 *
 * The guard also checks the other direction — an entry here that no source
 * discovers any more is reported, so the set cannot quietly outlive its names.
 */
export const KNOWN_SUBCOLLECTION_NAMES = new Set<string>([
  "activeUsers", // recipePresence/{id}, shoppingPresence/{id}, realtime_*/{id}
  "block_mirror", // users/{uid}
  "friendCategories", // users/{uid}, pre-rename spelling (BUT-2044)
  "comments", // menu_comments/{menuId}, and the {path=**} comment group
  "engagements", // shared_recipes/{id}, shared_menus/{id}
  "items", // unified_shopping_lists/{listId}, shared_shopping_lists/{id}
  "members", // shared_recipes/{id}, shared_menus/{id}
  "participants", // conversations/{conversationId}
  "poll_votes", // messages/{messageId}
  "report_history", // user_moderation/{contentOwnerId} (BUT-2046)
  "ratings", // menu_ratings/{menuId}
  "votes", // realtime_menus/{menuId}
  // The PRE-RENAME personal shopping-list subcollection under users/{uid}
  // (BUT-1697). The live one is `unified_shopping_lists`, which IS top-level as
  // well and is therefore absent from this set.
  "shopping_lists",
]);
