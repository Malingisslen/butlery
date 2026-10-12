import 'package:flutter/foundation.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth_service.dart';

/// Inloggningssätt: what the account signs in with, and the three changes
/// the page offers (BUT-916 slice B).
class AccountSignInMethodsViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  AccountSignInMethodsViewModel({AuthService? authService})
    : _auth = authService ?? ServiceLocator.get<AuthService>() {
    _auth.addListener(notifyListeners);
  }

  final AuthService _auth;

  bool get hasPassword => _auth.hasPasswordSignIn;

  bool isLinked(SignInProvider provider) => _auth.isProviderLinked(provider);

  /// Whether this platform shows [provider]'s sheet at all. A provider that
  /// is already linked is listed either way.
  bool isOffered(SignInProvider provider) => _auth.isProviderOffered(provider);

  String? emailOf(SignInProvider provider) =>
      _auth.providerAccountEmail(provider);

  /// The e-mail the account signs in with a password on, for the row.
  String? get passwordEmail => _auth.currentUserEmail;

  /// False when one method is left, which stays.
  bool get canUnlink => _auth.canUnlinkSignInMethod;

  /// An account that has no password can add one only when it has an
  /// address to put it on.
  bool get canAddPassword => _auth.currentUserEmail.orEmpty().isNotEmpty;

  SignInProvider? get onlyProvider {
    if (hasPassword || canUnlink) return null;
    for (final provider in SignInProvider.values) {
      if (isLinked(provider)) return provider;
    }
    return null;
  }

  /// Apple's sheet gives the code that revokes the app's tokens; where
  /// Firebase runs the sheet itself there is none, and the dialog says so.
  bool get appleRevokesHere => _auth.revokesAppleOnUnlink;

  Future<bool> link(SignInProvider provider) =>
      _run(() => _auth.linkProvider(provider));

  Future<bool> unlink(SignInProvider provider) =>
      _run(() => _auth.unlinkProvider(provider));

  Future<bool> addPassword(String password) =>
      _run(() => _auth.addPasswordSignIn(password));

  Future<bool> _run(Future<bool> Function() change) async {
    setLoading(true);
    clearError();
    final done = await change();
    setLoading(false);
    // AuthService keeps the reason; a closed sheet leaves none.
    if (!done) {
      final reason = _auth.errorMessage;
      if (reason != null) setError(reason);
    }
    return done;
  }

  @override
  void dispose() {
    _auth.removeListener(notifyListeners);
    super.dispose();
  }
}
