/// Lifecycle-stage cohort classifier (BUT-639).
///
/// Pure, deterministic, no I/O. Wire-up code (bootstrap, post-cook hooks)
/// owns the data fetch + emission; this file only owns the rules so they
/// can be unit-tested without Firebase or DI.
///
/// Stages and priority order (top wins on ambiguous overlap):
///   1. `churned`  — last cook >30 days ago
///   2. `dormant`  — last cook 14-30 days ago (inclusive of day 14)
///   3. `habitual` — 3+ cooks in the last 14 days
///   4. `activated`— first cook within 7 days of signup
///   5. `new_`     — fallback (signed up, no qualifying activity)
///
/// Priority matters: a user with 5 cooks last month but lastCookAt=40d
/// classifies as `churned`, not `habitual`. That's intentional — the
/// "stale" signal dominates because re-engagement campaigns key off it.
library;

/// Lifecycle cohort bucket — emitted as the `lifecycle_stage` user property.
/// Trailing underscore on `new_` because `new` is a Dart keyword.
enum LifecycleStage {
  new_,
  activated,
  habitual,
  dormant,
  churned
  ;

  /// Wire value emitted to Firebase Analytics. Strips the trailing
  /// underscore so dashboards see a clean `new` bucket.
  String get wireValue => this == LifecycleStage.new_ ? 'new' : name;
}

/// Classify a user into a [LifecycleStage] cohort.
///
/// All inputs are nullable / scalar so callers can pass whatever they have:
/// a fresh signup with no cooks yet still classifies cleanly as `new_`.
///
/// [now] is injected for testability — callers in production pass
/// `DateTime.now()`, tests pin a fixed instant.
LifecycleStage classifyLifecycleStage({
  required DateTime? signupAt,
  required DateTime? lastCookAt,
  required int cooksLast14Days,
  required DateTime now,
}) {
  // Missing signup is the strongest "we don't know" signal — classify as
  // new_ rather than guess. Avoids false-positive churn for legacy users
  // with a missing joinedAt field.
  if (signupAt == null) {
    return LifecycleStage.new_;
  }

  // Stage 1: churned (>30 days since last cook). Priority over everything
  // else because re-engagement messaging only makes sense for inactive
  // users — recency dominates frequency.
  if (lastCookAt != null) {
    // Compare full Durations (millisecond precision), not `.inDays`.
    // `.inDays` truncates toward zero, so a last-cook 30d12h ago yields
    // 30 and misclassifies a churned user (elapsed > 30d) as dormant —
    // the whole [30d, 31d) window collapsed onto the boundary. Duration
    // comparison keeps churned strictly >30d and dormant [14d, 30d].
    final sinceLastCook = now.difference(lastCookAt);
    if (sinceLastCook > const Duration(days: 30)) {
      return LifecycleStage.churned;
    }
    // Stage 2: dormant (14-30 days inclusive on the 14d boundary).
    // 14d is the same window as "habitual cooks last 14 days" — by
    // checking lastCookAt first we avoid the edge where cooksLast14Days
    // is 0 but lastCookAt happens to be 13.5 days ago.
    if (sinceLastCook >= const Duration(days: 14)) {
      return LifecycleStage.dormant;
    }
  } else {
    // Never cooked — if signed up >30 days ago, treat as churned;
    // 14-30 days ago, dormant; otherwise fall through to new_.
    final sinceSignup = now.difference(signupAt);
    if (sinceSignup > const Duration(days: 30)) return LifecycleStage.churned;
    if (sinceSignup >= const Duration(days: 14)) return LifecycleStage.dormant;
  }

  // Stage 3: habitual (3+ cooks in the last 14 days). Checked AFTER
  // recency so a stale-but-prolific user still classifies as dormant/churned.
  if (cooksLast14Days >= 3) {
    return LifecycleStage.habitual;
  }

  // Stage 4: activated (first cook within 7d of signup). Requires a
  // first cook to exist; without lastCookAt there is no activation.
  if (lastCookAt != null) {
    final activationWindow = signupAt.add(const Duration(days: 7));
    if (!lastCookAt.isAfter(activationWindow)) {
      return LifecycleStage.activated;
    }
  }

  // Stage 5: new_ — signed up, no qualifying activity yet.
  return LifecycleStage.new_;
}
