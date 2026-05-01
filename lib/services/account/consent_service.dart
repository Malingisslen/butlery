import 'dart:io';

import 'package:flutter/foundation.dart'
    show ChangeNotifier, Listenable, VoidCallback, kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/repositories/firebase/firebase_consent_repository.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Private subclass that just exposes [ChangeNotifier.notifyListeners] to
/// the surrounding library. ChangeNotifier marks `notifyListeners` as
/// `@protected` — only subclasses can fire it. Composition + this thin
/// shim lets [ConsentService] hold a notifier without itself extending
/// ChangeNotifier (which would clash with `BaseService.dispose()`'s
/// `Future<void>` signature).
class _ConsentChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Service for managing user consent (GDPR Article 7)
/// Handles consent tracking, storage, and validation for GDPR compliance.
/// Now uses FirebaseConsentRepository for secure, validated data access.
///
/// Implements [Listenable] (BUT-752) so multiple subscribers (FCMService
/// for push permissions, SearchModule for Algolia delegate re-init) can
/// observe consent changes via the standard `addListener` /
/// `removeListener` contract that the rest of the codebase already uses.
class ConsentService extends BaseService implements Listenable {
  @override
  String get serviceName => 'ConsentService';
  static const String _logTag = 'ConsentService';
  static const String _currentConsentVersion =
      '1.1.0'; // 1.1.0: Added aiProcessing consent purpose

  final auth.AuthRepository _authRepository;
  final FirebaseConsentRepository _consentRepository;

  /// Notifier fired after any successful consent save (BUT-752). Held by
  /// composition because `BaseService.dispose()` returns `Future<void>`,
  /// which conflicts with `ChangeNotifier.dispose()`'s `void` signature.
  final _ConsentChangeNotifier _changeNotifier = _ConsentChangeNotifier();

  @override
  void addListener(VoidCallback listener) =>
      _changeNotifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _changeNotifier.removeListener(listener);

  // Session cache — consent rarely changes, no need to hit Firestore every call
  UserConsent? _cachedConsent;
  String? _cachedUserId;
  bool _cachePopulated = false;

  ConsentService({
    required auth.AuthRepository authRepository,
    required FirebaseConsentRepository consentRepository,
  })  : _authRepository = authRepository,
        _consentRepository = consentRepository;

  /// Get current user's consent (cached per session, invalidated on save)
  Future<UserConsent?> getUserConsent() async {
    final userId = _authRepository.currentUserId;
    if (userId == null) {
      app_logger.AppLogger.warning('[$_logTag] No authenticated user');
      return null;
    }

    // Return cached result if available for same user (includes null = no consent doc)
    if (_cachePopulated && _cachedUserId == userId) {
      return _cachedConsent;
    }

    final consent = await safeExecute<UserConsent?>(
      () => _consentRepository.getUserConsent(userId),
      operationName: 'Get user consent',
      defaultValue: null,
    );

    _cachedConsent = consent;
    _cachedUserId = userId;
    _cachePopulated = true;
    return consent;
  }

  /// Save or update user consent
  Future<bool> saveConsent(ConsentPurposes purposes) async {
    final userId = _authRepository.currentUserId;
    if (userId == null) {
      app_logger.AppLogger.warning('[$_logTag] No authenticated user');
      return false;
    }

    return await safeExecute(
          () async {
            final existingConsent = await getUserConsent();
            final now = DateTime.now();
            final deviceInfo = await _getDeviceInfo();

            final consent = existingConsent?.copyWith(
                  purposes: purposes,
                  updatedAt: now,
                  consentVersion: _currentConsentVersion,
                  deviceInfo: deviceInfo,
                ) ??
                UserConsent(
                  userId: userId,
                  purposes: purposes,
                  grantedAt: now,
                  updatedAt: null,
                  consentVersion: _currentConsentVersion,
                  deviceInfo: deviceInfo,
                );

            // Use repository for secure storage (includes permission validation and audit logging)
            final success =
                await _consentRepository.saveConsent(userId, consent);

            if (success) {
              _cachedConsent = consent;
              _cachedUserId = userId;
              _cachePopulated = true;
              app_logger.AppLogger.info(
                  '[$_logTag] Consent saved for user $userId');
              _changeNotifier.notify();
            }

            return success;
          },
          operationName: 'Save consent',
          defaultValue: false,
        ) ??
        false;
  }

