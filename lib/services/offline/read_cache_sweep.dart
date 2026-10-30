import 'package:butlery/core/storage/drift/app_database.dart'
    if (dart.library.html) 'package:butlery/core/storage/drift/app_database_stub_web.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

/// Drops the cached reads of every account but the signed-in one, at start.
///
/// A sign-out clears its own account's caches, but an automatic logout, a
/// failed clear or an app killed mid-sign-out leaves them behind. Nothing is
/// swept while the signed-in account is unknown (the session may not be
/// restored yet): that would drop the offline reads of a user who is still
/// signed in. The write queue and the recipe copies are other tables and are
/// not touched.
Future<void> sweepReadCaches(
  AppDatabase database,
  AuthRepository auth,
) async {
  final signedInUserId = auth.currentUserId;
  if (signedInUserId == null) return;
  try {
    await database.cacheDao.clearReadCachesExcept(signedInUserId);
  } catch (e) {
    AppLogger.warning('Could not sweep stale read caches: $e');
  }
}
