/// A/B experiment assignment helper (BUT-657).
///
/// Centralizes the convention for stamping experiment variants onto a
/// user so dashboards and downstream queries can slice events by
/// `exp_<experimentName> = <variant>`. Production callers (e.g. the
/// future BUT-688 win-back A/B) will resolve the variant from Remote
/// Config on their own and call [setExperimentAssignment] once per
/// session per experiment.
///
/// Contract:
///   1. Sets a Firebase Analytics user property
///      `exp_<sanitizedExperimentName>` = `variant` via the gated
///      [AnalyticsService.setUserProperty] (so GDPR consent applies —
///      pre-consent the call silently no-ops, no fingerprint leak).
///   2. Logs the `experiment_assigned` event with
///      `{experiment_name, variant}` — also gated.
///   3. The event is **de-duped per session per experiment** via an
///      in-memory set. No Firestore round-trip; the cost of an extra
///      event firing on a process restart is acceptable (≤1/session)
///      vs. the latency / cost of a server check.
///
/// Sanitization:
///   - Firebase Analytics property names cap at 24 chars and accept
///     `[A-Za-z0-9_]`, must start with a letter. The `exp_` prefix
///     consumes 4 → name budget is 20.
///   - The raw `experimentName` is lowercased, non-`[a-z0-9]` runs
///     are collapsed to `_`, leading/trailing `_` trimmed, then
///     truncated to 20 chars. Result is stable for a given input and
///     preserves the prefix invariant.
library;

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';

class ExperimentAssignment {
  final AnalyticsService _analytics;

  /// Per-session de-dup set. Keyed by `<sanitizedName>=<variant>` so
  /// re-assignment to a *different* variant in the same session
  /// re-emits (rare, but possible if RC changes mid-session).
  final Set<String> _emittedThisSession = <String>{};

  ExperimentAssignment(this._analytics);

  /// Visible for testing — exposes the dedup set so tests can assert
  /// session boundaries deterministically. Production callers should
  /// not rely on this.
  Set<String> get debugEmittedKeys => Set.unmodifiable(_emittedThisSession);

  /// Maximum length of the property-name suffix after the `exp_` prefix.
  static const int _maxNameSuffixLen = 24 - 4; // 20

  /// Assign [variant] to [experimentName] for the current user.
  ///
  /// Calls in succession with the same `(name, variant)` pair within a
  /// session emit the event exactly once. Either argument empty → no-op.
  Future<void> setExperimentAssignment({
    required String experimentName,
    required String variant,
  }) async {
    if (experimentName.isEmpty || variant.isEmpty) {
      AppLogger.warning(
        'ExperimentAssignment: empty experimentName or variant — skipping',
      );
      return;
    }

    final sanitized = _sanitize(experimentName);
    if (sanitized.isEmpty) {
      AppLogger.warning(
        'ExperimentAssignment: experimentName "$experimentName" sanitized to empty — skipping',
      );
      return;
    }

    final propertyName =
        '${AnalyticsUserProperties.experimentPrefix}$sanitized';
    final dedupKey = '$sanitized=$variant';
    final alreadyEmitted = _emittedThisSession.contains(dedupKey);

    // Always set the user property — re-runs are cheap (FA stores the
    // latest value) and this guarantees the slice reaches FA even if
    // a prior set was dropped (network blip).
    try {
      await _analytics.setUserProperty(name: propertyName, value: variant);
    } catch (e) {
      AppLogger.warning('ExperimentAssignment.setUserProperty failed: $e');
    }

    if (alreadyEmitted) {
      return;
    }

    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.experimentAssigned,
        parameters: <String, Object>{
          'experiment_name': sanitized,
          'variant': variant,
        },
      );
      _emittedThisSession.add(dedupKey);
    } catch (e) {
      AppLogger.warning('ExperimentAssignment.logEvent failed: $e');
      // Do NOT add to the dedup set on failure — next call should retry.
    }
  }

  /// Sanitize an experiment name into a Firebase-Analytics-safe slug.
  ///
  /// - Lowercase
  /// - Non-`[a-z0-9]` collapsed to `_`
  /// - Leading non-letters stripped (FA requires a letter prefix; with
  ///   the `exp_` prefix this is also satisfied, but we keep the
  ///   suffix itself letter-led for clarity in dashboards)
  /// - Trailing `_` trimmed
  /// - Truncated to [_maxNameSuffixLen]
  static String _sanitize(String raw) {
    final lower = raw.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final trimmed = cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
    if (trimmed.isEmpty) return '';
    final truncated = trimmed.length > _maxNameSuffixLen
        ? trimmed.substring(0, _maxNameSuffixLen)
        : trimmed;
    // Trim a trailing `_` that may have been introduced by truncation.
    return truncated.replaceAll(RegExp(r'_+$'), '');
  }
}
