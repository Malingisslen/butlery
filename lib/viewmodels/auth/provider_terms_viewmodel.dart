import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// The terms step after a new Google/Apple sign-in (BUT-916 C1, C3; mockup
/// screen 2). Nothing is created for the account until [accept].
class ProviderTermsViewModel extends BaseViewModel {
  ProviderTermsViewModel({AuthService? authService, UserService? userService})
    : _auth = authService ?? ServiceLocator.get<AuthService>(),
      _users = userService ?? ServiceLocator.get<UserService>();

  final AuthService _auth;
  final UserService _users;

  bool _termsAccepted = false;
  bool _leaving = false;

  /// What the name field starts with: the provider's first name, editable.
  String get initialName => _auth.providerFirstName.orEmpty();

  bool get termsAccepted => _termsAccepted;

  /// The step was left unanswered before (C3): declining then says that the
  /// account is removed, not merely that the sign-up stops.
  bool get shownAgain => !_auth.providerAccountCreatedHere;

  bool get canCreate => _termsAccepted && !isLoading && !_leaving;

  void setTermsAccepted(bool value) {
    _termsAccepted = value;
    notifyListeners();
  }

  /// "Skapa konto": records the acceptance, then makes the profile with
  /// [displayName]. On success UserService's change moves AuthWrapper on.
  Future<bool> accept(String displayName) async {
    if (!canCreate) return false;
    clearError();
    setLoading(true);
    final ok = await _users.acceptProviderTerms(
      displayName: displayName.trim(),
    );
    if (isDisposed) return ok;
    setLoading(false);
    if (!ok) setError(_users.error);
    return ok;
  }

  /// "Avbryt": removes the auth account the sign-in made and signs out. If
  /// the removal fails (offline, stale sign-in) the sign-out still happens
  /// and the next sign-in meets this step again (C3).
  Future<void> decline() async {
    if (_leaving) return;
    _leaving = true;
    notifyListeners();
    await _auth.deleteCurrentAuthUser();
    await _auth.signOut();
  }
}
