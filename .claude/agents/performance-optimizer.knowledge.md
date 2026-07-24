# performance-optimizer — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every performance task and **APPEND** to it when it
discovers a new bottleneck, fixes a real perf bug, or is corrected by the
user.

## How to update this file

- **This file holds principles and is meant to be REWRITTEN** — edit a principle in place when it changes; never let the file grow by restatement. The dated raw record (device class, before/after numbers) lives in `performance-optimizer.knowledge.archive.md`, which IS append-only.
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

### 2026-04-26 — image cache size + WebP conversion (BUT-470, BUT-429)

**Device class**: tablets/desktop (large grid views) — primary win;
Android phones see incremental relief. Measurements taken on developer
workstation only — install-size delta and runtime cache-thrash deltas
from real devices to be confirmed by next-build CI metrics.

**Bottleneck 1 — image-cache thrash on grids**:
- `PaintingBinding.imageCache.maximumSize` was 100. On a tablet grid
  rendering ~150 thumbnails on screen + scroll, the LRU cache would evict
  before the offscreen items came back into view, causing redundant
  decode work and visible flicker on fast scroll-up.
- Fix: bumped maximumSize 100 → 300 in `lib/main.dart` line 142.
  `maximumSizeBytes` (50 MB) unchanged — that's still the hard ceiling.
- Why 300, not unbounded: the byte cap is the real safety net; the count
  cap just prevents thrash on small thumbnails. 300 is a heuristic that
  matches the largest realistic on-screen count (recipe grid + cards
  above + cards below the fold).

**Bottleneck 2 — illustration asset weight**:
- 12 PNGs in `assets/illustrations/` totaled 11,042,648 bytes
  (~10.5 MB). Bundled into APK + web build per shipped variant.
- Converted to WebP at quality 85 via Pillow 12.2.0
  (`img.save(dst, "WEBP", quality=85, method=6)`).
- After: 663,926 bytes (~650 KB). **Saved 10,378,722 bytes (94.0%)** of
  illustration weight.
- Per-file deltas (PNG → WebP):
  - rodbeta: 2,176,586 → 110,068 (94.9%)
  - bar:     2,147,600 → 106,230 (95.1%)
  - sparris: 1,473,618 → 101,704 (93.1%)
  - kal:     1,303,209 →  89,708 (93.1%)
  - citrus:  1,156,022 →  59,898 (94.8%)
  - pumpa:   1,056,210 →  62,224 (94.1%)
  - rabarber:  924,104 →  63,590 (93.1%)
  - broccoli:  244,423 →  18,128 (92.6%)
  - rodlok:    157,552 →  13,090 (91.7%)
  - champinjon:156,068 →  12,256 (92.1%)
  - morot:     153,002 →  15,812 (89.7%)
  - artskida:   94,254 →  11,218 (88.1%)

**Pattern: when to skip WebP conversion**:
- Animation frames (e.g. `assets/illustrations/arta/artskida{0..5}.PNG`)
  — quality-85 lossy compression can introduce small artifacts that
  compound visually across rapidly cycling frames. Leave PNG.
- App icons / splash images — toolchain expects PNG, switching costs
  more than it saves.
- Photos with very fine detail (text, grids) — verify visually before
  shipping; q=85 is fine for hand-drawn illustrations but can be too
  aggressive for photographic content.

**Pubspec note**: directory-level asset declarations (`assets/foo/`)
auto-pick up format changes. No `pubspec.yaml` edit required when files
swap extension within an already-declared directory. Saved a class of
"forgot to update pubspec" CI failures.

**Tooling note**: `cwebp` not on Windows dev boxes by default. Pillow
fallback (`pip install Pillow` then `Image.open(...).save(..., "WEBP",
quality=85, method=6)`) is reliable and ~94% size reduction matches
cwebp at the same quality.

### 2026-06-13 — isolate offload for SwedishLineClassifier (BUT-862)

**Context**: 3 hot-path candidates for `compute()` / `Isolate.run()`.

**Step-0 classification (plugin-isolate reality check)**:

1. **Recipe-text parser (SwedishLineClassifier / rule-based tier)**
   — pure Dart. No `flutter_onnxruntime`, no `rootBundle`, no
   platform channels. Dependencies: only `dart:math`, `dart:convert`,
   `crypto`, `clock`, `known_ingredients.dart` (static const), etc.
   Input: `String`. Output: `ParsedRecipeStructure` (primitives only —
   `String?`, `List<String>`, `int?`, `Duration?`).
   VERDICT: offloadable.

