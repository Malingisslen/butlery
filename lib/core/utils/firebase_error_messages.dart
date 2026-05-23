/// Friendly user-facing copy for Firebase errors.
///
/// BUT-968: callers were surfacing raw `FirebaseException.toString()` to the
/// user, e.g. "Failed to add recipe: [cloud_firestore/permission-denied] ...".
/// This helper maps the codes we actually see in production to localized
/// strings, with a generic fallback that doesn't expose the raw exception.
///
/// Apply at every catch block where the message goes to the UI. The
/// `firebase_service_mixin.dart::FirebaseErrorType` enum already classifies
/// these for retry/logging — this helper sits on top of that for the
/// user-message side.

import 'package:firebase_core/firebase_core.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Returns a localized, user-facing message for an exception caught at a
/// repository/service boundary. Pass [fallback] for an operation-specific
/// fallback (e.g. "Couldn't save recipe."); when omitted, falls back to
/// the global generic message.
///
/// Recognized codes (cloud_firestore, firebase_storage, firebase_auth):
/// - `permission-denied`, `unauthenticated`, `unauthorized` →
///   [AppLocale.current.errorPermissionDenied]
/// - `unavailable`, `deadline-exceeded`, `network-request-failed` →
///   [AppLocale.current.errorNetwork]
String mapFirebaseErrorMessage(Object error, {String? fallback}) {
  final l = AppLocale.current;
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
      case 'unauthenticated':
        return l.errorPermissionDenied;
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return l.errorNetwork;
    }
  }
  return fallback ?? l.errorGeneric;
}
