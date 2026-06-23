# Offline-Mode Audit (BUT-610)

_Audited 2026-06-23 across recipe browse/detail/cooking, import, shopping, and menu._

## TL;DR

**The app does not crash offline** — the worst App-Store-review outcome is already avoided.
Firestore offline persistence is **ON (100 MB)**, so the bulk of reads and writes work offline
automatically (cached reads succeed; writes queue locally and replay on reconnect). The real
gaps are: **(1)** the shopping view's offline banner is dead code (its `isOnline` flag ignores
connectivity), and **(2)** the import flows **hang** for 15–90 s offline before giving feedback.
Both are fixed in this pass. The remainder (offline writes that succeed but show no "pending
sync" hint, plus some cosmetic gaps) are itemized as follow-ups.

## Baseline — what already works offline (no action needed)

| Capability | Status | Where |
| --- | --- | --- |
| Firestore offline persistence | **ON, 100 MB** | `lib/core/bootstrap/firestore_bootstrap.dart:9-12` |
| Cached reads (recipes, menu plans, comments) | automatic via SDK | default `Source.serverAndCache` on `.get()`/`.snapshots()` |
| Offline writes (recipe edits, menu saves, check-offs) | queued + replayed | Firestore pending-writes buffer |
| Connectivity detection | present (mobile; web always-online) | `lib/services/offline/offline_initialization.dart` |
| Offline banner | wired in 16+ views | `LayoutComponents.offlineIndicator()` |
| Auto-sync on reconnect | present | `offline_service.dart` → `OfflineSyncManager.syncPendingChanges()` |
| Drift write-queue + retry/backoff (recipe CRUD) | present | `lib/services/offline/offline_sync_manager.dart` |
| Menu generation offline | works (rule-based, in-memory) | `lib/services/menu_service.dart` — no network/LLM |
| Cooking-mode core (steps, scaling, fonts) | 100 % local | `cooking_mode_view.dart` |

No unguarded null-derefs offline were found; all network image widgets have `errorWidget`
placeholders.

## Findings (severity-ranked)

| Sev | Surface | Issue | Site | Status |
| --- | --- | --- | --- | --- |
| **Bug** | Shopping | `isOnline => !hasError && isInitialized` — ignores connectivity, so the offline banner never shows | `unified_shopping_viewmodel.dart:80` | **FIXED this pass** |
| **Hang** | URL import | No offline pre-check → ~15 s headless-WebView timeout before feedback (×N for batch / +15 s for index probe) | `url_import_viewmodel.dart:289`, `web_scraper.dart:80` | **FIXED this pass** |
| **Hang** | Photo OCR | No offline pre-check → 30–90 s across provider timeouts | `ocr_extraction_service.dart:569`, `photo_import_viewmodel.dart:396` | **FIXED this pass** |
| Hang | Text/social import | 60 s Cloud-Function timeout, no offline pre-check | `import_base_viewmodel.dart:72` | follow-up |
| Broken | Recipe detail | `markAsCooked` queues silently offline but shows success — no "pending" hint | `recipe_cooking_service.dart:45` | follow-up |
| Broken | Recipe detail | Social `rateRecipe`/`removeRating` fails silently offline (error swallowed) | `recipe_detail_viewmodel.dart:496-561` | follow-up |
| Broken | Cooking mode | Substitution sheet opens empty offline with no "unavailable offline" message | `substitution_suggestion_service.dart:73` | follow-up |
| Broken | Recipe browse | RTDB presence bar / cooking-session card vanish offline (RTDB has no read cache) | `family_presence_bar.dart:98`, `mina_recept_view.dart:498` | follow-up |
| Hang | Recipe browse (web) | Cold-start `fetchUserRecipes` on web can spin (JS SDK won't serve `.get()` from cache without `Source.cache`) | `unified_recipe_service.dart:626` | follow-up (web-only) |
| Cosmetic | Cooking mode | No offline banner at all | `cooking_mode_view.dart` (absent) | follow-up |
| Cosmetic | Menu calendar | Never-cached week reads server-first; cache-first would be cleaner | `firebase_weekly_menu_plan_repository.dart:73` | follow-up |
| Cosmetic | Web | `isOnline` always true on web (connectivity_plus stubbed); banner never shows on web | `offline_initialization.dart:59` | follow-up |

## Hardening shipped this pass

1. **Shopping offline awareness** — `isOnline` now reflects the real connectivity signal the
   rest of the app uses, so the offline banner appears/disappears correctly in the shopping view.
2. **Import fast-fail offline** — URL import and photo-OCR import now pre-check connectivity and
   surface an immediate "you're offline" message instead of a 15–90 s silent spinner.

All rows marked _follow-up_ above are tracked in **BUT-1360** (remaining engineering items,
pick up individually).

## Still needs a human (can't be done headless / in CI)

A **real-device airplane-mode pass** — open the app, toggle airplane mode, and walk through:
browse a cached recipe, enter cooking mode, mark-as-cooked, check off a shopping item, attempt
a URL import. Confirm no crash/hang and that pending writes sync on reconnect. Tracked in
**BUT-1361** (same shape as BUT-1179).
