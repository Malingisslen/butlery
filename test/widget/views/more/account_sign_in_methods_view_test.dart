/// BUT-916 slice B: Inloggningssätt lists what the account signs in with and
/// adds or takes away Google, Apple and a password; the last method cannot
/// go, and a method is only dropped after the question is answered.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/more/account_sign_in_methods_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../../test_support/base_unit_test.dart';

/// An account that holds [methods] and records what the page asks of it.
class _MethodsAuth extends mocks.MockAuthService {
  _MethodsAuth(Set<String> methods, {this.address = 'anna@example.com'})
    : methods = {...methods};

  final Set<String> methods;
  final String? address;
  final linked = <SignInProvider>[];
  final unlinked = <SignInProvider>[];
  final passwords = <String>[];
  String? reason;
  bool succeeds = true;
  bool revokes = false;
  final reauthThrough = <SignInProvider>[];

  /// What the fresh sign-in the page asks for first answers.
  ProviderSignInOutcome reauthOutcome = ProviderSignInOutcome.signedIn;
  int reauthentications = 0;

  @override
  SignInProvider? reauthenticationProvider({bool forDeletion = false}) =>
      SignInProvider.google;

  @override
  bool get revokesAppleOnUnlink => revokes;

  @override
  Future<ProviderSignInOutcome> reauthenticateWithProvider(
    SignInProvider provider,
  ) async {
    reauthentications++;
    reauthThrough.add(provider);
    return reauthOutcome;
  }

  @override
  bool get hasPasswordSignIn => methods.contains('password');

  @override
  bool isProviderLinked(SignInProvider provider) =>
      methods.contains(provider.providerId);

  @override
  bool isProviderOffered(SignInProvider provider) => true;

  @override
  String? providerAccountEmail(SignInProvider provider) =>
      isProviderLinked(provider) ? 'anna@gmail.example' : null;

  @override
  String? get currentUserEmail => address;

  @override
  bool get canUnlinkSignInMethod => methods.length > 1;

  @override
  String? get errorMessage => reason;

  @override
  Future<bool> linkProvider(SignInProvider provider) async {
    linked.add(provider);
    if (!succeeds) return false;
    methods.add(provider.providerId);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> unlinkProvider(SignInProvider provider) async {
    unlinked.add(provider);
    if (!succeeds) return false;
    methods.remove(provider.providerId);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> addPasswordSignIn(String password) async {
    passwords.add(password);
    if (!succeeds) return false;
    methods.add('password');
    notifyListeners();
    return true;
  }
}

void main() {
  final sv = AppLocalizationsSv();

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<_MethodsAuth> pump(
    WidgetTester tester,
    Set<String> methods, {
    String? address = 'anna@example.com',
  }) async {
    final auth = _MethodsAuth(methods, address: address)
      ..setAuthState(
        currentUser: MockFactory.createMockUser(uid: 'anna'),
        isAuthenticated: true,
      );
    TestServiceLocator.registerMock<AuthService>(auth);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const AccountSignInMethodsView(),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('a password account with Google shows each method and its '
      'action, and Apple can be linked', (tester) async {
    await pump(tester, {'password', 'google.com'});

    expect(find.text(sv.signInMethodsPassword), findsOneWidget);
    expect(find.text(sv.signInMethodsOn), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('anna@gmail.example'), findsOneWidget);
    expect(find.text(sv.signInMethodsUnlink), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text(sv.signInMethodsLink), findsOneWidget);
    expect(find.text(sv.signInMethodsLastOne), findsOneWidget);
  });

  testWidgets('a Google-only account cannot unlink Google and is offered a '
      'password', (tester) async {
    await pump(tester, {'google.com'});

    expect(find.text(sv.signInMethodsUnlink), findsNothing);
    expect(
      find.text(sv.signInMethodsOnlyProvider('Google')),
      findsOneWidget,
    );
    expect(find.text(sv.signInMethodsSetPassword), findsOneWidget);
  });

  testWidgets('linking Apple asks the account to link it and says so', (
    tester,
  ) async {
    final auth = await pump(tester, {'password'});

    await tester.tap(find.text(sv.signInMethodsLink).last);
    await tester.pumpAndSettle();

    expect(auth.linked, [SignInProvider.apple]);
    expect(find.text(sv.signInMethodsLinked('Apple')), findsOneWidget);
  });

  testWidgets('unlinking asks first, and answering no changes nothing', (
    tester,
  ) async {
    final auth = await pump(tester, {'password', 'google.com'});

    await tester.tap(find.text(sv.signInMethodsUnlink));
    await tester.pumpAndSettle();
    expect(find.text(sv.signInMethodsUnlinkTitle('Google')), findsOneWidget);
    expect(
      find.textContaining(sv.signInMethodsInsteadPassword),
      findsOneWidget,
    );

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(auth.unlinked, isEmpty);
    expect(find.text(sv.signInMethodsUnlinkTitle('Google')), findsNothing);
  });

  testWidgets('confirming unlinks the method and the row offers to link it '
      'again', (tester) async {
    final auth = await pump(tester, {'password', 'google.com'});

    await tester.tap(find.text(sv.signInMethodsUnlink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.signInMethodsUnlink).last);
    await tester.pumpAndSettle();

    expect(auth.unlinked, [SignInProvider.google]);
    expect(find.text(sv.signInMethodsUnlinked('Google')), findsOneWidget);
    expect(find.text(sv.signInMethodsLink), findsNWidgets(2));
  });

  testWidgets('linking and unlinking ask for a fresh sign-in first, and '
      'closing it changes nothing', (tester) async {
    final auth = await pump(tester, {'password', 'google.com'});
    auth.reauthOutcome = ProviderSignInOutcome.cancelled;

    await tester.tap(find.text(sv.signInMethodsLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.signInMethodsUnlink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.signInMethodsUnlink).last);
    await tester.pumpAndSettle();

    expect(auth.reauthentications, 2);
    expect(auth.linked, isEmpty);
    expect(auth.unlinked, isEmpty);
  });

  Future<void> typePasswords(WidgetTester tester, String a, String b) async {
    for (final entry in {
      'signInMethods.newPassword': a,
      'signInMethods.repeatPassword': b,
    }.entries) {
      await tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey(entry.key)),
          matching: find.byType(TextField),
        ),
        entry.value,
      );
    }
    await tester.tap(
      find.widgetWithText(FilledButton, sv.signInMethodsSetPassword),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a refused link tells the user why and links nothing', (
    tester,
  ) async {
    final auth = await pump(tester, {'password'});
    auth
      ..succeeds = false
      ..reason = sv.signInMethodsAlreadyUsed('Apple');

    await tester.tap(find.text(sv.signInMethodsLink).last);
    await tester.pumpAndSettle();

    expect(find.text(sv.signInMethodsAlreadyUsed('Apple')), findsOneWidget);
    expect(find.text(sv.signInMethodsLinked('Apple')), findsNothing);
  });

