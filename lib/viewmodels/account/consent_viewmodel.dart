import 'package:flutter/foundation.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// ViewModel for managing user consent UI state and operations (GDPR Article 7)
/// Handles consent management UI, allowing users to grant/revoke consent
/// for different data processing purposes.
/// **State Management:**
/// - Current consent state
/// - Loading states managed by AsyncOperationMixin
/// - Success/error handling via AsyncOperationMixin
/// - Individual purpose toggles
/// **User Flow:**
/// 1. User views current consent settings
/// 2. User toggles consent purposes
/// 3. ViewModel saves consent via ConsentService
/// 4. Shows loading state during save (managed by AsyncOperationMixin)
/// 5. On success: Updates UI with new state
/// 6. On error: Shows error message with retry option
class ConsentViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final ConsentService _consentService;
  static const String _logTag = 'ConsentViewModel';

  ConsentViewModel({
    required ConsentService consentService,
  }) : _consentService = consentService;

  // State
  UserConsent? _currentConsent;
  bool _needsRenewal = false;

  // Current consent purposes (editable state)
  bool _analytics = false;
  bool _marketing = false;
  bool _socialFeatures = false;
  bool _pushNotifications = false;

  // Getters - State
  bool get isSaving =>
      isLoading; // Compatibility alias - StateNotifierMixin provides isLoading
  UserConsent? get currentConsent => _currentConsent;
  String? get errorMessage =>
      error; // Compatibility alias - StateNotifierMixin provides error
  bool get needsRenewal => _needsRenewal;
  bool get hasConsent => _currentConsent != null;

  // Getters - Consent purposes (required - always true)
  bool get essentialServices => true; // Cannot be disabled
  bool get dataProcessing => true; // Cannot be disabled

  // Getters - Consent purposes (optional - user-controllable)
  bool get analytics => _analytics;
  bool get marketing => _marketing;
  bool get socialFeatures => _socialFeatures;
  bool get pushNotifications => _pushNotifications;

  /// Load current user consent
  Future<void> loadConsent() async {
    try {
      await executeNamedOperation('load', () async {
        app_logger.AppLogger.info('[$_logTag] Loading user consent');

        final consent = await _consentService.getUserConsent();
        _currentConsent = consent;

        if (consent != null) {
          // Update editable state from loaded consent
          _analytics = consent.purposes.analytics;
          _marketing = consent.purposes.marketing;
          _socialFeatures = consent.purposes.socialFeatures;
          _pushNotifications = consent.purposes.pushNotifications;

          // Check if renewal needed
          _needsRenewal = await _consentService.needsConsentRenewal();
        } else {
          // No consent found - set defaults
          _analytics = false;
          _marketing = false;
          _socialFeatures = false;
          _pushNotifications = false;
          _needsRenewal = true;
        }

        app_logger.AppLogger.success('[$_logTag] Consent loaded successfully');
      });
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to load consent', e);
      setError(_formatErrorMessage(e));
    }
  }

  /// Save current consent settings
  Future<bool> saveConsent() async {
    try {
      return await executeNamedOperation('save', () async {
        app_logger.AppLogger.info('[$_logTag] Saving user consent');

        final purposes = ConsentPurposes(
          essentialServices: true, // Always required
          dataProcessing: true, // Always required
          analytics: _analytics,
          marketing: _marketing,
          socialFeatures: _socialFeatures,
          pushNotifications: _pushNotifications,
        );

        final success = await _consentService.saveConsent(purposes);

        if (success) {
          // Reload to get updated consent with timestamps
          await loadConsent();
          app_logger.AppLogger.success('[$_logTag] Consent saved successfully');
        } else {
          setError(AppLocale.current.errorGeneric);
        }

        return success;
      });
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to save consent', e);
      setError(_formatErrorMessage(e));
      return false;
    }
  }

  /// Toggle analytics consent
  void setAnalytics(bool value) {
    _analytics = value;
    notifyListeners();
    app_logger.AppLogger.debug('[$_logTag] Analytics consent: $value');
  }

  /// Toggle marketing consent
  void setMarketing(bool value) {
    _marketing = value;
    notifyListeners();
    app_logger.AppLogger.debug('[$_logTag] Marketing consent: $value');
  }

  /// Toggle social features consent
  void setSocialFeatures(bool value) {
    _socialFeatures = value;
    notifyListeners();
    app_logger.AppLogger.debug('[$_logTag] Social features consent: $value');
  }

  /// Toggle push notifications consent
  void setPushNotifications(bool value) {
    _pushNotifications = value;
    notifyListeners();
    app_logger.AppLogger.debug('[$_logTag] Push notifications consent: $value');
  }

  /// Revoke all optional consents
  Future<bool> revokeAllOptional() async {
    try {
      return await executeNamedOperation('revoke', () async {
        app_logger.AppLogger.info('[$_logTag] Revoking all optional consents');

        final success = await _consentService.revokeOptionalConsents();

        if (success) {
          // Reset local state
          _analytics = false;
          _marketing = false;
          _socialFeatures = false;
          _pushNotifications = false;

          await loadConsent();
          app_logger.AppLogger.success(
              '[$_logTag] All optional consents revoked');
        } else {
          setError(AppLocale.current.errorGeneric);
        }

        return success;
      });
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to revoke consents', e);
      setError(_formatErrorMessage(e));
      return false;
    }
  }

  /// Accept all optional consents
  void acceptAll() {
    _analytics = true;
    _marketing = true;
    _socialFeatures = true;
    _pushNotifications = true;
    notifyListeners();
    app_logger.AppLogger.debug('[$_logTag] Accepted all consents');
  }

  /// Reject all optional consents
  void rejectAll() {
    _analytics = false;
    _marketing = false;
    _socialFeatures = false;
    _pushNotifications = false;
    notifyListeners();
    app_logger.AppLogger.debug('[$_logTag] Rejected all optional consents');
  }

  /// Check if user has granted a specific consent
  Future<bool> hasConsentFor(String purpose) async {
    return await _consentService.hasConsent(purpose);
  }

  /// Get consent history
  Future<List<UserConsent>> getConsentHistory() async {
    try {
      return await _consentService.getConsentHistory();
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to get consent history', e);
      return [];
    }
  }

  /// Get user-friendly timestamp text
  String getConsentTimestampText() {
    final l = AppLocale.current;
    if (_currentConsent == null) return l.displayNoConsent;

    final timestamp = _currentConsent!.updatedAt ?? _currentConsent!.grantedAt;
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return l.commonJustNow;
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} h';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} d';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months m';
    }
  }

  // Private helper methods

  String _formatErrorMessage(Object error) {
    final errorStr = error.toString();
    final l = AppLocale.current;

    if (errorStr.contains('No authenticated user')) {
      return l.errorMustBeLoggedInToManageConsent;
    } else if (errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return l.errorNoInternetCheckConnection;
    } else if (errorStr.contains('permission')) {
      return l.errorPermissionDeniedRetry;
    } else {
      return l.errorGeneric;
    }
  }

  @override
  void dispose() {
    app_logger.AppLogger.debug('[$_logTag] ViewModel disposed');
    super.dispose();
  }
}
