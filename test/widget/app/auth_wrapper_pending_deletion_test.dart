// BUT-950: a signed-in user whose account is scheduled for deletion sees the
// pending-deletion screen instead of the app, and gets into the app once the
// deletion is cancelled.
import 'package:firebase_auth/firebase_auth.dart' show User, UserMetadata;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/app/auth/auth_wrapper.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/account/pending_deletion_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';

class _MockAuth extends Mock implements AuthService {}

class _MockUsers extends Mock implements UserService {}

class _MockService extends Mock implements AccountDeletionService {}

class _MockProfile extends Mock implements ProfileViewModel {}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'uid-alice';

  @override
  String? get email => 'alice@example.se';

  @override
  bool get emailVerified => true;

  // Created long before the e-mail verification gate date, so the gate does
  // not stand between the test and the branch under test.
  @override
  UserMetadata get metadata => UserMetadata(0, 0);
}

class _Module implements DIModule {
  _Module(this.auth, this.users, this.service, this.viewModel);

  final AuthService auth;
  final UserService users;
  final AccountDeletionService service;
  final PendingDeletionViewModel viewModel;

  @override
  String get name => 'AuthWrapperPendingDeletionTestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [
    AuthService,
    UserService,
    AccountDeletionService,
    PendingDeletionViewModel,
    PendingRetentionNoticeStore,
  ];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<AuthService>(auth);
    container.registerSingleton<UserService>(users);
    container.registerSingleton<AccountDeletionService>(service);
    container.registerFactory<PendingDeletionViewModel>(() => viewModel);
    container.registerSingleton<PendingRetentionNoticeStore>(
      PendingRetentionNoticeStore(),
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _MockService service;

  Future<void> setUpWrapper({bool profileLoadFailed = false}) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _MockAuth();
    final users = _MockUsers();
    service = _MockService();
    when(() => auth.currentUser).thenReturn(_FakeUser());
    // No profile. By default the wrapper is still loading; with
    // [profileLoadFailed] it draws its retry view, which only the app branch
    // can draw (the gate's own waiting state shows the loading text instead).
    when(() => users.currentUserProfile).thenReturn(null);
    when(() => users.hasError).thenReturn(profileLoadFailed);
    when(() => users.error).thenReturn(null);
    final container = DIContainer();
    await container.reset();
    container.registerModule(
      _Module(
        auth,
        users,
        service,
        PendingDeletionViewModel(
          accountDeletionService: service,
          profileViewModel: _MockProfile(),
          noticeStore: PendingRetentionNoticeStore(),
        ),
      ),
    );
    await container.initialize();
    ServiceLocator.initialize(container);
  }

  tearDown(() => DIContainer().reset());

  Widget host() => const MaterialApp(
    locale: Locale('sv'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: AuthWrapper(),
  );

  testWidgets('a scheduled deletion shows the pending screen, not the app', (
    tester,
  ) async {
    await setUpWrapper();
    when(
      () => service.scheduledDeletionAt(),
    ).thenAnswer((_) async => DateTime(2026, 10, 17));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Ditt konto ska raderas'), findsOneWidget);
    expect(find.textContaining('17 oktober 2026'), findsOneWidget);
    expect(find.text('Hämtar din profil …'), findsNothing);
  });

  testWidgets('no claim goes straight into the app', (tester) async {
    await setUpWrapper(profileLoadFailed: true);
    when(() => service.scheduledDeletionAt()).thenAnswer((_) async => null);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Ditt konto ska raderas'), findsNothing);
    expect(find.text('Försök igen'), findsOneWidget);
  });

  testWidgets('the gate waits with the loading text until the claim is read', (
    tester,
  ) async {
    await setUpWrapper();
    when(() => service.scheduledDeletionAt()).thenAnswer((_) async => null);

    await tester.pumpWidget(host());
    // The plate line animates forever, so settle cannot be used here.
    expect(find.text('Hämtar din profil …'), findsOneWidget);
  });

  testWidgets('undoing the deletion continues into the app', (tester) async {
    await setUpWrapper(profileLoadFailed: true);
    when(
      () => service.scheduledDeletionAt(),
    ).thenAnswer((_) async => DateTime(2026, 10, 17));
    when(() => service.cancelScheduledDeletion()).thenAnswer(
      (_) async => const DeletionScheduleResult(DeletionScheduleStatus.ok),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ångra raderingen'));
    await tester.pumpAndSettle();

    expect(find.text('Ditt konto ska raderas'), findsNothing);
    expect(find.text('Försök igen'), findsOneWidget);
    // The claim is not read again: the token was refreshed by the cancel.
    verify(() => service.scheduledDeletionAt()).called(1);
  });
}
