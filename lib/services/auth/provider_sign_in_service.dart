import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth/provider_sign_in_platform.dart';

/// How one attempt with a provider ended, before AuthService runs the
/// signed-in sequence.
class ProviderAttempt {
  const ProviderAttempt._(
    this.outcome, {
    this.mfa,
    this.isNewUser = false,
    this.error,
  });

  const ProviderAttempt.signedIn({bool isNewUser = false})
    : this._(ProviderSignInOutcome.signedIn, isNewUser: isNewUser);
  const ProviderAttempt.mfaRequired(MfaResolverInfo mfa)
    : this._(ProviderSignInOutcome.mfaRequired, mfa: mfa);
  const ProviderAttempt.linkNeedsPassword()
    : this._(ProviderSignInOutcome.linkNeedsPassword);
  const ProviderAttempt.cancelled() : this._(ProviderSignInOutcome.cancelled);
  const ProviderAttempt.failed([FirebaseAuthException? error])
    : this._(ProviderSignInOutcome.failed, error: error);

  final ProviderSignInOutcome outcome;
  final MfaResolverInfo? mfa;
  final bool isNewUser;

  /// Firebase's error, when there was one, for the user-facing message.
  final FirebaseAuthException? error;
}

class _PendingLink {
  _PendingLink(this.email, this.provider, this.credential);

  final String email;
  final SignInProvider provider;
  final AuthCredential credential;
}

/// Google and Apple sign-in behind AuthService (BUT-916, BUT-549).
///
/// Not a `BaseService`: it runs signed out, which `executeServiceOperation`'s
/// auth pre-flight refuses, the same reason `PasswordResetService` gives.
///
/// Everything it keeps lives in memory and is dropped at sign-out: the
/// credential waiting to be linked to a password account, the Google id
/// token a backup code is proved with, and Apple's one-time code that
/// revokes the app's Apple tokens when the account is deleted.
class ProviderSignInService {
  ProviderSignInService({
    required AuthRepository authRepository,
    required ProviderSignInPlatform platform,
  }) : _repo = authRepository,
       _platform = platform;

  final AuthRepository _repo;
  final ProviderSignInPlatform _platform;

  _PendingLink? _pendingLink;
  ProviderTokens? _googleTokens;
  String? _appleAuthorizationCode;
  String? _givenName;
  bool _createdHere = false;
  SignInProvider? _linkFailed;

  /// Whether this process's own sign-in created the account. The terms step
  /// met any other way was left unanswered before (C3) and says so.
  bool get accountCreatedHere => _createdHere;

  /// Codes Firebase uses when the user closes the provider's own sheet.
  static const Set<String> _cancelCodes = {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-canceled',
    'web-context-cancelled',
    'canceled',
    'user-cancelled',
  };

  bool isOffered(SignInProvider provider) =>
      _platform.flowFor(provider) != ProviderFlow.unavailable;

  PendingProviderLink? get pendingLink {
    final pending = _pendingLink;
    if (pending == null) return null;
    return PendingProviderLink(
      email: pending.email,
      provider: pending.provider,
    );
  }

  void clearPendingLink() => _pendingLink = null;

  /// The provider whose waiting credential could not be linked after the
  /// sign-in, once: reading it clears it, so the notice is shown once.
  SignInProvider? takeFailedLink() {
    final failed = _linkFailed;
    _linkFailed = null;
    return failed;
  }

  /// The provider tokens are only needed while a sign-in waits at its
  /// second factor (a backup code is proved with them); a finished sign-in
  /// drops them.
  void dropSignInTokens() {
    _googleTokens = null;
    _appleAuthorizationCode = null;
  }

  /// The first name the terms step starts from: what Apple shared on its one
  /// sheet that carries it, else the first word of the account's name.
  String? get firstName {
    final given = _givenName?.trim();
    if (given != null && given.isNotEmpty) return given;
    final name = _repo.currentUser?.displayName;
    final first = name.orEmpty().trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? null : first;
  }