  /// Check if user has granted consent for a specific purpose
  Future<bool> hasConsent(ConsentPurpose purpose) async {
    final consent = await getUserConsent();
    if (consent == null) return false;
    return consent.purposes[purpose];
  }

  /// Check if user needs to renew consent (version changed)
  Future<bool> needsConsentRenewal() async {
    final consent = await getUserConsent();
    if (consent == null) return true;

    return consent.needsRenewal(_currentConsentVersion);
  }

  /// Check if user has all required consents
  Future<bool> hasRequiredConsents() async {
    final consent = await getUserConsent();
    if (consent == null) return false;

    return consent.hasRequiredConsents;
  }

  /// Revoke all optional consents (keep only required ones)
  Future<bool> revokeOptionalConsents() async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return false;

    return await safeExecute(
          () async {
            final defaultPurposes = ConsentPurposes.defaults();
            return await saveConsent(defaultPurposes);
          },
          operationName: 'Revoke optional consents',
          defaultValue: false,
        ) ??
        false;
  }

  /// Get consent history for user (for GDPR accountability)
  Future<List<UserConsent>> getConsentHistory() async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return [];

    return await safeExecute(
          () => _consentRepository.getConsentHistory(userId),
          operationName: 'Get consent history',
          defaultValue: <UserConsent>[],
        ) ??
        [];
  }

  /// Get device information for consent tracking
  Future<String> _getDeviceInfo() async {
    return await safeExecute(
          () async {
            if (kIsWeb) {
              return 'Web Browser';
            } else if (Platform.isAndroid) {
              return 'Android Device';
            } else if (Platform.isIOS) {
              return 'iOS Device';
            } else if (Platform.isWindows) {
              return 'Windows Device';
            } else if (Platform.isMacOS) {
              return 'macOS Device';
            } else if (Platform.isLinux) {
              return 'Linux Device';
            } else {
              return 'Unknown Platform';
            }
          },
          operationName: 'Get device info',
          defaultValue: 'Unknown Device',
          logError: false, // This is a minor operation, don't clutter logs
        ) ??
        'Unknown Device';
  }

  // Note: Audit logging for consent changes is now handled automatically by FirebaseConsentRepository
  // This ensures GDPR compliance with Article 30 (Records of Processing Activities)

  /// Clear session cache on logout to prevent cross-user data leakage.
  void clearConsentCache() {
    _cachedConsent = null;
    _cachedUserId = null;
    _cachePopulated = false;
  }

  /// Get current consent version
  String get currentConsentVersion => _currentConsentVersion;

  /// Fail-closed consent check for callers that hold a nullable ConsentService.
  /// Returns false if service is null, consent is missing, or any error occurs.
  static Future<bool> checkSafely(
    ConsentService? service,
    ConsentPurpose purpose, {
    String logTag = 'ConsentCheck',
  }) async {
    if (service == null) return false;
    try {
      return await service.hasConsent(purpose);
    } catch (e) {
      app_logger.AppLogger.warning(
          '[$logTag] Failed to check ${purpose.name} consent, denying: $e');
      return false;
    }
  }
}

/// Fail-closed analytics consent gate for DI callers that hold a [GetIt]
/// container (modules, bootstrap stages, `main.dart`).
///
/// Returns `true` only when [ConsentService] is registered AND the user has
/// explicitly granted [ConsentPurpose.analytics]. "Not registered", "no
/// consent doc", and "lookup threw" all collapse to `false` so a pre-sign-in
/// init can never enable analytics-bound infrastructure (Firebase Analytics
/// collection toggle, Algolia provider swap).
///
/// Single canonical implementation per BUT-751 — replaces 2 inline copies
/// of the same pattern (main.dart `_enableCollectionIfConsented`,
/// search_module.dart `_hasAnalyticsConsent`).
Future<bool> hasAnalyticsConsent(
  GetIt container, {
  String logTag = 'AnalyticsConsentGate',
}) async {
  if (!container.isRegistered<ConsentService>()) return false;
  try {
    return await container<ConsentService>()
        .hasConsent(ConsentPurpose.analytics);
  } catch (e) {
    app_logger.AppLogger.warning(
        '[$logTag] Analytics consent check failed, denying: $e');
    return false;
  }
}
