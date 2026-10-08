// P5-U03 (chatt ERROR): a chat failure names what failed and offers
// Försök igen or Stäng, never OK (content-style-guide.md:87-97). Where typed
// content is at stake (an edit) it also says what was kept, and Försök igen
// sends the same content again, so nothing typed is lost.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_action_handler.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockPlanService extends Mock implements WeeklyMenuPlanService {}

class _MockMessagingService extends Mock implements MessagingService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockMessagingService messagingService;

  const conversationId = 'conv-1';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    messagingService = _MockMessagingService();
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(_MockPlanService());
    TestServiceLocator.registerMock<MessagingService>(messagingService);
    TestServiceLocator.registerMock<AuthRepository>(_MockAuthRepository());
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpAndRun(
    WidgetTester tester,
    Future<void> Function(ChatActionHandler handler) run,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => run(
                ChatActionHandler(
                  conversationId: conversationId,
                  context: context,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a failed poll says the poll was not created, and Försök igen '
      'sends the same poll again', (tester) async {
    final poll = {'question': 'Tacos eller pasta?'};
    var calls = 0;
    when(
      () => messagingService.sendPollMessage(
        conversationId: any(named: 'conversationId'),
        pollData: any(named: 'pollData'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('permission-denied');
    });

    await pumpAndRun(tester, (h) => h.handlePollCreate(poll));

    expect(find.text('Omröstningen kunde inte skapas.'), findsOneWidget);
    expect(find.text('Ett fel uppstod'), findsNothing);
    expect(find.text('OK'), findsNothing);

    await tester.tap(find.text('Försök igen'));
    await tester.pumpAndSettle();

    verify(
      () => messagingService.sendPollMessage(
        conversationId: conversationId,
        pollData: poll,
      ),
    ).called(2);
    expect(find.text('Omröstningen kunde inte skapas.'), findsNothing);
  });

  testWidgets('a failed edit says the message is unchanged, and Försök igen '
      'saves the same edit', (tester) async {
    var calls = 0;
    when(
      () => messagingService.editMessage(
        messageId: any(named: 'messageId'),
        newContent: any(named: 'newContent'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('unavailable');
    });
    final message = Message(
      id: 'msg-1',
      conversationId: conversationId,
      senderId: 'me',
      senderDisplayName: 'Malin',
      content: 'Vi ses sex',
      type: MessageType.text,
      status: MessageStatus.sent,
      sentAt: DateTime(2026, 9, 23),
    );

    await pumpAndRun(tester, (h) => h.handleMessageAction(message, 'edit'));
    await tester.enterText(find.byType(TextField), 'Vi ses sju');
    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        SnackBarUtils.failureMessage(
          'Ändringen kunde inte sparas.',
          'Meddelandet är oförändrat.',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Försök igen'));
    await tester.pumpAndSettle();

    verify(
      () => messagingService.editMessage(
        messageId: 'msg-1',
        newContent: 'Vi ses sju',
      ),
    ).called(2);
  });

  testWidgets('a failure with nothing to retry offers Stäng', (tester) async {
    when(
      () => messagingService.deleteMessage(any()),
    ).thenAnswer((_) async => throw Exception('unavailable'));
    final message = Message(
      id: 'msg-2',
      conversationId: conversationId,
      senderId: 'me',
      senderDisplayName: 'Malin',
      content: 'Hej',
      type: MessageType.text,
      status: MessageStatus.sent,
      sentAt: DateTime(2026, 9, 23),
    );

    await pumpAndRun(tester, (h) => h.handleMessageAction(message, 'delete'));
    // Confirm the delete question.
    await tester.tap(find.text('Ta bort').last);
    await tester.pumpAndSettle();

    expect(find.text('Stäng'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
  });
}
