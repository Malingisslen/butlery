import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// User ids whose offline data on this device is owed a purge (BUT-2298).
///
/// Account deletion and "Logga ut och släng ändringarna" both clear the
/// offline database. A failure, or an offline service that never initialised,
/// used to leave the recipe copies, queue rows and queued images behind for
/// good. The id is written here before the clear and removed only after it
/// succeeded, so the next start finishes the job.
///
/// **It holds a uid in plaintext `shared_preferences`.** The same uid already
/// names every row and image folder it purges, on the same device, so this adds
/// no new exposure; it is removed as soon as the purge succeeds, or when that
/// uid signs in again (a live account's data is its own).
///
/// **Deliberately NOT a `BaseService`** — pure local storage, no Firebase.
/// Every method fails soft: a store that cannot be read or written must never
/// stop a deletion or a sign-out.
class OfflinePurgeStore {
  static const String _key = 'offline_purge_owed';

  Future<Set<String>> pending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const <String>[]).toSet();
    } catch (e) {
      AppLogger.error('OfflinePurgeStore: could not read owed purges', e);
      return const {};
    }
  }

  /// Runs [clear] for every owed uid and forgets each one that succeeded; a
  /// failure keeps it for the next start. [signedInUserId] is skipped and
  /// forgotten: its account is live, so what it queued since is work to keep.
  Future<void> purgeOwed(
    Future<void> Function(String userId) clear, {
    String? signedInUserId,
  }) async {
    for (final userId in await pending()) {
      if (userId == signedInUserId) {
        await forget(userId);
        continue;
      }
      try {
        await clear(userId);
        await forget(userId);
      } catch (e) {
        AppLogger.error('OfflinePurgeStore: owed purge failed', e);
      }
    }
  }

  Future<void> record(String userId) =>
      _update((ids) => ids.add(userId), 'record');

  Future<void> forget(String userId) =>
      _update((ids) => ids.remove(userId), 'forget');

  Future<void> _update(void Function(Set<String>) change, String op) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = (prefs.getStringList(_key) ?? const <String>[]).toSet();
      change(ids);
      if (ids.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setStringList(_key, ids.toList());
      }
    } catch (e) {
      AppLogger.error('OfflinePurgeStore: could not $op an owed purge', e);
    }
  }
}