  Future<ProviderAttempt> signIn(SignInProvider provider) async {
    _pendingLink = null;
    if (provider == SignInProvider.google) _googleTokens = null;
    ProviderTokens? tokens;
    try {
      final UserCredential credential;
      switch (_platform.flowFor(provider)) {
        case ProviderFlow.unavailable:
          return const ProviderAttempt.failed();
        case ProviderFlow.native:
          tokens = await _platform.obtainTokens(provider);
          if (tokens == null) return const ProviderAttempt.cancelled();
          _keep(tokens);
          credential = await _repo.signInWithProviderTokens(tokens);
        case ProviderFlow.firebase:
          credential = await _repo.signInWithProviderFlow(provider);
      }
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
      _createdHere = isNewUser;
      dropSignInTokens();
      return ProviderAttempt.signedIn(isNewUser: isNewUser);
    } on FirebaseAuthMultiFactorException catch (e) {
      return ProviderAttempt.mfaRequired(MfaResolverInfo(resolver: e.resolver));
    } on FirebaseAuthException catch (e) {
      if (_cancelCodes.contains(e.code)) {
        return const ProviderAttempt.cancelled();
      }
      if (e.code == 'account-exists-with-different-credential' &&
          _holdForLink(e, provider, tokens)) {
        return const ProviderAttempt.linkNeedsPassword();
      }
      AppLogger.warning('Provider sign-in refused: ${e.code}');
      return ProviderAttempt.failed(e);
    } on ProviderSheetException catch (e) {
      AppLogger.warning('Provider sheet failed: ${e.reason}');
      return const ProviderAttempt.failed();
    } catch (e) {
      AppLogger.warning('Provider sign-in failed: ${e.runtimeType}');
      return const ProviderAttempt.failed();
    }
  }

  void _keep(ProviderTokens tokens) {
    if (tokens.provider == SignInProvider.google) _googleTokens = tokens;
    final code = tokens.authorizationCode;
    if (code != null) _appleAuthorizationCode = code;
    if (tokens.givenName != null) _givenName = tokens.givenName;
  }

  /// Keeps the provider's credential for the password account at its
  /// address (C4), but only when the provider's own token says the address
  /// is that person's and is verified. Otherwise anyone who can make a
  /// provider account with somebody's address could reach theirs.
  bool _holdForLink(
    FirebaseAuthException e,
    SignInProvider provider,
    ProviderTokens? tokens,
  ) {
    final email = e.email?.trim().toLowerCase();
    final credential = tokens != null
        ? _repo.providerCredential(tokens)
        : e.credential;
    final idToken =
        tokens?.idToken ??
        (credential is OAuthCredential ? credential.idToken : null);
    if (email == null || credential == null || idToken == null) return false;
    if (!assertsVerifiedEmail(idToken, email)) return false;
    _pendingLink = _PendingLink(email, provider, credential);
    return true;
  }

  /// Whether the JWT [idToken] carries [email] with `email_verified` true.
  /// Read for a decision on this device only: Firebase verifies the token's
  /// signature when the credential is linked.
  static bool assertsVerifiedEmail(String idToken, String email) {
    final parts = idToken.split('.');
    if (parts.length != 3) return false;
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map) return false;
      final verified = claims['email_verified'];
      final claimed = claims['email'];
      return (verified == true || verified == 'true') &&
          claimed is String &&
          claimed.trim().toLowerCase() == email.trim().toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// Links the waiting credential once the account it is bound to is the
  /// signed-in one: after the password, and after the second factor or a
  /// backup code when the account has one. Never throws. True when linked.
  Future<bool> linkPendingIfSignedIn() async {
    final pending = _pendingLink;
    if (pending == null) return false;
    final email = _repo.currentUser?.email?.trim().toLowerCase();
    if (email == null) return false;
    _pendingLink = null;
    if (email != pending.email) {
      AppLogger.info('Pending provider link dropped: another account');
      _linkFailed = pending.provider;
      return false;
    }
    try {
      await _repo.linkCredential(pending.credential);
      AppLogger.info('Linked ${pending.provider.providerId} to the account');
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Provider link failed: ${e.code}');
    } catch (e) {
      AppLogger.warning('Provider link failed: ${e.runtimeType}');
    }
    _linkFailed = pending.provider;
    return false;
  }

