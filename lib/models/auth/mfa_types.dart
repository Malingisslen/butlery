/// Domain types for MFA that hide firebase_auth from the view layer.
///
/// Views use these types instead of importing firebase_auth directly.
/// AuthService handles conversion between these and Firebase types.

/// Wraps a multi-factor resolver for sign-in challenges.
/// Views treat this as opaque; only AuthService unwraps it.
class MfaResolverInfo {
  final Object _resolver;
  final String? phoneHint;

  const MfaResolverInfo({
    required Object resolver,
    this.phoneHint,
  }) : _resolver = resolver;

  /// Used by AuthService to recover the Firebase resolver.
  T unwrap<T>() => _resolver as T;
}

/// Domain representation of an enrolled MFA factor.
class MfaFactorInfo {
  final Object _factor;
  final String? displayName;
  final double? enrollmentTimestamp;

  const MfaFactorInfo({
    required Object factor,
    this.displayName,
    this.enrollmentTimestamp,
  }) : _factor = factor;

  T unwrap<T>() => _factor as T;
}

/// Lightweight error type for MFA callbacks, replacing FirebaseAuthException in view layer.
class MfaError {
  final String code;
  final String? message;

  const MfaError({required this.code, this.message});
}

/// The number of one-time backup codes a user gets when two-step
/// verification is switched on (produktregler.md:748).
const int mfaBackupCodeCount = 10;

/// How a backup-code recovery ended.
enum MfaRecoveryOutcome {
  /// The phone factor is gone; sign in again with the password.
  recovered,

  /// The password or the code did not match, or the account has no second
  /// factor, or its code lock is on. Deliberately one outcome: the server
  /// gives the same answer for all of them, so it confirms no password.
  rejected,

  /// Too many attempts from this device or network; try again later.
  locked,

  /// The server could not be reached or is not set up.
  unavailable,
}

/// The last two digits of a masked phone hint, for "•• 47"
/// (Skarmar v12 etapp 3 #authmfa). Null when the hint has fewer than two
/// digits. Firebase already masks the number in a resolver's hints; the app
/// never knows the whole number.
String? maskedPhoneTail(String? hint) {
  if (hint == null) return null;
  final digits = hint.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 2) return null;
  return digits.substring(digits.length - 2);
}

/// Why a typed phone number cannot be sent to Firebase.
enum MfaPhoneProblem { countryCode, number, tooLong }

/// A phone number split into country code and national part, ready for
/// E.164. Built only by [parseMfaPhone].
class MfaPhoneNumber {
  const MfaPhoneNumber({required this.countryCode, required this.national});

  /// "+46": a plus sign and one to four digits.
  final String countryCode;

  /// Digits only, without the trunk-prefix zero.
  final String national;

  String get e164 => '$countryCode$national';

  /// "+46 70 123 45 67". The national digits are grouped 2-3-2-2 whatever
  /// the country, which is exact for a Swedish mobile number and merely
  /// readable for others; the point is that the user sees the whole number
  /// before the SMS is sent.
  String get display {
    final groups = <String>[];
    var rest = national;
    for (final size in const [2, 3, 2, 2]) {
      if (rest.isEmpty) break;
      final take = rest.length < size ? rest.length : size;
      groups.add(rest.substring(0, take));
      rest = rest.substring(take);
    }
    if (rest.isNotEmpty) groups.add(rest);
    return [countryCode, ...groups].join(' ');
  }
}

/// Result of [parseMfaPhone]: exactly one of [number] and [problem] is set.
class MfaPhoneParse {
  const MfaPhoneParse.ok(MfaPhoneNumber this.number) : problem = null;
  const MfaPhoneParse.invalid(MfaPhoneProblem this.problem) : number = null;

  final MfaPhoneNumber? number;
  final MfaPhoneProblem? problem;
}

const int _e164MaxDigits = 15;

/// Normalises what the user typed into a country code and a national number.
///
/// Spaces and hyphens are dropped. One leading 0 is removed from the national
/// number (070 123 45 67 becomes +46 70 123 45 67), because Firebase wants
/// the number without the trunk prefix. A national field that itself starts
/// with "+" is a complete number and the country-code field is ignored.
/// Never guesses a country: an unusable country code is a problem, not "+46".
MfaPhoneParse parseMfaPhone({
  required String countryCode,
  required String national,
}) {
  final nationalClean = national.replaceAll(RegExp(r'[\s-]'), '');
  final codeClean = countryCode.replaceAll(RegExp(r'[\s-]'), '');
  var digits = nationalClean;

  if (nationalClean.startsWith('+')) {
    // Three digits at least: a bare "+46" or "+4" is a country code with no
    // number behind it.
    if (!RegExp(r'^\+\d{3,}$').hasMatch(nationalClean)) {
      return const MfaPhoneParse.invalid(MfaPhoneProblem.number);
    }
    if (nationalClean.length - 1 > _e164MaxDigits) {
      return const MfaPhoneParse.invalid(MfaPhoneProblem.tooLong);
    }
    // Only +46 is split for display; for any other country the length of the
    // code is unknown here, and a wrong split would show a wrong number.
    if (nationalClean.startsWith('+46') && nationalClean.length > 3) {
      return MfaPhoneParse.ok(
        MfaPhoneNumber(
          countryCode: '+46',
          national: nationalClean.substring(3),
        ),
      );
    }
    return MfaPhoneParse.ok(
      MfaPhoneNumber(countryCode: nationalClean, national: ''),
    );
  }

  if (!RegExp(r'^\+\d{1,4}$').hasMatch(codeClean)) {
    return const MfaPhoneParse.invalid(MfaPhoneProblem.countryCode);
  }
  if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) {
    return const MfaPhoneParse.invalid(MfaPhoneProblem.number);
  }
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.isEmpty) {
    return const MfaPhoneParse.invalid(MfaPhoneProblem.number);
  }
  if (codeClean.length - 1 + digits.length > _e164MaxDigits) {
    return const MfaPhoneParse.invalid(MfaPhoneProblem.tooLong);
  }
  return MfaPhoneParse.ok(
    MfaPhoneNumber(countryCode: codeClean, national: digits),
  );
}
