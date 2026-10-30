// Removing someone from a group conversation asks first:
// Avbryt leaves them in, the red button removes exactly that person.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/messaging/conversation_group_detail_view.dart';
import 'package:butlery/widgets/messaging/components/group_member_item.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/service_mocks.dart'
    show MockChatGroupRepository;

class _MockMessaging extends Mock implements MessagingService {}

class _MockFriends extends Mock implements UnifiedFriendsService {}

const _me = 'test-user-123';

void main() {
  late MockChatGroupRepository groups;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    registerFallbackValue(<String>[]);
    final messaging = _MockMessaging();
    final friends = _MockFriends();
    groups = MockChatGroupRepository();
    final conversation = Conversation(
      id: 'c1',
      participantIds: [_me, 'u-anna', 'u-per'],
      participantDisplayNames: {
        _me: 'Malin',
        'u-anna': 'Anna Lindqvist',
        'u-per': 'Per Nilsson',
      },
      participantAvatarUrls: const {},
      lastReadTimestamps: {
        _me: DateTime(2026, 9, 27),
        'u-anna': DateTime(2026, 9, 27),
        'u-per': DateTime(2026, 9, 27),
      },
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 27),
      title: 'Söndagsmiddag',
      isGroup: true,
      groupId: 'chat-g1',
    );
    when(
      messaging.getMyConversations,
    ).thenAnswer((_) => const Stream<List<Conversation>>.empty());
    when(
      () => messaging.getConversation('c1'),
    ).thenAnswer((_) async => conversation);
    when(() => friends.friends).thenReturn(const []);
    when(() => groups.watchGroup('chat-g1')).thenAnswer(
      (_) => Stream.value(
        ChatGroup(
          id: 'chat-g1',
          name: 'Söndagsmiddag',
          memberIds: [_me, 'u-anna', 'u-per'],
          adminIds: [_me],
          memberDisplayNames: const {
            _me: 'Malin',
            'u-anna': 'Anna Lindqvist',
            'u-per': 'Per Nilsson',
          },
          memberAvatarUrls: const {},
          conversationId: 'c1',
          createdBy: _me,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 27),
        ),
      ),
    );
    when(
      () => groups.removeMember(
        groupId: any(named: 'groupId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
    TestServiceLocator.registerMock<MessagingService>(messaging);
    TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
    TestServiceLocator.registerMock<ChatGroupRepository>(groups);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ConversationGroupDetailView(conversationId: 'c1'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openRemovalFor(WidgetTester tester, String name) async {
    final row = find.ancestor(
      of: find.text(name),
      matching: find.byType(GroupMemberItem),
    );
    final remove = find.descendant(
      of: row.first,
      matching: find.text('Ta bort'),
    );
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
  }

  testWidgets('Ta bort opens the question and removes nobody yet', (
    tester,
  ) async {
    await pumpView(tester);
    await openRemovalFor(tester, 'Anna Lindqvist');

    expect(find.text('Ta bort Anna Lindqvist ur samtalet?'), findsOneWidget);
    verifyNever(
      () => groups.removeMember(
        groupId: any(named: 'groupId'),
        userId: any(named: 'userId'),
      ),
    );
  });

  testWidgets('Avbryt closes the question and keeps the member', (
    tester,
  ) async {
    await pumpView(tester);
    await openRemovalFor(tester, 'Anna Lindqvist');

    final cancel = find.widgetWithText(TextButton, 'Avbryt');
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(find.text('Ta bort Anna Lindqvist ur samtalet?'), findsNothing);
    verifyNever(
      () => groups.removeMember(
        groupId: any(named: 'groupId'),
        userId: any(named: 'userId'),
      ),
    );
  });

  testWidgets('the red button removes exactly the member asked about', (
    tester,
  ) async {
    await pumpView(tester);
    await openRemovalFor(tester, 'Per Nilsson');

    final confirm = find.widgetWithText(FilledButton, 'Ta bort');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    verify(
      () => groups.removeMember(groupId: 'chat-g1', userId: 'u-per'),
    ).called(1);
  });
}
