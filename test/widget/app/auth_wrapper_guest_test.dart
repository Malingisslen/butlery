// BUT-920: how the auth wrapper treats a guest (anonymous) account — no
// e-mail gate, a waiting screen while the guest start runs, and one quiet
// retry of an unfinished upgrade per account.
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
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/guest/guest_start_coordinator.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/account/pending_deletion_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';

final _sv = AppLocalizationsSv();

class _MockDeletion extends Mock implements AccountDeletionService {}

class _MockProfileVm extends Mock implements ProfileViewModel {}

class _MockAge extends Mock implements AgeVerificationService {}

class _FakeUser extends Fake implements User {
  _FakeUser({required this.isAnonymous});

  @override
  final bool isAnonymous;

  @override
  String get uid => 'uid-guest';

  @override
  String? get email => isAnonymous ? null : 'alice@example.se';

  @override
  bool get emailVerified => false;

  // Created after the verification gate's cut-off, so only the anonymous
  // exemption can keep this account out of the gate.
  @override
  UserMetadata get metadata => UserMetadata(
    DateTime(2026, 6, 1).millisecondsSinceEpoch,
    DateTime(2026, 6, 1).millisecondsSinceEpoch,
  );
}

class _FakeAuth extends Fake with ChangeNotifier implements AuthService {
  _FakeAuth(this._user);

  final User _user;

  @override
  User? get currentUser => _user;
}

class _FakeUsers extends Fake with ChangeNotifier implements UserService {
  UserProfile? profile;
  bool failed = false;

  @override
  UserProfile? get currentUserProfile => profile;

  @override
  bool get termsPending => false;

  @override
  bool get hasError => failed;

  @override
  String? get error => null;

  @override
  Future<void> retryLoadProfile() async {}

  @override
  Future<void> dispose() async => super.dispose();

  void loaded(UserProfile next) {
    profile = next;
    notifyListeners();
  }
}

class _FakeGuestStart extends Fake
    with ChangeNotifier
    implements GuestStartCoordinator {
  bool running = false;

  @override
  bool get isRunning => running;

  void setRunning(bool value) {
    running = value;
    notifyListeners();
  }
}

class _Module implements DIModule {
  _Module({
    required this.auth,
    required this.users,
    required this.deletion,
    required this.guestStart,
    required this.age,
  });

  final AuthService auth;
  final UserService users;
  final AccountDeletionService deletion;
  final GuestStartCoordinator guestStart;
  final AgeVerificationService age;

  @override
  String get name => 'AuthWrapperGuestTestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [
    AuthService,
    UserService,
    AccountDeletionService,
    PendingDeletionViewModel,
    PendingRetentionNoticeStore,
    GuestStartCoordinator,
    AgeVerificationService,
  ];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<AuthService>(auth);
    container.registerSingleton<UserService>(users);
    container.registerSingleton<AccountDeletionService>(deletion);
    container.registerFactory<PendingDeletionViewModel>(
      () => PendingDeletionViewModel(
        accountDeletionService: deletion,
        profileViewModel: _MockProfileVm(),
        noticeStore: PendingRetentionNoticeStore(),
      ),
    );
    container.registerSingleton<PendingRetentionNoticeStore>(
      PendingRetentionNoticeStore(),
    );
    container.registerSingleton<GuestStartCoordinator>(guestStart);
    container.registerSingleton<AgeVerificationService>(age);
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

UserProfile _profile({String uid = 'uid-guest', int? birthYear = 1990}) =>
    UserProfile(
      uid: uid,
      displayName: 'Anna',
      email: '',
      joinedAt: DateTime(2026, 6, 1),
      lastActiveAt: DateTime(2026, 6, 1),
      birthYear: birthYear,
    );

