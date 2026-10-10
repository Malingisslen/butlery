// P6-U06 — flow 06 account deletion (produktregler.md:607-616, § 11;
// Skarmar v12 etapp 5-7 #kontoradera #kontovantan #kontoreauth): the reason is
// asked first and reaches the request, the waiting state cannot be cancelled,
// re-authentication is a step. Since BUT-950 the confirmation schedules the
// deletion and says when the account goes; the partial-deletion outcome now
// belongs to the immediate deletion (see the pending-deletion view test).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/models/account/retained_record.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

class _FakeProfileViewModel implements ProfileViewModel {
  _FakeProfileViewModel(this.outcomes, {this.gate, this.failWith});

  final List<DeletionScheduleResult> outcomes;
  final Completer<void>? gate;
  final Object? failWith;
  final List<String> reasons = [];
  int signOuts = 0;

  @override
  Future<void> signOutAfterScheduling() async => signOuts++;

  @override
  Future<DeletionScheduleResult> scheduleDeletion({
    required String reason,
  }) async {
    reasons.add(reason);
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
    return outcomes.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeReportService implements ReportService {
  @override
  Future<OwnReportStatus> ownReportStatus() async => OwnReportStatus.none;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthService implements AuthService {
  int reauths = 0;

  @override
  Future<bool> reauthenticateWithPassword(String password) async {
    reauths++;
    return true;
  }

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Module implements DIModule {
  _Module(this.vm, this.auth);

  final _FakeProfileViewModel vm;
  final _FakeAuthService auth;

  @override
  String get name => 'AccountDeletionFlow06TestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [
    ProfileViewModel,
    ReportService,
    PendingRetentionNoticeStore,
    AnalyticsService,
    AuthService,
  ];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<ProfileViewModel>(vm);
    container.registerSingleton<ReportService>(_FakeReportService());
    container.registerSingleton<AnalyticsService>(_FakeAnalyticsService());
    container.registerSingleton<AuthService>(auth);
    container.registerSingleton<PendingRetentionNoticeStore>(
      PendingRetentionNoticeStore(),
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<(_FakeProfileViewModel, _FakeAuthService)> _setUp(
  List<DeletionScheduleResult> outcomes, {
  Completer<void>? gate,
  Object? failWith,
}) async {
  final vm = _FakeProfileViewModel(outcomes, gate: gate, failWith: failWith);
  final auth = _FakeAuthService();
  final container = DIContainer();
  await container.reset();
  container.registerModule(_Module(vm, auth));
  await container.initialize();
  ServiceLocator.initialize(container);
  return (vm, auth);
}

Widget _host() => MaterialApp(
  locale: const Locale('sv'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  routes: {'/auth': (_) => const Scaffold(body: Text('sign-in screen'))},
  home: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => AuthActionHandler.handleDeleteAccount(context),
        child: const Text('delete'),
      ),
    ),
  ),
);

/// Opens the dialog, types [reason], confirms, and passes the password step.
Future<void> _request(WidgetTester tester, {String reason = ''}) async {
  await tester.tap(find.text('delete'));
  await tester.pumpAndSettle();
  if (reason.isNotEmpty) {
    await tester.enterText(
      find.byKey(const ValueKey('accountDeletion.reason')),
      reason,
    );
  }
  await tester.tap(find.text('Jag förstår, radera mitt konto'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'hunter2');
  await tester.tap(find.text('Bekräfta'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => DIContainer().reset());

  group('the reason comes first', () {
    testWidgets('the typed reason reaches the deletion request', (
      tester,
    ) async {
      final (vm, _) = await _setUp([
        DeletionScheduleResult(
          DeletionScheduleStatus.ok,
          scheduledFor: DateTime(2026, 10, 17),
        ),
      ]);
      await tester.pumpWidget(_host());

      await tester.tap(find.text('delete'));
      await tester.pumpAndSettle();
      // The reason is asked in the first dialog, before the password step.
      expect(find.text('Varför raderar du kontot?'), findsOneWidget);
      expect(find.text('Bekräfta med lösenord'), findsNothing);
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      await _request(tester, reason: 'Vi flyttar ihop');
      await tester.pumpAndSettle();

      expect(vm.reasons, ['Vi flyttar ihop']);
      // The user is told when the account goes and how to undo it, and only
      // then lands on the sign-in screen.
      expect(find.text('Raderingen är schemalagd'), findsOneWidget);
      expect(find.textContaining('17 oktober 2026'), findsOneWidget);
      expect(find.textContaining('kan du ångra raderingen'), findsOneWidget);
      expect(find.text('sign-in screen'), findsNothing);
      expect(vm.signOuts, 0, reason: 'still signed in while the date shows');
      await tester.tap(find.text('Stäng'));
      await tester.pumpAndSettle();
      expect(vm.signOuts, 1);
      expect(find.text('sign-in screen'), findsOneWidget);
    });

    testWidgets('an empty reason still deletes, with the neutral default', (
      tester,
    ) async {
      final (vm, _) = await _setUp([
        DeletionScheduleResult(
          DeletionScheduleStatus.ok,
          scheduledFor: DateTime(2026, 10, 17),
        ),
      ]);
      await tester.pumpWidget(_host());
      await _request(tester);
      await tester.pumpAndSettle();

      expect(vm.reasons, [ProfileDialogs.defaultDeleteReason]);
    });
  });

  testWidgets('the waiting state cannot be cancelled and is no spinner', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _setUp([
      DeletionScheduleResult(
        DeletionScheduleStatus.ok,
        scheduledFor: DateTime(2026, 10, 17),
      ),
    ], gate: gate);
    await tester.pumpWidget(_host());
    await _request(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final waiting = find.byKey(const ValueKey('accountDeletion.scheduling'));
    expect(waiting, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Neither the system back nor the barrier closes it.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(waiting, findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(waiting, findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(waiting, findsNothing);
  });

  testWidgets('re-authentication is a step and the request is made again', (
    tester,
  ) async {
    final (vm, auth) = await _setUp([
      const DeletionScheduleResult(DeletionScheduleStatus.requiresReauth),
      DeletionScheduleResult(
        DeletionScheduleStatus.ok,
        scheduledFor: DateTime(2026, 10, 17),
      ),
    ]);
    await tester.pumpWidget(_host());
    await _request(tester, reason: 'x');
    await tester.pumpAndSettle();

    expect(find.text('Bekräfta att det är du'), findsOneWidget);
    expect(find.textContaining('kunde inte'), findsNothing);
    await tester.tap(find.text('Logga in igen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text('Bekräfta'));
    await tester.pumpAndSettle();

    expect(auth.reauths, 2);
    expect(vm.reasons, ['x', 'x']);
    expect(find.text('Raderingen är schemalagd'), findsOneWidget);
  });

  testWidgets('a network failure says the account was not deleted and why', (
    tester,
  ) async {
    await _setUp([
      const DeletionScheduleResult(DeletionScheduleStatus.network),
    ]);
    await tester.pumpWidget(_host());
    await _request(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Kontot kunde inte raderas'), findsOneWidget);
    expect(find.textContaining('Nätverksfel'), findsOneWidget);
    expect(find.text('Raderingen är schemalagd'), findsNothing);
    expect(find.text('sign-in screen'), findsNothing);
  });

  group('AccountDeletionOutcome', () {
    RetainedRecord hold({required bool provisional}) => RetainedRecord(
      resourceType: 'user_moderation',
      legalBasis: 'GDPR Art. 17(3)(e)',
      holdUntil: DateTime.utc(2999, 3, 11),
      provisional: provisional,
    );

    test('a provisional hold alone is not a partial deletion', () {
      final outcome = AccountDeletionOutcome(
        success: false,
        accountDeleted: true,
        failedCollections: const ['erasure_hold_evaluated'],
        retained: [hold(provisional: true)],
      );
      expect(outcome.isPartial, isFalse);
      expect(outcome.isComplete, isTrue);
      expect(outcome.owesRetentionNotice, isTrue);
    });

    test('a genuine failure beside a hold is partial', () {
      final outcome = AccountDeletionOutcome(
        success: false,
        accountDeleted: true,
        failedCollections: const ['erasure_hold_evaluated', 'storage'],
        retained: [hold(provisional: true)],
      );
      expect(outcome.genuinelyFailed, ['storage']);
      expect(outcome.isPartial, isTrue);
    });

    test('a failed Auth deletion is neither partial nor complete', () {
      const outcome = AccountDeletionOutcome(
        success: false,
        failedCollections: ['auth_deletion', 'storage'],
      );
      expect(outcome.isPartial, isFalse);
      expect(outcome.isComplete, isFalse);
    });
  });

  testWidgets('a deletion that throws says the account was not deleted, '
      'with Stäng and never the exception (P7-B2/B4)', (tester) async {
    await _setUp(
      const [],
      failWith: Exception('firebase-functions/internal: boom'),
    );
    await tester.pumpWidget(_host());
    await _request(tester, reason: 'x');
    await tester.pumpAndSettle();

    expect(find.text('Kontot kunde inte raderas.'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('boom'), findsNothing);
    // content-style-guide.md:77: the button only closes, so it is Stäng.
    expect(find.widgetWithText(FilledButton, 'Stäng'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Stäng'));
    await tester.pumpAndSettle();
    expect(find.text('Kontot kunde inte raderas.'), findsNothing);
  });
}
