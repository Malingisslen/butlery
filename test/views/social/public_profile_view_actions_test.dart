/// BUT-2249 (R8-6 = A): the public profile's "Fler åtgärder" menu with
/// Rapportera, and the friend button under the header. Neither is offered on
/// your own profile.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/public_profile_view.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../helpers/view_test_helpers.dart';

void main() {
  const them = 'them-uid';
  late MockFriendsViewModel friends;
  late MockUserRepository users;

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

    final recipes = MockRecipeRepository();
    when(
      () => recipes.fetchPublicUserRecipes(them),
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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: const PublicProfileView(userId: them)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('someone else: the friend button and Fler åtgärder → '
      'Rapportera, which opens the report reasons', (tester) async {
    await pump(tester);

    expect(find.text('Lägg till vän'), findsOneWidget);

    await tester.tap(find.byTooltip('Fler åtgärder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rapportera'));
    await tester.pumpAndSettle();

    expect(find.text('Spam'), findsOneWidget);
  });

  testWidgets('your own profile: neither the button nor the menu', (
    tester,
  ) async {
    when(() => friends.currentUserId).thenReturn(them);

    await pump(tester);

    expect(find.text('Lovisa'), findsWidgets);
    expect(find.text('Lägg till vän'), findsNothing);
    expect(find.byTooltip('Fler åtgärder'), findsNothing);
  });

  testWidgets('R8-7 through the view: a profile not findable in search gets '
      'no friend button for a non-friend', (tester) async {
    when(
      () => users.fetchPersistedSearchable(them),
    ).thenAnswer((_) async => false);

    await pump(tester);

    expect(find.text('Lovisa'), findsWidgets);
    expect(find.text('Lägg till vän'), findsNothing);
    expect(find.byTooltip('Fler åtgärder'), findsOneWidget);
  });

  testWidgets('friends lists not loaded: no button yet, and the view asks '
      'them to load', (tester) async {
    final service =
        TestServiceLocator.get<UnifiedFriendsService>()
            as MockUnifiedFriendsService;
    service.setFriendsState(isInitialized: false, isLoading: true);
    when(service.initialize).thenAnswer((_) async {});

    await pump(tester);

    expect(find.text('Lovisa'), findsWidgets);
    expect(find.text('Lägg till vän'), findsNothing);
    verify(service.initialize).called(1);
  });
}
