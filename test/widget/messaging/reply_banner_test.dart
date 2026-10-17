// The reply banner above the chat input: who is being answered, the quoted
// text, and a close button that drops the reply.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/widgets/messaging/reply_banner.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final message = Message(
    id: 'm1',
    conversationId: 'c1',
    senderId: 'u2',
    senderDisplayName: 'Erik',
    content: 'Ska vi ta pannkakor?',
    type: MessageType.text,
    status: MessageStatus.sent,
    sentAt: DateTime(2026, 10, 17, 12),
  );

  testWidgets('names the sender, quotes the message and cancels on close', (
    tester,
  ) async {
    var cancelled = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ReplyBanner(message: message, onCancelReply: () => cancelled++),
      ),
    );

    expect(find.textContaining('Erik'), findsOneWidget);
    expect(find.text('Ska vi ta pannkakor?'), findsOneWidget);

    await tester.tap(find.byTooltip('Avbryt svar'));
    await tester.pump();

    expect(cancelled, 1);
  });
}
