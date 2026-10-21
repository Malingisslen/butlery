/// BUT-2294: a chat image whose picture has not arrived. The sender sees their
/// own copy and that it waits for a connection; the others see that an image
/// is on its way; after 48 hours nobody is promised a picture any more.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/widgets/messaging/builders/message_content_builder.dart';
import 'package:butlery/widgets/messaging/pending_image_bubble.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockOffline extends Mock implements OfflineService {}

class _MockStorage extends Mock implements OfflineUserStorage {}

final _sent = DateTime.utc(2026, 10, 20, 12);
final _l10n = AppLocalizationsSv();

Message _placeholder({Map<String, dynamic>? metadata}) => Message(
  id: 'm1',
  conversationId: 'c1',
  senderId: 'u1',
  senderDisplayName: 'Erik',
  content: '',
  type: MessageType.image,
  status: MessageStatus.sent,
  sentAt: _sent,
  metadata: metadata ?? const {'pendingImage': true},
);

Future<void> _pump(
  WidgetTester tester,
  Message message, {
  required bool mine,
  Future<String?> Function(String, String)? localCopy,
}) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: localCopy == null
          ? Builder(
              builder: (context) => MessageContentBuilder.build(
                context: context,
                message: message,
                isFromCurrentUser: mine,
              ),
            )
          : PendingImageBubble(
              message: message,
              isFromCurrentUser: mine,
              localCopy: localCopy,
            ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the others see that an image is on its way', (tester) async {
    await withClock(
      Clock.fixed(_sent.add(const Duration(minutes: 5))),
      () async {
        await _pump(tester, _placeholder(), mine: false);
      },
    );

    expect(find.text(_l10n.messagingImagePending), findsOneWidget);
    expect(find.text(_l10n.messagingImageLoadFailed), findsNothing);
  });

  testWidgets('the sender sees that it waits for a connection, with their own '
      'copy', (tester) async {
    final dir = Directory.systemTemp.createTempSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final copy = File('${dir.path}/copy.jpg')..writeAsBytesSync([1]);
    String? askedFor;

    await withClock(
      Clock.fixed(_sent.add(const Duration(minutes: 5))),
      () async {
        await _pump(
          tester,
          _placeholder(),
          mine: true,
          localCopy: (messageId, userId) async {
            askedFor = '$messageId:$userId';
            return copy.path;
          },
        );
        await tester.pump();
      },
    );

    expect(find.text(_l10n.messagingImageWaitingToSend), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(askedFor, 'm1:u1');
  });

  testWidgets('the others never look for a copy on their own phone', (
    tester,
  ) async {
    var asked = false;
    await withClock(
      Clock.fixed(_sent.add(const Duration(minutes: 5))),
      () async {
        await _pump(
          tester,
          _placeholder(),
          mine: false,
          localCopy: (_, _) async {
            asked = true;
            return null;
          },
        );
      },
    );

    expect(asked, isFalse);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('after 48 hours the others are told the image never arrived, '
      'without looking for a copy', (tester) async {
    var asked = false;
    await withClock(
      Clock.fixed(_sent.add(const Duration(hours: 49))),
      () async {
        await _pump(
          tester,
          _placeholder(),
          mine: false,
          localCopy: (_, _) async {
            asked = true;
            return null;
          },
        );
      },
    );

    expect(find.text(_l10n.messagingImageNeverArrived), findsOneWidget);
    expect(find.text(_l10n.messagingImagePending), findsNothing);
    expect(asked, isFalse);
  });

  testWidgets('after 48 hours the sender is told so only once their phone no '
      'longer holds the picture', (tester) async {
    await withClock(
      Clock.fixed(_sent.add(const Duration(hours: 49))),
      () async {
        await _pump(
          tester,
          _placeholder(),
          mine: true,
          localCopy: (_, _) async => null,
        );
        await tester.pump();
      },
    );

    expect(find.text(_l10n.messagingImageNeverArrived), findsOneWidget);
    expect(find.text(_l10n.messagingImageWaitingToSend), findsNothing);
  });

  testWidgets('a picture still waiting on the sender\'s phone after 48 hours '
      'is slow, not lost', (tester) async {
    final dir = Directory.systemTemp.createTempSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final copy = File('${dir.path}/copy.jpg')..writeAsBytesSync([1]);

    await withClock(
      Clock.fixed(_sent.add(const Duration(hours: 49))),
      () async {
        await _pump(
          tester,
          _placeholder(),
          mine: true,
          localCopy: (_, _) async => copy.path,
        );
        await tester.pump();
      },
    );

    expect(find.text(_l10n.messagingImageWaitingToSend), findsOneWidget);
    expect(find.text(_l10n.messagingImageNeverArrived), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a copy that cannot be found leaves the label alone', (
    tester,
  ) async {
    await withClock(
      Clock.fixed(_sent.add(const Duration(minutes: 5))),
      () async {
        await _pump(
          tester,
          _placeholder(),
          mine: true,
          localCopy: (_, _) async => throw StateError('no queue'),
        );
        await tester.pump();
      },
    );

    expect(find.text(_l10n.messagingImageWaitingToSend), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an image message with no picture and no pending mark is still '
      'the failure it was', (tester) async {
    await _pump(tester, _placeholder(metadata: const {}), mine: false);

    expect(find.text(_l10n.messagingImageLoadFailed), findsOneWidget);
    expect(find.byType(PendingImageBubble), findsNothing);
  });

  group('through the chat as the sender sees it', () {
    late _MockOffline offline;
    late _MockStorage storage;
    late File copy;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
      await TestServiceLocator.initialize();
      offline = _MockOffline();
      storage = _MockStorage();
      when(() => offline.isQueueReady).thenReturn(true);
      when(() => offline.userStorage).thenReturn(storage);
      final dir = Directory.systemTemp.createTempSync();
      addTearDown(() => dir.deleteSync(recursive: true));
      copy = File('${dir.path}/copy.jpg')..writeAsBytesSync([1]);
      when(
        () => storage.chatImageCopyPath(any(), any()),
      ).thenAnswer((_) async => copy.path);
      TestServiceLocator.registerMock<OfflineService>(offline);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    testWidgets('the sender gets their own copy of the picture, looked up by '
        'the message and its sender', (tester) async {
      await withClock(
        Clock.fixed(_sent.add(const Duration(minutes: 5))),
        () async {
          await _pump(tester, _placeholder(), mine: true);
          await tester.pump();
        },
      );

      expect(find.text(_l10n.messagingImageWaitingToSend), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      verify(() => storage.chatImageCopyPath('m1', 'u1')).called(1);
    });

    testWidgets('a queue that is not ready gives no copy, only the label', (
      tester,
    ) async {
      when(() => offline.isQueueReady).thenReturn(false);

      await withClock(
        Clock.fixed(_sent.add(const Duration(minutes: 5))),
        () async {
          await _pump(tester, _placeholder(), mine: true);
          await tester.pump();
        },
      );

      expect(find.text(_l10n.messagingImageWaitingToSend), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      verifyNever(() => storage.chatImageCopyPath(any(), any()));
    });
  });
}
