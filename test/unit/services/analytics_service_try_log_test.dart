/// BUT-766: regression gate for the static `AnalyticsService.tryLog` helper.
///
/// What this proves:
///   1. When AnalyticsService is registered in [ServiceLocator], `tryLog`
///      forwards the event to its `logEvent`.
///   2. When the service is not registered, `tryLog` no-ops silently —
///      callers in degraded mode (e.g. early bootstrap, web with missing
///      Firebase) don't crash.
///   3. When the underlying `logEvent` throws, `tryLog` swallows it. This
///      is the cascade-prevention guarantee that lets the helper replace
///      the prior try/catch shapes safely.
library;

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AnalyticsRepository {}

class _MockConsent extends Mock implements ConsentService {}

AnalyticsService _buildServiceWithConsent(_MockRepo repo) {
  final consent = _MockConsent();
  when(() => consent.hasConsent(any())).thenAnswer((_) async => true);
  final service = AnalyticsService(repository: repo);
  service.setConsentService(consent);
  return service;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object>{});
    registerFallbackValue(ConsentPurpose.analytics);
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('BUT-766: AnalyticsService.tryLog', () {
    test('forwards event when AnalyticsService is registered', () async {
      final repo = _MockRepo();
      when(() => repo.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});
      final service = _buildServiceWithConsent(repo);

      prod.ServiceLocator.initialize(DIContainer());
      GetIt.instance.registerSingleton<AnalyticsService>(service);

      AnalyticsService.tryLog('demo_event', parameters: {'flag': 'on'});

      // logEvent is fire-and-forget AND consent-checked async — flush a few
      // microtask turns to let the chain complete before we verify.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      verify(() => repo.logEvent(
            name: 'demo_event',
            parameters: {'flag': 'on'},
          )).called(1);
    });

    test('no-ops when AnalyticsService is NOT registered', () {
      prod.ServiceLocator.initialize(DIContainer());
      // No registerSingleton<AnalyticsService>(...) — service is missing.

      // Must not throw.
      expect(
        () => AnalyticsService.tryLog('demo', parameters: {'a': 1}),
        returnsNormally,
      );
    });

    test('no-ops when ServiceLocator has not been initialized', () {
      prod.ServiceLocator.reset();
      expect(() => AnalyticsService.tryLog('demo'), returnsNormally);
    });

    test('swallows exceptions from logEvent', () async {
      final repo = _MockRepo();
      when(() => repo.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenThrow(StateError('simulated logEvent crash'));
      final service = _buildServiceWithConsent(repo);

      prod.ServiceLocator.initialize(DIContainer());
      GetIt.instance.registerSingleton<AnalyticsService>(service);

      // Must not surface the StateError to the caller.
      expect(
        () => AnalyticsService.tryLog('demo'),
        returnsNormally,
      );
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
  });
}
