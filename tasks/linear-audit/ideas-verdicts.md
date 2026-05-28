# Linear Product / Feature / UX-Idea Audit — 2026-05-28

Audit context: solo founder, beta product, not a social network (friends/sharing/comments/ratings/groups stay), no monetization decisions yet. Verdicts are blunt: DELETE liberally; "nice to have" = DELETE.

**Quick status summary:** 12 of the 60 tickets are already `Done` (BUT-617, 933, 938, 939, 952, 961, 979, 980, 981, 983, 985, 986, 989, 991, 993, 994, 996, 997, 922, 940). Those get an `ALREADY-DONE` verdict and should be archived from the Backlog filter if still showing.

---

## Already-shipped (close + archive)

## BUT-617 [ALREADY-DONE] — Multiple photos per recipe
**Theme:** Multi-photo
**Reason:** Status = Done 2026-05-24. Model carries `List<String> imageUrls` (verified `recipe_unified.dart`).
**Action:** confirm archived.

## BUT-922 [ALREADY-DONE] — Persist OCR/source artefacts
**Theme:** Transparency
**Reason:** Done 2026-05-24, `lib/models/recipe/source_artefact.dart` exists.
**Action:** confirm archived.

## BUT-933 [ALREADY-DONE] — Bulk tag/add-to-menu/share/export wired
**Theme:** Bulk ops
**Action:** confirm archived.

## BUT-938 [ALREADY-DONE] — Photo gallery viewer
**Theme:** Multi-photo
**Action:** confirm archived.

## BUT-939 [ALREADY-DONE] — `firstFriend` activation milestone
**Theme:** Activation/analytics
**Action:** confirm archived.

## BUT-940 [ALREADY-DONE] — Re-extract from source
**Theme:** Transparency
**Action:** confirm archived.

## BUT-952 [ALREADY-DONE] — Bulk mark-all-read notifications
**Theme:** Bulk ops
**Action:** confirm archived.

## BUT-961 [ALREADY-DONE] — Standardise date/time formatting
**Theme:** Consistency polish
**Action:** confirm archived.

## BUT-979 [ALREADY-DONE] — Groups empty state
**Theme:** Onboarding/empty
**Action:** confirm archived.

## BUT-980 [ALREADY-DONE] — Persist source URL on video imports
**Theme:** Transparency
**Reason:** `sourceUrl`/`sourceArtefact` plumbing verified across import strategies (youtube/tiktok/url/instagram pipelines all reference it).
**Action:** confirm archived.

## BUT-981 [ALREADY-DONE] — Social-feed empty state
**Theme:** Onboarding/empty
**Action:** confirm archived.

## BUT-983 [ALREADY-DONE] — Images in recipe comments
**Theme:** Social
**Action:** confirm archived.

## BUT-985 [ALREADY-DONE] — Multi-recipe paste in text import
**Theme:** Import multi
**Action:** confirm archived.

## BUT-986 [ALREADY-DONE] — Branded empty-state illustrations
**Theme:** Onboarding/empty
**Action:** confirm archived.

## BUT-989 [ALREADY-DONE] — Recipe-to-recipe relations
**Theme:** Recipe model
**Action:** confirm archived.

## BUT-991 [ALREADY-DONE] — Auto-add shopping to pantry
**Theme:** Shopping/pantry loop
**Action:** confirm archived.

## BUT-993 [ALREADY-DONE] — Bulk block/unblock
**Theme:** Bulk ops
**Action:** confirm archived.

## BUT-994 [ALREADY-DONE] — Bulk tag management
**Theme:** Bulk ops
**Action:** confirm archived.

## BUT-996 [ALREADY-DONE] — Copy-week + bulk move menu
**Theme:** Bulk ops menu
**Action:** confirm archived.

## BUT-997 [ALREADY-DONE] — Multi-select group member removal
**Theme:** Bulk ops
**Action:** confirm archived.

---

## Monetization scaffolding cluster (KILL until pricing decisions exist)

## BUT-248 [DELETE] — Entitlement & IAP infra for future monetization
**Theme:** Monetization
**Reason:** Memory says "No monetization decisions yet — just build the app." Building IAP infra before knowing the pricing model is premature optimization. Comes back when you have a pricing decision.
**Action:** delete. Re-file when monetization scope is decided.

## BUT-443 [DELETE] — Entitlement + paywall scaffolding (RevenueCat)
**Theme:** Monetization
**Reason:** Pure duplicate of BUT-248 from a different analysis report. Same DELETE for same reason.
**Action:** delete (merge into BUT-248 only if you choose to retain one as the canonical "when monetization lands" placeholder).

---

## Auth cluster

