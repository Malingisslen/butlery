import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// "Koppla ihop" (BUT-916 C4; mockup screen 3): the address already has a
/// password account, so its password is asked for once. The provider joins
/// the account only after the whole sign-in, second factor included, has
/// gone through; AuthService does the joining.
class ProviderLinkViewModel extends BaseViewModel {
  ProviderLinkViewModel({AuthService? authService})
    : _auth = authService ?? ServiceLocator.get<AuthService>();

  final AuthService _auth;

  PendingProviderLink? get pending => _auth.pendingProviderLink;

  MfaResolverInfo? get pendingMfaChallenge => _auth.pendingMfaChallenge;

  /// True when signed in (and linked); false with [pendingMfaChallenge] set
  /// when the second factor is asked for next; false with [error] otherwise.
  Future<bool> submit(String password) async {
    final link = pending;
    if (link == null || isLoading) return false;
    if (password.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    clearError();
    setLoading(true);
    final ok = await _auth.signInWithEmail(
      email: link.email,
      password: password,
    );
    if (isDisposed) return ok;
    setLoading(false);
    if (!ok && _auth.pendingMfaChallenge == null) {
      setError(_auth.errorMessage);
    }
    return ok;
  }

  Future<bool> sendPasswordReset() async {
    final link = pending;
    if (link == null) return false;
    return _auth.sendPasswordResetEmail(link.email);
  }

  void cancel() => _auth.cancelPendingProviderLink();
}
