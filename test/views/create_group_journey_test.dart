/// Journey test: a user creates a group and invites a friend.
///
/// The real [CreateGroupDialog] runs (form validation, friend picker, draft
/// persistence); only the friends service edge (category creation and the
/// invitation sender) is a mock. The user opens "Skapa ny grupp", names it,
/// ticks a friend, taps "Skapa grupp", and the dialog closes handing back the
/// created group after the friend was invited to THAT group. When creation
/// fails the user is told, nothing is sent, and the dialog stays open.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/social/groups/create_group_dialog.dart';

import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/helpers/field_finder.dart';
import '../test_support/base_unit_test.dart';

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockCategories extends Mock implements FriendsCategoriesOperations {}

class _MockInvitations extends Mock implements FriendsInvitationsOperations {}

const _draftKey = 'group_creation_draft_v1';
const _me = 'u-me';

final _sv = AppLocalizationsSv();

UserProfile _friend(String uid, String name) => UserProfile(
  uid: uid,
  displayName: name,
  email: '$uid@example.com',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 1, 1),
  isOnline: false,
);

void main() {
  late _MockFriendsService friends;
  late _MockCategories categories;
  late _MockInvitations invitations;
  FriendCategory? dialogResult;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());

    dialogResult = null;
    friends = _MockFriendsService();
    categories = _MockCategories();
    invitations = _MockInvitations();
    when(() => friends.categories).thenReturn(categories);
    when(() => friends.invitations).thenReturn(invitations);
    when(() => friends.friendsList).thenReturn([
      _friend('u-anna', 'Anna Andersson'),
      _friend('u-per', 'Per Persson'),
    ]);
    when(
      () => friends.stateStream,
    ).thenAnswer((_) => const Stream<FriendsServiceState>.empty());
    TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  dialogResult = await showDialog<FriendCategory>(
                    context: context,
                    builder: (_) => const CreateGroupDialog(),
                  );
                },
                child: const Text('Ny grupp'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ny grupp'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets('user names a group, ticks a friend, and the friend is invited '
      'to the group that was created', (tester) async {
    when(
      () => categories.createCategory(
        name: any(named: 'name'),
        description: any(named: 'description'),
        icon: any(named: 'icon'),
      ),
    ).thenAnswer((_) async => 'g1');
    when(
      () => invitations.sendGroupInvitations(
        userIds: any(named: 'userIds'),
        groupId: any(named: 'groupId'),
      ),
    ).thenAnswer((_) async => {'u-anna': true});
    final created = FriendCategory(
      id: 'g1',
      ownerId: _me,
      name: 'Middagsgänget',
      friendUserIds: const [],
    );
    when(() => categories.getCategoryById('g1')).thenReturn(created);

    await openDialog(tester);
    expect(find.text(_sv.groupCreateNew), findsOneWidget);

    await tester.enterText(
      fieldLabelled(_sv.socialGroupName),
      'Middagsgänget',
    );
    await tester.ensureVisible(find.text('Anna Andersson'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.text('Anna Andersson'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.text(_sv.groupSelectedMembers(1)),
      findsOneWidget,
      reason: 'the user sees that one friend is picked',
    );

    await tester.tap(find.text(_sv.socialCreateGroup));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    verify(
      () => categories.createCategory(
        name: 'Middagsgänget',
        description: '',
        icon: any(named: 'icon'),
      ),
    ).called(1);
    verify(
      () => invitations.sendGroupInvitations(
        userIds: ['u-anna'],
        groupId: 'g1',
      ),
    ).called(1);
    expect(
      find.text(_sv.groupCreateNew),
      findsNothing,
      reason: 'the dialog closes once the group exists',
    );
    expect(dialogResult?.name, 'Middagsgänget');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(_draftKey),
      isNull,
      reason: 'a committed group leaves no draft for the next dialog',
    );
  });

  testWidgets('a group that cannot be created tells the user, invites '
      'nobody, and keeps the dialog open', (tester) async {
    when(
      () => categories.createCategory(
        name: any(named: 'name'),
        description: any(named: 'description'),
        icon: any(named: 'icon'),
      ),
    ).thenAnswer((_) async => null);

    await openDialog(tester);

    await tester.tap(find.text(_sv.socialCreateGroup));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    verifyNever(
      () => categories.createCategory(
        name: any(named: 'name'),
        description: any(named: 'description'),
        icon: any(named: 'icon'),
      ),
    );
    expect(
      find.text(_sv.groupCreateNew),
      findsOneWidget,
      reason: 'an unnamed group is not created',
    );

    await tester.enterText(
      fieldLabelled(_sv.socialGroupName),
      'Middagsgänget',
    );
    await tester.ensureVisible(find.text('Per Persson'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.text('Per Persson'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.text(_sv.socialCreateGroup));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(_sv.errorCouldNotCreateGroup), findsOneWidget);
    expect(find.text(_sv.groupCreateNew), findsOneWidget);
    verifyNever(
      () => invitations.sendGroupInvitations(
        userIds: any(named: 'userIds'),
        groupId: any(named: 'groupId'),
      ),
    );
    expect(dialogResult, isNull);
  });
}
