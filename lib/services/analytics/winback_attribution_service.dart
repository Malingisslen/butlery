/// Win-back conversion attribution (BUT-691).
///
/// Closes the measurement loop for the server-side win-back push
/// pipeline (BUT-688). The Cloud Function in
/// `functions/src/analytics/detect-lapsed-users.ts` stamps four
/// bridge fields on `users/{uid}` whenever a win-back push fires:
///
///   - `lastWinBackVariant`  (e.g. `baseline`, `curiosity`)
///   - `lastWinBackChannel`  (`push`; future-proof for `email` once
///                            BUT-686 ships)
///   - `lastWinBackBucket`   (one of `win_back_mild | win_back_moderate
///                            | win_back_strong`)
///   - `lastWinBackSentAt`   (server `Timestamp`)
///
/// On every cold start the client calls [bootstrap], which reads those
/// fields. If they exist AND `sentAt` is within the 7-day attribution
/// window, the helper:
///   1. Caches the four fields in memory for the remainder of the
///      session.
///   2. Calls [ExperimentAssignment.setExperimentAssignment] with
///      `experimentName: 'winback_copy'` so the FA dashboard slices
///      every event for this session by `exp_winback_copy = <variant>`.
///
/// Then [AnalyticsService.logEvent] (line 155-ish) probes every event
/// via [attemptAttribution]. The first event whose name is in the
/// "meaningful actions" set ([_meaningfulActions]) emits
/// `winback_converted` with the five spec params and clears the
/// bridge fields on the user doc to prevent double-counting if the
/// user later returns and the same session never gets re-bootstrapped.
///
/// Single-attribution-per-session is enforced via
/// [_attributedThisSession]. A self-recursion guard short-circuits
/// the `winback_converted` event itself so emitting one doesn't
/// re-trigger probing.
///
/// **Failure semantics**: every operation here is best-effort. The
/// caller in `AnalyticsService.logEvent` does not `await` us, so a
/// thrown error would surface as an unhandled future. We swallow
/// everything internally — analytics misses are infinitely preferable
/// to crashing a real-user-action event path.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/experiment_assignment.dart';
import 'package:butlery/services/analytics_service.dart';

/// In-memory snapshot of the four bridge fields read at session start.
class _WinbackContext {
  final String variant;
  final String channel;
  final String bucket;
  final DateTime sentAt;

  const _WinbackContext({
    required this.variant,
    required this.channel,
    required this.bucket,
    required this.sentAt,
  });
}

class WinbackAttributionService extends BaseService {
  final AnalyticsService _analytics;
  final ExperimentAssignment _experimentAssignment;
  final FirestoreRepository _firestoreRepository;

  /// Attribution window — server-side `detect-lapsed-users.ts` re-fires
  /// at most once per dormancy stage, so 7 days comfortably covers the
  /// expected return-to-app window. Mirrors what the dashboard query
  /// will use to slice `winback_converted` against `lastWinBackSentAt`.
  static const Duration _attributionWindow = Duration(days: 7);

  /// Events whose first occurrence within the window counts as a
  /// "meaningful action". Compile-time constant — additions require a
  /// product decision (the more we add, the noisier the attribution).
  static const Set<String> _meaningfulActions = <String>{
    AnalyticsEvents.recipeCooked,
    AnalyticsEvents.importSuccess,
    AnalyticsEvents.menuGenerated,
  };

  _WinbackContext? _context;
  String? _userId;
  bool _attributedThisSession = false;
  int _clearFieldsCallCount = 0;

  WinbackAttributionService({
    required AnalyticsService analytics,
    required ExperimentAssignment experimentAssignment,
    required FirestoreRepository firestoreRepository,
  })  : _analytics = analytics,
        _experimentAssignment = experimentAssignment,
        _firestoreRepository = firestoreRepository;

  @override
  String get serviceName => 'WinbackAttributionService';

  /// True after [bootstrap] resolved a fresh win-back send for the user.
  /// AnalyticsService uses this as a fast-path so the 99% of users with
  /// no win-back context don't pay even the method-call cost of
  /// [attemptAttribution] on every analytics event.
  bool get hasContext => _context != null && !_attributedThisSession;

  /// Visible for testing — the cached variant from the last successful
  /// bootstrap, or null if no win-back fields were present / window
  /// was stale.
  String? get debugCachedVariant => _context?.variant;

  /// Visible for testing — whether the single-attribution-per-session
  /// invariant has been tripped.
  bool get debugAttributed => _attributedThisSession;

  /// Visible for testing — count of `_clearFields` invocations. Used by
  /// tests to assert clear-side-effects without depending on the exact
  /// FieldValue.delete behavior of fake_cloud_firestore.
  int get debugClearFieldsCalls => _clearFieldsCallCount;