2. **CRF inference loop (CrfViterbiDecoder / CrfIngredientParser)**
   — **also** pure Dart (weights loaded from bundled JSON via
   `rootBundle` in `IngredientParsingStrategy._ensureInitialized()`).
   The Viterbi decoder itself is pure Map/List arithmetic, no plugin
   calls. HOWEVER: `IngredientParsingStrategy` uses `rootBundle`
   (a platform channel) to bootstrap the weights, and holds mutable
   state across calls (`_crfParser`, `_neuralParser` etc.) that cannot
   cross an isolate boundary. The decoder _instance_ is non-sendable.
   Wrapping the decoder alone would require re-loading weights on every
   `compute()` call (expensive). The existing `ingredient_parsing_strategy`
   also chains to the BERT NER ONNX model on uncertain lines.
   VERDICT: not offloaded this pass. If needed later, extract a
   stateless `CrfViterbiDecoder.decodeAll(weights, lines)` top-level
   function that takes serialized weights and returns labels.

3. **OCR post-processor (OcrErrorCorrector.correctLine/Lines)**
   — pure Dart (string→string, static const tables, no plugin calls).
   But: it runs per-ingredient-line, O(words × confusions), and is
   already fast (<1ms per line). The overhead of spawning an isolate
   would exceed the work being done. VERDICT: not worth isolate overhead.
   The ONNX-based NER + line-classifier (`OnnxNerService`,
   `OnnxLineClassifierService`) both use `flutter_onnxruntime` plugin
   and are hard-excluded from isolate offload.

**What was implemented**: `compute(parseStructureInIsolate, text)` for
the rule-based tier path in `ParsingContext.parseStructureCachedAsync`.

- Top-level worker function `parseStructureInIsolate(String text)`
  added to `lib/services/parsing/parsers/swedish_line_classifier.dart`.
- `ParsedRecipeStructure.toIsolateMap()` / `fromIsolateMap()` for
  primitive-safe isolate boundary crossing (`Duration` encoded as int
  minutes).
- `parsing_context.dart` now imports `flutter/foundation.dart` for
  `compute` and calls `compute(parseStructureInIsolate, text)` on the
  rule-based fallback path. Neural (ONNX) path unchanged.
- Public API (`parseStructureCachedAsync`) unchanged — callers see no
  difference.

**Tests**: 521 parsing unit tests + 18 arch tests — all pass unchanged.

**Profiler confirmation PENDING**: actual jank delta (ms on main
thread for long Instagram caption, before/after) requires
`flutter run --profile` + DevTools on device. Not measurable headless.
Estimated win for a 100-line recipe text: ~30–80ms off the main thread
(per rough profiler observation from similar workloads — not measured
in this session). Mark for In-Review manual smoke test.

**Device class measured**: not yet measured on device (headless session).
Numbers to fill in after manual profiling.

### 2026-07-12 — executeAsync* guards only at ENTRY: subscription created after internal awaits leaks on dispose-during-startup (BUT-1461)

**Pattern (Critical / dangling Firestore listener):** a fire-and-forget async
initializer (`..startListening()` from `initState`) that awaits one or more reads
BEFORE assigning its `StreamSubscription` can leak the subscription if the view is
disposed during those awaits.

`BaseViewModel.executeAsync` / `executeAsyncVoid` check `_isDisposed` **only once at
entry** (`base_viewmodel.dart:213` / `:175`) — they do NOT re-check across the awaits
inside the operation closure. So this sequence leaks:

1. `startListening()` parks on `await ensureForUser()` / `await getRoster()` (real
   network round-trips on a cold open).
2. User navigates away → `dispose()` runs `_subscription?.cancel()` while
   `_subscription` is still `null` → no-op. `_isDisposed = true`.
3. Awaits resolve; the closure keeps running (no re-check) and creates
   `service.watch(...).listen(...)`, assigning a **live snapshots() subscription to an
   already-disposed VM**. Nothing ever cancels it → ongoing per-listener Firestore read
   cost + the `.listen` closure retains the VM in memory.

The emission callback's `if (isDisposed) return` does NOT save you — it makes each
emission a no-op but the subscription stays open and billing reads.

**Fix:** re-guard the async gap right after the last pre-subscription await, before
creating/assigning the subscription:
```dart
_roster = await _rosterService.getRoster(household.id);
if (isDisposed) return;            // bail if disposed during the reads
await _subscription?.cancel();
_subscription = service.watch(...).listen(...);
```

**Generalization:** any subscription/timer/controller whose creation sits AFTER an
`await` inside an `executeAsync*` body needs an explicit `if (isDisposed) return;`
immediately before the creation — the base-class entry guard is not enough. Grep target:
`.listen(` or `Timer(` that follows an `await` inside an `executeAsync`/`executeAsyncVoid`
closure. (Found by review; not yet profiled on device — the cost is an uncancelled
Firestore listener, confirmable in DevTools Memory by push/pop of a recipe detail with a
throttled network so the reads are slow.)
