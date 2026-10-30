/// BUG-31: codes that genuinely mean the credential is gone/revoked and the
/// session MUST end. Everything else (empty code, transient/network errors)
/// is treated as recoverable so a one-off stream error doesn't sign the user
/// out mid-session. Keeps real session-revocation security intact.
const Set<String> fatalAuthStreamCodes = {
  'user-disabled',
  'user-token-expired',
  'user-not-found',
  'invalid-user-token',
  'token-expired',
};

bool isFatalAuthStreamError(String code) => fatalAuthStreamCodes.contains(code);
