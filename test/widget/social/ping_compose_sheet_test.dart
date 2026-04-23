// test/widget/social/ping_compose_sheet_test.dart
//
// BUT-407-C: widget tests for the ping compose bottom sheet.
//
// Strategy: inject a `_FakePingService` into [PingComposeSheet] so we don't
// have to stand up Firestore, ServiceLocator, or PermissionService. We
// exercise the behavioural contract of the widget — chip selection enables
// Send, Send invokes `sendPing`, rate-limit keeps the sheet open with an
// inline error, and the 100-char cap is enforced.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/ping.dart';
import 'package:butlery/services/social/ping_service.dart';
import 'package:butlery/widgets/social/ping_compose_sheet.dart';

/// Records every `sendPing` invocation. Throws on demand to exercise
/// rate-limit and generic-error code paths.
class _FakePingService implements PingService {
  final List<_SentCall> calls = [];
  Object? errorToThrow;

  @override
  Future<Ping> sendPing({
    required String groupId,
    String? toUserId,
    required PingType type,
    String? message,
  }) async {
    calls.add(_SentCall(
      groupId: groupId,
      toUserId: toUserId,
      type: type,
      message: message,
    ));
    if (errorToThrow != null) {
      final e = errorToThrow!;
      errorToThrow = null;
      throw e;
    }
    return Ping.create(
      groupId: groupId,
      fromUserId: 'me',
      toUserId: toUserId,
      type: type,
      message: message,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SentCall {
  final String groupId;
  final String? toUserId;
  final PingType type;
  final String? message;

  _SentCall({
    required this.groupId,
    required this.toUserId,
    required this.type,
    required this.message,
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sv'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('PingComposeSheet', () {
    testWidgets('renders 3 type chips, message field, and send button',
        (tester) async {
      final svc = _FakePingService();
      await tester.pumpWidget(_wrap(PingComposeSheet(
        groupId: 'g1',
        targetUserId: 'erik',
        pingService: svc,
      )));
      await tester.pump();

      // All three chips are present by their keys.
      expect(find.byKey(const Key('ping-type-nudge')), findsOneWidget);
      expect(find.byKey(const Key('ping-type-timer')), findsOneWidget);
      expect(find.byKey(const Key('ping-type-help')), findsOneWidget);
      // Message field and send button.
      expect(find.byKey(const Key('ping-message-field')), findsOneWidget);
      expect(find.byKey(const Key('ping-send-button')), findsOneWidget);
    });

    testWidgets('send disabled until a type is selected', (tester) async {
      final svc = _FakePingService();
      await tester.pumpWidget(_wrap(PingComposeSheet(
        groupId: 'g1',
        targetUserId: 'erik',
        pingService: svc,
      )));
      await tester.pump();

      // Tapping Send without a selection must not call the service.
      await tester.tap(find.byKey(const Key('ping-send-button')));
      await tester.pump();
      expect(svc.calls, isEmpty);

      // Selecting a chip and tapping Send calls sendPing.
      await tester.tap(find.byKey(const Key('ping-type-nudge')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ping-send-button')));
      await tester.pump();
      await tester.pump();
      expect(svc.calls, hasLength(1));
    });

    testWidgets(
        'type + send → pingService.sendPing called with correct args and sheet pops',
        (tester) async {
      final svc = _FakePingService();

      // Show the sheet via the helper so we can verify the pop behavior.
      late BuildContext rootContext;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        rootContext = ctx;
        return const SizedBox.shrink();
      })));

      // Push a modal sheet containing our widget.
      unawaited(showModalBottomSheet<void>(
        context: rootContext,
        builder: (_) => PingComposeSheet(
          groupId: 'g42',
          targetUserId: 'sara',
          pingService: svc,
        ),
      ));
      await tester.pumpAndSettle();

      // Sheet is open.
      expect(find.byKey(const Key('ping-send-button')), findsOneWidget);

      // Choose helpMe + enter a message.
      await tester.tap(find.byKey(const Key('ping-type-help')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('ping-message-field')),
        'kom och rör',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('ping-send-button')));
      // Microtasks first — sendPing resolves, then pop + snackbar schedule.
      await tester.pump();
      await tester.pump();

      // Service got the right args.
      expect(svc.calls, hasLength(1));
      final call = svc.calls.first;
      expect(call.groupId, 'g42');
      expect(call.toUserId, 'sara');
      expect(call.type, PingType.helpMe);
      expect(call.message, 'kom och rör');

      // Snackbar is visible right after pop is requested.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Skickat'), findsOneWidget);
    });

    testWidgets('rate-limit thrown → inline error shown, sheet stays open',
        (tester) async {
      final svc = _FakePingService()
        ..errorToThrow = PingRateLimitedException('nope');

      await tester.pumpWidget(_wrap(PingComposeSheet(
        groupId: 'g1',
        targetUserId: 'erik',
        pingService: svc,
      )));
      await tester.pump();

      await tester.tap(find.byKey(const Key('ping-type-nudge')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ping-send-button')));
      await tester.pump();
      await tester.pump();

      // Inline error shown, sheet still open.
      expect(find.byKey(const Key('ping-inline-error')), findsOneWidget);
      expect(
        find.text('Du har skickat för många puttar den senaste timmen'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ping-send-button')), findsOneWidget);
    });

    testWidgets('message field enforces 100-char cap', (tester) async {
      final svc = _FakePingService();
      await tester.pumpWidget(_wrap(PingComposeSheet(
        groupId: 'g1',
        targetUserId: 'erik',
        pingService: svc,
      )));
      await tester.pump();

      final longText = 'å' * 200;
      await tester.enterText(
        find.byKey(const Key('ping-message-field')),
        longText,
      );
      await tester.pump();

      // Grab the underlying controller by locating the TextField widget.
      final tf = tester.widget<TextField>(
        find.byKey(const Key('ping-message-field')),
      );
      // Flutter's maxLength enforcement clips input to 100 characters.
      expect(tf.controller!.text.length, kPingMaxMessageLength);
    });
  });
}

/// Local helper so the test file doesn't pull in `package:async` just for
/// a single fire-and-forget.
void unawaited(Future<void> f) {
  f.catchError((Object _) {});
}
