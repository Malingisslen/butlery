/// The chat's entry point to the group weekly menu (BUT-1971).
///
/// What the chat's entry point has to get right. The first three only hold
/// TOGETHER — a test written from the menu literal alone leaves the visibility
/// filter and the document key open, and each of them fails on its own:
///
/// 1. The item appears only on a conversation that belongs to a chat group.
///    A direct message has no plan document, so the screen would open on a
///    week nobody writes.
/// 2. Selecting it reaches the group-menu action at all — the popup value and
///    the handler's switch are two literals that must agree.
/// 3. The screen is keyed on the conversation's `id`, NOT on its `groupId`.
///    `MessagingService.closePoll` writes `groupId: conversation.id`. The
///    fixture therefore gives the conversation an `id` that DIFFERS from its
///    `groupId`; with the two equal the swap is unkillable.
/// 4. Conversation info routes on `groupId`, not on the `isGroup` flag — the
///    detail view reads a `chat_groups` document, and only `groupId` says one
///    exists.
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
import 'package:butlery/views/messaging/chat_view/chat_action_handler.dart';
import 'package:butlery/views/messaging/group_detail_view.dart';
import 'package:butlery/widgets/messaging/chat_app_bar.dart';

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
const _conversationId = 'conv-1';

Conversation _conversation({String? groupId}) => Conversation(
  id: _conversationId,
  participantIds: const [_me],
  participantDisplayNames: const {_me: 'Malin'},
  participantAvatarUrls: const {},
  lastReadTimestamps: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  isGroup: groupId != null,
  groupId: groupId,
  title: 'Torsdagsklubben',
);

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

  /// Renders the real app bar wired to the real action handler, and opens its
  /// overflow menu.
  Future<void> openMenu(WidgetTester tester, Conversation conversation) async {
    when(
      () => messaging.getConversation(any()),
    ).thenAnswer((_) async => conversation);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            appBar: ChatAppBar(
              conversation: conversation,
              onMenuAction: (action) => ChatActionHandler(
                conversationId: _conversationId,
                context: context,
              ).handleMenuAction(action),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  // The two fields answer different questions and can disagree: `isGroup` is
  // an ordinary client field, while `groupId` is what says a `chat_groups`
  // document exists — `Conversation.groupId`'s own doc says not to substitute
  // one for the other. The fixture below sets them APART on purpose.
  testWidgets('conversation info follows groupId, not the isGroup flag', (
    tester,
  ) async {
    final conversation = Conversation(
      id: _conversationId,
      participantIds: const [_me],
      participantDisplayNames: const {_me: 'Malin'},
      participantAvatarUrls: const {},
      lastReadTimestamps: const {},
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isGroup: true,
      groupId: null,
      title: 'Torsdagsklubben',
    );
    await openMenu(tester, conversation);

    // The app bar's own gate, measured against the one fixture where the two
    // fields disagree.
    expect(find.text('Veckans meny'), findsNothing);

    await tester.tap(find.text('Konversationsinfo'));
    await tester.pumpAndSettle();

    expect(
      find.byType(ConversationGroupDetailView),
      findsNothing,
      reason: 'there is no chat_groups document for the detail view to read',
    );
    expect(find.text('Typ: Direktmeddelande'), findsOneWidget);
  });

  testWidgets('a direct message is offered no group menu', (tester) async {
    await openMenu(tester, _conversation());

    expect(
      find.text('Veckans meny'),
      findsNothing,
      reason: 'a DM has no plan document, so the screen would open on nothing',
    );
  });

  testWidgets('a group conversation opens its week, keyed on the CONVERSATION '
      'id', (tester) async {
    await openMenu(tester, _conversation(groupId: 'chat-group-1'));

    expect(find.text('Veckans meny'), findsOneWidget);

    await tester.tap(find.text('Veckans meny'));
    await tester.pumpAndSettle();

    final view = tester.widget<GroupWeeklyMenuView>(
      find.byType(GroupWeeklyMenuView),
    );
    expect(
      view.groupId,
      _conversationId,
      reason:
          'closePoll writes `groupId: conversation.id`, so the chat-group id '
          'would open a document nobody writes',
    );
  });
}
