# Role #26 — Growth Marketer / ASO — scan findings

Scope (owned paths): functions/src/analytics/{detect-lapsed-users,send-activity-digest,
track-retention,winback-variant,winback-context}.ts, lib/core/bootstrap/handlers/
deep_link_handler.dart, lib/services/analytics/{acquisition_milestone,winback_attribution_service}.dart,
lib/services/in_app_review_service.dart, store_assets/metadata/sv-SE/keywords.txt

Lens: retention loops, win-back, deep links, in-app review eligibility, acquisition instrumentation,
attribution correctness.

NOTE: per memory (`feedback_no_store_submission_yet`) NO store submission yet — store-listing /
keyword-limit / Play-data-safety items are intentionally NOT raised here.

Already-known watch-items / tracked tickets (NOT re-filed):
- In-app review counts every 4–5★ rating with no (userId, recipeId) dedup → can prematurely
  reach the 3-cook threshold via re-ratings. **Already a dossier watch-item** (ROLE_MAP #26,
  in_app_review_service.dart:87–93). Skipped.
- No `review_submitted`/`review_completed` event past the OS prompt; PWA-install events missing;
  win-back RC runbook absent; keywords at 100% of iOS limit — **all four are existing dossier
  watch-items.** Skipped.
- Win-back push bypasses prefs/quiet-hours — **BUT-438** (.claude/linear-tracker.json). The
  current code DOES gate via `evaluateSendGate` + `sendPushToUserRespectingPreferences`, so this
  appears resolved; not re-filed.
- Win-back copy variants / contextual copy — **BUT-934**; referral infra, web landing —
  in `_scan_dedup_titles.txt`. Skipped.

Investigated and DROPPED (verified NOT bugs):
- Anonymous-user UTM never mirrored to Firestore (acquisition_milestone.dart:80 early-return):
  the deep-link handler auth-gates at deep_link_handler.dart:106 and **requeues** the link as
  `_pendingDeepLink`, re-running it post-login when a uid exists. `_trackCampaignAttribution`
  (line 124) is only reached when authed, so the anon branch is effectively dead and attribution
  does flush after sign-in. No data loss. Not a finding.
- Lapsed-detection ±12h window (detect-lapsed-users.ts:127–132): the daily schedule tiles the
  24h windows exactly day-over-day, so no user falls between thresholds. Correct.
- Weekly digest counts the user's OWN activity only (recipes/comments/ratings/shares by them),
  not friends' — matches the "Du hade X aktiviteter" self-summary copy. Product choice, not a bug.

---

## PASS 1 — primary (retention/win-back, deep links, in-app review timing)

### Web-share-target import deep link is dead — early host guard rejects `butlery://import`
- type: bug  area: import / acquisition-funnel  priority: High
- pass: 1
- finding: The web share target and the import path both build the URL
  `butlery://import?url=<encoded>` (deep_link_handler.dart:60 and :67–68). For that URL
  `Uri.parse` yields scheme=`butlery`, **host=`import`**, path=`""` (verified empirically). The
  host-validation guard at lines 114–117 returns early whenever
  `scheme=='butlery' && host.isNotEmpty && host != 'butlery.app'` — so host=`import` trips the
  guard and the handler returns **before** reaching the import branch at lines 140–141
  (`path.startsWith('/import') || (scheme=='butlery' && host=='import')`). That branch is
  therefore unreachable for the canonical `butlery://import` form; only the host-less variant
  `butlery:/import` (path=`/import`) would route — but the code never produces that form.
- why: "Share a URL to Butlery → it opens Smart Import pre-filled" is a core acquisition/
  activation loop (web Share Target API, manifest share_target). Today a user who shares a
  recipe URL into the app on web/Android gets silently dropped — the single most direct
  import-funnel entry point is broken. High user-visible impact, zero error surfaced.
- fix: Allow `import` as a recognized host in the guard, e.g. change the condition to
  `host != 'butlery.app' && host != 'import'` (or whitelist known custom-scheme hosts), so the
  import branch at 140–141 is reachable. Add a journey test asserting `butlery://import?url=...`
  navigates to `Routes.smartImport` with the URL argument.
- evidence: lib/core/bootstrap/handlers/deep_link_handler.dart:60, :67–68, :114–118, :140–142

### In-app review last-prompt key lacks the `_v1` version suffix used by its siblings
- type: bug  area: in-app-review / cooldown integrity  priority: Low
- pass: 1
- finding: `_prefsLastPromptAtKey = 'last_in_app_review_prompt_at'` (in_app_review_service.dart:35)
  has no `_v1` suffix, unlike its two siblings `..._happy_cook_count_v1` and `..._first_seen_at_v1`
  (lines 32–34). The 90-day cooldown floor (criterion 4, lines 100–105) reads this key.
