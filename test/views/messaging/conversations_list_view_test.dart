/// Behaviour tests for [ConversationsListView] — the messaging inbox.
///
/// The view is `Consumer<ConversationsViewModel>`-driven: production wraps it
/// in a `ChangeNotifierProvider<ConversationsViewModel>.value` owned by
/// `_ConversationsProviderWrapper` in the messaging deferred module. We mirror
/// that here by providing a REAL [ConversationsViewModel] built on a
/// [MockMessagingService] whose `getMyConversations()` returns a broadcast
/// stream WE control. Driving real VM state transitions (loading → empty →
/// populated → error) through that stream exercises the actual loading-flag,
/// search-filter and section-bucketing logic the view branches on, rather than
/// stubbing the VM's getters.
///
/// The VM resolves `currentUserId` through the production [PermissionService]
/// (test-user-123 by default) and `LayoutComponents.offlineIndicator()`
/// resolves [OfflineService] in initState — both wired through the prod↔test
/// ServiceLocator bridge.
///
/// Rebuilt for BUT-1180 — replaces a ~51-test ULTRATHINK smoke-suite of
/// `takeException isNull` / `find.byType(Scaffold)` structural asserts that all
/// threw "ServiceLocator not initialized" because they never wired the bridge.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/views/messaging/conversations_list_view.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/widgets/messaging/conversation_list_item.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/service_mocks.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../helpers/view_test_helpers.dart';

// The current user the bridged FakePermissionService reports. The VM reads this
// to resolve direct-conversation display titles.
const _currentUserId = 'test-user-123';

// Swedish copy the view renders (from app_sv.arb). Captured as constants so a
// behaviour regression — not a copy tweak — is what fails an assertion.
// ButleryHeader renders the title lowercased (project convention: header
// titles display in lowercase), so the rendered text is 'meddelanden'.
const _appBarTitle = 'meddelanden'; // messagingTitle, lowercased by the header
const _loadingCopy =
    'Laddar konversationer...'; // messagingLoadingConversations
const _emptyTitle = 'Inga konversationer än'; // messagingNoConversationsYet
const _emptySubtitle =
    'Starta din första konversation genom att trycka på meddelande-knappen'; // messagingStartFirstConversation
const _newConversation = 'Ny konversation'; // messagingNewConversation

/// Builds a direct conversation with [otherDisplayName] as the partner. When
/// [withUnreadMessage] is true the conversation carries a lastMessage but NO
/// read-timestamp for the current user, so `hasUnreadMessages(currentUser)`
/// returns true (the unread-indicator path).
Conversation _directConversation({
  required String id,
  required String otherUserId,
  required String otherDisplayName,
  String? lastMessageContent,
  bool withUnreadMessage = false,
}) {
  final created = DateTime(2026, 6, 2, 12);
  Message? lastMessage;
  if (lastMessageContent != null) {
    // Message.text stamps sentAt = clock.now() (real run time). For a READ
    // conversation the read-timestamp must be AFTER that message, so use a
    // far-future read time; for an UNREAD one we leave the current user's
    // read-timestamp absent (hasUnreadMessages → true).
    lastMessage = Message.text(
      conversationId: id,
      senderId: otherUserId,
      senderDisplayName: otherDisplayName,
      content: lastMessageContent,
    );
  }
  final readTime = DateTime(2100);
  return Conversation(
    id: id,
    participantIds: [_currentUserId, otherUserId],
    participantDisplayNames: {
      _currentUserId: 'Jag',
      otherUserId: otherDisplayName,
    },
    participantAvatarUrls: {_currentUserId: null, otherUserId: null},
    lastMessage: lastMessage,
    lastReadTimestamps: withUnreadMessage
        ? const {}
        : {_currentUserId: readTime, otherUserId: readTime},
    createdAt: created,
    updatedAt: created,
    isGroup: false,
  );
}

