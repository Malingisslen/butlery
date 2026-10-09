import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

enum PasswordResetStage {
  /// The link is being checked; nothing to type yet.
  checking,

  /// The check could not finish (offline, too many attempts, unknown); the
  /// same link may still work, so the view offers a retry.
  checkFailed,

  /// Used or expired: only a new link helps.
  linkInvalid,

  /// The address is known and the two password fields are open.
  ready,

  /// The password is saved and the view has handed over to sign-in.
  done,
}

/// "Välj nytt lösenord" from a reset link (BUT-2170; flow 06
/// `återställ → sätt nytt`). The password rule is sign-up's
/// (`FormValidators.minPasswordLength`); Firebase's own policy may still
/// refuse it, which comes back as [PasswordResetFailure.weakPassword].
class PasswordResetViewModel extends BaseViewModel {
  PasswordResetViewModel({
    required PasswordResetService resetService,
    required AuthService authService,
  }) : _resetService = resetService,
       _authService = authService;

  final PasswordResetService _resetService;
  final AuthService _authService;

  String? _code;
  String? _email;
  PasswordResetStage _stage = PasswordResetStage.checking;
  PasswordResetFailure? _checkFailure;

  PasswordResetStage get stage => _stage;

  /// The account the link belongs to, once checked.
  String? get email => _email;

  /// Why the check could not finish, for [PasswordResetStage.checkFailed].
  PasswordResetFailure? get checkFailure => _checkFailure;

  /// Whether this device is signed in to some account other than the one
  /// being reset. Sign-in is then not the next screen.
  bool get signedInElsewhere {
    final current = _authService.currentUser;
    return current != null && !_sameAddress(current.email, _email);
  }

  Future<void> start(String code) async {
    _code = code;
    await _check();
  }

  Future<void> retryCheck() => _check();

  Future<void> _check() async {
    final code = _code;
    if (code == null) return;
    _stage = PasswordResetStage.checking;
    _checkFailure = null;
    notifyListeners();
    final result = await _resetService.check(code);
    if (isDisposed) return;
    if (result.email != null) {
      _email = result.email;
      _stage = PasswordResetStage.ready;
    } else if (result.failure == PasswordResetFailure.linkInvalid) {
      _stage = PasswordResetStage.linkInvalid;
    } else {
      _checkFailure = result.failure;
      _stage = PasswordResetStage.checkFailed;
    }
    notifyListeners();
  }

  /// Saves the password. True when saved; the view then leaves. On a refusal
  /// the reason is in [error] and both fields keep what was typed.
  Future<bool> save({
    required String newPassword,
    required String repeated,
  }) async {
    final code = _code;
    if (code == null || _stage != PasswordResetStage.ready || isLoading) {
      return false;
    }
    final l = AppLocale.current;
    if (newPassword.isEmpty) {
      setError(l.errorPasswordCannotBeEmpty);
      return false;
    }
    if (newPassword.length < FormValidators.minPasswordLength) {
      setError(l.validationPasswordMinEight);
      return false;
    }
    if (newPassword != repeated) {
      setError(l.accountSecurityPasswordMismatch);
      return false;
    }
    clearError();
    setLoading(true);
    final failure = await _resetService.confirm(
      code: code,
      newPassword: newPassword,
    );
    if (isDisposed) return failure == null;
    if (failure == null) {
      // Still loading through the sign-out, so a second tap cannot resend
      // the code that was just spent.
      await _handOver();
      setLoading(false);
      return true;
    }
    setLoading(false);
    switch (failure) {
      case PasswordResetFailure.linkInvalid:
        _stage = PasswordResetStage.linkInvalid;
        notifyListeners();
      case PasswordResetFailure.weakPassword:
        setError(l.setNewPasswordWeak);
      case PasswordResetFailure.network:
        setError(l.setNewPasswordSaveFailedBecause(l.errorNetwork));
      case PasswordResetFailure.tooManyAttempts:
        setError(l.setNewPasswordSaveFailedBecause(l.errorTooManyAttempts));
      case PasswordResetFailure.unknown:
        setError(l.setNewPasswordSaveFailed);
    }
    return false;
  }

  /// Decision B1 (Malin, 2026-10-08): sign-in with the address filled in.
  /// Firebase ends the account's other sessions on a reset, so a device
  /// signed in to the SAME account is signed out here rather than left to
  /// fail on its next token refresh. [AuthService.forceSignOut] also closes
  /// that account's service scope, and keeps the device's drafts.
  Future<void> _handOver() async {
    final email = _email!;
    if (!signedInElsewhere) {
      PasswordResetHandoff.record(PasswordResetDone(email));
      if (_authService.currentUser != null) {
        await _authService.forceSignOut();
      }
    }
    _stage = PasswordResetStage.done;
    notifyListeners();
  }

  /// "Skicka ny länk": the sign-in screen opens "Glömt lösenord".
  void requestNewLink() =>
      PasswordResetHandoff.record(const PasswordResetRequestNewLink());

  static bool _sameAddress(String? a, String? b) =>
      a != null &&
      b != null &&
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