  /// Whether a backup code can be proved through [provider] on this device.
  /// Where Firebase runs the sheet itself the app never sees a token, so the
  /// sign-in screen offers the support route instead (C8 spike).
  bool canProveForRecovery(SignInProvider provider) {
    if (_platform.flowFor(provider) != ProviderFlow.native) return false;
    return provider == SignInProvider.apple || _googleTokens != null;
  }

  /// The proof for a backup code. Google's token from the sign-in that
  /// stopped at the second factor; for Apple a fresh sheet with a new
  /// nonce, since a replayed Apple token may be refused. Null when the
  /// user closed the sheet or there is nothing to prove with.
  Future<MfaProviderProof?> recoveryProof(SignInProvider provider) async {
    if (!canProveForRecovery(provider)) return null;
    if (provider == SignInProvider.google) {
      final tokens = _googleTokens!;
      return MfaProviderProof(
        providerId: provider.providerId,
        idToken: tokens.idToken,
      );
    }
    try {
      final fresh = await _platform.obtainTokens(provider);
      if (fresh == null) return null;
      _keep(fresh);
      return MfaProviderProof(
        providerId: provider.providerId,
        idToken: fresh.idToken,
        nonce: fresh.rawNonce,
      );
    } catch (e) {
      AppLogger.warning(
        'Apple sheet for a backup code failed: ${e.runtimeType}',
      );
      return null;
    }
  }

  /// Whether the signed-in account has a password. Provider data that is
  /// not there to read counts as a password account, the app's old default.
  bool get hasPasswordSignIn {
    final ids = _repo.providerIds;
    return ids.isEmpty || ids.contains('password');
  }

  /// The provider the one re-authentication entry point asks for, or null
  /// for the password. Before a deletion Apple comes first where its sheet
  /// gives the one-time code that revokes the app's Apple tokens.
  SignInProvider? reauthenticationProvider({bool forDeletion = false}) {
    final ids = _repo.providerIds;
    final appleNative =
        _platform.flowFor(SignInProvider.apple) == ProviderFlow.native;
    if (forDeletion && appleNative && ids.contains('apple.com')) {
      return SignInProvider.apple;
    }
    if (ids.contains('password')) return null;
    for (final provider in SignInProvider.values) {
      if (ids.contains(provider.providerId) && isOffered(provider)) {
        return provider;
      }
    }
    return null;
  }

  /// Re-authenticates through [provider]'s sheet, which refreshes the
  /// token's `auth_time`. A second factor on the account comes back as
  /// [ProviderSignInOutcome.mfaRequired].
  Future<ProviderAttempt> reauthenticate(SignInProvider provider) async {
    try {
      switch (_platform.flowFor(provider)) {
        case ProviderFlow.unavailable:
          return const ProviderAttempt.failed();
        case ProviderFlow.native:
          final tokens = await _platform.obtainTokens(provider);
          if (tokens == null) return const ProviderAttempt.cancelled();
          _keep(tokens);
          try {
            await _repo.reauthenticateWithProviderTokens(tokens);
          } finally {
            // Apple's code stays for the deletion that may follow.
            _googleTokens = null;
          }
        case ProviderFlow.firebase:
          await _repo.reauthenticateWithProviderFlow(provider);
      }
      return const ProviderAttempt.signedIn();
    } on FirebaseAuthMultiFactorException catch (e) {
      return ProviderAttempt.mfaRequired(MfaResolverInfo(resolver: e.resolver));
    } on FirebaseAuthException catch (e) {
      if (_cancelCodes.contains(e.code)) {
        return const ProviderAttempt.cancelled();
      }
      AppLogger.warning('Provider re-authentication refused: ${e.code}');
      return ProviderAttempt.failed(e);
    } catch (e) {
      AppLogger.warning('Provider re-authentication failed: ${e.runtimeType}');
      return const ProviderAttempt.failed();
    }
  }