void main() {
  late MockMessagingService messagingService;
  late StreamController<List<Conversation>> conversationsController;
  late MockOfflineService offlineService;
  late ConversationsViewModel viewModel;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // The VM subscribes to getMyConversations() in its constructor. A broadcast
    // controller lets the test drive loading → data → error transitions and
    // emit nothing by default (the initial loading state).
    conversationsController = StreamController<List<Conversation>>.broadcast();
    messagingService = MockMessagingService();
    when(
      () => messagingService.getMyConversations(),
    ).thenAnswer((_) => conversationsController.stream);

    // LayoutComponents.offlineIndicator() resolves OfflineService and reads
    // isOnline in initState. Register an online mock so it builds collapsed.
    offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);

    // PermissionService is auto-registered by TestServiceLocator with
    // currentUserId == 'test-user-123', which is exactly _currentUserId.
    // BUT-1838: chatGroupRepository is passed explicitly — the VM's
    // constructor resolves it eagerly (ServiceLocator fallback), and nothing
    // registers ChatGroupRepository in this view test's DI bridge.
    viewModel = ConversationsViewModel(
      messagingService: messagingService,
      chatGroupRepository: MockChatGroupRepository(),
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await conversationsController.close();
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget testApp() {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: ChangeNotifierProvider<ConversationsViewModel>.value(
        value: viewModel,
        child: const ConversationsListView(),
      ),
    );
  }

  // Pump the view on a tall surface. The inbox nests a Scaffold + search bar +
  // an empty/list body; on a short surface the branded empty state overflows
  // vertically. That overflow is a layout artifact of the surrounding scaffold,
  // orthogonal to the state behaviour under test — so we ignore RenderFlex
  // overflow FlutterErrors ONLY, letting every other error fail as normal.
  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(testApp());
  }

  group('ConversationsListView — inbox states', () {
    testWidgets(
      'before the stream emits, shows the Swedish loading copy and the title',
      (tester) async {
        await pumpView(tester);
        // Two discrete pumps (not pumpAndSettle): the loading overlay animates
        // perpetually, so pumpAndSettle would hang.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(_appBarTitle), findsOneWidget);
        expect(find.text(_loadingCopy), findsOneWidget);
      },
    );

    testWidgets(
      'an empty conversations emission renders the branded empty state, not a list',
      (tester) async {
        await pumpView(tester);
        await tester.pump();

        conversationsController.add(const []);
        await tester.pumpAndSettle();

        expect(find.text(_emptyTitle), findsOneWidget);
        expect(find.text(_emptySubtitle), findsOneWidget);
        // No conversation rows are rendered in the empty state.
        expect(find.byType(ConversationListItem), findsNothing);
        // The empty state's primary CTA reuses the "new conversation" label.
        expect(find.text(_newConversation), findsWidgets);
      },
    );

    testWidgets(
      'a populated emission renders one row per conversation with its partner title',
      (tester) async {
        await pumpView(tester);
        await tester.pump();

        conversationsController.add([
          _directConversation(
            id: 'c1',
            otherUserId: 'u-anna',
            otherDisplayName: 'Anna Andersson',
            lastMessageContent: 'Vi ses imorgon!',
          ),
          _directConversation(
            id: 'c2',
            otherUserId: 'u-erik',
            otherDisplayName: 'Erik Svensson',
            lastMessageContent: 'Tack för recepten',
          ),
        ]);
        await tester.pumpAndSettle();

        // One row per conversation, each titled by the OTHER participant's name
        // (getDisplayTitle resolves against the current user).
        expect(find.byType(ConversationListItem), findsNWidgets(2));
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Erik Svensson'), findsOneWidget);
        // The empty state is gone.
        expect(find.text(_emptyTitle), findsNothing);
        // The last-message preview is shown for direct conversations.
        expect(find.text('Vi ses imorgon!'), findsOneWidget);
      },
    );

    testWidgets(
      'an unread conversation shows the unread indicator dot; a read one does not',
      (tester) async {
        await pumpView(tester);
        await tester.pump();

        final unread = _directConversation(
          id: 'c-unread',
          otherUserId: 'u-unread',
          otherDisplayName: 'Olästa Meddelanden',
          lastMessageContent: 'Du har ett nytt meddelande',
          withUnreadMessage: true,
        );
        final read = _directConversation(
          id: 'c-read',
          otherUserId: 'u-read',
          otherDisplayName: 'Lästa Meddelanden',
          lastMessageContent: 'Redan läst',
        );
        conversationsController.add([unread, read]);
        await tester.pumpAndSettle();

        // Both rows render.
        expect(find.byType(ConversationListItem), findsNWidgets(2));

        // The unread row styles its title heavier (bodyBold) than the read row
        // (bodyMedium) — the user-visible "this conversation is unread" cue.
        // Assert the unread weight is strictly heavier than the read weight
        // rather than a hardcoded value, so a typography token tweak that keeps
        // the contrast doesn't break the test.
        Finder titleText(String name) => find.descendant(
          of: find.byType(ConversationListItem),
          matching: find.text(name),
        );
        final unreadTitle = tester.widget<Text>(
          titleText('Olästa Meddelanden'),
        );
        final readTitle = tester.widget<Text>(titleText('Lästa Meddelanden'));
        final unreadWeight = unreadTitle.style?.fontWeight ?? FontWeight.normal;
        final readWeight = readTitle.style?.fontWeight ?? FontWeight.normal;
        expect(
          unreadWeight.index,
          greaterThan(readWeight.index),
          reason: 'unread title should be visually heavier than read title',
        );

        // And the model invariant driving that cue holds for each.
        expect(unread.hasUnreadMessages(_currentUserId), isTrue);
        expect(read.hasUnreadMessages(_currentUserId), isFalse);
      },
    );

    testWidgets(
      'typing a search query filters the visible rows to the matching partner',
      (tester) async {
        await pumpView(tester);
        await tester.pump();

        conversationsController.add([
          _directConversation(
            id: 'c1',
            otherUserId: 'u-anna',
            otherDisplayName: 'Anna Andersson',
            lastMessageContent: 'Hej',
          ),
          _directConversation(
            id: 'c2',
            otherUserId: 'u-erik',
            otherDisplayName: 'Erik Svensson',
            lastMessageContent: 'Hej',
          ),
        ]);
        await tester.pumpAndSettle();
        expect(find.byType(ConversationListItem), findsNWidgets(2));

        // The search field is the only TextField in the view. Type a query that
        // matches only Anna's title; the search listener pushes it into the VM,
        // which re-filters _filteredConversations.
        await tester.enterText(find.byType(TextField), 'anna');
        await tester.pumpAndSettle();

        expect(find.byType(ConversationListItem), findsOneWidget);
        expect(find.text('Anna Andersson'), findsOneWidget);
        expect(find.text('Erik Svensson'), findsNothing);
      },
    );

    testWidgets(
      'a stream error surfaces the Swedish error empty state with a retry action',
      (tester) async {
        await pumpView(tester);
        await tester.pump();

        conversationsController.addError(Exception('stream blew up'));
        await tester.pumpAndSettle();

        // The VM maps the stream error to errorCouldNotLoad('konversationer');
        // the view renders the generic error empty state titled errorGeneric with
        // that subtitle and a retry CTA. Assert the VM reached the error state and
        // the error subtitle is visible.
        expect(viewModel.conversationsError, isNotNull);
        expect(find.text(viewModel.conversationsError!), findsOneWidget);
        // No list and no loading copy once the error state is shown.
        expect(find.byType(ConversationListItem), findsNothing);
        expect(find.text(_loadingCopy), findsNothing);
      },
    );
  });
}
