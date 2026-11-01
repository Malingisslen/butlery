/// Steg 10E: the recipe list on a public profile (count line, "Visa fler",
/// no stars, read-only tap).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/public_profile_view.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../helpers/view_test_helpers.dart';

void main() {
  const them = 'them-uid';
  late MockFriendsViewModel friends;
  late MockUserRepository users;
  late MockRecipeRepository recipes;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    // The friends-service mock mixes in ChangeNotifier; the real service is
    // not a Listenable, so Provider's Listenable guard is a mock artefact.
    Provider.debugCheckInvalidValueType = null;
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    users = MockUserRepository();
    when(() => users.fetchProfile(them)).thenAnswer(
      (_) async =>
          MockFactory.createUserProfile(userId: them, displayName: 'Lovisa'),
    );
    when(
      () => users.fetchPersistedSearchable(them),
    ).thenAnswer((_) async => true);
    TestServiceLocator.registerMock<UserRepository>(users);

    recipes = MockRecipeRepository();
    when(
      () => recipes.fetchPublicUserRecipes(
        them,
        limit: any(named: 'limit'),
        after: any(named: 'after'),
      ),
    ).thenAnswer((_) async => <Recipe>[]);
    TestServiceLocator.registerMock<RecipeRepository>(recipes);

    (TestServiceLocator.get<UnifiedFriendsService>()
            as MockUnifiedFriendsService)
        .setFriendsState(isInitialized: true, isLoading: false);

    friends = MockFriendsViewModel();
    friends.setFriendshipStatus(them, FriendshipStatus.none);
    when(() => friends.currentUserId).thenReturn('me-uid');
    TestServiceLocator.registerMock<FriendsViewModel>(friends);

    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    when(() => offline.addListener(any())).thenReturn(null);
    when(() => offline.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offline);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  void stubRecipes(List<Recipe> list, {int publicRecipeCount = 0}) {
    when(() => users.fetchProfile(them)).thenAnswer(
      (_) async => MockFactory.createUserProfile(
        userId: them,
        displayName: 'Lovisa',
        publicRecipeCount: publicRecipeCount,
      ),
    );
    when(
      () => recipes.fetchPublicUserRecipes(
        them,
        limit: any(named: 'limit'),
        after: any(named: 'after'),
      ),
    ).thenAnswer((_) async => list);
  }

  List<Recipe> build(int n) => [
    for (var i = 0; i < n; i++)
      RecipeFactory.build(id: 'r$i', title: 'Recept $i'),
  ];

  Future<void> pump(WidgetTester tester, {RouteFactory? onRoute}) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const PublicProfileView(userId: them),
        onGenerateRoute: onRoute,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a recipe row shows no rating star or number', (tester) async {
    stubRecipes([
      RecipeFactory.build(id: 'r1', title: 'Pannkakor', rating: 4.5),
    ]);

    await pump(tester);

    expect(find.text('Pannkakor'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is ButleryIcon && w.icon == ButleryIcons.star,
      ),
      findsNothing,
    );
    expect(find.textContaining('4,5'), findsNothing);
  });

  testWidgets('the count line uses publicRecipeCount when it is larger', (
    tester,
  ) async {
    stubRecipes(build(2), publicRecipeCount: 47);

    await pump(tester);

    expect(find.text('47 publika recept'), findsOneWidget);
  });

  testWidgets('the count line uses the loaded length when the count lags', (
    tester,
  ) async {
    stubRecipes(build(3), publicRecipeCount: 1);

    await pump(tester);

    expect(find.text('3 publika recept'), findsOneWidget);
  });

  testWidgets('Visa fler shows only with a full page', (tester) async {
    stubRecipes(build(20), publicRecipeCount: 25);

    await pump(tester);

    expect(find.text('Visa fler'), findsOneWidget);
  });

  testWidgets('no Visa fler with a short page', (tester) async {
    stubRecipes(build(5), publicRecipeCount: 5);

    await pump(tester);

    expect(find.text('Visa fler'), findsNothing);
  });

  testWidgets('Visa fler loads the next page after the last recipe', (
    tester,
  ) async {
    final first = build(20);
    stubRecipes(first, publicRecipeCount: 21);
    when(
      () => recipes.fetchPublicUserRecipes(
        them,
        limit: any(named: 'limit'),
        after: first.last,
      ),
    ).thenAnswer(
      (_) async => [RecipeFactory.build(id: 'x', title: 'Sista receptet')],
    );

    await pump(tester);
    await tester.ensureVisible(find.text('Visa fler'));
    await tester.tap(find.text('Visa fler'));
    await tester.pumpAndSettle();

    expect(find.text('Sista receptet', skipOffstage: false), findsOneWidget);
    expect(find.text('Visa fler'), findsNothing);
  });

  testWidgets('tapping a row pushes the read-only recipe detail', (
    tester,
  ) async {
    final recipe = RecipeFactory.build(id: 'r1', title: 'Pannkakor');
    stubRecipes([recipe], publicRecipeCount: 1);
    RouteSettings? pushed;

    await pump(
      tester,
      onRoute: (settings) {
        if (settings.name == Routes.recipeDetail) {
          pushed = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('detalj')),
          );
        }
        return null;
      },
    );
    await tester.tap(find.text('Pannkakor'));
    await tester.pumpAndSettle();

    expect(pushed, isNotNull);
    final args = pushed!.arguments! as Map<String, dynamic>;
    expect(args['readOnly'], isTrue);
    expect(args['publicCopy'], isTrue);
    expect(args['recipe'], same(recipe));
    expect(args.keys.toSet(), {'recipe', 'readOnly', 'publicCopy'});
  });
}
