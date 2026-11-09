import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/acquisition_flusher.dart';
import 'package:butlery/services/analytics_service.dart';

/// Flushes the pending campaign channel with the registered services, and
/// again whenever consent changes, which is when a person who registered
/// first says yes.
class AcquisitionFlushHandler {
  AcquisitionFlushHandler._();

  static bool _listening = false;

  static Future<void> flush() async {
    final consent = ServiceLocator.tryGet<ConsentService>();
    if (!_listening && consent != null) {
      _listening = true;
      consent.addListener(() => unawaited(flush()));
    }
    await AcquisitionFlusher.forPlatform(
      auth: ServiceLocator.tryGet<AuthRepository>(),
      consent: consent,
      repository: ServiceLocator.tryGet<AcquisitionRepository>(),
      analytics: ServiceLocator.tryGet<AnalyticsService>(),
    ).flush();
  }
}
