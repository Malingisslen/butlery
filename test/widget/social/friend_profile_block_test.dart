/// The Blockera entry on a friend's profile (BUT-1951).
///
/// Three things this pins, each of which fails on its own:
///
/// 1. The item exists at all. Before this the profile menu offered only
///    "Rapportera", so blocking had no entry point anywhere in the app.
/// 2. It is HIDDEN for someone already blocked — the action has no meaning
///    twice, and the unblock path lives in privacy settings.
/// 3. Confirming reaches the ViewModel. The popup value and the handler are
///    separate literals that must agree.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friend_profile_view.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _MockMessagingService extends Mock implements MessagingService {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockUserService extends Mock implements UserService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

const _them = 'user-them';

final _friend = UserProfile(
  uid: _them,
  email: 'them@example.com',
  displayName: 'Anna Svensson',
  joinedAt: DateTime.utc(2026, 1, 1),
  lastActiveAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late MockFriendsViewModel friendsViewModel;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    friendsViewModel = MockFriendsViewModel();

    final permissions = _MockPermissionService();
    when(() => permissions.currentUserId).thenReturn('user-me');

    TestServiceLocator.registerMock<MessagingService>(_MockMessagingService());
    TestServiceLocator.registerMock<PermissionService>(permissions);
    TestServiceLocator.registerMock<UserService>(_MockUserService());
    TestServiceLocator.registerMock<AuthRepository>(_MockAuthRepository());
    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    TestServiceLocator.registerMock<OfflineService>(offline);
    TestServiceLocator.registerMock<FriendsViewModel>(friendsViewModel);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> openMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: FriendProfileView(friend: _friend)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(ButleryIcons.moreVertical));
    await tester.pumpAndSettle();
  }

  testWidgets('the profile menu offers Blockera and it reaches the ViewModel', (
    tester,
  ) async {
    await openMenu(tester);

    expect(find.text('Blockera'), findsOneWidget);
    expect(find.text('Rapportera'), findsOneWidget);

    await tester.tap(find.text('Blockera'));
    await tester.pumpAndSettle();

    // Confirm.
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    expect(friendsViewModel.blockedUserIds, equals([_them]));
  });

  testWidgets('a FRIEND is still offered Blockera', (tester) async {
    // Hiding Blockera from a friend hides it from everyone who can reach
    // this screen at all.
    friendsViewModel.setFriendshipStatus(_them, FriendshipStatus.friends);

    await openMenu(tester);

    expect(find.text('Blockera'), findsOneWidget);
  });

  testWidgets('someone already blocked is not offered Blockera again', (
    tester,
  ) async {
    friendsViewModel.setBlockedUsers({_them});
    // Seeded as blocked AND still reading as a friend — the state the
    // BUT-2022 reorder makes reachable. `setBlockedUsers` also writes the
    // status, so without this line `getFriendshipStatus` answers `blocked`
    // too and a revert of the guard to the ordered enum stays green.
    friendsViewModel.setFriendshipStatus(_them, FriendshipStatus.friends);

    await openMenu(tester);

    expect(
      find.text('Blockera'),
      findsNothing,
      reason: 'unblocking lives in privacy settings, not here',
    );
    expect(
      find.text('Rapportera'),
      findsOneWidget,
      reason: 'the rest of the menu must survive the conditional item',
    );
  });

  testWidgets('the ⋯ sheet holds share, report and block, once', (
    tester,
  ) async {
    await openMenu(tester);

    expect(find.byTooltip('Fler val'), findsOneWidget);
    expect(find.text('Rapportera'), findsOneWidget);
    expect(find.text('Blockera'), findsOneWidget);
    expect(find.text('Dela profil'), findsOneWidget);
  });

  testWidgets('the page body has two buttons and the Recept rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: FriendProfileView(friend: _friend)),
    );
    await tester.pumpAndSettle();

    // "Skicka meddelande" is the one primary action; "Dela ett recept" is the
    // outlined one next to it.
    final heroes = find.byType(HeroButton);
    expect(heroes, findsOneWidget);
    expect(
      find.descendant(of: heroes, matching: find.text('Skicka meddelande')),
      findsOneWidget,
    );
    expect(find.text('Dela ett recept'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Dela ett recept'),
        matching: find.byType(HeroButton),
      ),
      findsNothing,
    );

    expect(find.text('MELLAN ER'), findsOneWidget);
    expect(find.text('Delat med dig av Anna Svensson'), findsOneWidget);
    expect(
      find.text('Dela en länk till Anna Svenssons profil'),
      findsOneWidget,
    );
    // Removing the friend is the red line at the foot of the page, not a
    // stand-alone button.
    expect(find.text('Ta bort som vän'), findsOneWidget);
    expect(find.text('Dela profil'), findsNothing);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('vänner'), findsOneWidget);
    expect(find.text('publika recept'), findsOneWidget);
  });

  testWidgets('the public recipes row shows the count and uses a genitive', (
    tester,
  ) async {
    final friend = _friend.copyWith(
      displayName: 'Jonas',
      publicRecipeCount: 23,
    );
    await tester.pumpWidget(
      createLocalizedTestApp(child: FriendProfileView(friend: friend)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jonas publika recept'), findsOneWidget);
    // The figure sits in the stats and at the end of the row.
    expect(find.text('23'), findsNWidgets(2));
  });

  testWidgets('a name not ending in s gets an s added in the genitive', (
    tester,
  ) async {
    final friend = _friend.copyWith(displayName: 'Anna', publicRecipeCount: 4);
    await tester.pumpWidget(
      createLocalizedTestApp(child: FriendProfileView(friend: friend)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Annas publika recept'), findsOneWidget);
    expect(find.text('Anna publika recept'), findsNothing);
  });

  testWidgets('Skicka meddelande is the saffron primary button', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: FriendProfileView(friend: _friend)),
    );
    await tester.pumpAndSettle();

    final hero = find.ancestor(
      of: find.text('Skicka meddelande'),
      matching: find.byType(HeroButton),
    );
    expect(hero, findsOneWidget);
    final fill = tester
        .widget<FilledButton>(
          find.descendant(
            of: hero,
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          ),
        )
        .style!
        .backgroundColor!
        .resolve({});
    expect(fill, AppModeColors.actionPrimary(Brightness.light));
  });

  testWidgets('Ta bort som vän removes the friend after confirming and leaves '
      'the profile', (tester) async {
    when(
      () => friendsViewModel.removeFriend(any()),
    ).thenAnswer((_) async => true);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FriendProfileView(friend: _friend),
              ),
            ),
            child: const Text('open profile'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open profile'));
    await tester.pumpAndSettle();
    expect(find.byType(FriendProfileView), findsOneWidget);

    await tester.tap(find.text('Ta bort som vän'));
    await tester.pumpAndSettle();

    // Nothing is removed until the dialog is confirmed.
    verifyNever(() => friendsViewModel.removeFriend(any()));
    expect(find.text('Ta bort Anna Svensson som vän?'), findsOneWidget);

    // The dialog's confirm button reads the same as the page's red line.
    await tester.tap(find.text('Ta bort som vän').last);
    await tester.pumpAndSettle();

    verify(() => friendsViewModel.removeFriend(_them)).called(1);
    expect(find.byType(FriendProfileView), findsNothing);
  });

  testWidgets('cancelling the remove-friend dialog keeps the friend', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: FriendProfileView(friend: _friend)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ta bort som vän'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    verifyNever(() => friendsViewModel.removeFriend(any()));
    expect(find.byType(FriendProfileView), findsOneWidget);
  });

  testWidgets('Rapportera opens the report dialog', (tester) async {
    await openMenu(tester);

    await tester.tap(find.text('Rapportera'));
    await tester.pumpAndSettle();

    expect(find.text('Anmäl innehåll'), findsOneWidget);
  });

  testWidgets('the public recipes row opens that friend\'s public profile', (
    tester,
  ) async {
    final pushed = <RouteSettings>[];
    final friend = _friend.copyWith(publicRecipeCount: 3);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: FriendProfileView(friend: friend),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('route-stub')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anna Svenssons publika recept'));
    await tester.pumpAndSettle();

    expect(pushed.map((r) => r.name), [Routes.publicProfile]);
    expect(pushed.single.arguments, _them);
  });
}
