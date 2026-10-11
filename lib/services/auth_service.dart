import 'package:clock/clock.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_account_changes.dart';
import 'package:butlery/services/auth/auth_provider_flows.dart';
import 'package:butlery/services/auth/provider_sign_in_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:get_it/get_it.dart';

/// Firebase authentication service managing login, registration, and session state.
class AuthService extends ChangeNotifier
    with
        StateNotifierMixin,
        AsyncOperationMixin,
        StreamManagementMixin,
        ErrorHandlingMixin,
        AuthAccountChanges,
        AuthProviderFlows {
  final auth_repo.AuthRepository _authRepository;
  final AnalyticsService _analyticsService;
  final ProviderSignInService? _providerSignIn;

  @override
  @protected
  ProviderSignInService? get providerSignIn => _providerSignIn;

  @override
  @protected
  auth_repo.AuthRepository get accountRepository => _authRepository;
  User? _currentUser;
  StreamSubscription<User?>? _authStateSubscription;

  bool _sessionExpired = false; // ignore: prefer_final_fields

  /// A sign-in waiting for its second factor (P6-U09; Skarmar v12 etapp 3
  /// #authmfa). The password was right; the account has two-step
  /// verification, so Firebase handed back a resolver instead of a user.
  MfaResolverInfo? _pendingMfa;

  /// The challenge the sign-in screen must show, or null.
  MfaResolverInfo? get pendingMfaChallenge => _pendingMfa;

  User? get currentUser => _currentUser;
  String? get currentUserDisplayName => _currentUser?.displayName;
  String? get currentUserEmail => _currentUser?.email;
  String? get currentUserPhotoUrl => _currentUser?.photoURL;
  String? get errorMessage => error;
  @override
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;
  String? get currentUserId => _authRepository.currentUserId;

  /// True when a token refresh failed due to revocation — signals VMs to show re-auth prompt.
  bool get sessionExpired => _sessionExpired;

  AuthService({
    auth_repo.AuthRepository? authRepository,
    required AnalyticsService analyticsService,
    ProviderSignInService? providerSignIn,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository(),
       _analyticsService = analyticsService,
       _providerSignIn = providerSignIn {
    _authStateSubscription = _authRepository.authStateChanges().listen(
      (User? user) {
        _currentUser = user;
        // BUT-833: pin analytics user identifier to the authoritative auth
        // stream — fires on cold-start (cached user), sign-in, sign-out, and
        // forced revocation. SDK suppresses the call pre-consent, so calling
        // unconditionally is safe.
        unawaited(_analyticsService.setUserId(user?.uid));
        notifyListeners();
      },
      onError: (error) {
        final code = error is FirebaseAuthException ? error.code : '';
        AppLogger.warning('Auth state stream error (code: $code): $error');
        // BUG-31: only force sign-out when the error genuinely means the
        // credential is revoked/invalid. A transient/one-off auth-stream error
        // (network blip, a single stream hiccup, no FirebaseAuthException code)
        // used to nuke the session mid-flow — including during onboarding —
        // logging the user out for a recoverable error. For those, log and let
        // the stream recover instead of invalidating the session.
        if (!_isFatalAuthStreamError(code)) {
          AppLogger.warning(
            'Auth stream error treated as transient — keeping session',
          );
          return;
        }
        // Invalidate session on a fatal auth stream error to prevent
        // fake-authenticated state where UI shows logged-in but session is broken.
        _currentUser = null;
        // BUT-966: surface session expiry to the UI. Without this, the user
        // sees a silent forced sign-out (the snackbar/banner had nothing to
        // bind to). `_sessionExpired` lets the login view show a banner;
        // the error message gives ViewModels something to watch.
        _sessionExpired = true;
        notifyListeners();
        unawaited(_handleAuthStreamError(code));
      },
    );
  }

  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      clearError();
      setLoading(true);

      _authRepository.holdRegistrationDisplayName(
        email: email,
        displayName: displayName,
      );
      final UserCredential credential = await _authRepository.createUser(
        email,
        password,
      );

      if (credential.user != null) {
        await _authRepository.updateDisplayName(credential.user!, displayName);
        _currentUser = _authRepository.currentUser;

        // Send verification email (non-blocking — failure must not prevent registration)
        try {
          await _authRepository.sendEmailVerification();
        } catch (e) {
          AppLogger.warning('Failed to send verification email: $e');
        }

        setLoading(false);
        _sessionExpired = false;
        await DIContainer().pushUserScope();
        await _analyticsService.logSignUp(method: 'email');
        return true;
      }

      setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      _handleAuthError(e);
      await _analyticsService.logEvent(
        name: AnalyticsEvents.authFailed,
        parameters: {
          'method': 'email',
          'error_code': e.code,
          'action': 'sign_up',
        },
      );
      return false;
    } catch (e) {
      setLoading(false);
      // Filter out false-positive GMS errors
      if (!e.toString().contains('com.google.android.gms')) {
        setError(AppLocale.current.errorUnexpected);
      }
      _currentUser = _authRepository.currentUser;
      return _currentUser != null;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      clearError();
      setLoading(true);
      _pendingMfa = null;
      // A waiting Google/Apple credential is bound to one address (C4).
      if (pendingProviderLink?.email != email.trim().toLowerCase()) {
        _providerSignIn?.clearPendingLink();
      }

      AppLogger.debug(
        'Attempting login for email: ${email.substring(0, 3)}...',
      );
      await _authRepository.signIn(email: email, password: password);
      _currentUser = _authRepository.currentUser;
      AppLogger.debug(
        'Login result - User: ${_currentUser?.uid.maskedUserId ?? "null"}',
      );

      setLoading(false);

      if (_currentUser == null) {
        AppLogger.error('Login appeared successful but no user returned');
        setError(AppLocale.current.errorLoginFailed);
        return false;
      }

      await completeSignIn(method: 'email');
      return true;
    } on FirebaseAuthMultiFactorException catch (e) {
      // Not an error: the first factor passed and the second is asked for.
      // Before P6-U09 nothing caught this, so an account with two-step
      // verification could not sign in at all.
      setLoading(false);
      holdMfaChallenge(MfaResolverInfo(resolver: e.resolver));
      return false;
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      AppLogger.error('Firebase Auth Error: ${e.code} - ${e.message}');
      _handleAuthError(e);
      await _analyticsService.logEvent(
        name: AnalyticsEvents.authFailed,
        parameters: {
          'method': 'email',
          'error_code': e.code,
          'action': 'sign_in',
        },
      );
      return false;
    } catch (e) {
      setLoading(false);
      AppLogger.error('Unexpected login error: $e');
      // Filter out false-positive GMS errors
      if (!e.toString().contains('com.google.android.gms')) {
        setError(AppLocale.current.errorUnexpected);
      }
      _currentUser = _authRepository.currentUser;
      return _currentUser != null;
    }
  }

  /// Completes a sign-in whose second factor was just resolved, by the code
  /// or by the phone reading it itself. Returns whether a user is signed in.
  Future<bool> finishMfaSignIn() async {
    _pendingMfa = null;
    _currentUser = _authRepository.currentUser;
    if (_currentUser == null) {
      notifyListeners();
      return false;
    }
    _sessionExpired = false;
    await DIContainer().pushUserScope();
    _providerSignIn?.dropSignInTokens();
    // Only now, with both factors given, may a waiting provider credential
    // join the account (C4).
    await _providerSignIn?.linkPendingIfSignedIn();
    notifyListeners();
    return true;
  }

  @override
  @protected
  Future<void> completeSignIn({
    required String method,
    bool isNewUser = false,
  }) async {
    _currentUser = _authRepository.currentUser;
    _sessionExpired = false;
    await DIContainer().pushUserScope();
    if (isNewUser) {
      await _analyticsService.logSignUp(method: method);
    } else {
      await _analyticsService.logLogin(method: method);
    }
    _providerSignIn?.dropSignInTokens();
    await _providerSignIn?.linkPendingIfSignedIn();
    notifyListeners();
  }

  @override
  @protected
  void holdMfaChallenge(MfaResolverInfo challenge) {
    _pendingMfa = challenge;
    AppLogger.info('Sign-in waits for the second factor');
    notifyListeners();
  }

  /// Drops a waiting challenge (the user went back to the sign-in form).
  @override
  void clearPendingMfa() {
    if (_pendingMfa == null) return;
    _pendingMfa = null;
    // Kept while signed in: a re-authentication's challenge ends here too,
    // and a deletion may still need the Apple code it gave.
    if (!isAuthenticated) _providerSignIn?.dropSignInTokens();
    notifyListeners();
  }

  Future<void> signOut() async {
    await executeAsync(() async {
      // Read before the sign-out clears it: only this person's tray goes.
      final userId = (_currentUser ?? _authRepository.currentUser)?.uid;
      await DIContainer().popUserScope();

      await _authRepository.signOut();
      await _providerSignIn?.signOut();
      _currentUser = null;
      AppLogger.info('User signed out successfully');
      await clearDeviceDraftsOnExplicitSignOut(userId);
      await _analyticsService.logLogout();
    }).catchError((e) {
      setError(AppLocale.current.errorCouldNotLogOut);
    });
  }

  /// The device drafts a sign-out the user made herself deletes.
  ///
  /// PQ-12 = A (produktbeslut-2026-09-23.json): drafts go when the user logs
  /// out herself (produktregler.md:164-172), never at an automatic logout, so
  /// [logoutDueToInactivity] and [forceSignOut] do not call this. The one
  /// user-initiated path that runs through [logoutDueToInactivity], "Logga ut
  /// nu" in the timeout warning, calls it separately
  /// (SessionTimeoutService.forceLogout). No store here is the offline queue,
  /// which no sign-out clears by itself (produktregler.md:193, :833).
  /// Best-effort: every store logs and never throws.
  static Future<void> clearDeviceDraftsOnExplicitSignOut(
    String? userId,
  ) async {
    await WeeklyMenuOverflowTrayStore.clearAll(userId: userId);
    await WeeklyMenuDraftStore.clearAll(userId: userId);
    await RecipeFormAutoSaveManager.clearDraftsFor(userId);
  }

  /// Logout for session timeout - tracks separately for security monitoring.
  ///
  /// Never touches the offline queue or the device drafts: "En utloggning på
  /// grund av timeout får aldrig rensa kön" (produktregler.md:833), and PQ-12
  /// = A keeps the drafts.
  Future<void> logoutDueToInactivity() async {
    await executeAsync(() async {
      _clearConsentCacheIfAvailable();
      await DIContainer().popUserScope();

      await _authRepository.signOut();
      await _providerSignIn?.signOut();
      _currentUser = null;
      AppLogger.info('User logged out due to session inactivity');
      await _analyticsService.logEvent(
        name: AnalyticsEvents.logoutInactivity,
        parameters: {
          'reason': 'session_timeout',
          'timestamp': clock.now().toIso8601String(),
        },
      );
    }).catchError((e) {
      AppLogger.error('Session timeout logout failed', e);
      setError(AppLocale.current.errorCouldNotLogOut);
    });
  }

  /// BUT-966: surface the auth-stream error to the user, then complete the
  /// sign-out. [forceSignOut] clears errors in its `finally`, so the
  /// localized message is set *after* forceSignOut and a second
  /// notifyListeners fires so observers can react.
  /// BUG-31: codes that genuinely mean the credential is gone/revoked and the
  /// session MUST end. Everything else (empty code, transient/network errors)
  /// is treated as recoverable so a one-off stream error doesn't sign the user
  /// out mid-session. Keeps real session-revocation security intact.
  static const Set<String> _fatalAuthStreamCodes = {
    'user-disabled',
    'user-token-expired',
    'user-not-found',
    'invalid-user-token',
    'token-expired',
  };

  bool _isFatalAuthStreamError(String code) =>
      _fatalAuthStreamCodes.contains(code);

  Future<void> _handleAuthStreamError(String code) async {
    try {
      await forceSignOut();
      setError(AppLocale.current.errorSessionExpired);
      notifyListeners();
      await _analyticsService.logEvent(
        name: AnalyticsEvents.sessionTimeoutLogout,
        parameters: {
          'reason': 'auth_stream_error',
          'error_code': code,
        },
      );
    } catch (e) {
      AppLogger.error('Failed to handle auth stream error: $e');
    }
  }

  Future<void> forceSignOut() async {
    try {
      _clearConsentCacheIfAvailable();
      await DIContainer().popUserScope();

      await _authRepository.signOut();
      await _providerSignIn?.signOut();
    } catch (e) {
      AppLogger.error('Force sign out error: $e');
    } finally {
      _currentUser = null;
      clearError();
      notifyListeners();
      AppLogger.info('Force sign out completed');
    }
  }

  /// Force-refresh the Firebase ID token. If the refresh token is revoked
  /// or the account is disabled, triggers sign-out and sets [sessionExpired].
  Future<bool> refreshSession() async {
    if (_currentUser == null) return false;
    try {
      await _currentUser!.getIdToken(true);
      _currentUser = _authRepository.currentUser;
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-token-expired' || e.code == 'user-disabled') {
        _sessionExpired = true;
        notifyListeners();
        await forceSignOut();
      } else {
        _handleAuthError(e);
      }
      return false;
    } catch (e) {
      AppLogger.warning('Token refresh failed: $e');
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    return await executeAsync(() async {
      try {
        await _authRepository.sendPasswordResetEmail(email);
      } on FirebaseAuthException catch (e) {
        // An unknown address gets the same answer as a known one, so the
        // reset form cannot be used to find out who has an account.
        if (e.code != 'user-not-found') rethrow;
      }
      return true;
    }).catchError((e) {
      if (e is FirebaseAuthException) {
        _handleAuthError(e);
      } else {
        setError(AppLocale.current.errorUnexpected);
      }
      return false;
    });
  }

  /// Requires recent login - will fail if session is stale.
  Future<bool> deleteAccount() async {
    if (_currentUser == null) {
      setError(AppLocale.current.errorNoUserLoggedIn);
      return false;
    }

    return await executeAsync(() async {
      await _authRepository.deleteCurrentUser();
      _currentUser = null;
      await _providerSignIn?.signOut();
      return true;
    }).catchError((e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          setError(AppLocale.current.errorReauthRequired);
        } else {
          _handleAuthError(e);
        }
      } else {
        setError(AppLocale.current.errorCouldNotDeleteAccount);
      }
      return false;
    });
  }

  /// Quiet, best-effort deletion of the current Firebase Auth user, for flows
  /// that must clean up an auth account WITHOUT the user-facing error surface of
  /// [deleteAccount] — the underage age-gate block, which signs out regardless.
  /// Delegates to the repository so no caller touches `FirebaseAuth.instance`
  /// directly (BUT-1551). Never throws — logs the outcome and returns; the
  /// caller signs out regardless, so no result is surfaced.
  Future<void> deleteCurrentAuthUser() async {
    try {
      await _authRepository.deleteCurrentUser();
      _currentUser = null;
      await _providerSignIn?.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        AppLogger.info(
          'Auth-user delete needs reauth; caller signs out regardless',
        );
      } else {
        AppLogger.warning('Auth-user delete failed: ${e.code}');
      }
    } catch (e) {
      AppLogger.warning('Auth-user delete failed: $e');
    }
  }

  /// Reload user data from Firebase and notify listeners.
  Future<void> reloadUser() async {
    try {
      await _authRepository.reloadCurrentUser();
      _currentUser = _authRepository.currentUser;
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to reload user: $e');
    }
  }

  void _handleAuthError(FirebaseAuthException e) => handleAccountAuthError(e);

  /// Clear consent cache before user scope disposal to prevent stale state
  void _clearConsentCacheIfAvailable() {
    try {
      final consent = GetIt.instance.get<ConsentService>();
      consent.clearConsentCache();
    } catch (_) {
      // ConsentService may not be registered or scope already gone
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    disposeStreamResources();
    super.dispose();
  }
}
