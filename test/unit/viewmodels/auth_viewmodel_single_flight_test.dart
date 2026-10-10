import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/auth_viewmodel.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

/// Keeps each request in flight until the test releases it, and counts how
/// many requests actually reached the service.
class GatedAuthService extends MockAuthService {
  int signInCalls = 0;
  int registerCalls = 0;
  Completer<bool> gate = Completer<bool>();

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) {
    signInCalls++;
    return gate.future;
  }

  @override
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    registerCalls++;
    return gate.future;
  }
}

void main() {
  group('AuthViewModel double submit', () {
    late GatedAuthService service;
    late AuthViewModel viewModel;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      service = GatedAuthService();
      viewModel = AuthViewModel(authService: service);
    });

    tearDown(() {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Future<bool> signIn() =>
        viewModel.signIn(email: 'anna@example.com', password: 'Str0ng!Pass1');

    Future<bool> register() => viewModel.register(
      email: 'anna@example.com',
      password: 'Str0ng!Pass1',
      displayName: 'Anna',
    );

    test('two sign-ins while one is in flight send one request and both '
        'callers get its result', () async {
      final first = signIn();
      final second = signIn();

      expect(service.signInCalls, 1);

      service.gate.complete(true);
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(service.signInCalls, 1);
    });

    test('a sign-in after the first one finished is sent again', () async {
      final first = signIn();
      service.gate.complete(false);
      expect(await first, isFalse);

      service.gate = Completer<bool>();
      final retry = signIn();
      expect(service.signInCalls, 2);
      service.gate.complete(true);
      expect(await retry, isTrue);
    });

    test('two registrations while one is in flight send one request', () async {
      final first = register();
      final second = register();

      expect(service.registerCalls, 1);

      service.gate.complete(true);
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(service.registerCalls, 1);
    });

    test('a sign-in in flight does not swallow a registration', () async {
      final signInFuture = signIn();
      final registerFuture = register();

      expect(service.signInCalls, 1);
      expect(service.registerCalls, 1);

      service.gate.complete(true);
      await signInFuture;
      await registerFuture;
    });
  });
}
