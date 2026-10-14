// Megagenomgång A42: a shared link that cannot be opened must say so. The
// invitation, shopping and profile branches used to return without a word
// when the id was invalid.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late DeepLinkHandler handler;

  setUp(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(
        isAuthenticated: true,
        userId: 'deep-link-user',
      ),
    );
    handler = DeepLinkHandler()..reset();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  const links = {
    'invitation': 'butlery://butlery.app/invite?id=kort&from=kort&type=friend',
    'shopping list': 'butlery://butlery.app/shopping?id=kort',
    'profile': 'butlery://butlery.app/profile?id=kort',
  };

  for (final entry in links.entries) {
    testWidgets('an invalid ${entry.key} link shows the unavailable notice', (
      tester,
    ) async {
      await tester.pumpWidget(createLocalizedTestApp(child: const SizedBox()));
      final context = tester.element(find.byType(Scaffold).first);

      await tester.runAsync(
        () => handler.processDeepLink(entry.value, context),
      );
      await tester.pump();

      expect(
        find.text(AppLocalizationsSv().deepLinkUnavailable),
        findsOneWidget,
      );
    });
  }
}
