// The Art. 12(4) notice must be on disk BEFORE the dialog is shown, and it must
// be written even when the context that would show the dialog is already gone.
//
// This is the mechanism the whole build exists for, and it is the easiest thing
// here to get subtly wrong. `AccountDeletionService.deleteUserAccount` signs out
// INSIDE itself before returning — `AuthService.signOut` runs `popUserScope()`
// and the repository sign-out, both really async — and `AuthWrapper` rebuilds to
// the signed-out tree on that, disposing the context `handleDeleteAccount`
// holds. The entire outcome-handling block in that method sits inside one
// `if (context.mounted)` gate, so a write placed there is skipped on exactly the
// runs where the live dialog never appears — which are the runs the persisted
// notice exists to save.
//
// A test that asserts "the record was written and the dialog was shown" passes
// with the order reversed and with the write inside the gate. These assert the
// two things that actually matter: the store already holds the record while the
// dialog is still on screen undismissed, and the write survives an unmounted
// context.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/account/retained_record.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

/// Returns a deletion that lawfully kept moderation evidence.
class _FakeProfileViewModel implements ProfileViewModel {
  _FakeProfileViewModel(this.outcome, {this.gate});

  final AccountDeletionOutcome outcome;

  /// When set, the deletion does not resolve until the test completes it. That
  /// is what lets a case tear the widget tree down FIRST and be certain the
  /// outcome arrives to a dead context — without it the deletion resolves
  /// immediately and `context.mounted` is still true, which makes the
  /// placement assertion below pass for the wrong reason.
  final Completer<void>? gate;

