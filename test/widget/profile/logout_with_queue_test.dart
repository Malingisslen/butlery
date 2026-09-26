// P6-U08a — sign-out with a queue (produktregler.md:193; Skarmar v12 del 4
// #utloggningko). Every user-initiated sign-out with N > 0 pending changes
// is blocked with an explanation, and nothing is thrown away unless the user
// picks "Logga ut och släng ändringarna".

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService(this.uid);

  final String? uid;
  int signOuts = 0;

  @override
  String? get currentUserId => uid;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void clearError() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeProfileViewModel implements ProfileViewModel {
  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSource implements PendingChangesSource {
  _FakeSource(this.pending);

  PendingChanges pending;
  final List<String> discarded = [];
  bool throwOnRead = false;

  @override
  Future<PendingChanges> read(String userId) async {
    if (throwOnRead) throw StateError('db closed');
    return pending;
  }

  @override
  Future<void> discard(String userId) async {
    discarded.add(userId);
    pending = PendingChanges.none;
  }
}

class _Module implements DIModule {
  _Module(this.auth, this.profile);

  final _FakeAuthService auth;
  final _FakeProfileViewModel profile;

  @override
  String get name => 'LogoutWithQueueTestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [AuthService, ProfileViewModel];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<AuthService>(auth);
    container.registerSingleton<ProfileViewModel>(profile);
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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
        onPressed: () => AuthActionHandler.handleLogout(context),
        child: const Text('logout'),
      ),
    ),
  ),
);

void main() {
  late _FakeAuthService auth;
  late _FakeProfileViewModel profile;
  late _FakeSource source;
  late SignOutGuard Function() originalFactory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = _FakeAuthService('anna');
    profile = _FakeProfileViewModel();
    source = _FakeSource(
      const PendingChanges(recipeChanges: 2, imageUploads: 1),
    );
    final container = DIContainer();
    await container.reset();
    container.registerModule(_Module(auth, profile));
    await container.initialize();
    ServiceLocator.initialize(container);
    originalFactory = AuthActionHandler.guardFactory;
    AuthActionHandler.guardFactory = () =>
        SignOutGuard(authService: auth, source: source);
  });

  tearDown(() async {
    AuthActionHandler.guardFactory = originalFactory;
    await DIContainer().reset();
  });

  testWidgets('a sign-out with 3 pending changes is blocked and explained', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    expect(find.text('3 ändringar har inte sparats'), findsOneWidget);
    expect(
      find.text(
        'Om du loggar ut nu försvinner de. Butlery väntar gärna tills du har nät igen.',
      ),
      findsOneWidget,
    );
    expect(find.text('Recept · 2 ändringar'), findsOneWidget);
    expect(find.text('Bilder · 1 väntar på uppladdning'), findsOneWidget);
    // The plain question is not asked on top of it.
    expect(find.text('Logga ut'), findsNothing);
  });

  testWidgets('"Vänta på synk" keeps the user signed in and the queue', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vänta på synk'));
    await tester.pumpAndSettle();

    expect(profile.logouts, 0);
    expect(source.discarded, isEmpty);
    expect(find.text('sign-in screen'), findsNothing);
  });

  testWidgets('dismissing the dialog is waiting, never a discard', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5)); // the barrier
    await tester.pumpAndSettle();

    expect(profile.logouts, 0);
    expect(source.discarded, isEmpty);
  });

  testWidgets('"Logga ut och släng ändringarna" discards, then signs out', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logga ut och släng ändringarna'));
    await tester.pumpAndSettle();

    expect(source.discarded, ['anna']);
    expect(profile.logouts, 1);
    expect(find.text('sign-in screen'), findsOneWidget);
  });

  testWidgets('an empty queue asks the ordinary question', (tester) async {
    source.pending = PendingChanges.none;
    await tester.pumpWidget(_host());
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('signOut.pendingChanges')),
      findsNothing,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  test('an unreadable queue fails open: nothing is thrown away', () async {
    source.throwOnRead = true;
    final guard = SignOutGuard(authService: auth, source: source);
    expect(await guard.pendingForCurrentUser(), PendingChanges.none);
    expect(source.discarded, isEmpty);
  });

  test('AuthViewModel.signOut is blocked by the queue too', () async {
    final vm = AuthViewModel(
      authService: auth,
      signOutGuard: SignOutGuard(authService: auth, source: source),
    );
    final blocked = await vm.signOut();
    expect(blocked.total, 3);
    expect(auth.signOuts, 0, reason: 'blocked sign-out never signs out');

    await vm.discardPendingAndSignOut();
    expect(source.discarded, ['anna']);
    expect(auth.signOuts, 1);

    source.pending = PendingChanges.none;
    expect(await vm.signOut(), PendingChanges.none);
    expect(auth.signOuts, 2);
  });
}
