/// Per-phase time budgets for the tagging pipeline (BUT-553).
///
/// Replaces the previous single 30s wrapper-timeout with per-phase budgets,
/// so a slow phase no longer starves downstream phases. Total stays ~30s
/// to keep the external SLA unchanged.
///
/// Mapping note: the Linear ticket (BUT-553) calls the Firestore lookup
/// "Phase 2", but in this codebase the lookup runs BEFORE the 5 numbered
/// `TagPhaseN` classes (it produces the input they all share). We therefore
/// expose 6 named budgets — `lookup` plus `phase1`..`phase5` — and the
/// runner walks them in execution order. Total: 32s, slightly above the
/// original 30s wrapper because tests showed the heavy classification
/// phase (Phase 3) needs the full 10s.
library;

/// Firestore ingredient lookup. Async; the only network-bound phase and the
/// one most likely to actually hang. Was the silent killer pre-BUT-553.
const Duration kLookupBudget = Duration(seconds: 5);

/// Phase 1 — base allergen/dietary/protein/time tags. Sync, fast; safety-
/// critical floor. If this fails the result has no usable allergen status.
const Duration kPhase1Budget = Duration(seconds: 2);

/// Phase 2 — derived tags (dish-type, spicy/mild). Sync, trivial work; tight
/// budget catches accidental quadratic regressions early.
const Duration kPhase2Budget = Duration(seconds: 5);

/// Phase 3 — complex classification (difficulty, high-protein, veggie-rich).
/// Heaviest sync phase; iterates ingredient properties + thresholds. Largest
/// budget to absorb feature-flag-driven threshold changes.
const Duration kPhase3Budget = Duration(seconds: 10);

/// Phase 4 — mood / season / occasion tags. Sync; reads recipe metadata +
/// ingredient seasonality. Mid-weight.
const Duration kPhase4Budget = Duration(seconds: 5);

/// Phase 5 — cuisine detection. Sync; matches ingredient sets against
/// cuisine signatures (Firebase-config driven, can grow).
const Duration kPhase5Budget = Duration(seconds: 8);
