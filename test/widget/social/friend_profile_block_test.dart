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

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friend_profile_view.dart';

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
    await tester.tap(find.byIcon(Icons.more_vert));
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
    // The screen's condition is `!= blocked`. Inverting it to `== none` is
    // invisible to a two-valued fake, and it hides Blockera from every friend
    // — which is everyone who can reach this screen at all.
    friendsViewModel.setFriendshipStatus(_them, FriendshipStatus.friends);

    await openMenu(tester);

    expect(find.text('Blockera'), findsOneWidget);
  });

  testWidgets('someone already blocked is not offered Blockera again', (
    tester,
  ) async {
    friendsViewModel.setBlockedUsers({_them});

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
}
