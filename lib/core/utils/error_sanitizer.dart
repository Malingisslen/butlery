/// Converts a raw exception to a user-friendly Swedish message without BuildContext.
/// Mirrors SnackBarUtils.userFriendlyMessage logic for use in setError() paths.
import 'package:butlery/core/l10n/app_locale.dart';

String sanitizeErrorForUser(dynamic error) {
  final s = error.toString().toLowerCase();
  final locale = AppLocale.current;

  // Network errors
  if (s.contains('socketexception') ||
      s.contains('connection refused') ||
      s.contains('network') ||
      s.contains('no internet') ||
      (s.contains('connection') && s.contains('failed'))) {
    return locale.errorNetwork;
  }
  if (s.contains('timeout') || s.contains('timed out')) {
    return locale.errorTimeout;
  }
  // Authentication
  if (s.contains('unauthenticated') ||
      s.contains('not authenticated') ||
      s.contains('sign in') ||
      (s.contains('auth') && s.contains('expired'))) {
    return locale.errorAuthentication;
  }
  // Permission
  if (s.contains('permission') ||
      s.contains('unauthorized') ||
      s.contains('forbidden') ||
      s.contains('access denied')) {
    return locale.errorPermissionDenied;
  }
  // Not found
  if (s.contains('not found') ||
      s.contains('not exist') ||
      s.contains('no document') ||
      s.contains('404')) {
    return locale.errorNotFound;
  }
  // Server errors
  if (s.contains('internal server') ||
      s.contains('500') ||
      s.contains('503') ||
      s.contains('server error')) {
    return locale.errorServer;
  }
  return locale.errorGeneric;
}
