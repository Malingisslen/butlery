/// Widget tests for [GroupMenuEntryButton] (BUT-1971).
///
/// What this entry point has to get right:
///
/// 1. Only GROUP conversations reach the screen. A DM has no weekly plan, so a
///    user with only DMs must be told, not navigated.
/// 2. The screen is keyed on the conversation's `id`, NOT on `groupId` —
///    `MessagingService.closePoll` writes `groupId: conversation.id`, so the
///    chat-group id would read a document nobody writes. The fixture therefore
///    gives the chosen conversation an `id` that DIFFERS from its `groupId`;
///    with the two equal the swap is unkillable and the test is decoration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/group_weekly_menu_view.dart';
import 'package:butlery/widgets/menu/group_menu_entry_button.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockMessagingService extends Mock implements MessagingService {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockGroupPlanService extends Mock
    implements GroupWeeklyMenuPlanService {}

class _MockRealtime extends Mock implements RealtimeGroupMenuModule {}

class _MockUserService extends Mock implements UserService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

const _me = 'user-me';

Conversation _conversation({
  required String id,
  String? groupId,
  String? title,
}) {
  return Conversation(
    id: id,
    participantIds: const [_me],
    participantDisplayNames: const {_me: 'Malin'},
    participantAvatarUrls: const {},
    lastReadTimestamps: const {},
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    isGroup: groupId != null,
    groupId: groupId,
    title: title,
  );
}

void main() {
  late _MockMessagingService messaging;
  late _MockPermissionService permissions;
  late _MockGroupPlanService planService;
  late _MockRealtime realtime;
  late _MockUserService userService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    messaging = _MockMessagingService();
    permissions = _MockPermissionService();
    planService = _MockGroupPlanService();
    realtime = _MockRealtime();
    userService = _MockUserService();
    when(() => permissions.currentUserId).thenReturn(_me);

    // The pushed screen builds for real, so its collaborators must answer.
    when(
      () => planService.readWeek(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (_) async => const GroupWeeklyMenuPlanRead(plan: null, readFailed: false),
    );
    when(
      () => realtime.subscribe(
        groupId: any(named: 'groupId'),
        date: any(named: 'date'),
        onUpdate: any(named: 'onUpdate'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer(
      (_) => const Stream<GroupWeeklyMenuPlan?>.empty().listen((_) {}),
    );
    when(() => userService.getUserProfiles(any())).thenAnswer((_) async => []);

    TestServiceLocator.registerMock<MessagingService>(messaging);
    TestServiceLocator.registerMock<PermissionService>(permissions);
    TestServiceLocator.registerMock<GroupWeeklyMenuPlanService>(planService);
    TestServiceLocator.registerMock<RealtimeGroupMenuModule>(realtime);
    TestServiceLocator.registerMock<UserService>(userService);
    TestServiceLocator.registerMock<AuthRepository>(_MockAuthRepository());
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  void stubConversations(List<Conversation> conversations) {
    when(
      () => messaging.getMyConversations(),
    ).thenAnswer((_) => Stream.value(conversations));
  }

  Future<void> tapEntry(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: const GroupMenuEntryButton()),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
  }

  testWidgets('a user with only DMs is told, not navigated', (tester) async {
    stubConversations([_conversation(id: 'dm-1')]);

    await tapEntry(tester);

    expect(find.text('Du är inte med i någon grupp än.'), findsOneWidget);
    // Informational, not an error: `showError` would draw its own dismiss
    // action and read as something having gone wrong.
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(
      find.byType(GroupWeeklyMenuView),
      findsNothing,
      reason: 'a DM has no weekly plan document to open',
    );
  });

  // A stream that fails is precisely why the `catch` exists: `_open` is fired
  // through `unawaited`, so without it the tap produces nothing at all.
  testWidgets('a failing conversation stream is reported, not swallowed', (
    tester,
  ) async {
    when(
      () => messaging.getMyConversations(),
    ).thenAnswer((_) => Stream.error(Exception('offline')));

    await tapEntry(tester);

    expect(find.text('Kunde inte hämta dina grupper.'), findsOneWidget);
    expect(find.byType(GroupWeeklyMenuView), findsNothing);
  });

  testWidgets('a group with no title opens under the fallback name', (
    tester,
  ) async {
    stubConversations([_conversation(id: 'conv-a', groupId: 'chat-group-a')]);

    await tapEntry(tester);

    final view = tester.widget<GroupWeeklyMenuView>(
      find.byType(GroupWeeklyMenuView),
    );
    expect(
      view.groupName,
      'Namnlös grupp',
      reason: 'an empty app bar reads as a broken screen',
    );
  });

  testWidgets('the chosen group opens keyed on its CONVERSATION id', (
    tester,
  ) async {
    stubConversations([
      _conversation(id: 'conv-a', groupId: 'chat-group-a', title: 'Måndag'),
      // Untitled on purpose: `_pickGroup` carries its OWN copy of the fallback,
      // and the single-group test above skips the picker entirely, so nothing
      // else can reach this one.
      _conversation(id: 'conv-b', groupId: 'chat-group-b'),
    ]);

    await tapEntry(tester);

    // Two groups, so the picker rides along.
    await tester.tap(find.text('Namnlös grupp'));
    await tester.pumpAndSettle();

    final view = tester.widget<GroupWeeklyMenuView>(
      find.byType(GroupWeeklyMenuView),
    );
    expect(
      view.groupId,
      'conv-b',
      reason:
          'closePoll writes `groupId: conversation.id`, so the chat-group '
          'id would open a document nobody writes',
    );
    expect(view.groupName, 'Namnlös grupp');
  });
}