void main() {
  late _FakeUsers users;
  late _FakeGuestStart guestStart;
  late _MockAge age;

  Future<void> setUpWrapper({required bool anonymous}) async {
    SharedPreferences.setMockInitialValues({});
    users = _FakeUsers();
    guestStart = _FakeGuestStart();
    age = _MockAge();
    when(
      () => age.retryUnfinishedGuestUpgrade(
        birthYear: any(named: 'birthYear'),
      ),
    ).thenAnswer((_) async => true);
    final deletion = _MockDeletion();
    // No claim, so the pending-deletion gate lets the app branch through.
    when(() => deletion.scheduledDeletionAt()).thenAnswer((_) async => null);
    final container = DIContainer();
    await container.reset();
    container.registerModule(
      _Module(
        auth: _FakeAuth(_FakeUser(isAnonymous: anonymous)),
        users: users,
        deletion: deletion,
        guestStart: guestStart,
        age: age,
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

  // The plate line animates forever, so settle cannot be used; a few pumps
  // let the pending-deletion gate's claim read finish.
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(host());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('e-mail verification gate', () {
    testWidgets('an anonymous, unverified, new account is let into the app', (
      tester,
    ) async {
      await setUpWrapper(anonymous: true);
      // A failed profile load draws the app branch's retry view, which only
      // the code after the gate can draw.
      users.failed = true;

      await pumpHost(tester);

      expect(find.text(_sv.commonRetry), findsOneWidget);
      expect(find.text(_sv.emailVerificationTitle), findsNothing);
    });

    testWidgets('control: a non-anonymous, unverified, new account meets the '
        'gate', (tester) async {
      await setUpWrapper(anonymous: false);
      users.failed = true;

      await pumpHost(tester);

      expect(find.text(_sv.emailVerificationTitle), findsOneWidget);
      expect(find.text(_sv.commonRetry), findsNothing);
    });
  });

  group('guest start in progress', () {
    testWidgets('a guest waits on the preparing screen, not Hem or the '
        'profile error, until the start is done', (tester) async {
      await setUpWrapper(anonymous: true);
      users.failed = true;
      guestStart.running = true;

      await pumpHost(tester);

      expect(find.text(_sv.guestStartPreparing), findsOneWidget);
      expect(find.text(_sv.commonRetry), findsNothing);

      guestStart.setRunning(false);
      await tester.pump();

      expect(find.text(_sv.guestStartPreparing), findsNothing);
      expect(find.text(_sv.commonRetry), findsOneWidget);
    });

    testWidgets('control: a non-guest is never held on the preparing screen', (
      tester,
    ) async {
      await setUpWrapper(anonymous: false);
      users.failed = true;
      guestStart.running = true;

      await pumpHost(tester);

      expect(find.text(_sv.guestStartPreparing), findsNothing);
    });
  });

  group('unfinished guest upgrade retry', () {
    testWidgets('a profile loaded at startup retries once with its birth '
        'year, and a later profile change for the same account does not '
        'retry again', (tester) async {
      await setUpWrapper(anonymous: false);
      users.profile = _profile(birthYear: 1990);

      await pumpHost(tester);

      verify(() => age.retryUnfinishedGuestUpgrade(birthYear: 1990)).called(1);

      users.loaded(_profile(birthYear: 1990));
      await tester.pump();

      // The first call is already verified above, so only a new one counts.
      verifyNever(
        () => age.retryUnfinishedGuestUpgrade(
          birthYear: any(named: 'birthYear'),
        ),
      );
    });

    testWidgets('a profile that loads later retries once, and a different '
        'account retries again', (tester) async {
      await setUpWrapper(anonymous: false);

      await pumpHost(tester);
      verifyNever(
        () => age.retryUnfinishedGuestUpgrade(
          birthYear: any(named: 'birthYear'),
        ),
      );

      users.loaded(_profile(uid: 'uid-a', birthYear: 1985));
      users.loaded(_profile(uid: 'uid-a', birthYear: 1985));
      await tester.pump();
      verify(
        () => age.retryUnfinishedGuestUpgrade(
          birthYear: any(named: 'birthYear'),
        ),
      ).called(1);

      users.loaded(_profile(uid: 'uid-b', birthYear: 1970));
      await tester.pump();
      verify(() => age.retryUnfinishedGuestUpgrade(birthYear: 1970)).called(1);
    });
  });
}
