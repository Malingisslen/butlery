/// BUT-2406: a link opened while signed out leaves its campaign channel in
/// memory for the registration that follows; a link opened by someone who is
/// already signed in does not.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics/pending_acquisition.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  const link =
      'https://butlery.se/recipe?utm_source=Instagram&utm_medium=social';

  Future<void> open(WidgetTester tester, {required bool signedIn}) async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(
        isAuthenticated: signedIn,
        userId: signedIn ? 'deep-link-user' : null,
      ),
    );
    PendingAcquisition.clear();
    final handler = DeepLinkHandler()..reset();
    await tester.pumpWidget(createLocalizedTestApp(child: const SizedBox()));
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(() => handler.processDeepLink(link, context));
    await tester.pump();
  }

  tearDown(() async {
    PendingAcquisition.clear();
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  testWidgets('a signed-out link leaves its allowlisted channel pending', (
    tester,
  ) async {
    await open(tester, signedIn: false);

    expect(PendingAcquisition.current?.source, 'instagram');
    expect(PendingAcquisition.current?.medium, 'social');
  });

  testWidgets('a signed-in link is not held for the next person', (
    tester,
  ) async {
    await open(tester, signedIn: true);

    expect(PendingAcquisition.current, isNull);
  });
}