  /// Revokes the app's Apple tokens before a deletion is scheduled (C10).
  /// A failure is logged and never blocks the deletion; the code is never
  /// logged. Where Firebase ran Apple's sheet there is no code, and the log
  /// says the revocation was not done.
  Future<void> revokeAppleIfLinked() async {
    if (!_repo.providerIds.contains('apple.com')) return;
    final code = _appleAuthorizationCode;
    _appleAuthorizationCode = null;
    if (code == null) {
      AppLogger.warning('Apple tokens not revoked: no authorization code here');
      return;
    }
    try {
      await _repo.revokeAppleToken(code);
      AppLogger.info('Apple tokens revoked before the deletion');
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Apple token revocation failed: ${e.code}');
    } catch (e) {
      AppLogger.warning('Apple token revocation failed: ${e.runtimeType}');
    }
  }

  static const Set<String> _methodIds = {
    'password',
    'google.com',
    'apple.com',
  };

  /// The ways the signed-in account can sign in with. Provider data that is
  /// not there to read counts as one password method, the app's old default.
  Set<String> get signInMethods {
    final ids = _repo.providerIds.toSet().intersection(_methodIds);
    return ids.isEmpty ? {'password'} : ids;
  }

  bool isLinked(SignInProvider provider) =>
      signInMethods.contains(provider.providerId);

  /// The address a linked provider holds, which may be Apple's relay.
  String? providerEmail(SignInProvider provider) =>
      _repo.providerEmail(provider.providerId);

  /// Whether one method can go without leaving the account unable to sign
  /// in.
  bool get canUnlinkAny => signInMethods.length > 1;

  /// Whether Apple's tokens can be revoked on this device: only its own
  /// sheet gives the one-time code that takes.
  bool get revokesApple =>
      _platform.flowFor(SignInProvider.apple) == ProviderFlow.native;

  /// Adds [provider] to the signed-in account. The provider's address need
  /// not match the account's: the account is the one that is signed in.
  Future<ProviderAttempt> linkProvider(SignInProvider provider) async {
    try {
      switch (_platform.flowFor(provider)) {
        case ProviderFlow.unavailable:
          return const ProviderAttempt.failed();
        case ProviderFlow.native:
          final tokens = await _platform.obtainTokens(provider);
          if (tokens == null) return const ProviderAttempt.cancelled();
          _keep(tokens);
          try {
            await _repo.linkCredential(_repo.providerCredential(tokens));
          } finally {
            _googleTokens = null;
            _appleAuthorizationCode = null;
          }
        case ProviderFlow.firebase:
          await _repo.linkWithProviderFlow(provider);
      }
      return const ProviderAttempt.signedIn();
    } on FirebaseAuthException catch (e) {
      if (_cancelCodes.contains(e.code)) {
        return const ProviderAttempt.cancelled();
      }
      AppLogger.warning('Provider link refused: ${e.code}');
      return ProviderAttempt.failed(e);
    } catch (e) {
      AppLogger.warning('Provider link failed: ${e.runtimeType}');
      return const ProviderAttempt.failed();
    }
  }

  /// Removes [provider] from the account. For Apple the app's Apple tokens
  /// are revoked first, which needs the one-time code of a fresh Apple sheet
  /// (`reauthenticate`); without a code the revocation is logged as not done
  /// and the method still goes. Throws when Firebase refuses the unlink.
  Future<void> unlinkProvider(SignInProvider provider) async {
    await _repo.reloadCurrentUser();
    if (!canUnlinkAny) throw StateError('The last sign-in method stays');
    if (provider == SignInProvider.apple) await revokeAppleIfLinked();
    await _repo.unlinkProvider(provider.providerId);
    AppLogger.info('Unlinked ${provider.providerId} from the account');
  }

  /// Adds e-mail and password to an account made with Google or Apple, on
  /// the address the account already has (an Apple relay address works).
  Future<void> addPassword(String password) async {
    final email = _repo.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw StateError('The account has no address to set a password on');
    }
    await _repo.linkEmailPassword(email, password);
  }

  /// Drops everything held for the session and signs the Google SDK out.
  Future<void> signOut() async {
    _pendingLink = null;
    _googleTokens = null;
    _appleAuthorizationCode = null;
    _givenName = null;
    _createdHere = false;
    _linkFailed = null;
    await _platform.signOutGoogle();
  }
}
