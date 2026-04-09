import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';

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
  /// Returns false if consent not yet configured (privacy-by-default, GDPR Art.25)
  Future<bool> hasAnalyticsConsent() async {
    return ConsentService.checkSafely(_consentService, ConsentPurpose.analytics,
        logTag: 'BaseTracker');
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
