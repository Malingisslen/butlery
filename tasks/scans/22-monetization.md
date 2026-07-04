# Scan — Role 22: Monetization / Subscriptions Lead

Date: 2026-06-27
Strategy context (DECIDED, per project memory): Butlery is FREE-to-user. Monetization rails =
(1) grocery-channel aggregation (big bet) + (2) POD cookbook gifting (small). NO consumer
subscription / paywall / RevenueCat. Findings below are reframed around the *actual* rails;
no subscription/tier features proposed.

Owned paths reviewed: lib/app/butlery_app.dart (session-start wiring),
lib/services/analytics/analytics_events.dart, lib/services/analytics/user_property_bootstrap.dart,
lib/services/import/import_rate_limiter.dart, lib/services/import/models/rate_limit_models.dart,
lib/models/user_profile.dart.

---

## PASS 1 — Instrumentation for the real rails + segmentation correctness

### NEW-1 [HIGH] No analytics events exist for the grocery-channel intent funnel (the big-bet rail)
The decided primary rail is grocery-channel aggregation, yet `AnalyticsEvents`
(`lib/services/analytics/analytics_events.dart:18-206`) defines **zero** events that capture
grocery intent. The shopping section (lines 92-97) only tracks list lifecycle
(`shopping_list_created/item_added/item_checked/shared/completed`) — none distinguishes a
*purchase-intent* signal (e.g. "exported shopping list toward a store", "tapped a buy/order
action", "shopping list → channel hand-off"). A grep for `grocery|cart_export|ica|willys|hemkop|mathem|matpris`
across `lib/services/analytics/` returns nothing. Consequence: when the grocery rail is built
(backlog "Swedish grocery delivery integration (ICA/Coop/Mathem cart export)", deferred), there
will be no day-1 funnel — adoption/intent must be reconstructed retroactively, and the linchpin
"is shopping-list quality driving channel intent?" question is unmeasurable today.
Distinct from the deferred *feature-build* ticket: this is the measurement layer the build will
need to define up front.
**Evidence:** `lib/services/analytics/analytics_events.dart:92-97` (shopping events, no intent
signal); no grocery/cart event anywhere under `lib/services/analytics/`.

### NEW-2 [MEDIUM] No analytics events exist for the cookbook-gifting funnel (the small rail)
The second decided rail is POD cookbook gifting. The cookbook EPIC (BUT-1316/1325/1326/1327/1328,
all `deferred`) builds the feature, but `AnalyticsEvents` defines no funnel events for it:
no `cookbook_created`, `cookbook_shared_link`, `cookbook_gifted`, `cookbook_print_ordered`, or
equivalent. The recipe/social sections (lines 64-118) cover recipe + sharing primitives but not
cookbook assembly → share → gift → print conversion. As with NEW-1, the gifting/print-revenue
funnel will be invisible at launch unless the events are specified alongside the build.
Smaller stakes than the grocery rail (revenue is "small" per strategy), hence MEDIUM.
**Evidence:** `lib/services/analytics/analytics_events.dart:64-118`; no cookbook event in the
registry; cookbook EPIC tickets are feature-build only (no telemetry scope).

---

## PASS 2 — What pass 1 missed: leftover dead-premise plumbing & segmentation that assumes subscriptions

### NEW-3 [MEDIUM] `subscription_tier` user-property + its bootstrap path are dead-premise plumbing
The `subscription_tier` user property (`analytics_events.dart:247-251`) and the entire
`emitSubscriptionTier` path (`user_property_bootstrap.dart:38,55,59-69`) were seeded by BUT-623
to "slice post-beta **paid cohorts** from day 1." That premise is now dead: there is no consumer
subscription and none is coming. The property hardcodes `'free'` for every user forever
(`butlery_app.dart:619-624` never passes a tier; default `'free'` in `emitAtSessionStart`), so it
emits a constant-valued dimension to Firebase Analytics on every session — a permanently
zero-information property and a costless-but-misleading "we have tiers" signal in the schema and
in role #22's own dossier mandate. This is leftover code from the same Canceled cluster as
BUT-656/653 (already closed), but unlike those the *code pattern still lives* and a naive reader
(or the dossier) treats it as live monetization infrastructure. Recommend: either retire
`subscription_tier` / `emitSubscriptionTier` outright, OR repurpose the slot to a meaningful
free-app cohort that the real rails can slice on (e.g. `grocery_intent_cohort` /
`gifting_cohort`). Decision needed — flag, don't auto-delete.
**Evidence:** `lib/services/analytics/analytics_events.dart:247-251`;
`lib/services/analytics/user_property_bootstrap.dart:38,55,63-69`;
`lib/app/butlery_app.dart:619-624` (no tier arg, defaults `'free'`).

### NEW-4 [LOW] Role-22 dossier mandate still describes a subscription business; no longer matches strategy
The dossier section "## 22. Monetization / Subscriptions Lead"
(`docs/architecture/ROLE_RESPONSIBILITY_MAP.md:635-651`) still defines the mandate as "Build and
evolve Butlery's subscription infrastructure (tiers, entitlements, billing integration…)" and its
sole watch-item is about making rate-limits a "function of subscription tier" at "paid launch."
This directly contradicts the decided FREE-to-user + grocery/cookbook strategy and the closed
BUT-656/653 cluster. The world-watch sources are all StoreKit / Play Billing / VAT-on-subscriptions
— none cover the grocery-aggregation or POD-print rails the role actually owns. The dossier is
marked stale (`docs/org/dossier-staleness/monetization-subscriptions-lead.stale`, stale_since
2026-06-27) but its *content* still points the role at a dead premise. Recommend refresh of the
mandate + watch-items to the real rails (covered by `/refresh-dossiers`, noting it here so the
monetization angle isn't lost).
**Evidence:** `docs/architecture/ROLE_RESPONSIBILITY_MAP.md:635-651`;
`docs/org/dossier-staleness/monetization-subscriptions-lead.stale`.

---

## Checked but NOT filed (already decided / not a defect)

- **`import_tier_succeeded/failed` events** (`analytics_events.dart:129-130`) — these are
  *parse-pipeline* tiers (site_config / regex / LLM extraction), NOT subscription tiers. Verified
  via `recipe_parser_service.dart:801-820` and `parse_events_tracker.dart:13-14`. Legitimate,
  not dead premise. No finding.
- **Uniform LLM cost rate-limits** (`rate_limit_models.dart:303-304` $0.50/day, $10/mo; callsites
  `import_rate_limiter.dart:278,301`) — the dossier framed these as needing "tier-differentiation
  at paid launch." With the subscription premise dead, they are simply universal FinOps cost guards
  for a free app, which is correct as-is. The "make them tier-aware" watch-item is itself obsolete
  (folded into NEW-4). No new finding; this is FinOps (role #7) territory, not a monetization gap.
- **BUT-656/653/668/672/661** — Canceled paid-tier cluster, already in tracker/lessons as decided
  "dead paid-tier premise." Not re-flagged.
- **Cookbook EPIC (BUT-1316/1325/1326/1327/1328) and grocery cart-export ticket** — these build
  the *features*; NEW-1/NEW-2 are the *measurement* layer those builds lack, which is net-new and
  not covered by the existing tickets.

---

COVERAGE: 2 passes done. Reviewed all 6 owned paths + dossier + tracker + dedup + lessons +
accepted-deviations. 4 NEW findings (1 HIGH, 2 MEDIUM, 1 LOW). Core theme: the codebase is
instrumented for a subscription business that was cancelled, and not instrumented for the two
rails actually decided (grocery intent, cookbook gifting). No subscription/paywall features
proposed.
