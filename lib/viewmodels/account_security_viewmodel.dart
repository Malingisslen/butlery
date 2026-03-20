import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';

class AccountSecurityViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final AuthService _authService = ServiceLocator.get<AuthService>();

  String? get currentEmail => _authService.currentUser?.email;

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    if (newPassword.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    if (confirmPassword.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    if (newPassword.length < FormValidators.minPasswordLength) {
      setError(AppLocale.current.validationPasswordTooShort);
      return false;
    }
    if (newPassword != confirmPassword) {
      setError(AppLocale.current.accountSecurityPasswordMismatch);
      return false;
    }

    clearError();
    setLoading(true);

    // Reauthenticate first
    final reauthed =
        await _authService.reauthenticateWithPassword(currentPassword);
    if (!reauthed) {
      setLoading(false);
      setError(_authService.errorMessage ?? AppLocale.current.errorUnexpected);
      return false;
    }

    final success = await _authService.changePassword(newPassword);
    setLoading(false);

    if (!success) {
      setError(_authService.errorMessage ?? AppLocale.current.errorUnexpected);
    }
    return success;
  }

  Future<bool> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    if (currentPassword.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    final emailError = ValidationUtils.validateEmail(newEmail);
    if (emailError != null) {
      setError(emailError);
      return false;
    }

    clearError();
    setLoading(true);

    // Reauthenticate first
    final reauthed =
        await _authService.reauthenticateWithPassword(currentPassword);
    if (!reauthed) {
      setLoading(false);
      setError(_authService.errorMessage ?? AppLocale.current.errorUnexpected);
      return false;
    }

    final success = await _authService.changeEmail(newEmail);
    setLoading(false);

    if (!success) {
      setError(_authService.errorMessage ?? AppLocale.current.errorUnexpected);
    }
    return success;
  }
}
