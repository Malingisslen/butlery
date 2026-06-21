/// BUT-1333: Unit tests for AuthMfaService (phone/SMS MFA) and the shared
/// error-code mapper.
///
/// Intent: prove user-visible MFA behaviour — enrollment starts, codes are
/// delivered to the caller, sign-in resolution fires, errors are mapped to
/// the correct l10n keys. Tests are NOT testing Firebase SDK internals; they
/// test the service's contract with its two dependencies (AuthRepository +
/// AnalyticsService) and the callbacks it drives.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/auth_error_mapper.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';

// ---------------------------------------------------------------------------
// Local mocks — narrow, no concrete @override bodies (BUT-368 anti-pattern).
// ---------------------------------------------------------------------------

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockUser extends Mock implements User {}

class _MockMultiFactor extends Mock implements MultiFactor {}

/// MultiFactorResolver has a private ctor; mock via implements so the test
/// can stub `hints`, `session`, and `resolveSignIn` without calling the ctor.
class _MockMultiFactorResolver extends Mock implements MultiFactorResolver {}

// ---------------------------------------------------------------------------
// Helpers — concrete instantiable Firebase types used as plain values.
// ---------------------------------------------------------------------------

/// A PhoneMultiFactorInfo the service can find via whereType<>.
PhoneMultiFactorInfo _phoneHint({String phoneNumber = '+46701234567'}) =>
    PhoneMultiFactorInfo(
      displayName: null,
      enrollmentTimestamp: 0,
      factorId: 'phone',
      uid: 'hint-uid',
      phoneNumber: phoneNumber,
    );

/// A MultiFactorInfo that is NOT a phone hint (simulates TOTP only).
MultiFactorInfo _totpHint() => TotpMultiFactorInfo(
      enrollmentTimestamp: 0,
      factorId: 'totp',
      uid: 'totp-hint-uid',
    );

/// Wraps a MultiFactorResolver in the domain MfaResolverInfo opaque shell.
MfaResolverInfo _resolverInfo(_MockMultiFactorResolver resolver) =>
    MfaResolverInfo(resolver: resolver);

// ---------------------------------------------------------------------------
// Fallback values required by mocktail for any() on named-param types.
// ---------------------------------------------------------------------------

class _FakePhoneAuthCredential extends Fake implements PhoneAuthCredential {}

class _FakeMultiFactorAssertion extends Fake implements MultiFactorAssertion {}

class _FakeFirebaseAuthException extends Fake
    implements FirebaseAuthException {}

