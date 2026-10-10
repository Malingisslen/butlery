// BUT-950: the screen shown while an account is scheduled for deletion.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/account/pending_deletion_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/views/account/pending_deletion_view.dart';

class _MockService extends Mock implements AccountDeletionService {}

class _MockProfile extends Mock implements ProfileViewModel {}

class _MockAuth extends Mock implements AuthService {}

class _Module implements DIModule {
  _Module(this.viewModel, this.auth);

  final PendingDeletionViewModel viewModel;
  final AuthService auth;

  @override
  String get name => 'PendingDeletionViewTestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [PendingDeletionViewModel, AuthService];

  @override
  Future<void> configure(GetIt container) async {
    container.registerFactory<PendingDeletionViewModel>(() => viewModel);
    container.registerSingleton<AuthService>(auth);
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _MockService service;
  late _MockProfile profile;
  late _MockAuth auth;
  var undone = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    undone = 0;
    service = _MockService();
    profile = _MockProfile();
    auth = _MockAuth();
    final container = DIContainer();
    await container.reset();
    container.registerModule(
      _Module(
        PendingDeletionViewModel(
          accountDeletionService: service,
          profileViewModel: profile,
          noticeStore: PendingRetentionNoticeStore(),
        ),
        auth,
      ),
    );
    await container.initialize();
    ServiceLocator.initialize(container);
  });

  tearDown(() => DIContainer().reset());

  Widget host() => MaterialApp(
    locale: const Locale('sv'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: PendingDeletionView(
      scheduledFor: DateTime(2026, 10, 17),
      onUndone: () => undone++,
    ),
  );

  DeletionScheduleResult result(DeletionScheduleStatus status) =>
      DeletionScheduleResult(status);

  testWidgets('shows the date and the three ways out', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Ditt konto ska raderas'), findsOneWidget);
    expect(find.textContaining('17 oktober 2026'), findsOneWidget);
    expect(find.text('Ångra raderingen'), findsOneWidget);
    expect(find.text('Radera nu'), findsOneWidget);
    expect(find.text('Logga ut'), findsOneWidget);
  });

  testWidgets('Logga ut asks to confirm the sign-out', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('Logga ut'));
    await tester.pumpAndSettle();

    expect(find.text('Är du säker på att du vill logga ut?'), findsOneWidget);
  });

  group('Ångra raderingen', () {
    testWidgets('lets the caller open the app once the deletion is cancelled', (
      tester,
    ) async {
      when(
        () => service.cancelScheduledDeletion(),
      ).thenAnswer((_) async => result(DeletionScheduleStatus.ok));
      await tester.pumpWidget(host());

      await tester.tap(find.text('Ångra raderingen'));
      await tester.pumpAndSettle();

      expect(undone, 1);
    });

    testWidgets('a deletion that already started says so and stays here', (
      tester,
    ) async {
      when(() => service.cancelScheduledDeletion()).thenAnswer(
        (_) async => result(DeletionScheduleStatus.deletionInProgress),
      );
      await tester.pumpWidget(host());

      await tester.tap(find.text('Ångra raderingen'));
      await tester.pumpAndSettle();

      expect(undone, 0);
      expect(
        find.textContaining('Raderingen har redan startat'),
        findsOneWidget,
      );
    });

    testWidgets('a plain failure says so and stays here', (tester) async {
      when(
        () => service.cancelScheduledDeletion(),
      ).thenAnswer((_) async => result(DeletionScheduleStatus.failed));
      await tester.pumpWidget(host());

      await tester.tap(find.text('Ångra raderingen'));
      await tester.pumpAndSettle();

      expect(undone, 0);
      expect(
        find.textContaining('Raderingen kunde inte ångras'),
        findsOneWidget,
      );
    });

    testWidgets('a network failure says what failed and why', (tester) async {
      when(
        () => service.cancelScheduledDeletion(),
      ).thenAnswer((_) async => result(DeletionScheduleStatus.network));
      await tester.pumpWidget(host());

      await tester.tap(find.text('Ångra raderingen'));
      await tester.pumpAndSettle();

      expect(undone, 0);
      expect(
        find.textContaining('Raderingen kunde inte ångras'),
        findsOneWidget,
      );
      expect(find.textContaining('Nätverksfel'), findsOneWidget);
    });
  });

  group('Radera nu', () {
    testWidgets('does nothing when the confirmation is declined', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.tap(find.text('Radera nu'));
      await tester.pumpAndSettle();
      expect(find.text('Radera kontot nu?'), findsOneWidget);
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      verifyNever(() => profile.deleteAccount(reason: any(named: 'reason')));
    });

    testWidgets('deletes with an empty reason once confirmed', (tester) async {
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenAnswer(
        (_) async =>
            const AccountDeletionOutcome(success: true, accountDeleted: true),
      );
      await tester.pumpWidget(host());

      await tester.tap(find.text('Radera nu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radera nu').last);
      await tester.pumpAndSettle();

      verify(() => profile.deleteAccount(reason: '')).called(1);
      expect(find.textContaining('kunde inte raderas'), findsNothing);
    });

    testWidgets('a stale sign-in is a step: sign in again, then retry', (
      tester,
    ) async {
      var calls = 0;
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenAnswer(
        (_) async => ++calls == 1
            ? const AccountDeletionOutcome(success: false, requiresReauth: true)
            : const AccountDeletionOutcome(success: true, accountDeleted: true),
      );
      when(
        () => auth.reauthenticateWithPassword(any()),
      ).thenAnswer((_) async => true);
      await tester.pumpWidget(host());

      await tester.tap(find.text('Radera nu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radera nu').last);
      await tester.pumpAndSettle();
      expect(find.text('Bekräfta att det är du'), findsOneWidget);
      await tester.tap(find.text('Logga in igen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.tap(find.text('Bekräfta'));
      await tester.pumpAndSettle();

      verify(() => auth.reauthenticateWithPassword('hunter2')).called(1);
      expect(calls, 2);
    });

    testWidgets('a failed deletion says the account was not deleted', (
      tester,
    ) async {
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenAnswer(
        (_) async => const AccountDeletionOutcome(success: false),
      );
      await tester.pumpWidget(host());

      await tester.tap(find.text('Radera nu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radera nu').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Kontot kunde inte raderas'), findsOneWidget);
    });

    testWidgets('a partial deletion shows the audit id and no retry', (
      tester,
    ) async {
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenAnswer(
        (_) async => const AccountDeletionOutcome(
          success: false,
          accountDeleted: true,
          failedCollections: ['storage'],
          auditLogId: 'del-1',
        ),
      );
      await tester.pumpWidget(host());

      await tester.tap(find.text('Radera nu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radera nu').last);
      await tester.pumpAndSettle();

      expect(find.text('del-1'), findsOneWidget);
      expect(find.text('Försök igen'), findsNothing);
    });
  });
}
