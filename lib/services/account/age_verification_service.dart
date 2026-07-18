import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/services/auth_service.dart';

/// BUT-1386 (ADR-0002): client wrapper for the server-side `verifySignupAge`
/// callable. The Cloud Function is the single authority for the age gate and
/// the sole writer of `birthYear` — the client no longer writes it directly.
///
/// Flow:
///   1. Send `{ birthYear }` to the callable (region europe-west1).
///   2. On `compliant: true` the CF has set the `ageCompliant:true` custom auth
///      claim and written `birthYear` server-side. The client MUST then
///      force-refresh the ID token so the new claim is present BEFORE the user
///      can reach any UGC-posting screen (comments/messages/friend-requests/
///      ratings) — otherwise the stale token lacks the claim and the first
///      write is denied by firestore.rules.
///   3. On `compliant: false` the CF has ALREADY DELETED the user's Auth
///      account server-side (under-15). The session is now invalid; the caller
///      shows a quiet rejection and returns the user to the start screen.
///
/// Infrastructure errors (HttpsError: invalid-argument / resource-exhausted /
/// internal) propagate as [FirebaseFunctionsException] so the caller can
/// surface a generic retry error and NOT proceed into the app.

/// Outcome of a [AgeVerificationService.verifyAge] call.
///
/// BUT-1454: carries [isMinor] alongside [compliant] so onboarding can stamp a
/// compliant 15–17-year-old's profile as a minor at completion — which makes
/// `public_profiles.isSearchable` serialize false (default-private search). On
/// a rejection the account is already deleted, so [isMinor] is meaningless and
/// reported false.
class AgeVerificationResult {
  const AgeVerificationResult({
    required this.compliant,
    required this.isMinor,
  });

  final bool compliant;
  final bool isMinor;
}

class AgeVerificationService extends BaseService {
  @override
  String get serviceName => 'AgeVerificationService';

  final AuthService _authService;
  final FirebaseFunctions _functions;
  static const String _logTag = 'AgeVerificationService';
  static const String _callableName = 'verifySignupAge';

  AgeVerificationService({
    required AuthService authService,
    required FirebaseFunctions functions,
  }) : _authService = authService,
       _functions = functions;

  /// Verify [birthYear] against Butlery's age floor via the CF.
  ///
  /// Returns [AgeVerificationResult.compliant] `true` when the account is
  /// compliant (>= 15). On compliance the ID token is force-refreshed so the
  /// `ageCompliant` claim lands before any UGC write, and
  /// [AgeVerificationResult.isMinor] reports whether the caller is a compliant
  /// 15–17-year-old (BUT-1454, so onboarding can suppress search). Returns
  /// `compliant: false` when the CF rejected the account as under-15 (it has
  /// already deleted the Auth record server-side).
  ///
  /// Rethrows [FirebaseFunctionsException] / other errors so the caller can
  /// distinguish an infrastructure failure (retry) from a definite under-15
  /// rejection.
  Future<AgeVerificationResult> verifyAge(int birthYear) async {
    final callable = _functions.httpsCallable(_callableName);
    final response = await callable.call<Map<dynamic, dynamic>>({
      'birthYear': birthYear,
    });

    final compliant = response.data['compliant'] == true;
    final isMinor = response.data['isMinor'] == true;

    if (compliant) {
      // Force-refresh so the freshly-minted `ageCompliant:true` claim is in the
      // token before the user can reach any UGC-posting screen. Best-effort:
      // Firebase auto-refreshes within the hour and on the next write attempt,
      // so a transient refresh hiccup must not block onboarding completion.
      final refreshed = await _authService.refreshSession();
      if (!refreshed) {
        app_logger.AppLogger.warning(
          '[$_logTag] Token force-refresh after age verification did not '
          'complete; the ageCompliant claim may lag until the next refresh.',
        );
      }
    }

    return AgeVerificationResult(compliant: compliant, isMinor: isMinor);
  }
}
