import 'dart:async';

import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_input_section.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

/// BUT-1903, and this file exists because of ONE optional positional argument.
///
/// `MessageSendErrorMapper` decides whether a refused chat message gets "your
/// phone's clock is wrong" or the generic error, by comparing `clock.now()`
/// against a **freshly** server-stamped `issuedAtTime`. Its own suite injects
/// the reader, so it can never see how the reader is built. The real one is
/// built here, in the View:
///
///     currentUser?.getIdTokenResult(true)
///
/// `true` is an OPTIONAL POSITIONAL argument. Dropping it compiles, passes the
/// analyzer, and leaves the mapper's ten tests green — but it then reads the
/// CACHED token, which can be an hour old, so the measured "clock lead" is
/// inflated by token age alone. The result is precisely what the whole design
/// forbids: a user whose clock is fine, denied by the rate limiter or the
/// 60-minute account-maturity gate, told to go and fix their clock.
///
/// Nothing else in the repo can redden on that. Hence these tests.
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

class _MockIdTokenResult extends Mock implements IdTokenResult {}

/// The LITERALS, deliberately — not `context.l10n.chatSendFailedDeviceClockAhead`.
/// A getter-based assertion passes even if the two ARB values are swapped, and the
/// same reasoning governs the event name below: asserting against
/// `AnalyticsEvents.messageSendDeniedClockAhead` is circular and would survive the
/// constant being retyped to another funnel's value, which the analytics registry
/// lint cannot see either. If a copy edit reddens these tests, THAT IS THE POINT —
/// update the literal here, do not reach for the getter.
const _clockAheadMessage =
    'Kunde inte skicka. Telefonens klocka ligger för långt fram — '
    'kontrollera datum och tid i inställningarna.';
const _genericMessage = 'Kunde inte skicka meddelandet. Försök igen.';
const _deniedEventName = 'message_send_denied_clock_ahead';

void main() {
  late _MockAuthRepository authRepository;
  late _MockUser user;
  late MockAnalyticsService analytics;

  final t0 = DateTime.utc(2026, 8, 19, 12);

  IdTokenResult tokenIssuedAt(DateTime issuedAt) {
    final result = _MockIdTokenResult();
    when(() => result.issuedAtTime).thenReturn(issuedAt);
    return result;
  }

  setUp(() async {
    await GetIt.instance.reset();
    authRepository = _MockAuthRepository();
    user = _MockUser();
    analytics = MockAnalyticsService();

    when(() => authRepository.currentUser).thenReturn(user);

    GetIt.instance.registerSingleton<AuthRepository>(authRepository);
    GetIt.instance.registerSingleton<AnalyticsService>(analytics);
    ServiceLocator.initialize(DIContainer());

    // Asserted HERE rather than in each test body: a future test that forgot the
    // call is exactly the vacuous case this guards. An unregistered
    // `AuthRepository` makes `ServiceLocator.get` throw inside the reader closure,
    // which `classify` catches and turns into the GENERIC arm — so the whole file
    // would pass with the clock branch deleted. An unregistered `AnalyticsService`
    // makes `tryLog` a silent no-op. `tryGet` below is the identical lookup
    // `AnalyticsService.tryLog` performs, not a proxy for it.
    expect(ServiceLocator.get<AuthRepository>(), same(authRepository));
    expect(ServiceLocator.tryGet<AnalyticsService>(), same(analytics));
  });

  tearDown(() async => GetIt.instance.reset());

  Widget subject({required Future<void> Function() onSend}) {
    return createLocalizedTestApp(
      child: ChatInputSection(
        conversationId: 'conv-1',
        onSendMessage: (String _, {MessageType type = MessageType.text}) =>
            onSend(),
        onAttachment: (String _) async {},
      ),
    );
  }

  Future<void> typeAndSend(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'hej hej');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
  }

  FirebaseException denied() =>
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

  testWidgets('a device two hours ahead is told to check its clock, and the '
      'token is FORCE-refreshed to prove it', (tester) async {
    // Stubbed NARROWLY on the force-refresh overload. This is the assertion
    // that kills the mutant: with `true` dropped, the call becomes
    // `getIdTokenResult()`, mocktail throws MissingStubError inside the reader
    // closure, `classify` catches it and returns `other`, and the clock
    // sentence below never renders.
    when(
      () => user.getIdTokenResult(true),
    ).thenAnswer((_) async => tokenIssuedAt(t0));

    await withClock(Clock.fixed(t0.add(const Duration(hours: 2))), () async {
      await tester.pumpWidget(subject(onSend: () async => throw denied()));
      await typeAndSend(tester);
      await tester.pumpAndSettle();
    });

    // Stated as intent, not left to the side effect above.
    verify(() => user.getIdTokenResult(true)).called(1);
    expect(
      find.text(_clockAheadMessage),
      findsOneWidget,
    );
    expect(
      find.text(_genericMessage),
      findsNothing,
    );
    expect(
      analytics.capturedEvents.map((e) => e.name),
      contains(_deniedEventName),
    );
  });

  testWidgets('a device ten minutes ahead gets the generic message and is not '
      'counted', (tester) async {
    when(
      () => user.getIdTokenResult(true),
    ).thenAnswer((_) async => tokenIssuedAt(t0));

    // Ten minutes is INSIDE the rule's one-hour bound, so this denial came from
    // the rate limiter, the maturity gate or membership — never the clock.
    await withClock(Clock.fixed(t0.add(const Duration(minutes: 10))), () async {
      await tester.pumpWidget(subject(onSend: () async => throw denied()));
      await typeAndSend(tester);
      await tester.pumpAndSettle();
    });

    expect(
      find.text(_genericMessage),
      findsOneWidget,
    );
    verify(() => user.getIdTokenResult(true)).called(1);
    expect(analytics.capturedEvents, isEmpty);
  });

  testWidgets('the denial is counted even when the user has navigated away', (
    tester,
  ) async {
    when(
      () => user.getIdTokenResult(true),
    ).thenAnswer((_) async => tokenIssuedAt(t0));

    // Without this case, moving the count below `if (!mounted) return;` stays
    // green on every other test here — and the population that gives up and
    // leaves is exactly the one worth counting.
    final gate = Completer<void>();

    await withClock(Clock.fixed(t0.add(const Duration(hours: 2))), () async {
      await tester.pumpWidget(subject(onSend: () => gate.future));
      await typeAndSend(tester);
      await tester.pump();

      // Replace the tree: ChatInputSection is now unmounted with the send
      // still in flight.
      await tester.pumpWidget(
        createLocalizedTestApp(child: const SizedBox.shrink()),
      );
      gate.completeError(denied());
      await tester.pumpAndSettle();
    });

    verify(() => user.getIdTokenResult(true)).called(1);
    expect(
      analytics.capturedEvents.map((e) => e.name),
      contains(_deniedEventName),
    );
    expect(find.text(_clockAheadMessage), findsNothing);
  });
}
