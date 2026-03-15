import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Base class for analytics event trackers providing GDPR consent checking
abstract class BaseTracker {
  final AnalyticsRepository repository;
  ConsentService? _consentService;

  BaseTracker({required this.repository});

  /// Update consent service reference
  void setConsentService(ConsentService? service) {
    _consentService = service;
  }

  /// Check if user has granted analytics consent
  /// Returns true if consent not yet configured (graceful degradation)
  Future<bool> hasAnalyticsConsent() async {
    if (_consentService == null) {
      return true;
    }

    try {
      return await _consentService!.hasConsent('analytics');
    } catch (e) {
      app_logger.AppLogger.warning(
        '[BaseTracker] Failed to check consent, defaulting to false: $e',
      );
      return false;
    }
  }

  /// Log generic event through repository
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logEvent(name: name, parameters: parameters);
  }
}
