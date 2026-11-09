import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

enum SessionRevocationOutcome {
  /// Every other device is signed out and this one has a fresh session.
  revoked,

  /// The server wants a sign-in with Google or Apple from the last minutes.
  reauthRequired,
  rateLimited,
  failed,

  /// The server revoked the sessions but this device could not take its new
  /// one; it was signed out the ordinary way and the person signs in again.
  signedOutAfterFailure,

  /// A press while an earlier one is still running.
  busy,
}

/// "Logga ut från alla enheter" (BUT-2481). The server revokes every refresh
/// token of the account and returns a custom token, which this device signs in
/// with so it stays signed in. The token lives only in a local variable and is
/// never logged.
class SessionRevocationService extends ChangeNotifier with StateNotifierMixin {
  final AuthRepository _authRepository;
  final FirebaseFunctions? _functions;
  final Future<void> Function() _signOutAfterFailure;

  /// [signOutAfterFailure] is the ordinary automatic sign-out: it keeps the
  /// person's drafts, because they did not ask to sign out.
  SessionRevocationService({
    required AuthRepository authRepository,
    required Future<void> Function() signOutAfterFailure,
    FirebaseFunctions? functions,
  }) : _authRepository = authRepository,
       _signOutAfterFailure = signOutAfterFailure,
       _functions = functions;

  Future<SessionRevocationOutcome> revokeOtherSessions() async {
    if (isLoading) return SessionRevocationOutcome.busy;
    final functions = _functions;
    if (functions == null) return SessionRevocationOutcome.failed;
    setLoading(true);
    try {
      return await _run(functions);
    } finally {
      setLoading(false);
    }
  }

  Future<SessionRevocationOutcome> _run(FirebaseFunctions functions) async {
    String? token;
    try {
      // The server spends the App Check token (consumeAppCheckToken).
      final result = await functions
          .httpsCallable(
            'revokeOtherSessions',
            options: HttpsCallableOptions(limitedUseAppCheckToken: true),
          )
          .call<dynamic>();
      final data = result.data;
      token = data is Map ? data['customToken'] as String? : null;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.warning('Revoke other sessions refused: ${e.code}');
      return _refusal(e);
    } catch (e) {
      AppLogger.warning('Revoke other sessions failed: ${e.runtimeType}');
      return SessionRevocationOutcome.failed;
    }
    // From here the server has revoked every refresh token, this device's
    // included, so a missing token or a failed swap must end signed out.
    if (token != null && await _swapSession(token)) {
      return SessionRevocationOutcome.revoked;
    }
    AppLogger.warning('Revoke other sessions: signing out this device');
    await _signOutAfterFailure();
    return SessionRevocationOutcome.signedOutAfterFailure;
  }

  /// One retry: the custom token is valid for an hour, so a second try after a
  /// network blip is safe.
  Future<bool> _swapSession(String token) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _authRepository.signInWithCustomToken(token);
        return true;
      } catch (e) {
        AppLogger.warning('Custom token sign-in failed: ${e.runtimeType}');
      }
    }
    return false;
  }

  SessionRevocationOutcome _refusal(FirebaseFunctionsException e) {
    final details = e.details;
    final needsSignIn =
        details is Map && details['code'] == 'requires-recent-login';
    if (needsSignIn) return SessionRevocationOutcome.reauthRequired;
    if (e.code == 'resource-exhausted') {
      return SessionRevocationOutcome.rateLimited;
    }
    return SessionRevocationOutcome.failed;
  }
}
