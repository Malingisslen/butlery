/// Hosts for the inbox-style views: feedback, conversations, notifications
/// and the shared shopping lists.
library;

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/views/admin/feedback_inbox_view.dart';
import 'package:butlery/views/messaging/conversations_list_view.dart';
import 'package:butlery/views/notifications/notifications_view.dart';
import 'package:butlery/views/social/shared_shopping_lists_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../state_host.dart';
import 'shopping_hosts.dart' show sharedListSketchHost;

class _MockFeedbackRepository extends Mock implements FeedbackRepository {}

const _me = 'test-user-123';

FeedbackEntry _feedback(
  String id,
  String text,
  FeedbackCategory category, {
  FeedbackStatus status = FeedbackStatus.newReport,
}) => FeedbackEntry(
  id: id,
  userId: 'u1',
  category: category,
  description: text,
  status: status,
  recentInteractions: const [],
  createdAt: DateTime.utc(2026, 9, 20, 8),
);

Conversation _conversation(
  String id,
  String name,
  String preview, {
  bool unread = false,
  int minutesAgo = 5,
}) {
  final sent = DateTime.utc(2026, 9, 20, 17).subtract(
    Duration(minutes: minutesAgo),
  );
  final other = 'u-$id';
  return Conversation(
    id: id,
    participantIds: [_me, other],
    participantDisplayNames: {_me: 'Malin', other: name},
    participantAvatarUrls: {_me: null, other: null},
    lastMessage: Message(
      id: 'm-$id',
      conversationId: id,
      senderId: other,
      senderDisplayName: name,
      content: preview,
      type: MessageType.text,
      status: MessageStatus.sent,
      sentAt: sent,
    ),
    lastReadTimestamps: {
      _me: unread
          ? sent.subtract(const Duration(hours: 1))
          : DateTime.utc(2100),
    },
    createdAt: sent.subtract(const Duration(days: 3)),
    updatedAt: sent,
    isGroup: false,
  );
}

NotificationHistoryEntry _notification(
  String id,
  String category,
  String title,
  String body, {
  bool opened = false,
  int hoursAgo = 1,
}) => NotificationHistoryEntry(
  id: id,
  notificationId: 'n-$id',
  category: category,
  type: category,
  data: {'title': title, 'body': body},
  sentAt: DateTime.utc(2026, 9, 20, 12).subtract(Duration(hours: hoursAgo)),
  delivered: true,
  opened: opened,
);

UnifiedShoppingList _sharedList(String id, String name, List<String> items) =>
    ShoppingListFactory.build(
      id: id,
      name: name,
      ownerId: _me,
      ownerDisplayName: 'Malin',
      type: ListType.collaborative,
      memberPermissions: const {
        _me: SharedListPermission.admin,
        'u-per': SharedListPermission.edit,
        'u-anna': SharedListPermission.edit,
      },
      items: [
        for (final (i, n) in items.indexed)
          ShoppingListFactory.buildItem(
            id: '$id-$i',
            name: n,
            amount: 1,
            unit: 'st',
            category: 'Torrvaror',
            bought: i == 0,
            addedAt: DateTime(2026, 9, 20),
          ),
      ],
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
    );

final reviewCHosts = <String, StateHost>{
  'FeedbackInboxView': StateHost(
    build: (ctx) async {
      final stream = StreamController<List<FeedbackEntry>>.broadcast();
      ctx.disposers.add(() => unawaited(stream.close()));
      final repo = _MockFeedbackRepository();
      when(
        () => repo.watchFeedback(
          status: any(named: 'status'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => stream.stream);
      TestServiceLocator.registerMock<FeedbackRepository>(repo);
      // A broadcast event sent before the view subscribes is lost.
      Timer(
        const Duration(milliseconds: 50),
        () => stream.add([
          _feedback(
            'f1',
            'Knappen Spara svarar inte i receptredigeraren',
            FeedbackCategory.bug,
          ),
          _feedback(
            'f2',
            'Veckomenyn visar fel vecka efter midnatt',
            FeedbackCategory.bug,
            status: FeedbackStatus.triaged,
          ),
          _feedback(
            'f3',
            'Krasch vid export av stor lista',
            FeedbackCategory.bug,
            status: FeedbackStatus.resolved,
          ),
        ]),
      );
      return const FeedbackInboxView();
    },
  ),
  'ConversationsListView': StateHost(
    build: (ctx) async {
      final stream = StreamController<List<Conversation>>.broadcast();
      final messaging = MockMessagingService();
      when(messaging.getMyConversations).thenAnswer((_) => stream.stream);
      final vm = ConversationsViewModel(
        messagingService: messaging,
        chatGroupRepository: MockChatGroupRepository(),
      );
      ctx.disposers
        ..add(() => unawaited(stream.close()))
        ..add(vm.dispose);
      scheduleMicrotask(
        () => stream.add([
          _conversation(
            'anna',
            'Anna Lindqvist',
            'Toppen, då tar jag med koriander.',
            unread: true,
          ),
          _conversation(
            'per',
            'Per Nilsson',
            'Kan du köpa havremjölk i stället?',
            minutesAgo: 180,
          ),
          _conversation(
            'cecilia',
            'Cecilia Berg',
            'Tack för receptet på rabarberpajen!',
            minutesAgo: 60 * 30,
          ),
        ]),
      );
      return ChangeNotifierProvider<ConversationsViewModel>.value(
        value: vm,
        child: const ConversationsListView(),
      );
    },
  ),
  'NotificationsView': StateHost(
    build: (ctx) async {
      final service = MockNotificationService();
      when(
        () => service.getNotificationHistory(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => [
          _notification(
            'a',
            'friends',
            'Ny vänförfrågan',
            'Anna Lindqvist vill bli vän med dig.',
          ),
          _notification(
            'b',
            'shopping',
            'Veckans inköp har ändrats',
            'Per lade till Kokosmjölk i listan.',
            hoursAgo: 4,
          ),
          _notification(
            'c',
            'recipes',
            'Anna delade ett recept',
            'Kycklinggryta med citron väntar på dig.',
            opened: true,
            hoursAgo: 26,
          ),
          _notification(
            'd',
            'messaging',
            'Nytt meddelande',
            'Cecilia: Tack för receptet på rabarberpajen!',
            opened: true,
            hoursAgo: 50,
          ),
        ],
      );
      TestServiceLocator.registerMock<NotificationService>(service);
      return const NotificationsView();
    },
  ),
  'CollaborativeShoppingView': sharedListSketchHost,
  'SharedShoppingListsView': StateHost(
    build: (ctx) async {
      final lists = [
        _sharedList('l1', 'Veckans inköp', ['Röda linser', 'Kokosmjölk']),
        _sharedList('l2', 'Midsommarfesten', [
          'Jordgubbar',
          'Gräddfil',
          'Sill',
        ]),
      ];
      final service = MockUnifiedShoppingService()
        ..setShoppingState(lists: lists, collaborativeLists: lists);
      when(service.loadLists).thenAnswer((_) async {});
      TestServiceLocator.registerMock<UnifiedShoppingService>(service);
      return const SharedShoppingListsView();
    },
  ),
};