- why: The unversioned key is the one gating "don't nag the user again for 90 days." If a future
  migration bumps the schema and follows the established `_v1` convention for the other two keys,
  it is easy to also rename this one and silently reset every user's cooldown to zero — re-prompting
  users who were recently asked (iOS caps at 3/year; an accidental reset wastes that budget). Minor
  consistency/robustness gap, not an active defect.
- fix: Rename to `last_in_app_review_prompt_at_v1` with a one-time read-through migration of the
  old key, or document why this key is deliberately unversioned.
- evidence: lib/services/in_app_review_service.dart:32–35, :100–105, :125

---

## PASS 2 — second sweep (acquisition instrumentation, attribution correctness)

### Activity-digest push has no per-category opt-out — only master toggle + quiet hours gate it
- type: bug  area: notifications / digest correctness  priority: Medium
- pass: 2
- finding: The weekly digest gates the in-app notification doc on the user's
  `digestFrequency != "never"` preference (send-activity-digest.ts:71–78), but the **FCM push**
  is sent with category `"reEngagement"` (line 175) "because that's the only typed value the
  BUT-438 contract exposes" (comment 144–150). So `evaluateSendGate` (line 169) and
  `sendPushToUserRespectingPreferences` evaluate the digest against the user's **re-engagement**
  category preference, not a digest preference. A user who set `digestFrequency = "weekly"` but
  who has opted **out of re-engagement** pushes will be silently dropped (acceptable), but the
  inverse is the real gap: the digest push rides on the re-engagement toggle, so a user who wants
  re-engagement pings but explicitly chose a digest cadence has the two coupled, and there is no
  dedicated digest push-category preference at all. The per-category gate the code claims to honor
  does not exist for digest.
- why: Mis-categorized lifecycle pushes are exactly the failure class BUT-438 fixed for win-back.
  The digest reuses the win-back route AND the win-back category, so digest opt-out is effectively
  only honored for the in-app doc, not the push — a preference-fidelity gap that can read as
  "I turned digests down but still get pushed" or couples two distinct lifecycle channels.
- fix: Add a `digest` notification category to the BUT-438 typed contract + preference model, gate
  the digest push on it, and pass that category to both `evaluateSendGate` and
  `sendPushToUserRespectingPreferences`. Until then, document the coupling as an accepted deviation.
- evidence: functions/src/analytics/send-activity-digest.ts:71–78, :144–150, :169–184

### Win-back conversion attribution can mis-credit a variant after a same-day re-fire
- type: bug  area: win-back attribution correctness  priority: Medium
- pass: 2
- finding: `detect-lapsed-users.ts` overwrites the four `lastWinBack*` bridge fields on every
  threshold trigger and deliberately does NOT gate on their presence (file header, lines 19–22;
  write at lines 228–238). A user who crosses two thresholds close together (e.g. inactivity
  detected at the 14-day window after a 7-day send was still un-attributed) has the bridge fields
  overwritten with the newer variant/bucket. The client `WinbackAttributionService.bootstrap`
  only reads the fields once per cold start (winback_attribution_service.dart:132) and attributes
  the **first** meaningful action to whatever variant was last written — which may be the *moderate*
  variant even though the *mild* push is what actually drove the return. The single-attribution-
  per-session latch (line 218) then clears all fields, discarding the earlier send's credit
  entirely. No per-send attribution record is kept server-side; the bridge is last-write-wins.
- why: This is the measurement loop the whole BUT-688/691 win-back A/B exists to feed. Last-write-
  wins on the bridge means the A/B test can systematically mis-attribute conversions to the
  later/stronger variant whenever dormancy stages overlap inside the 7-day window — biasing the
  experiment toward "strong" copy and corrupting variant-level conversion rates.
- why-not-already-tracked: BUT-934/BUT-438 cover copy and prefs; the dossier watch-items list
  review-event blindness and RC-runbook gaps, not this overwrite-vs-attribution race. New angle.
- fix: Either (a) don't overwrite bridge fields while an un-attributed send is still inside its
  window (skip the merge if `lastWinBackSentAt` is recent and unconverted), or (b) move to an
  append-only per-send attribution log (e.g. `users/{uid}/winback_sends/{auto}`) and attribute the
  conversion to the nearest preceding send, instead of a single mutable bridge doc.
- evidence: functions/src/analytics/detect-lapsed-users.ts:19–22, :228–238;
  lib/services/analytics/winback_attribution_service.dart:132, :192–236

---

COVERAGE: All 10 owned files reviewed across both passes (5 analytics CFs incl. winback-context,
deep_link_handler, acquisition_milestone, winback_attribution_service, in_app_review_service,
keywords.txt). 4 NEW findings (1 High, 2 Medium, 1 Low); 3 candidates investigated and dropped as
non-bugs; 6+ dossier/tracked items deliberately not re-filed. Store-listing/keyword/Play-safety
gaps intentionally excluded per no-store-submission memory.