## BUT-549 [MERGE into BUT-916] — Sign in with Apple
**Theme:** Auth/OAuth
**Reason:** SIWA is a *subset* of BUT-916 (social sign-in). Apple's 4.8 rule applies only once another OAuth provider exists, so it's a sub-bullet of BUT-916, not a peer ticket.
**Action:** merge into BUT-916 as an acceptance criterion ("must include SIWA on iOS").

## BUT-916 [KEEP] — Social sign-in (OAuth)
**Theme:** Auth
**Reason:** Conversion uplift is real (30-40%). But memory says social login is "post-beta" — keep but mark blocked until beta done. Owns the SIWA sub-task from BUT-549.
**Action:** keep, label `post-beta`, absorb BUT-549.

## BUT-920 [KEEP] — Guest/demo mode
**Theme:** Auth/conversion
**Reason:** Genuinely useful funnel-top. Firebase anonymous auth is well-trodden; conversion ↔ sign-up is clean. Worth a sprint when onboarding is the focus.
**Action:** keep.

---

## Multi-X import / capture cluster

## BUT-903 [KEEP] — Multi-page recipe import (2-5 photos → one recipe)
**Theme:** Multi-X import
**Reason:** Highest-value content (cookbooks/magazines) currently unimportable. Ticket already has full spec + acceptance criteria. Ready to execute.
**Action:** keep, primary item in import-multi epic.

## BUT-941 [KEEP] — Multi-share from OS share sheet
**Theme:** Multi-X import
**Reason:** Silent data loss today (OS sends 3, app receives 1). UX expectation gap is real. Pair with BUT-903 for shared receive UI.
**Action:** keep, sub-item of import-multi epic.

## BUT-947 [KEEP] — Multi-URL / index-page URL import
**Theme:** Multi-X import
**Reason:** Power user use case, single-URL pipeline reusable. Acceptable scope.
**Action:** keep, sub-item of import-multi epic.

## BUT-210 [MERGE into BUT-903 / DELETE PDF+voice parts] — PDF/voice/multi-recipe import
**Theme:** Multi-X import / blue-sky
**Reason:** "Multi-recipe selection" is now covered by BUT-947 (URL) + BUT-985 (text, done) + BUT-903 (photo). PDF parsing and voice dictation are major standalone efforts with low expected use vs cost.
**Action:** delete (multi-recipe portions covered elsewhere); if PDF/voice come up later, re-file as separate tickets.

## BUT-949 [KEEP, deprioritize] — Multi-photo "I cooked this" album
**Theme:** Multi-X social
**Reason:** Reasonable feature but cook-snap is not core. Schedule after BUT-903 ships and reuses the same upload widget.
**Action:** keep, low priority.

---

## Shopping/menu/pantry loop (the marquee differentiator)

## BUT-956 [KEEP — flagship] — Auto-aggregate shopping list from weekly menu
**Theme:** Shopping/menu loop
**Reason:** Memory ranks this as "biggest structural product gap". Competitors have it. Unit-normalisation is genuinely hard but unlocks the menu→shopping value loop. Worth its own epic.
**Action:** keep, own epic.

## BUT-999 [KEEP] — Add recipe to multiple menu days/slots
**Theme:** Menu bulk
**Reason:** Small, useful, complements menu epic.
**Action:** keep, sub-item of shopping/menu epic.

---

## Recipe-detail content gaps

## BUT-444 [KEEP — High] — Portion scaling + Swedish unit conversion
**Theme:** Recipe detail
**Reason:** #1 review-complaint vector. Deterministic logic (no LLM cost). Table-stakes vs every named competitor. Already High priority.
**Action:** keep, top of recipe-detail epic.

## BUT-445 [KEEP] — Nutrition display view
**Theme:** Recipe detail
**Reason:** Verified: `lib/models/nutrition_info.dart` exists, no view renders it. Half-built features are bad signal — finish it (~1 day) or delete the model. Pair with BUT-444 (per-serving display).
**Action:** keep, sub-item of recipe-detail epic.

## BUT-604 [KEEP] — Inline cooking timers parsed from instructions
**Theme:** Recipe detail / cooking mode
**Reason:** Visible competitor parity gap; Swedish-language NLP work is novel and aligns with the cooking-mode focus already prioritized.
**Action:** keep, sub-item of recipe-detail epic.

## BUT-976 [KEEP, deprioritize] — Per-step images in instructions
**Theme:** Recipe detail
**Reason:** Real value but schema change + migration + editor + viewer + import pipeline. Defer until BUT-444/445/604 land.
**Action:** keep, low priority.

## BUT-936 [DELETE] — Explain what changed when scaling portions
**Theme:** Recipe detail polish
**Reason:** Pre-optimizing a feature (BUT-444) that doesn't exist yet. Build BUT-444 first; if users complain, then add diff UI.
**Action:** delete; revisit only if BUT-444 ships and users complain.