  /// Read the four bridge fields from `users/{userId}` and either:
  ///   - cache + assign the experiment (if within window), or
  ///   - clear the user doc fields (if stale), or
  ///   - no-op (if no fields set).
  ///
  /// Should be called once per cold start, after the user is logged in
  /// and Firestore is reachable. Network failures are swallowed.
  Future<void> bootstrap({required String userId}) async {
    if (userId.isEmpty) return;
    _userId = userId;

    await executeServiceOperation<void>(
      () async {
        final docRef = _userDocRef(userId);
        final snapshot = await _firestoreRepository.getDocument(docRef);

        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;

        final variant = data['lastWinBackVariant'];
        final channel = data['lastWinBackChannel'];
        final bucket = data['lastWinBackBucket'];
        final sentAtRaw = data['lastWinBackSentAt'];

        // Variant + sentAt are the only strictly-required fields; the
        // CF always writes all four together, but we tolerate partial
        // writes (e.g. a future migration that backfills only some).
        if (variant is! String || variant.isEmpty) return;
        final sentAt = _coerceTimestamp(sentAtRaw);
        if (sentAt == null) return;

        final age = DateTime.now().difference(sentAt);
        if (age > _attributionWindow) {
          // Out-of-window: clear so future sends are not confounded
          // by dead bridge state. Do NOT call ExperimentAssignment —
          // assigning a stale variant would pollute the live session.
          await _clearFields(userId);
          return;
        }

        _context = _WinbackContext(
          variant: variant,
          channel: (channel is String && channel.isNotEmpty) ? channel : 'push',
          bucket: (bucket is String && bucket.isNotEmpty) ? bucket : 'unknown',
          sentAt: sentAt,
        );

        // Slice the entire session by the variant — this is the FA
        // user-property side of the bridge that the server cannot set
        // directly. See ExperimentAssignment for the per-session dedup.
        await _experimentAssignment.setExperimentAssignment(
          experimentName: 'winback_copy',
          variant: variant,
        );
      },
      operationName: 'Bootstrap winback attribution',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Probe a single event. Called fire-and-forget from
  /// [AnalyticsService.logEvent]; must never throw upward (the caller
  /// does not await us, and an unhandled future would surface in
  /// `runZonedGuarded` as a noisy crash for what is fundamentally
  /// a metrics best-effort).
  Future<void> attemptAttribution(String eventName) async {
    // Self-recursion guard (belt-and-suspenders): also covered by the
    // _attributedThisSession latch below, but checking the name first
    // skips the work entirely on the conversion event path.
    if (eventName == AnalyticsEvents.winbackConverted) return;
    if (_attributedThisSession) return;
    final ctx = _context;
    if (ctx == null) return;
    if (!_meaningfulActions.contains(eventName)) return;

    final userId = _userId;
    if (userId == null || userId.isEmpty) return;

    final hoursSinceSend = DateTime.now().difference(ctx.sentAt).inHours;

    // Re-check window — bootstrap may have happened ~6.9d ago and the
    // session held open until day 8. Out-of-window: clear and skip.
    if (DateTime.now().difference(ctx.sentAt) > _attributionWindow) {
      await _safe(() => _clearFields(userId), 'clear stale fields');
      _context = null;
      return;
    }

    // Latch BEFORE emitting so a failed emit doesn't open the door to
    // double-counting on a subsequent retry. Worst case we miss one
    // conversion; we'd rather miss than over-count.
    _attributedThisSession = true;

    await _safe(
      () => _analytics.logEvent(
        name: AnalyticsEvents.winbackConverted,
        parameters: <String, Object>{
          'channel': ctx.channel,
          'variant': ctx.variant,
          'bucket': ctx.bucket,
          'hours_since_send': hoursSinceSend,
          'action_type': eventName,
        },
      ),
      'emit winback_converted',
    );

    await _safe(() => _clearFields(userId), 'clear bridge fields');
    _context = null;
  }

  /// Best-effort `FieldValue.delete()` on the four bridge fields.
  /// Uses the `FirestoreRepository`-provided firestore handle (avoids
  /// `FirebaseFirestore.instance` per `lib/repositories/CLAUDE.md`).
  /// Single document write — DocumentReference comes from the repo;
  /// the `update` call itself goes directly through the SDK.
  Future<void> _clearFields(String userId) async {
    _clearFieldsCallCount++;
    final docRef = _userDocRef(userId);
    await docRef.update(<String, Object?>{
      'lastWinBackVariant': FieldValue.delete(),
      'lastWinBackChannel': FieldValue.delete(),
      'lastWinBackBucket': FieldValue.delete(),
      'lastWinBackSentAt': FieldValue.delete(),
    });
  }

  DocumentReference<Map<String, dynamic>> _userDocRef(String userId) {
    return _firestoreRepository.firestore
        .collection(FirestoreCollections.users)
        .doc(userId);
  }

  /// Tolerant timestamp coercion — server writes `Timestamp`, but tests
  /// (and theoretical future migrations) may use ISO strings or millis.
  static DateTime? _coerceTimestamp(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  Future<void> _safe(Future<void> Function() op, String label) async {
    try {
      await op();
    } catch (e) {
      AppLogger.warning('WinbackAttributionService.$label failed: $e');
    }
  }
}
