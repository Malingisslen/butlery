/// BUT-2170: which links open "Välj nytt lösenord". Only Firebase's reset
/// action on our Hosting domain does, wrapped in the mobile link or bare;
/// other mail actions and look-alike hosts must not.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/auth/password_reset_link.dart';

String _action(String mode, {String code = 'abc123', String? host}) =>
    'https://${host ?? PasswordResetLink.linkDomain}/__/auth/action'
    '?apiKey=k&mode=$mode&oobCode=$code&continueUrl=x&lang=sv';

String _wrapped(String inner, {String? host}) =>
    'https://${host ?? PasswordResetLink.linkDomain}/__/auth/links'
    '?link=${Uri.encodeComponent(inner)}';

void main() {
  group('PasswordResetLink.parse', () {
    test('reads the code from the mobile link Firebase sends', () {
      final link = PasswordResetLink.parse(
        _wrapped(_action('resetPassword')),
      );
      expect(link?.code, 'abc123');
    });

    test('reads the code from the bare action page link', () {
      expect(
        PasswordResetLink.parse(_action('resetPassword'))?.code,
        'abc123',
      );
    });

    test('ignores the other mail actions, which stay on Firebase pages', () {
      for (final mode in [
        'verifyEmail',
        'verifyAndChangeEmail',
        'recoverEmail',
      ]) {
        final link = _wrapped(_action(mode));
        expect(PasswordResetLink.parse(link), isNull, reason: mode);
        expect(PasswordResetLink.firebaseActionUrl(link), isNotNull);
      }
    });

    test('refuses another host, outside or inside the wrapper', () {
      expect(
        PasswordResetLink.parse(_action('resetPassword', host: 'evil.example')),
        isNull,
      );
      expect(
        PasswordResetLink.parse(
          _wrapped(_action('resetPassword', host: 'evil.example')),
        ),
        isNull,
      );
      expect(
        PasswordResetLink.parse(
          _wrapped(_action('resetPassword'), host: 'evil.example'),
        ),
        isNull,
      );
    });

    test('refuses plain http and a look-alike host', () {
      expect(
        PasswordResetLink.parse(
          _action('resetPassword').replaceFirst('https:', 'http:'),
        ),
        isNull,
      );
      const lookAlike = '${PasswordResetLink.linkDomain}.evil.example';
      expect(
        PasswordResetLink.parse(_action('resetPassword', host: lookAlike)),
        isNull,
      );
      expect(
        PasswordResetLink.parse(
          _wrapped(_action('resetPassword'), host: lookAlike),
        ),
        isNull,
      );
    });

    test('refuses a wrapper around anything but the action page', () {
      final otherPage = _action(
        'resetPassword',
      ).replaceFirst('/__/auth/action', '/__/auth/other');
      expect(PasswordResetLink.parse(_wrapped(otherPage)), isNull);
    });

    test('refuses a reset link without a code', () {
      expect(
        PasswordResetLink.parse(_action('resetPassword', code: '')),
        isNull,
      );
    });

    test('leaves the app\'s own links alone', () {
      expect(
        PasswordResetLink.parse('https://butlery.app/recipe?id=1'),
        isNull,
      );
      expect(
        PasswordResetLink.firebaseActionUrl('butlery://import?url=x'),
        isNull,
      );
      expect(PasswordResetLink.parse('not a link at all'), isNull);
    });
  });
}
