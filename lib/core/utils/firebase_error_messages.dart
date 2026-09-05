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
    if (_networkCodes.contains(error.code)) return l.errorNetwork;
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
      case 'unauthenticated':
        return l.errorPermissionDenied;
    }
  }
  return fallback ?? l.errorGeneric;
}

/// The device could not reach the network at all — a subset of the codes
/// [mapFirebaseErrorMessage] turns into the network message.
///
/// BUT-1922: `closePoll` tells these apart from a block list that could not be
/// read for some other reason, because they need different advice. The split
/// leaves `deadline-exceeded` out on purpose: it is a CLIENT-side timeout and
/// fires on a connected but slow device, so telling that user they are offline
/// would be false.
bool isFirebaseOfflineError(Object error) =>
    error is FirebaseException && _offlineCodes.contains(error.code);

const Set<String> _offlineCodes = {
  'unavailable',
  'network-request-failed',
};

const Set<String> _networkCodes = {
  ..._offlineCodes,
  'deadline-exceeded',
};