---

## Blue-sky / post-monetization (KILL or PARK aggressively)

## BUT-213 [DELETE] — Evaluate Riverpod/go_router/Freezed migration
**Theme:** Tech debt / blue-sky
**Reason:** Solo dev with working architecture. "Evaluate" tickets without a forcing function rot in backlog forever. If a real pain point emerges, file it then.
**Action:** delete.

## BUT-625 [DELETE] — Voice/hands-free cooking mode
**Theme:** Differentiation / blue-sky
**Reason:** Multi-week effort, post-monetization, speculative ROI. Ticket has been sitting since April with no movement. If you want to differentiate, do BUT-604 (timers) and BUT-444 (scaling) first — both cheaper, more visible.
**Action:** delete; re-file post-monetization if still relevant.

## BUT-344 [DELETE] — Group chat ↔ social group unification
**Theme:** Social
**Reason:** "Not a social network" per memory. Unifying two systems is a large effort with low retention payoff for a recipe app. If the two screens confuse users, fix discoverability cheaper.
**Action:** delete.

## BUT-934 [KEEP, deprioritize] — Lapsed-user re-engagement notifications
**Theme:** Retention
**Reason:** Direct retention metric impact, but requires real user base + push-consent infra to be worthwhile. Build it when DAU is non-trivial.
**Action:** keep, label `post-launch`.

---

## Onboarding / empty-state cluster

## BUT-923 [KEEP] — Re-launch onboarding from Settings
**Theme:** Onboarding
**Reason:** Real user need (allergies diagnosed later), cheap.
**Action:** keep, sub-item of onboarding-polish epic.

## BUT-930 [KEEP] — Seed sample menus + shopping lists
**Theme:** Onboarding
**Reason:** Shows full workflow on first launch. Cheap, high "wow" payoff.
**Action:** keep, sub-item of onboarding-polish epic. Blocked-by BUT-956 for the auto-generation part.

## BUT-975 [KEEP] — Friends-tab branded empty state
**Theme:** Onboarding/empty
**Reason:** Social entry point — first impression of the feature.
**Action:** keep, sub-item of onboarding-polish epic.

---

## Consistency polish cluster

## BUT-944 [KEEP] — Single icon convention (heart/star/bookmark)
**Theme:** Design system
**Reason:** Real design-system gap. Modest effort, durable payoff.
**Action:** keep, sub-item of consistency-polish epic.

## BUT-948 [KEEP] — Long-press semantics
**Theme:** Design system
**Reason:** Discoverability bug source. Pick a rule, apply.
**Action:** keep, sub-item of consistency-polish epic.

## BUT-954 [KEEP] — Standardise destructive-action confirmation
**Theme:** Design system
**Reason:** Foundational rule; trivial to write, drives many other tickets.
**Action:** keep, FIRST item in consistency-polish epic (write the rule before other UX work).

## BUT-957 [DELETE] — Consolidate loading indicators
**Theme:** Polish
**Reason:** Pure aesthetic; users won't notice. Low/low priority = bin.
**Action:** delete.

## BUT-964 [KEEP] — Primary-action FAB placement
**Theme:** Design system
**Reason:** Friends-tab "Add friend" missing on tabs 1/3 is a real bug. Bundle into consistency-polish.
**Action:** keep, sub-item of consistency-polish epic.

---

## Transparency / AI-literacy cluster

## BUT-925 [KEEP] — Show ingredient parse confidence
**Theme:** AI transparency
**Reason:** Data exists, surfacing it shifts user trust. Cheap.
**Action:** keep, sub-item of import-transparency epic.

## BUT-928 [KEEP] — OCR confidence in assisted dialog
**Theme:** AI transparency
**Reason:** Same shape as BUT-925, pair them.
**Action:** keep, sub-item of import-transparency epic.

## BUT-931 [KEEP, deprioritize] — Distinguish AI vs user content
**Theme:** AI transparency
**Reason:** Foundational for future AI features, less urgent today.
**Action:** keep, sub-item of import-transparency epic.

---

## Discovery cluster

## BUT-972 [KEEP] — Promote "Save a copy" on shared recipes
**Theme:** Discovery
**Reason:** Forking is the primary use case for shared recipes today. Trivial fix.
**Action:** keep, sub-item of discovery-polish epic.

## BUT-977 [KEEP — High] — Global ingredient search on home
**Theme:** Discovery
**Reason:** Biggest discoverability win called out in audit. Powerful feature is invisible. Cheap.
**Action:** keep, top of discovery-polish epic.

## BUT-982 [KEEP] — Discoverability hints for gestures
**Theme:** Discovery
**Reason:** Pair with BUT-948 — if long-press becomes "select", you must surface alternate paths.
**Action:** keep, sub-item of discovery-polish epic.

