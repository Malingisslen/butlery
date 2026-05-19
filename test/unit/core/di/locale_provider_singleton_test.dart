// BUT-868: Singleton-identity invariant for `LocaleProvider`.
//
// BUT-801 fixed a dual-instance bug in `lib/main.dart`: the app state used to
// hold a `final LocaleProvider _localeProvider = LocaleProvider()` while the
// DI container also registered a singleton, so settings-hub writes (which
// went through `ServiceLocator`) didn't reach the `MaterialApp.localeListenable`
// (which read the local field). Both lookup paths must now resolve to the
// same instance.
//
// `ApplicationBootstrap` wires `ServiceLocator.initialize(_diContainer)`, so
// `ApplicationBootstrap().container` and `ServiceLocator` share the same
// underlying `DIContainer`. This test pins that contract for `LocaleProvider`
// without spinning up the full bootstrap (which needs Firebase + SharedPreferences).

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';

void main() {
  group('LocaleProvider singleton identity (BUT-868)', () {
    late DIContainer container;

    setUp(() async {
      // GetIt is process-global; reset so prior-test registrations don't leak.
      await GetIt.instance.reset();
      ServiceLocator.reset();

      container = DIContainer();
      // Mirrors CoreModule.configure: a single LocaleProvider instance
      // registered as a true singleton on the underlying GetIt registry.
      container.container.registerSingleton<LocaleProvider>(LocaleProvider());
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    test('container.get and ServiceLocator.get return the same instance', () {
      final fromContainer = container.get<LocaleProvider>();
      final fromLocator = ServiceLocator.get<LocaleProvider>();

      expect(identical(fromContainer, fromLocator), isTrue,
          reason: 'Both lookup paths must resolve to the same '
              'DIContainer-backed singleton; otherwise locale writes from one '
              'path are invisible to listeners on the other (BUT-801 regression).');
    });

    test('repeated lookups return the same instance across both paths', () {
      // Pin the contract under the singleton-of-singletons assumption: every
      // resolution of LocaleProvider returns one stable instance.
      final a = container.get<LocaleProvider>();
      final b = container.get<LocaleProvider>();
      final c = ServiceLocator.get<LocaleProvider>();
      final d = ServiceLocator.get<LocaleProvider>();

      expect(identical(a, b), isTrue);
      expect(identical(c, d), isTrue);
      expect(identical(a, c), isTrue);
    });
  });
}
