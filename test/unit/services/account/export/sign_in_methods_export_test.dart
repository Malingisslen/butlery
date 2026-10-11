/// Unit tests for [ComplianceExportManager.exportSignInMethods] (BUT-916, C12).
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' show UserInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/account/export/compliance_export_manager.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

class _NoFunctions extends Fake implements FirebaseFunctions {}

class _Info extends Fake implements UserInfo {
  _Info(this.providerId, this.email, {this.photoURL});

  @override
  final String providerId;
  @override
  final String? email;
  @override
  final String? photoURL;
  @override
  String get uid => 'provider-uid-$providerId';
  @override
  String? get displayName => 'Anna';
}

ComplianceExportManager _manager(String uid, List<UserInfo> providers) {
  final user = MockUser()..setUserState(uid: uid);
  when(() => user.providerData).thenReturn(providers);
  return ComplianceExportManager(
    functions: _NoFunctions(),
    authRepository: FakeAuthRepository()
      ..setAuthState(user: user, userId: uid, isAuthenticated: true),
  );
}

void main() {
  group('ComplianceExportManager.exportSignInMethods (BUT-916)', () {
    test('lists each linked provider with its own user id and e-mail and '
        'nothing else', () async {
      final manager = _manager('me', [
        _Info('password', 'anna@example.com'),
        _Info(
          'google.com',
          'anna@gmail.com',
          photoURL: 'https://lh3.googleusercontent.com/a/photo',
        ),
        _Info('apple.com', 'x1y2@privaterelay.appleid.com'),
      ]);

      final result = await manager.exportSignInMethods('me');

      expect(result['sign_in_methods'], [
        {
          'provider_id': 'password',
          'provider_uid': 'provider-uid-password',
          'email': 'anna@example.com',
        },
        {
          'provider_id': 'google.com',
          'provider_uid': 'provider-uid-google.com',
          'email': 'anna@gmail.com',
        },
        {
          'provider_id': 'apple.com',
          'provider_uid': 'provider-uid-apple.com',
          'email': 'x1y2@privaterelay.appleid.com',
        },
      ]);
      expect(result.toString(), isNot(contains('googleusercontent')));
      expect(result.toString(), isNot(contains('Anna')));
      expect(result['data_minimisation'], contains('sign-in tokens'));
      expect(result['gdpr_article'], 'Article 15 - Right of Access');
    });

    test('refuses to export another account than the signed-in one', () async {
      final manager = _manager('me', [_Info('password', 'anna@example.com')]);

      await expectLater(
        manager.exportSignInMethods('someone-else'),
        throwsA(isA<ComplianceExportException>()),
      );
    });
  });
}