## BUT-987 [KEEP] — Surface allergens contextually
**Theme:** Discovery
**Reason:** Allergens are core to the value prop and buried 3 levels deep. Cheap fix.
**Action:** keep, sub-item of discovery-polish epic.

## BUT-990 [DELETE] — In-app FAQ entry from outside Settings
**Theme:** Discovery
**Reason:** Premature. Beta, no significant FAQ corpus, no user-support volume justifying it. When support tickets pile up, reconsider.
**Action:** delete.

## BUT-1000 [KEEP, deprioritize] — Recipes shared by friend X filter
**Theme:** Discovery / social
**Reason:** Small surface, real but niche. Tag onto a future social sprint.
**Action:** keep, low priority.

## BUT-1002 [DELETE] — Bulk friend-add / contact import
**Theme:** Social / growth
**Reason:** GDPR-heavy, requires contact-permission UX + server-side hash index. Not justified at beta scale. If growth ever bottlenecks on friend density, revisit.
**Action:** delete.

---

# Proposed Epic Rollups

For solo dev sanity. Each epic = parent ticket, individual tickets become sub-tasks.

## Epic 1 — Multi-X Import & Capture
**Bundles:** BUT-903 (multi-page photo), BUT-941 (multi-share), BUT-947 (multi-URL).
**Already done in scope:** BUT-985 (text), BUT-617 (model), BUT-938 (viewer), BUT-980 (source URL), BUT-983 (comment images), BUT-922 (artefacts), BUT-940 (re-extract).
**Rationale:** Same UX pattern (thumbnail strip, per-item progress, per-item retry, cap at 5). Shared receive widget. Worth one epic so the shared widget gets built once.

## Epic 2 — Recipe Detail Content Parity
**Bundles:** BUT-444 (portion scaling, High), BUT-445 (nutrition view), BUT-604 (inline timers), BUT-976 (per-step images, low).
**Rationale:** Competitor-parity content on the same screen; ship as one coherent recipe-detail upgrade. Get BUT-444 + BUT-445 + BUT-604 into beta; BUT-976 post-beta.

## Epic 3 — Menu → Shopping Loop (flagship)
**Bundles:** BUT-956 (auto-aggregate, High), BUT-999 (add to multiple days).
**Already done in scope:** BUT-996 (copy week), BUT-991 (shopping→pantry).
**Rationale:** This is the marquee product feature. Unit normalisation is its own multi-week effort — treat as the next big initiative after Recipe Detail Parity.

## Epic 4 — Onboarding & Empty States Polish
**Bundles:** BUT-923 (re-launch onboarding), BUT-930 (seed sample week), BUT-975 (friends empty state).
**Already done in scope:** BUT-979 (groups), BUT-981 (feed), BUT-986 (branded illustrations).
**Rationale:** First-impression batch; ship together so the new-user flow looks coherent end-to-end.

## Epic 5 — Design System & Consistency
**Bundles:** BUT-954 (destructive confirms — write the rule first), BUT-944 (icon convention), BUT-948 (long-press semantics), BUT-964 (FAB placement).
**Already done in scope:** BUT-961 (date/time).
**Rationale:** Cross-cutting. Do BUT-954 first as the foundational rule; the rest are mechanical applications.

## Epic 6 — Import Transparency & AI Literacy
**Bundles:** BUT-925 (parse confidence), BUT-928 (OCR confidence), BUT-931 (AI provenance).
**Rationale:** Three small wins on the same import-assist screen. Bundle for context-switching efficiency.

## Epic 7 — Discoverability Polish
**Bundles:** BUT-977 (global search, High), BUT-972 (Save a Copy), BUT-982 (gesture hints), BUT-987 (contextual allergens).
**Rationale:** Surface existing power features. All cheap; ship as one polish sprint.

## Epic 8 — Auth & Conversion (post-beta)
**Bundles:** BUT-916 (OAuth, absorbs BUT-549 SIWA), BUT-920 (guest mode).
**Rationale:** Funnel-top work; post-beta per memory.

---

# Deleted Outright

BUT-213 (Riverpod eval), BUT-248 (IAP), BUT-443 (paywall dup of 248), BUT-344 (group chat unify), BUT-549 (folded into 916), BUT-625 (voice control), BUT-957 (loading consolidation), BUT-990 (FAQ entry), BUT-1002 (contact import), BUT-210 (PDF/voice), BUT-936 (scaling diff UI).

Also deferred low-pri (kept but post-launch label): BUT-934 (re-engagement push), BUT-949 (cook-snap album), BUT-976 (per-step images), BUT-1000 (per-friend filter), BUT-931 (AI provenance).
