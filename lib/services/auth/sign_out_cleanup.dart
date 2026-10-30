import 'package:butlery/core/utils/logger.dart';

/// Removes one account's cached reads from the device. Handed to
/// `AuthService` by the DI module, which can reach the offline database.
typedef ReadCacheCleaner = Future<void> Function(String userId);

/// The cached reads a sign-out removes from the device. Called before the
/// user scope is popped, while the offline service still exists. Drafts are
/// not here: they go only once the sign-out has succeeded, through
/// `LocalUserDataRegistry.clearDrafts`.
///
/// Never touches the offline write queue or the recipe copies: that is
/// `SignOutGuard`'s to discard, and only after the user chose to.
/// Best-effort: nothing here throws, so a sign-out cannot fail on it.
class SignOutCleanup {
  const SignOutCleanup._();

  static Future<void> clearReadCaches(
    ReadCacheCleaner? cleaner,
    String? userId,
  ) async {
    if (cleaner == null || userId == null) return;
    try {
      await cleaner(userId);
    } catch (e) {
      // The next start drops the caches of every account but the signed-in one.
      AppLogger.warning('SignOutCleanup: could not clear read caches ($e)');
    }
  }
}
