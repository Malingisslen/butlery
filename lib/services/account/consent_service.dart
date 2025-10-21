import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Service for managing user consent (GDPR Article 7)
///
/// Handles consent tracking, storage, and validation for GDPR compliance.
class ConsentService {
  static const String _logTag = 'ConsentService';
  static const String _currentConsentVersion = '1.0.0'; // Update when policies change

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  ConsentService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  /// Get current user's consent
  Future<UserConsent?> getUserConsent() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      app_logger.AppLogger.warning('[$_logTag] No authenticated user');
      return null;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('consent')
          .doc('current')
          .get();

      if (!doc.exists) {
        app_logger.AppLogger.debug('[$_logTag] No consent found for user $userId');
        return null;
      }

      return UserConsent.fromFirestore(doc);
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

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('consent')
          .doc('current')
          .set(consent.toFirestore());

      // Log consent change to audit log
      await _logConsentChange(userId, purposes, existingConsent?.purposes);

      app_logger.AppLogger.info('[$_logTag] Consent saved for user $userId');
      return true;
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
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('consent_history')
          .orderBy('grantedAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => UserConsent.fromFirestore(doc)).toList();
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

  /// Log consent changes to audit log for GDPR accountability
  Future<void> _logConsentChange(
    String userId,
    ConsentPurposes newPurposes,
    ConsentPurposes? oldPurposes,
  ) async {
    try {
      final changes = <String, Map<String, bool>>{};

      if (oldPurposes == null) {
        changes['initial_consent'] = newPurposes.toMap().map(
          (key, value) => MapEntry(key, value as bool),
        );
      } else {
        // Track what changed
        final newMap = newPurposes.toMap();
        final oldMap = oldPurposes.toMap();

        for (final key in newMap.keys) {
          if (newMap[key] != oldMap[key]) {
            changes[key] = {
              'from': oldMap[key] as bool,
              'to': newMap[key] as bool,
            };
          }
        }
      }

      if (changes.isNotEmpty) {
        await _firestore.collection('audit_logs').add({
          'userId': userId,
          'action': 'consent_change',
          'changes': changes,
          'timestamp': FieldValue.serverTimestamp(),
          'consentVersion': _currentConsentVersion,
        });

        // Also save to consent history
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('consent_history')
            .add({
          'purposes': newPurposes.toMap(),
          'grantedAt': FieldValue.serverTimestamp(),
          'consentVersion': _currentConsentVersion,
          'deviceInfo': await _getDeviceInfo(),
        });
      }
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to log consent change: $e');
    }
  }

  /// Get current consent version
  String get currentConsentVersion => _currentConsentVersion;
}
