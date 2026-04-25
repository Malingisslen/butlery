# performance-optimizer — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every performance task and **APPEND** to it when it
discovers a new bottleneck, fixes a real perf bug, or is corrected by the
user.

## How to update this file

- **Append-only** — never delete entries; supersede with a newer dated entry.
- **Date every entry** — `### YYYY-MM-DD — short title`.
- **For perf wins, record the measurement** — "X ms → Y ms on Z device" or
  "Y rebuilds → 1 rebuild." Numbers age better than adjectives.

---

## Performance non-negotiables

- Target: **60fps** on the user's primary device class (mid-range Android).
- Memory: no leaks across navigations — verify by pushing/popping a route
  10× and watching `flutter devtools` allocator.
- Cold start: aim for sub-2s on mid-range Android.

## Standard anti-patterns (already in agent file — summarized)

- Heavy work in `build()` — extract, cache, or move to a ViewModel.
- `ListView` with children for long lists — always `ListView.builder`.
- Missing `const` on stable subtrees — Flutter rebuilds them every frame.
- Missing `RepaintBoundary` on expensive isolated widgets.
- `notifyListeners()` in a loop — debounce or batch.
- Stream subscriptions without cancellation in `dispose()`.
- Image loaded full-resolution into a thumbnail slot — use
  `cached_network_image` with `memCacheWidth` / `memCacheHeight`.
- Unnecessary `setState` calls (selective rebuilds via Provider/Selector).

## Firebase-specific perf patterns

- **Pagination**: every collection-level read on a user-facing path needs
  `limit()` and pagination cursors.
- **Indexes**: confirm composite indexes exist in `firestore.indexes.json`
  before deploying a query that filters+sorts on multiple fields.
- **No client-side filtering** when a server-side `where()` would do.
- **Batch writes** for multi-doc updates (limit 500 ops per batch).
- **Optimistic updates** for user-facing actions — display the change
  immediately, reconcile on success/failure.
- **Offline persistence** — Firestore caches by default; check it isn't
  disabled in `main.dart` boot path.

## Profiling toolchain

- `flutter run --profile` for representative measurements (NOT debug —
  debug builds are misleading for perf).
- DevTools → Performance tab → record a typical user flow.
- DevTools → Memory tab → for leak suspicions.
- `dart devtools --vm-service-uri=...` for explicit VM connection.

## Severity tagging

- **Critical** — visible jank (<60fps), memory leak, OOM crash, app freeze.
- **High** — perceptible bottleneck (slow page transition, list scroll
  drop), unnecessary rebuilds in a hot path.
- **Medium** — optimization opportunity (would help on lower-end device).
- **Low** — micro-optimization (rarely worth the readability cost).

Always include profiler recommendations and concrete code improvements.

---

## Discovered patterns

*Append new dated entries below as the agent learns them. For each entry,
record: device class measured on, before/after numbers if any, and the
concrete code change that produced the win.*

### 2026-04-25 — initial seed
Knowledge file seeded from `performance-optimizer.md` and standard Flutter
perf guidance. Future entries should record real bottlenecks found in
this codebase with measurements, not generic advice — generic advice
already lives in the main agent file.
