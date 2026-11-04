import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/models/auth/provider_sign_in_types.dart';

/// BUT-2502: Firebase can report a first sign-in as failed after the server
/// already made the account and signed it in. Only a sign-in that left the
/// device signed in through [provider], where nobody was signed in before,
/// counts as having gone through.
bool signedInDespiteFailure(
  User? user,
  SignInProvider provider, {
  required bool signedInBefore,
}) =>
    !signedInBefore &&
    user != null &&
    user.providerData.any((info) => info.providerId == provider.providerId);

/// Whether [user]'s account was made by the sign-in that just happened: the
/// result that would have said so was lost with the error.
bool accountJustCreated(User user) {
  final created = user.metadata.creationTime;
  final lastSignIn = user.metadata.lastSignInTime;
  return created != null &&
      lastSignIn != null &&
      lastSignIn.difference(created).abs() < const Duration(minutes: 1);
}
