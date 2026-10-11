import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/messaging/dialogs/block_group_member_dialog.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPermissionService extends Mock implements PermissionService {}

class _MockUserService extends Mock implements UserService {}

const _me = 'user-me';
const _anna = 'user-anna';
const _bjorn = 'user-bjorn';

UserProfile _profile(String uid, String name) => UserProfile(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  joinedAt: DateTime.utc(2026, 1, 1),
  lastActiveAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late MockFriendsViewModel friendsViewModel;
  final sentinel = _profile('sentinel', 'Sentinel');
  UserProfile? result;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    friendsViewModel = MockFriendsViewModel();
    final permissions = _MockPermissionService();
    final userService = _MockUserService();
    when(() => permissions.currentUserId).thenReturn(_me);
    when(() => userService.getUserProfiles(any())).thenAnswer(
      (invocation) async => ProfileBatchLookup(
        profiles: (invocation.positionalArguments.first as List<String>)
            .map(
              (id) => _profile(id, id == _anna ? 'Anna Svensson' : 'Björn Ek'),
            )
            .toList(),
        missingIds: const {},
        unavailableIds: const {},
      ),
    );
    TestServiceLocator.registerMock<PermissionService>(permissions);
    TestServiceLocator.registerMock<UserService>(userService);
    production.ServiceLocator.initialize(DIContainer());
    result = sentinel;
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    production.ServiceLocator.reset();
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await BlockGroupMemberDialog.show(
                context,
                participantIds: const [_me, _anna, _bjorn],
                friendsViewModel: friendsViewModel,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Avbryt closes the picker and hands the caller null', (
    tester,
  ) async {
    await openDialog(tester);
    expect(find.byType(BlockGroupMemberDialog), findsOneWidget);
    expect(find.text('Anna Svensson'), findsOneWidget);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(find.byType(BlockGroupMemberDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('tapping a member row returns that member profile', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(find.text('Anna Svensson'));
    await tester.pumpAndSettle();

    expect(find.byType(BlockGroupMemberDialog), findsNothing);
    expect(result?.uid, _anna);
  });
}
