/// BUT-2376: a chat photo opens the shared fullscreen viewer on that one
/// photo, with the message text as its caption and none when the text is
/// empty.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/widgets/common/image/fullscreen_image_viewer.dart';
import 'package:butlery/widgets/messaging/builders/message_content_builder.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

const _url = 'https://invalid.invalid/photo.jpg';

Message _imageMessage(String content) => Message(
  id: 'm1',
  conversationId: 'c1',
  senderId: 'u1',
  senderDisplayName: 'Erik',
  content: content,
  type: MessageType.image,
  status: MessageStatus.sent,
  sentAt: DateTime.utc(2026, 10, 11),
  metadata: const {'imageUrl': _url},
);

Future<FullscreenImageViewer> _tapPhoto(
  WidgetTester tester,
  Message message,
) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: Builder(
        builder: (context) => MessageContentBuilder.build(
          context: context,
          message: message,
          isFromCurrentUser: false,
        ),
      ),
    ),
  );
  final photo = find.descendant(
    of: find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label == AppLocalizationsSv().a11yImageMessageTap,
    ),
    matching: find.byType(GestureDetector),
  );
  await tester.tap(photo.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return tester.widget<FullscreenImageViewer>(
    find.byType(FullscreenImageViewer),
  );
}

void main() {
  testWidgets('the message text becomes the caption', (tester) async {
    final viewer = await _tapPhoto(tester, _imageMessage('Söndagsmiddag'));
    expect(viewer.imageUrls, [_url]);
    expect(viewer.caption, 'Söndagsmiddag');
  });

  testWidgets('a photo sent without text opens with no caption', (
    tester,
  ) async {
    final viewer = await _tapPhoto(tester, _imageMessage(''));
    expect(viewer.imageUrls, [_url]);
    expect(viewer.caption, isNull);
  });
}
