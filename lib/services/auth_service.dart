import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/auth_error_mapper.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/cache/permission_cache_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/performance/intelligent_cache_manager.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_ingredient_repository.dart';

/// Firebase authentication service managing login, registration, and session state.
class AuthService extends ChangeNotifier
    with
        StateNotifierMixin,
        AsyncOperationMixin,
        StreamManagementMixin,
        ErrorHandlingMixin {
  final auth_repo.AuthRepository _authRepository;
  final AnalyticsService _analyticsService;
  User? _currentUser;
  StreamSubscription<User?>? _authStateSubscription;

  User? get currentUser => _currentUser;
  String? get currentUserDisplayName => _currentUser?.displayName;
  String? get currentUserEmail => _currentUser?.email;
  String? get currentUserPhotoUrl => _currentUser?.photoURL;
  String? get errorMessage => error;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;
  String? get currentUserId => _authRepository.currentUserId;

  AuthService({
    auth_repo.AuthRepository? authRepository,
    required AnalyticsService analyticsService,
  })  : _authRepository = authRepository ?? FirebaseAuthRepository(),
        _analyticsService = analyticsService {
    _authStateSubscription = _authRepository.authStateChanges().listen(
      (User? user) {
        _currentUser = user;
        notifyListeners();
      },
      onError: (error) {
        final code = error is FirebaseAuthException ? error.code : '';
        AppLogger.warning('Auth state stream error (code: $code): $error');
        // Invalidate session on any auth stream error to prevent
        // fake-authenticated state where UI shows logged-in but session is broken
        _currentUser = null;
        notifyListeners();
        forceSignOut();
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
        name: 'auth_failed',
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

      AppLogger.debug(
          'Attempting login for email: ${email.substring(0, 3)}...');
      await _authRepository.signIn(email: email, password: password);
      _currentUser = _authRepository.currentUser;
      AppLogger.debug(
          'Login result - User: ${_currentUser?.uid.maskedUserId ?? "null"}');

      setLoading(false);

      if (_currentUser == null) {
        AppLogger.error('Login appeared successful but no user returned');
        setError(AppLocale.current.errorLoginFailed);
        return false;
      }

      await DIContainer().pushUserScope();
      await _analyticsService.logLogin(method: 'email');
      return true;
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      AppLogger.error('Firebase Auth Error: ${e.code} - ${e.message}');
      _handleAuthError(e);
      await _analyticsService.logEvent(
        name: 'auth_failed',
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

  Future<void> signOut() async {
    await executeAsync(() async {
      await DIContainer().popUserScope();
      _resetSessionScopedServices();
      await _authRepository.signOut();
      _currentUser = null;
      AppLogger.info('User signed out successfully');
      await _analyticsService.logLogout();
    }).catchError((e) {
      setError(AppLocale.current.errorCouldNotLogOut);
    });
  }

  /// Logout for session timeout - tracks separately for security monitoring.
  Future<void> logoutDueToInactivity() async {
    await executeAsync(() async {
      await DIContainer().popUserScope();
      _resetSessionScopedServices();
      await _authRepository.signOut();
      _currentUser = null;
      AppLogger.info('User logged out due to session inactivity');
      await _analyticsService.logEvent(
        name: 'logout_inactivity',
        parameters: {
          'reason': 'session_timeout',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }).catchError((e) {
      AppLogger.error('Session timeout logout failed', e);
      setError(AppLocale.current.errorCouldNotLogOut);
    });
  }

  Future<void> forceSignOut() async {
    try {
      await DIContainer().popUserScope();
      _resetSessionScopedServices();
      await _authRepository.signOut();
    } catch (e) {
      AppLogger.error('Force sign out error: $e');
    } finally {
      _currentUser = null;
      clearError();
      notifyListeners();
      AppLogger.info('Force sign out completed');
    }
  }

  /// Re-authenticate user with password (required before sensitive operations).
  Future<bool> reauthenticateWithPassword(String password) async {
    try {
      clearError();
      await _authRepository.reauthenticateWithPassword(password);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    return await executeAsync(() async {
      await _authRepository.sendPasswordResetEmail(email);
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

  /// Change user password. Requires prior reauthentication.
  Future<bool> changePassword(String newPassword) async {
    try {
      clearError();
      await _authRepository.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      return false;
    }
  }

  /// Send verification to new email address. Requires prior reauthentication.
  Future<bool> changeEmail(String newEmail) async {
    try {
      clearError();
      await _authRepository.verifyBeforeUpdateEmail(newEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      return false;
    }
  }

  /// Reset session-scoped services before sign-out to prevent stale timers/data.
  void _resetSessionScopedServices() {
    void safeReset(String name, void Function() fn) {
      try {
        fn();
      } catch (e) {
        AppLogger.warning('$name reset failed during sign-out: $e');
      }
    }

    safeReset('PresenceService',
        () => ServiceLocator.tryGet<PresenceService>()?.resetForLogout());
    safeReset('UnifiedRecipeService',
        () => ServiceLocator.tryGet<UnifiedRecipeService>()?.resetForLogout());
    safeReset('NotificationService',
        () => ServiceLocator.tryGet<NotificationService>()?.resetForLogout());
    safeReset('PermissionCacheService',
        () => ServiceLocator.tryGet<PermissionCacheService>()?.invalidateAll());
    safeReset('ConsentService',
        () => ServiceLocator.tryGet<ConsentService>()?.clearConsentCache());
    safeReset('IntelligentCacheManager',
        () => ServiceLocator.tryGet<IntelligentCacheManager>()?.clearCache());
    safeReset('UserIngredientRepository', () {
      final repo = ServiceLocator.tryGet<UserIngredientRepository>();
      if (repo is FirebaseUserIngredientRepository) repo.clearAllCaches();
    });
    safeReset('PersonalTagService',
        () => ServiceLocator.tryGet<PersonalTagService>()?.resetForLogout());
    safeReset('UnifiedMenuService',
        () => ServiceLocator.tryGet<UnifiedMenuService>()?.resetForLogout());
    safeReset(
        'UnifiedShoppingService',
        () =>
            ServiceLocator.tryGet<UnifiedShoppingService>()?.resetForLogout());
    safeReset('OfflineService',
        () => ServiceLocator.tryGet<OfflineService>()?.resetForLogout());
    safeReset('UserService',
        () => ServiceLocator.tryGet<UserService>()?.resetForLogout());
    safeReset('UnifiedFriendsService',
        () => ServiceLocator.tryGet<UnifiedFriendsService>()?.resetForLogout());
  }

  /// Send email verification to the current user.
  Future<void> sendEmailVerification() async {
    try {
      await _authRepository.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      rethrow;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      rethrow;
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

  void _handleAuthError(FirebaseAuthException e) {
    AppLogger.error('Firebase Auth Error Code: ${e.code}');
    setError(mapAuthErrorToMessage(e));
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    disposeStreamResources();
    super.dispose();
  }
}
