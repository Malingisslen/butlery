import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/firebase/firebase_consent_repository.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Service for managing user consent (GDPR Article 7)
///
/// Handles consent tracking, storage, and validation for GDPR compliance.
/// Now uses FirebaseConsentRepository for secure, validated data access.
class ConsentService {
  static const String _logTag = 'ConsentService';
  static const String _currentConsentVersion = '1.0.0'; // Update when policies change

  final FirebaseAuth _auth;
  final FirebaseConsentRepository _consentRepository;

  ConsentService({
    required FirebaseAuth auth,
    required FirebaseConsentRepository consentRepository,
  })  : _auth = auth,
        _consentRepository = consentRepository;

  /// Get current user's consent
  Future<UserConsent?> getUserConsent() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      app_logger.AppLogger.warning('[$_logTag] No authenticated user');
      return null;
    }

    try {
      return await _consentRepository.getUserConsent(userId);
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to get user consent: $e');
      return null;
    }
  }

  /// Save or update user consent
  Future<bool> saveConsent(ConsentPurposes purposes) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      app_logger.AppLogger.warning('[$_logTag] No authenticated user');
      return false;
    }

    try {
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
      final success = await _consentRepository.saveConsent(userId, consent);

      if (success) {
        app_logger.AppLogger.info('[$_logTag] Consent saved for user $userId');
      }

      return success;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to save consent: $e');
      return false;
    }
  }

  /// Check if user has granted consent for a specific purpose
  Future<bool> hasConsent(String purpose) async {
    final consent = await getUserConsent();
    if (consent == null) return false;

    switch (purpose) {
      case 'analytics':
        return consent.purposes.analytics;
      case 'marketing':
        return consent.purposes.marketing;
      case 'socialFeatures':
        return consent.purposes.socialFeatures;
      case 'pushNotifications':
        return consent.purposes.pushNotifications;
      case 'essentialServices':
        return consent.purposes.essentialServices;
      case 'dataProcessing':
        return consent.purposes.dataProcessing;
      default:
        app_logger.AppLogger.warning('[$_logTag] Unknown consent purpose: $purpose');
        return false;
    }
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
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final defaultPurposes = ConsentPurposes.defaults();
      return await saveConsent(defaultPurposes);
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to revoke consents: $e');
      return false;
    }
  }

  /// Get consent history for user (for GDPR accountability)
  Future<List<UserConsent>> getConsentHistory() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      return await _consentRepository.getConsentHistory(userId);
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to get consent history: $e');
      return [];
    }
  }

  /// Get device information for consent tracking
  Future<String> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
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
    } catch (e) {
      app_logger.AppLogger.warning('[$_logTag] Failed to get device info: $e');
      return 'Unknown Device';
    }
  }

  // Note: Audit logging for consent changes is now handled automatically by FirebaseConsentRepository
  // This ensures GDPR compliance with Article 30 (Records of Processing Activities)

  /// Get current consent version
  String get currentConsentVersion => _currentConsentVersion;
}