  testWidgets('unlinking Apple where the app can revoke asks Apple\'s own '
      'sheet and says so', (tester) async {
    final auth = await pump(tester, {'password', 'apple.com'});
    auth.revokes = true;

    await tester.tap(find.text(sv.signInMethodsUnlink));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(sv.signInMethodsUnlinkAppleAsks),
      findsOneWidget,
    );
    await tester.tap(find.text(sv.signInMethodsUnlink).last);
    await tester.pumpAndSettle();

    expect(auth.reauthThrough, [SignInProvider.apple]);
    expect(auth.unlinked, [SignInProvider.apple]);
  });

  testWidgets('unlinking Apple where the app cannot revoke tells the user '
      'to remove Butlery at Apple', (tester) async {
    final auth = await pump(tester, {'password', 'apple.com'});

    await tester.tap(find.text(sv.signInMethodsUnlink));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(sv.signInMethodsUnlinkAppleYourself),
      findsOneWidget,
    );
    await tester.tap(find.text(sv.signInMethodsUnlink).last);
    await tester.pumpAndSettle();
    // The ordinary fresh sign-in, not Apple's sheet.
    expect(auth.reauthThrough, [SignInProvider.google]);
    expect(auth.unlinked, [SignInProvider.apple]);
  });

  testWidgets('unlinking Google never opens Apple\'s sheet, even where Apple '
      'could be revoked, and the dialog has no Apple text', (tester) async {
    final auth = await pump(tester, {'password', 'google.com', 'apple.com'});
    auth.revokes = true;

    await tester.tap(find.text(sv.signInMethodsUnlink).first);
    await tester.pumpAndSettle();
    expect(find.text(sv.signInMethodsUnlinkTitle('Google')), findsOneWidget);
    expect(find.textContaining(sv.signInMethodsUnlinkAppleAsks), findsNothing);
    expect(
      find.textContaining(sv.signInMethodsUnlinkAppleYourself),
      findsNothing,
    );
    await tester.tap(find.text(sv.signInMethodsUnlink).last);
    await tester.pumpAndSettle();

    expect(auth.reauthThrough, [SignInProvider.google]);
    expect(auth.unlinked, [SignInProvider.google]);
  });

  testWidgets('without a password the dialog says which method is left, and '
      'no sign-in is asked before the answer', (tester) async {
    final auth = await pump(tester, {'google.com', 'apple.com'});

    await tester.tap(find.text(sv.signInMethodsUnlink).first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(sv.signInMethodsInsteadProvider('Apple')),
      findsOneWidget,
    );
    expect(auth.reauthentications, 0);
  });

  testWidgets('a refused unlink tells the user and keeps the method', (
    tester,
  ) async {
    final auth = await pump(tester, {'password', 'google.com'});
    auth
      ..succeeds = false
      ..reason = sv.signInMethodsUnlinkFailed('Google');

    await tester.tap(find.text(sv.signInMethodsUnlink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.signInMethodsUnlink).last);
    await tester.pumpAndSettle();

    expect(find.text(sv.signInMethodsUnlinkFailed('Google')), findsOneWidget);
    expect(find.text(sv.signInMethodsUnlinked('Google')), findsNothing);
  });

  testWidgets('a password that could not be set tells the user', (
    tester,
  ) async {
    final auth = await pump(tester, {'google.com'});
    auth
      ..succeeds = false
      ..reason = sv.signInMethodsPasswordFailed;

    await tester.tap(find.text(sv.signInMethodsSetPassword));
    await tester.pumpAndSettle();
    await typePasswords(tester, 'hemligt-losen-123', 'hemligt-losen-123');

    expect(find.text(sv.signInMethodsPasswordFailed), findsOneWidget);
    expect(find.text(sv.signInMethodsPasswordSet), findsNothing);
  });

  testWidgets('a failed fresh sign-in is shown and changes nothing', (
    tester,
  ) async {
    final auth = await pump(tester, {'password'});
    auth.reauthOutcome = ProviderSignInOutcome.failed;
    auth.reason = 'Inloggningen gick inte';

    await tester.tap(find.text(sv.signInMethodsLink).last);
    await tester.pumpAndSettle();

    expect(auth.linked, isEmpty);
    expect(find.text('Inloggningen gick inte'), findsOneWidget);
  });

  testWidgets('a password is set after a fresh sign-in, and says so', (
    tester,
  ) async {
    final auth = await pump(tester, {'google.com'});

    await tester.tap(find.text(sv.signInMethodsSetPassword));
    await tester.pumpAndSettle();
    await typePasswords(tester, 'hemligt-losen-123', 'hemligt-losen-123');

    expect(auth.reauthentications, 1);
    expect(auth.passwords, ['hemligt-losen-123']);
    expect(find.text(sv.signInMethodsPasswordSet), findsOneWidget);
  });

  testWidgets('no password is set when the fresh sign-in is closed', (
    tester,
  ) async {
    final auth = await pump(tester, {'google.com'});
    auth.reauthOutcome = ProviderSignInOutcome.cancelled;

    await tester.tap(find.text(sv.signInMethodsSetPassword));
    await tester.pumpAndSettle();
    await typePasswords(tester, 'hemligt-losen-123', 'hemligt-losen-123');

    expect(auth.reauthentications, 1);
    expect(auth.passwords, isEmpty);
  });

  testWidgets('a repeat that does not match is turned back', (tester) async {
    final auth = await pump(tester, {'google.com'});

    await tester.tap(find.text(sv.signInMethodsSetPassword));
    await tester.pumpAndSettle();
    await typePasswords(tester, 'hemligt-losen-123', 'hemligt-losen-124');

    expect(find.text(sv.accountSecurityPasswordMismatch), findsOneWidget);
    expect(auth.passwords, isEmpty);
  });

  testWidgets('a short password is turned back in the dialog and nothing is '
      'set', (tester) async {
    final auth = await pump(tester, {'google.com'});

    await tester.tap(find.text(sv.signInMethodsSetPassword));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('signInMethods.newPassword')),
        matching: find.byType(TextField),
      ),
      'kort',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, sv.signInMethodsSetPassword),
    );
    await tester.pumpAndSettle();

    expect(find.text(sv.validationPasswordRule), findsOneWidget);
    expect(auth.passwords, isEmpty);
  });

  testWidgets('an account with no address says a password cannot be set', (
    tester,
  ) async {
    final auth = await pump(tester, {'apple.com'}, address: null);

    await tester.tap(find.text(sv.signInMethodsSetPassword));
    await tester.pumpAndSettle();

    expect(find.text(sv.signInMethodsNoAddress), findsOneWidget);
    expect(auth.passwords, isEmpty);
  });
}
