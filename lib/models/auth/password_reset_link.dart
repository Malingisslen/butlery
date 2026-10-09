/// The "glömt lösenord" link as the app receives it (BUT-2170, flow 06
/// `glömt lösenord → återställ → sätt nytt`).
///
/// The reset mail is sent with `handleCodeInApp`, so Firebase wraps its own
/// action page in a mobile link on the Hosting domain:
/// `https://<linkDomain>/__/auth/links?link=<action URL>`. The phone opens
/// that link in the app when the app is installed; anywhere else Firebase
/// falls back to the action page itself, which is why the app never needs a
/// web fallback of its own.
class PasswordResetLink {
  const PasswordResetLink._(this.code);

  /// Firebase's one-time action code (`oobCode`).
  final String code;

  /// The Hosting domain Firebase builds the mobile link on. Its two
  /// association files live in `web/.well-known/`, which that site serves.
  static const String linkDomain = 'butlery-app-1.firebaseapp.com';

  /// Where Firebase sends someone who finishes on its own page instead.
  static const String continueUrl = 'https://$linkDomain/';

  static const String androidPackageName = 'se.butlery.app';
  static const String iOSBundleId = 'se.butlery.app';

  static const String _mobileLinkPath = '/__/auth/links';
  static const String _actionPath = '/__/auth/action';

  /// The reset link in [link], or null when [link] is anything else: another
  /// mail action (verify e-mail, change e-mail), another host, or no code.
  static PasswordResetLink? parse(String link) {
    final action = firebaseActionUrl(link);
    if (action == null) return null;
    if (action.queryParameters['mode'] != 'resetPassword') return null;
    final code = action.queryParameters['oobCode'];
    if (code == null || code.isEmpty) return null;
    return PasswordResetLink._(code);
  }

  /// The Firebase action page [link] points at, unwrapped from the mobile
  /// link when it is one. Null when [link] is not on [linkDomain].
  static Uri? firebaseActionUrl(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'https' || uri.host != linkDomain) {
      return null;
    }
    if (uri.path == _actionPath) return uri;
    if (uri.path != _mobileLinkPath) return null;
    final inner = uri.queryParameters['link'];
    if (inner == null) return null;
    final action = Uri.tryParse(inner);
    if (action == null ||
        action.scheme != 'https' ||
        action.host != linkDomain ||
        action.path != _actionPath) {
      return null;
    }
    return action;
  }
}
