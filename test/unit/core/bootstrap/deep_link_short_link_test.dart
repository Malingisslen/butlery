/// BUT-2462: the short link the app hands out when sharing
/// (`https://butlery.se/s/<code>`) opens what it stands for. The long link
/// behind a code is a stranger's input, so anything that is not a share link
/// on our own host ends in the unavailable notice.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/bootstrap/handlers/deep_link_handler.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/deep_link_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  const code = 'Ab3dE5gH';
  const recipeId = 'abcdefghij0123456789ab';
  final shortLink = 'https://butlery.se/s/$code';

  late DeepLinkHandler handler;
  late MockDeepLinkRepository deepLinks;
  late MockRecipeRepository recipes;
  late List<RouteSettings> pushed;

  setUp(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(
        isAuthenticated: true,
        userId: 'deep-link-user',
      ),
    );
    deepLinks = MockDeepLinkRepository();
    recipes = MockRecipeRepository();
    TestServiceLocator.registerMock<DeepLinkService>(
      DeepLinkService(deepLinkRepository: deepLinks),
    );
    TestServiceLocator.registerMock<RecipeRepository>(recipes);
    when(() => recipes.read(recipeId)).thenAnswer(
      (_) async => RecipeFactory.build(id: recipeId, title: 'Delad gryta'),
    );
    pushed = [];
    handler = DeepLinkHandler()..reset();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  Future<void> open(WidgetTester tester, String link) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const SizedBox(),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox(),
          );
        },
      ),
    );
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(() => handler.processDeepLink(link, context));
    await tester.pump();
  }

  Finder unavailableNotice() =>
      find.text(AppLocalizationsSv().deepLinkUnavailable);

  testWidgets('a short link to a recipe opens that recipe', (tester) async {
    when(() => deepLinks.getLongUrl(code)).thenAnswer(
      (_) async => 'https://butlery.se/recipe?id=$recipeId&type=recipe',
    );

    await open(tester, shortLink);

    final recipePushes = pushed.where((r) => r.name == Routes.recipeDetail);
    expect(recipePushes, hasLength(1));
    expect(unavailableNotice(), findsNothing);
  });

  testWidgets('an unknown code shows the unavailable notice', (tester) async {
    when(() => deepLinks.getLongUrl(code)).thenAnswer((_) async => null);

    await open(tester, shortLink);

    expect(unavailableNotice(), findsOneWidget);
    expect(pushed.where((r) => r.name == Routes.recipeDetail), isEmpty);
  });

  testWidgets('a code that points outside butlery.se is not followed', (
    tester,
  ) async {
    when(
      () => deepLinks.getLongUrl(code),
    ).thenAnswer((_) async => 'https://evil.example/recipe?id=$recipeId');

    await open(tester, shortLink);

    expect(unavailableNotice(), findsOneWidget);
    verifyNever(() => recipes.read(any()));
  });

  testWidgets('the 7-day expiry runs on the long link behind the code', (
    tester,
  ) async {
    final stale = clock
        .now()
        .subtract(const Duration(days: 8))
        .millisecondsSinceEpoch;
    when(() => deepLinks.getLongUrl(code)).thenAnswer(
      (_) async => 'https://butlery.se/recipe?id=$recipeId&timestamp=$stale',
    );

    await open(tester, shortLink);

    expect(find.text(AppLocalizationsSv().deepLinkExpired), findsOneWidget);
    verifyNever(() => recipes.read(any()));
  });
}
