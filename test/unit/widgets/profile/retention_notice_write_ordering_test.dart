// The Art. 12(4) duty after BUT-950. Scheduling a deletion keeps nothing yet,
// so the confirmation cannot carry a notice; the one warning left is the
// hedged line in the confirmation dialog, driven by the pre-read
// `ownReportStatus`. The notice that follows an immediate deletion is written
// by `PendingDeletionViewModel` (see its test).

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
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

class _FakeProfileViewModel implements ProfileViewModel {
  _FakeProfileViewModel(this.outcome);

  final AccountDeletionOutcome outcome;
  int scheduled = 0;

  @override
  Future<DeletionScheduleResult> scheduleDeletion({
    required String reason,
  }) async {
    scheduled++;
    return DeletionScheduleResult(
      DeletionScheduleStatus.ok,
      scheduledFor: DateTime(2999, 3, 11),
    );
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
  _TestModule(this.outcome, {this.reportStatus = OwnReportStatus.none});

  final AccountDeletionOutcome outcome;
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
      _FakeProfileViewModel(outcome),
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
  OwnReportStatus reportStatus = OwnReportStatus.none,
}) async {
  // DIContainer is a process-wide singleton that refuses registration once
  // initialized, so each case has to reset it rather than build a fresh one.
  final container = DIContainer();
  await container.reset();
  container.registerModule(
    _TestModule(outcome, reportStatus: reportStatus),
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

  testWidgets('scheduling a deletion writes no retention notice and says when '
      'the account goes', (tester) async {
    // Nothing is kept until the server erases the account, so nothing is owed
    // at this moment and nothing may be stored.
    final store = await _setUpLocator(
      _heldOutcome(),
      reportStatus: OwnReportStatus.reported,
    );
    await tester.pumpWidget(_host());

    await _requestDeletion(tester);
    await tester.pumpAndSettle();

    expect(find.text('Raderingen är schemalagd'), findsOneWidget);
    expect(find.textContaining('11 mars 2999'), findsOneWidget);
    expect(await store.read(), isNull);
  });
}
