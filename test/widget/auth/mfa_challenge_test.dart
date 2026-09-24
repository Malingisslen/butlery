// P6-U09 — the MFA challenge view and the backup-code gate
// (Skarmar v12 etapp 3 #authmfa, etapp 6 #mfaaktiv; produktregler.md:745-749).

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/views/settings/mfa_settings_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _FakeMfa implements AuthMfaService {
  void Function(String)? codeSent;
  void Function()? autoVerified;
  bool codeOk = false;
  MfaRecoveryOutcome recovery = MfaRecoveryOutcome.rejected;
  final List<String> recoveredWith = [];

  @override
  Future<void> startMfaSignIn(
    MfaResolverInfo resolverInfo, {
    required void Function(String verificationId) onCodeSent,
    required void Function(MfaError error) onError,
    void Function()? onAutoVerified,
  }) async {
    codeSent = onCodeSent;
    autoVerified = onAutoVerified;
    onCodeSent('vid-1');
  }

  @override
  Future<bool> completeMfaSignIn(
    MfaResolverInfo resolverInfo,
    String verificationId,
    String smsCode,
  ) async => codeOk;

  @override
  Future<MfaRecoveryOutcome> recoverWithBackupCode({
    required String email,
    required String password,
    required String code,
  }) async {
    recoveredWith.add(code);
    return recovery;
  }

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuth implements AuthService {
  bool signedIn = false;
  int finishCalls = 0;
  int signIns = 0;
  int cleared = 0;

  @override
  Future<bool> finishMfaSignIn() async {
    finishCalls++;
    signedIn = true;
    return true;
  }

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signIns++;
    signedIn = true;
    return true;
  }

  @override
  void clearPendingMfa() => cleared++;

  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _challenge = MfaResolverInfo(
  resolver: Object(),
  phoneHint: '+*******4547',
);

Widget _host(
  _FakeMfa mfa,
  _FakeAuth auth,
  void Function(MfaChallengeResult?) onResult,
) => createLocalizedTestApp(
  child: Builder(
    builder: (context) => ElevatedButton(
      onPressed: () async {
        final result = await Navigator.of(context).push<MfaChallengeResult>(
          MaterialPageRoute(
            builder: (_) => MfaChallengeView(
              challenge: _challenge,
              email: 'anna@example.com',
              password: 'hemligt123',
              mfaService: mfa,
              authService: auth,
            ),
          ),
        );
        onResult(result);
      },
      child: const Text('open'),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

/// Lets the 60 s countdown run out so no timer is left pending.
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 61; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('shows the masked hint, one code field and 60 seconds', (
    tester,
  ) async {
    final mfa = _FakeMfa();
    await tester.pumpWidget(_host(mfa, _FakeAuth(), (_) {}));
    await _open(tester);

    expect(find.text('Skriv koden'), findsOneWidget);
    expect(find.textContaining('slutar på •• 47'), findsOneWidget);
    expect(find.textContaining('4547'), findsNothing);
    expect(
      find.text('Koden gäller i 60 sekunder. 60 s kvar.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mfaChallenge.code')), findsOneWidget);
    expect(find.text('Skicka en ny kod'), findsOneWidget);
    expect(find.text('Använd en reservkod'), findsOneWidget);

    await tester.pump(const Duration(seconds: 22));
    expect(
      find.text('Koden gäller i 60 sekunder. 38 s kvar.'),
      findsOneWidget,
    );
    await _drain(tester);
    expect(find.text('Koden har gått ut. Skicka en ny kod.'), findsOneWidget);
  });

  testWidgets('a wrong code says so and does not sign in', (tester) async {
    final mfa = _FakeMfa()..codeOk = false;
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(mfa, auth, (_) {}));
    await _open(tester);

    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.code')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.verify')));
    await tester.pump();

    expect(
      find.text(
        'Koden stämmer inte. Kontrollera siffrorna eller skicka en ny kod.',
      ),
      findsOneWidget,
    );
    expect(auth.finishCalls, 0);
    await _drain(tester);
  });

  testWidgets('a right code signs in', (tester) async {
    final mfa = _FakeMfa()..codeOk = true;
    final auth = _FakeAuth();
    MfaChallengeResult? result;
    await tester.pumpWidget(_host(mfa, auth, (r) => result = r));
    await _open(tester);

    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.code')),
      '419000',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.verify')));
    await tester.pumpAndSettle();

    expect(result, MfaChallengeResult.signedIn);
    expect(auth.finishCalls, 1);
  });

  testWidgets(
    'automatic verification mid-typing signs in without an error',
    (tester) async {
      final mfa = _FakeMfa()..codeOk = false;
      final auth = _FakeAuth();
      MfaChallengeResult? result;
      await tester.pumpWidget(_host(mfa, auth, (r) => result = r));
      await _open(tester);

      await tester.enterText(
        find.byKey(const ValueKey('mfaChallenge.code')),
        '419',
      );
      // The phone read the SMS and the SDK resolved the sign-in.
      mfa.autoVerified!();
      await tester.pumpAndSettle();

      expect(result, MfaChallengeResult.signedIn);
      expect(auth.finishCalls, 1, reason: 'finished exactly once');
      expect(find.byKey(const ValueKey('mfaChallenge.error')), findsNothing);
    },
  );

  testWidgets('a rejected backup code says so and stays', (tester) async {
    final mfa = _FakeMfa()..recovery = MfaRecoveryOutcome.rejected;
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(mfa, auth, (_) {}));
    await _open(tester);

    await tester.tap(find.text('Använd en reservkod'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.backupCode')),
      'ABCDE-FGHJK',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.backupSubmit')));
    await tester.pump();

    expect(
      find.textContaining('Lösenordet eller reservkoden stämmer inte'),
      findsOneWidget,
    );
    expect(auth.signIns, 0);
    await _drain(tester);
  });

  testWidgets('a locked recovery says to wait', (tester) async {
    final mfa = _FakeMfa()..recovery = MfaRecoveryOutcome.locked;
    await tester.pumpWidget(_host(mfa, _FakeAuth(), (_) {}));
    await _open(tester);

    await tester.tap(find.text('Använd en reservkod'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.backupCode')),
      'ABCDE-FGHJK',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.backupSubmit')));
    await tester.pump();

    expect(find.textContaining('Vänta en timme'), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('a backup code signs in again and reports the reset', (
    tester,
  ) async {
    final mfa = _FakeMfa()..recovery = MfaRecoveryOutcome.recovered;
    final auth = _FakeAuth();
    MfaChallengeResult? result;
    await tester.pumpWidget(_host(mfa, auth, (r) => result = r));
    await _open(tester);

    await tester.tap(find.text('Använd en reservkod'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.backupCode')),
      'abcde-fghjk',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.backupSubmit')));
    await tester.pumpAndSettle();

    expect(mfa.recoveredWith, ['abcde-fghjk']);
    expect(auth.signIns, 1, reason: 'a fresh sign-in with the password');
    expect(result, MfaChallengeResult.signedInWithBackupCode);
  });

  group('backup codes before the protection applies', () {
    final codes = List.generate(10, (i) => 'ABCDE-FGH${i}K');

    Widget dialogHost(void Function(bool) onResult) => createLocalizedTestApp(
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async =>
              onResult(await MfaBackupCodesDialog.show(context, codes)),
          child: const Text('open'),
        ),
      ),
    );

    testWidgets('all ten codes are shown and Fortsätt waits for the tick', (
      tester,
    ) async {
      bool? acknowledged;
      await tester.pumpWidget(dialogHost((v) => acknowledged = v));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final list = tester.widget<SelectableText>(
        find.byKey(const ValueKey('mfa.backupCodes.list')),
      );
      expect(list.data!.split('\n'), codes);

      final continueButton = find.byKey(
        const ValueKey('mfa.backupCodes.continue'),
      );
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      final saved = find.byKey(const ValueKey('mfa.backupCodes.saved'));
      await tester.ensureVisible(saved);
      await tester.pumpAndSettle();
      await tester.tap(saved);
      await tester.pump();
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(acknowledged, isTrue);
    });

    testWidgets('cancelling enrolls nothing', (tester) async {
      bool? acknowledged;
      await tester.pumpWidget(dialogHost((v) => acknowledged = v));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(acknowledged, isFalse);
    });

    testWidgets('the switch stays hidden in the app (PQ-16)', (tester) async {
      expect(const MfaSettingsView().offersEnrollment, isFalse);
    });
  });
}
