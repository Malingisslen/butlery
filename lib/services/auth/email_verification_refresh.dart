import 'package:butlery/services/auth_service.dart';

/// BUT-2305: Firebase keeps `emailVerified` from sign-in until the user is
/// reloaded, so someone who taps the link in their mail and comes back
/// stayed blocked from friends and chat until they logged out. Runs on every
/// resume; only an unverified user costs the extra call.
Future<void> refreshEmailVerification(AuthService? auth) async {
  final user = auth?.currentUser;
  if (user == null || user.emailVerified) return;
  await auth!.reloadUser();
  // The rules read `email_verified` from the ID token, which a reload leaves
  // as it was at sign-in; without a fresh token the app would let the user
  // try and the server would still refuse.
  if (auth.currentUser?.emailVerified ?? false) await auth.refreshSession();
}
