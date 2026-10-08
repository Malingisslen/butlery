/// P8-U03 · flow 05, the two deep-link transitions that were built but had
/// no test (flows-roles-budget.md:79 and :81; fas2/block288-uxfrysning.json
/// overgangar, both REQUIRED).
///
/// - TR::FLOW::05::deep-link::utloggad: a link opened while signed out waits
///   for the sign-in and then goes to the link's target
///   (lib/core/bootstrap/handlers/deep_link_handler.dart:173-178 keeps it;
///   lib/app/auth/auth_wrapper.dart:103-105 drains it at sign-in).
/// - TR::FLOW::05::deep-link::redan-medlem: a link to something already
///   shared with me opens it at once, with no view in between
///   (deep_link_handler.dart:283-309).
///
/// The real DeepLinkHandler runs. Fakes sit only at the edges: the auth
/// repository (who is signed in) and the recipe repository (the read).
/// Every named route is stubbed, and a spy observer records the pushes, as
/// in test/views/deep_link_import_journey_test.dart.
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
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _SpyNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

Widget _app(_SpyNavigatorObserver observer) => MaterialApp(
  navigatorObservers: [observer],
  home: const Scaffold(body: SizedBox.shrink()),
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(body: Text('stub:${settings.name}')),
  ),
);

/// A Firestore-shaped id: 20-28 letters and digits
/// (deep_link_handler.dart `_isValidFirestoreId`).
const _recipeId = 'R3cipeSharedWithMe01';

String _recipeLink() =>
    'https://butlery.app/recipe?id=$_recipeId'
    '&timestamp=${clock.now().millisecondsSinceEpoch}';

void main() {
  late _SpyNavigatorObserver observer;
  late DeepLinkHandler handler;
  late FakeAuthRepository auth;
  late MockRecipeRepository recipes;
  late Recipe shared;

  setUp(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());

    auth = MockFactory.createAuthRepository();
    TestServiceLocator.registerMock<AuthRepository>(auth);

    shared = RecipeFactory.build(id: _recipeId, title: 'Linsgryta');
    recipes = MockRecipeRepository();
    when(() => recipes.read(_recipeId)).thenAnswer((_) async => shared);
    TestServiceLocator.registerMock<RecipeRepository>(recipes);

    handler = DeepLinkHandler()..reset();
    observer = _SpyNavigatorObserver();
  });

  tearDown(() async {
    handler.reset();
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  List<Route<dynamic>> pushesAfterHome() => observer.pushed.skip(1).toList();

  group('TR::FLOW::05::deep-link::utloggad', () {
    testWidgets('a link opened while signed out waits, and after the sign-in '
        'it goes to the link\'s target', (tester) async {
      auth.setAuthState(isAuthenticated: false);
      await tester.pumpWidget(_app(observer));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);

      await tester.runAsync(
        () => handler.processDeepLink(_recipeLink(), context),
      );
      await tester.pumpAndSettle();

      // Signed out: nothing opens, and the recipe is not read.
      expect(pushesAfterHome(), isEmpty);
      verifyNever(() => recipes.read(any()));

      // The sign-in: AuthWrapper drains the kept link
      // (auth_wrapper.dart:103-105).
      auth.setAuthState(
        isAuthenticated: true,
        userId: 'member-1',
        user: MockFactory.createMockUser(uid: 'member-1'),
      );
      await tester.runAsync(() => handler.processPendingDeepLink(context));
      await tester.pumpAndSettle();

      final pushed = pushesAfterHome();
      expect(pushed, hasLength(1));
      expect(pushed.single.settings.name, Routes.recipeDetail);
      expect(pushed.single.settings.arguments, same(shared));

      // The link is used once: a second drain opens nothing more.
      await tester.runAsync(() => handler.processPendingDeepLink(context));
      await tester.pumpAndSettle();
      expect(pushesAfterHome(), hasLength(1));
    });
  });

  group('TR::FLOW::05::deep-link::redan-medlem', () {
    testWidgets('a link to a recipe already shared with me opens the recipe '
        'at once, with no view in between', (tester) async {
      auth.setAuthState(
        isAuthenticated: true,
        userId: 'member-1',
        user: MockFactory.createMockUser(uid: 'member-1'),
      );
      await tester.pumpWidget(_app(observer));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);

      await tester.runAsync(
        () => handler.processDeepLink(_recipeLink(), context),
      );
      await tester.pumpAndSettle();

      final pushed = pushesAfterHome();
      expect(
        pushed.map((r) => r.settings.name),
        [Routes.recipeDetail],
        reason: 'the recipe itself is the only route pushed',
      );
      expect(pushed.single.settings.arguments, same(shared));
      expect(find.text('stub:${Routes.recipeDetail}'), findsOneWidget);
      // No notice either: the link is valid and the recipe readable.
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