// ---------------------------------------------------------------------------
// Setup helper — wires verifyPhoneNumber to immediately call codeSent.
//
// This captures the codeSent callback from the named-param call and invokes
// it synchronously so tests can assert onCodeSent without a real Firebase SDK.
// ---------------------------------------------------------------------------
void _stubVerifyPhoneNumberCodeSent(
  _MockAuthRepository repo, {
  String verificationId = 'vid-001',
}) {
  when(() => repo.verifyPhoneNumber(
        multiFactorSession: any(named: 'multiFactorSession'),
        multiFactorInfo: any(named: 'multiFactorInfo'),
        phoneNumber: any(named: 'phoneNumber'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        timeout: any(named: 'timeout'),
      )).thenAnswer((invocation) async {
    final codeSent =
        invocation.namedArguments[#codeSent] as void Function(String, int?);
    codeSent(verificationId, null);
  });
}

/// Like [_stubVerifyPhoneNumberCodeSent] but fires verificationCompleted
/// instead — simulates Android's automatic SMS reading path.
void _stubVerifyPhoneNumberAutoVerify(
  _MockAuthRepository repo,
  PhoneAuthCredential credential,
) {
  when(() => repo.verifyPhoneNumber(
        multiFactorSession: any(named: 'multiFactorSession'),
        multiFactorInfo: any(named: 'multiFactorInfo'),
        phoneNumber: any(named: 'phoneNumber'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        timeout: any(named: 'timeout'),
      )).thenAnswer((invocation) async {
    final verificationCompleted =
        invocation.namedArguments[#verificationCompleted] as void Function(
            PhoneAuthCredential);
    verificationCompleted(credential);
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockAuthRepository mockRepo;
  late _MockAnalyticsService mockAnalytics;
  late AuthMfaService sut;
  late _MockUser mockUser;
  late _MockMultiFactor mockMultiFactor;

  setUpAll(() {
    registerFallbackValue(_FakePhoneAuthCredential());
    registerFallbackValue(_FakeFirebaseAuthException());
    registerFallbackValue(MultiFactorSession('fallback-session'));
    registerFallbackValue(Duration.zero);
    registerFallbackValue(_FakeMultiFactorAssertion());
  });

  setUp(() {
    mockRepo = _MockAuthRepository();
    mockAnalytics = _MockAnalyticsService();
    mockUser = _MockUser();
    mockMultiFactor = _MockMultiFactor();

    // logLogin is fire-and-forget analytics; stub it so it doesn't throw.
    when(() => mockAnalytics.logLogin(method: any(named: 'method')))
        .thenAnswer((_) async {});
    // logEvent likewise.
    when(() => mockAnalytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        )).thenAnswer((_) async {});

    // Default: user is signed in; multiFactor delegates to mockMultiFactor.
    when(() => mockRepo.currentUser).thenReturn(mockUser);
    when(() => mockUser.multiFactor).thenReturn(mockMultiFactor);

    sut = AuthMfaService(
      analyticsService: mockAnalytics,
      authRepository: mockRepo,
    );
  });

  tearDown(() {
    sut.dispose();
    resetMocktailState();
  });

  // -------------------------------------------------------------------------
  // Criterion 1a — startMfaEnrollment: codeSent path
  // -------------------------------------------------------------------------

  group('startMfaEnrollment — code-sent path', () {
    test(
        'calls verifyPhoneNumber with a multiFactorSession and fires onCodeSent',
        () async {
      // This test proves that startMfaEnrollment passes the session returned
      // by user.multiFactor.getSession() into _authRepository.verifyPhoneNumber
      // and that the onCodeSent callback fires with the verificationId.
      // It would fail if getSession() were not called, if verifyPhoneNumber
      // were never invoked, or if codeSent callback were swallowed.
      final session = MultiFactorSession('session-abc');
      when(() => mockMultiFactor.getSession()).thenAnswer((_) async => session);
      _stubVerifyPhoneNumberCodeSent(mockRepo, verificationId: 'vid-001');

      String? capturedId;
      MfaError? capturedError;

      await sut.startMfaEnrollment(
        '+46701234567',
        onCodeSent: (id) => capturedId = id,
        onError: (e) => capturedError = e,
      );

      expect(capturedId, 'vid-001',
          reason: 'onCodeSent must receive the verificationId from codeSent');
      expect(capturedError, isNull,
          reason: 'no error path should fire on a clean code-sent flow');
      final captured = verify(
        () => mockRepo.verifyPhoneNumber(
          multiFactorSession: captureAny(named: 'multiFactorSession'),
          multiFactorInfo: any(named: 'multiFactorInfo'),
          phoneNumber: any(named: 'phoneNumber'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          timeout: any(named: 'timeout'),
        ),
      ).captured;
      expect(captured.single, same(session),
          reason: 'the session from getSession() must be forwarded verbatim');
    });

    test('fires onError with user-not-found code when no user is signed in',
        () async {
      // Proves the null-user guard: if currentUser is null, onError fires
      // immediately without touching verifyPhoneNumber.
      when(() => mockRepo.currentUser).thenReturn(null);

      MfaError? capturedError;
      await sut.startMfaEnrollment(
        '+46701234567',
        onCodeSent: (_) {},
        onError: (e) => capturedError = e,
      );

      expect(capturedError?.code, 'user-not-found',
          reason: 'null user must emit user-not-found MfaError');
      verifyNever(
        () => mockRepo.verifyPhoneNumber(
          multiFactorSession: any(named: 'multiFactorSession'),
          multiFactorInfo: any(named: 'multiFactorInfo'),
          phoneNumber: any(named: 'phoneNumber'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          timeout: any(named: 'timeout'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Criterion 1b — startMfaEnrollment: auto-verification path (Android only)
  // -------------------------------------------------------------------------

  group('startMfaEnrollment — auto-verification path', () {
    test('onAutoVerified fires when SDK auto-reads the SMS code', () async {
      // Proves that the verificationCompleted callback branch is wired:
      // when Firebase SDK resolves the code automatically (Android fast-path),
      // the service calls user.multiFactor.enroll() and fires onAutoVerified.
      // Would fail if the verificationCompleted branch were deleted or if
      // onAutoVerified were never called after enroll() succeeds.
      final session = MultiFactorSession('session-abc');
      when(() => mockMultiFactor.getSession()).thenAnswer((_) async => session);
      when(() => mockMultiFactor.enroll(any())).thenAnswer((_) async {});

      final credential = _FakePhoneAuthCredential();
      _stubVerifyPhoneNumberAutoVerify(mockRepo, credential);

      var autoVerifiedCalled = false;
      MfaError? capturedError;

      await sut.startMfaEnrollment(
        '+46701234567',
        onCodeSent: (_) {},
        onError: (e) => capturedError = e,
        onAutoVerified: () => autoVerifiedCalled = true,
      );

      expect(autoVerifiedCalled, isTrue,
          reason: 'auto-verification path must invoke onAutoVerified callback');
      expect(capturedError, isNull);
      verify(() => mockMultiFactor.enroll(any())).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // Criterion 1c — completeMfaEnrollment
  // -------------------------------------------------------------------------

  group('completeMfaEnrollment', () {
    test('returns true and logs analytics when enroll succeeds', () async {
      // Proves that completeMfaEnrollment returns true on the happy path and
      // that the analytics event fires. Would fail if enroll throws, if the
      // return is hardcoded false, or if the analytics call is missing.
      when(() => mockMultiFactor.enroll(any())).thenAnswer((_) async {});

      final result = await sut.completeMfaEnrollment('vid-001', '123456');

      expect(result, isTrue);
      verify(() => mockAnalytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).called(1);
    });

    test('returns false when no user is signed in', () async {
      // Proves the null-user guard on the completion path: if the user signed
      // out between starting and completing enrollment, return false safely.
      when(() => mockRepo.currentUser).thenReturn(null);

      final result = await sut.completeMfaEnrollment('vid-001', '123456');

      expect(result, isFalse,
          reason: 'no current user means enrollment cannot complete');
    });

    test('returns false and sets errorMessage on FirebaseAuthException',
        () async {
      // Proves the error-handling path: a FirebaseAuthException during enroll
      // causes the method to return false and surface an error message.
      when(() => mockMultiFactor.enroll(any()))
          .thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));

      final result = await sut.completeMfaEnrollment('vid-001', 'wrong');

      expect(result, isFalse);
      expect(sut.errorMessage, isNotNull,
          reason: 'error message must be set after a failed enroll');
      expect(
        sut.errorMessage,
        AppLocale.current.errorInvalidVerificationCode,
        reason:
            'error must map invalid-verification-code to the correct l10n key',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Criterion 2 — unenrollMfa
  // -------------------------------------------------------------------------

  group('unenrollMfa', () {
    test('calls user.multiFactor.unenroll and returns true', () async {
      // Proves the happy-path contract: given a signed-in user and a valid
      // MfaFactorInfo, unenrollMfa delegates to Firebase and returns true.
      // Would fail if unenroll is never called or if the return were false.
      when(() => mockMultiFactor.unenroll(
            multiFactorInfo: any(named: 'multiFactorInfo'),
          )).thenAnswer((_) async {});

      final factor = MfaFactorInfo(
        factor: _totpHint(), // any MultiFactorInfo subtype works here
        displayName: 'Test factor',
        enrollmentTimestamp: 0,
      );

      final result = await sut.unenrollMfa(factor);

      expect(result, isTrue);
      verify(() => mockMultiFactor.unenroll(
            multiFactorInfo: any(named: 'multiFactorInfo'),
          )).called(1);
    });

    test('returns false when no user is signed in', () async {
      // Proves the null-user guard: unenroll must not attempt Firebase calls
      // when the user is not authenticated.
      when(() => mockRepo.currentUser).thenReturn(null);

      final factor = MfaFactorInfo(
        factor: _totpHint(),
        displayName: null,
        enrollmentTimestamp: 0,
      );

      final result = await sut.unenrollMfa(factor);

      expect(result, isFalse,
          reason: 'unenroll without a signed-in user must return false');
      verifyNever(() => mockMultiFactor.unenroll(
            multiFactorInfo: any(named: 'multiFactorInfo'),
          ));
    });
  });

  // -------------------------------------------------------------------------
  // Criterion 3a — startMfaSignIn: no-phone-factor error
  // -------------------------------------------------------------------------

  group('startMfaSignIn — no phone factor', () {
    test(
        'fires onError with code no-phone-factor when resolver has no phone hints',
        () async {
      // This test proves the custom no-phone-factor branch:
      // when the resolver's hints contain no PhoneMultiFactorInfo, the service
      // fires onError with code 'no-phone-factor' WITHOUT calling verifyPhoneNumber.
      // This is a custom MfaError, NOT routed through mapAuthErrorToMessage.
      final resolver = _MockMultiFactorResolver();
      when(() => resolver.hints).thenReturn([_totpHint()]);
      when(() => resolver.session)
          .thenReturn(MultiFactorSession('sign-in-session'));

      final resolverInfo = _resolverInfo(resolver);

      MfaError? capturedError;
      await sut.startMfaSignIn(
        resolverInfo,
        onCodeSent: (_) {},
        onError: (e) => capturedError = e,
      );

      expect(capturedError?.code, 'no-phone-factor',
          reason:
              'resolver with no PhoneMultiFactorInfo hints must emit no-phone-factor');
      verifyNever(
        () => mockRepo.verifyPhoneNumber(
          multiFactorSession: any(named: 'multiFactorSession'),
          multiFactorInfo: any(named: 'multiFactorInfo'),
          phoneNumber: any(named: 'phoneNumber'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          timeout: any(named: 'timeout'),
        ),
      );
    });

    test(
        'fires onError with code no-phone-factor when resolver has empty hints',
        () async {
      // Edge case: empty hints list (not TOTP — literally nothing).
      final resolver = _MockMultiFactorResolver();
      when(() => resolver.hints).thenReturn([]);
      when(() => resolver.session)
          .thenReturn(MultiFactorSession('sign-in-session'));

      final resolverInfo = _resolverInfo(resolver);

      MfaError? capturedError;
      await sut.startMfaSignIn(
        resolverInfo,
        onCodeSent: (_) {},
        onError: (e) => capturedError = e,
      );

      expect(capturedError?.code, 'no-phone-factor');
    });
  });

  // -------------------------------------------------------------------------
  // Criterion 3b — startMfaSignIn: phone factor present
  // -------------------------------------------------------------------------

  group('startMfaSignIn — phone factor present', () {
    test('fires onCodeSent when resolver contains a PhoneMultiFactorInfo hint',
        () async {
      // Proves the happy path: a resolver with a PhoneMultiFactorInfo causes
      // verifyPhoneNumber to be called (with the session from the resolver)
      // and the codeSent callback to arrive at onCodeSent.
      final resolver = _MockMultiFactorResolver();
      when(() => resolver.hints).thenReturn([_phoneHint()]);
      when(() => resolver.session)
          .thenReturn(MultiFactorSession('sign-in-session'));

      final resolverInfo = _resolverInfo(resolver);

      _stubVerifyPhoneNumberCodeSent(mockRepo, verificationId: 'sign-in-vid');

      String? capturedId;
      MfaError? capturedError;

      await sut.startMfaSignIn(
        resolverInfo,
        onCodeSent: (id) => capturedId = id,
        onError: (e) => capturedError = e,
      );

      expect(capturedId, 'sign-in-vid',
          reason: 'onCodeSent must receive the verificationId');
      expect(capturedError, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Criterion 3c — completeMfaSignIn
  // -------------------------------------------------------------------------

  group('completeMfaSignIn', () {
    test('calls resolver.resolveSignIn and returns true on success', () async {
      // Proves that completeMfaSignIn constructs a credential and delegates
      // to MultiFactorResolver.resolveSignIn, then returns true.
      // Would fail if resolveSignIn were skipped or if the return were hardcoded.
      final resolver = _MockMultiFactorResolver();
      when(() => resolver.resolveSignIn(any()))
          .thenAnswer((_) async => FakeUserCredential());

      final resolverInfo = _resolverInfo(resolver);
      final result =
          await sut.completeMfaSignIn(resolverInfo, 'sign-in-vid', '654321');

      expect(result, isTrue);
      verify(() => resolver.resolveSignIn(any())).called(1);
      verify(() => mockAnalytics.logLogin(method: any(named: 'method')))
          .called(1);
    });

    test('returns false and sets errorMessage on FirebaseAuthException',
        () async {
      final resolver = _MockMultiFactorResolver();
      when(() => resolver.resolveSignIn(any()))
          .thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));

      final resolverInfo = _resolverInfo(resolver);
      final result =
          await sut.completeMfaSignIn(resolverInfo, 'sign-in-vid', 'wrong');

      expect(result, isFalse);
      expect(sut.errorMessage, AppLocale.current.errorInvalidVerificationCode);
    });
  });

  // -------------------------------------------------------------------------
  // Criterion 4 — mapAuthErrorToMessage: error-code mapping
  // -------------------------------------------------------------------------

  group('mapAuthErrorToMessage — MFA-specific codes', () {
    FirebaseAuthException exc(String code) => FirebaseAuthException(code: code);

    test('maps invalid-phone-number to errorInvalidPhoneNumber l10n key',
        () async {
      // Proves the phone-number-specific branch is not collapsed into the
      // generic fallback. Would fail if the switch arm were removed.
      final message = mapAuthErrorToMessage(exc('invalid-phone-number'));
      expect(message, AppLocale.current.errorInvalidPhoneNumber,
          reason: 'invalid-phone-number must map to the dedicated l10n key');
      expect(message, isNot(AppLocale.current.errorAuthentication),
          reason: 'must not fall through to the generic authentication error');
    });

    test('maps quota-exceeded to errorTooManySmsAttempts l10n key', () async {
      // Proves the SMS-rate-limit branch. Collapsing this to generic would
      // give a confusing "authentication error" to users hitting the SMS limit.
      final message = mapAuthErrorToMessage(exc('quota-exceeded'));
      expect(message, AppLocale.current.errorTooManySmsAttempts,
          reason: 'quota-exceeded must map to the SMS-limit l10n key');
      expect(message, isNot(AppLocale.current.errorAuthentication));
    });

    test('maps invalid-verification-code to errorInvalidVerificationCode',
        () async {
      // Proves the code-mismatch branch. Critical for MFA UX: user needs to
      // know to re-enter the code, not that "authentication failed" generically.
      final message = mapAuthErrorToMessage(exc('invalid-verification-code'));
      expect(message, AppLocale.current.errorInvalidVerificationCode,
          reason:
              'invalid-verification-code must map to the code-specific l10n key');
      expect(message, isNot(AppLocale.current.errorAuthentication));
    });

    test('unknown code falls back to generic errorAuthentication', () async {
      // Proves the default branch exists and catches unknown codes rather
      // than throwing. Pair with the positive tests above so future switch
      // deletions fail at least one assertion.
      final message = mapAuthErrorToMessage(exc('some-future-firebase-code'));
      expect(message, AppLocale.current.errorAuthentication,
          reason: 'unknown codes must fall back to the generic auth error');
    });

    test(
        'no-phone-factor is NOT routed through mapAuthErrorToMessage — it is a '
        'custom MfaError emitted directly', () async {
      // Documents the intentional gap: 'no-phone-factor' is not a Firebase
      // error code; the service emits it as an MfaError.code without
      // going through the error mapper. Asserting that the mapper returns
      // the generic fallback for it proves the isolation is correct.
      final message = mapAuthErrorToMessage(exc('no-phone-factor'));
      expect(message, AppLocale.current.errorAuthentication,
          reason:
              'no-phone-factor is not a Firebase code; mapper returns generic fallback');
    });
  });
}

/// Minimal UserCredential fake needed for completeMfaSignIn stubs.
class FakeUserCredential extends Fake implements UserCredential {
  @override
  User? get user => null;
}