  @override
  Future<AccountDeletionOutcome> deleteAccount({String? reason}) async {
    if (gate != null) await gate!.future;
    return outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeReportService implements ReportService {
  _FakeReportService([this.status = OwnReportStatus.none]);

  final OwnReportStatus status;

  @override
  Future<OwnReportStatus> ownReportStatus() async => status;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthService implements AuthService {
  @override
  Future<bool> reauthenticateWithPassword(String password) async => true;

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

class _TestModule implements DIModule {
  _TestModule(
    this.outcome, {
    this.gate,
    this.reportStatus = OwnReportStatus.none,
  });

  final AccountDeletionOutcome outcome;
  final Completer<void>? gate;
  final OwnReportStatus reportStatus;

  @override
  String get name => 'RetentionNoticeOrderingTestModule';

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
    container.registerSingleton<ProfileViewModel>(
      _FakeProfileViewModel(outcome, gate: gate),
    );
    container.registerSingleton<ReportService>(
      _FakeReportService(reportStatus),
    );
    container.registerSingleton<AnalyticsService>(_FakeAnalyticsService());
    container.registerSingleton<AuthService>(_FakeAuthService());
    container.registerSingleton<PendingRetentionNoticeStore>(
      PendingRetentionNoticeStore(),
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

AccountDeletionOutcome _heldOutcome() => AccountDeletionOutcome(
  success: true,
  accountDeleted: true,
  retained: [
    RetainedRecord(
      resourceType: 'user_moderation',
      legalBasis: 'GDPR Art. 17(3)(e)',
      // Far future on purpose. This suite's `store.read()` assertions run the
      // expiry check, so a near date would redden them on a calendar day with
      // no commit behind it.
      holdUntil: DateTime.utc(2999, 3, 11),
    ),
  ],
);

Future<PendingRetentionNoticeStore> _setUpLocator(
  AccountDeletionOutcome outcome, {
  Completer<void>? gate,
  OwnReportStatus reportStatus = OwnReportStatus.none,
}) async {
  // DIContainer is a process-wide singleton that refuses registration once
  // initialized, so each case has to reset it rather than build a fresh one.
  final container = DIContainer();
  await container.reset();
  container.registerModule(
    _TestModule(outcome, gate: gate, reportStatus: reportStatus),
  );
  await container.initialize();
  ServiceLocator.initialize(container);
  return ServiceLocator.get<PendingRetentionNoticeStore>();
}

Widget _host() {
  return MaterialApp(
    locale: const Locale('sv'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => AuthActionHandler.handleDeleteAccount(context),
          child: const Text('delete'),
        ),
      ),
    ),
  );
}

/// Drives the flow from the delete button through the two dialogs that guard
/// it, up to the point where the deletion itself runs.
Future<void> _requestDeletion(WidgetTester tester) async {
  await tester.tap(find.text('delete'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Jag förstår, radera mitt konto'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'hunter2');
  await tester.tap(find.text('Bekräfta'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => DIContainer().reset());

  testWidgets(
    'the record is already on disk while the notice is still on screen',
    (tester) async {
      // The ordering assertion, and the reason it is shaped this way: reading
      // the store AFTER the dialog closes would pass even if the write happened
      // second. This reads it at the one moment that distinguishes them —
      // dialog up, not yet dismissed.
      final store = await _setUpLocator(_heldOutcome());
      await tester.pumpWidget(_host());

      await _requestDeletion(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Ditt konto är raderat'),
        findsOneWidget,
        reason: 'the notice should be up and undismissed at this point',
      );
      expect(
        await store.read(),
        isNotNull,
        reason: 'the record must already be persisted before the dialog shows',
      );
      expect(
        store.deliveredLiveInThisProcess,
        isTrue,
        reason:
            'this run delivered live, so the sign-in gate must stand back '
            'rather than stack a second notice and count it as a recovery',
      );
    },
  );

  testWidgets('the record is cleared once the notice has been read', (
    tester,
  ) async {
    final store = await _setUpLocator(_heldOutcome());
    await tester.pumpWidget(_host());

    await _requestDeletion(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();

    expect(
      await store.read(),
      isNull,
      reason:
          'the device copy has done its job; the sign-in screen must not '
          'repeat a notice the person has already read',
    );
  });

  testWidgets(
    'the record is written even when the context is already gone',
    (tester) async {
      // The run the mechanism exists for. The host tears its own subtree down
      // while the deletion is in flight, which is what the sign-out rebuild
      // does in production — if the write sat inside the `context.mounted`
      // gate, nothing would be persisted and the notice would be lost for good.
      // GATED: the deletion does not resolve until this test says so, so the
      // tree below is provably torn down BEFORE the outcome arrives. Without
      // the gate the deletion resolves while the context is still mounted and
      // this case passes with the write inside the gate — measured, not
      // assumed: that mutant survived the ungated version of this test.
      final gate = Completer<void>();
      final store = await _setUpLocator(_heldOutcome(), gate: gate);

      await tester.pumpWidget(_host());
      await _requestDeletion(tester);
      // Tear the whole tree down before the deletion future resolves — a
      // different root type, so the element tree (Navigator included) is
      // disposed rather than reused, which is what the sign-out rebuild does
      // to the context this handler is holding.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('signed out'),
        ),
      );
      await tester.pumpAndSettle();

      // Premise: the deletion has NOT resolved yet, so a non-null read after
      // the release below is attributable to the post-teardown path. Without
      // this the gate could be deleted and the case would stay green while
      // proving nothing.
      expect(await store.read(), isNull);

      // Only now does the deletion come back — to a context that is gone.
      gate.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('Ditt konto är raderat'),
        findsNothing,
        reason: 'the context is gone, so the live dialog cannot have shown',
      );
      expect(
        await store.read(),
        isNotNull,
        reason: 'the persisted notice is the only delivery left on this run',
      );
      expect(
        store.deliveredLiveInThisProcess,
        isFalse,
        reason:
            'nothing was delivered live here, so the claim must NOT be '
            'made — claiming it would make the sign-in gate stand back and '
            'lose the second delivery on the very run this feature is for',
      );
    },
  );

  group('the pre-deletion warning reaches the dialog', () {
    // ADR-0019's whole UI consequence is one comparison in the handler, and
    // these cases drive it through the real flow: the hedged row appears for a
    // reported user, and stays away both when the read confirmed nothing and
    // when the read could not answer at all. A failed read must not surface
    // moderation-adjacent text.
    testWidgets('reported draws the hedged row', (tester) async {
      await _setUpLocator(
        _heldOutcome(),
        reportStatus: OwnReportStatus.reported,
      );
      await tester.pumpWidget(_host());

      await tester.tap(find.text('delete'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Om det finns en pågående granskning'),
        findsOneWidget,
      );
    });

    testWidgets('unknown stays silent — a failed read is not a finding', (
      tester,
    ) async {
      await _setUpLocator(
        _heldOutcome(),
        reportStatus: OwnReportStatus.unknown,
      );
      await tester.pumpWidget(_host());

      await tester.tap(find.text('delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('pågående granskning'), findsNothing);
    });

    testWidgets('none stays silent', (tester) async {
      await _setUpLocator(_heldOutcome(), reportStatus: OwnReportStatus.none);
      await tester.pumpWidget(_host());

      await tester.tap(find.text('delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('pågående granskning'), findsNothing);
    });
  });

  testWidgets('an ordinary deletion writes nothing', (tester) async {
    // Nothing was kept, so nothing is owed and nothing may be stored.
    final store = await _setUpLocator(
      const AccountDeletionOutcome(success: true, accountDeleted: true),
    );
    await tester.pumpWidget(_host());

    await _requestDeletion(tester);
    await tester.pumpAndSettle();

    expect(await store.read(), isNull);
    expect(
      store.deliveredLiveInThisProcess,
      isFalse,
      reason: 'no notice was owed, so no delivery may be claimed either',
    );
  });
}
