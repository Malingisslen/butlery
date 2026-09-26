// lib/services/auth/sign_out_guard.dart
//
// Flow 08 (P6-U08a): signing out with unsaved changes in the offline queue.
// "Utloggning med kö — Blockeras med förklaring: ”N ändringar har inte
// sparats.” Alternativ: Vänta på synk · Logga ut och släng. Aldrig tyst kast."
// (produktregler.md:193). The same confirmation follows "Logga ut nu" in the
// session-timeout warning (produktregler.md:832, § 16.2).

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:flutter/foundation.dart';

/// The user's changes that have not reached the server, by what they concern.
///
/// The drawing names what the changes are about, not only how many there
/// are ("Antalet och vad det rör står i klartext", Skarmar v12 del 4
/// #utloggningko). The queues carry two kinds today: recipe writes in the
/// sync queue and image uploads in the upload queue.
@immutable
class PendingChanges {
  const PendingChanges({
    required this.recipeChanges,
    required this.imageUploads,
  });

  /// Nothing waits.
  static const PendingChanges none = PendingChanges(
    recipeChanges: 0,
    imageUploads: 0,
  );

  /// Recipe writes in the sync queue, permanent failures included.
  final int recipeChanges;

  /// Images waiting in the upload queue, permanent failures included.
  final int imageUploads;

  /// Every change that has not reached the server.
  int get total => recipeChanges + imageUploads;

  bool get isEmpty => total == 0;

  @override
  bool operator ==(Object other) =>
      other is PendingChanges &&
      other.recipeChanges == recipeChanges &&
      other.imageUploads == imageUploads;

  @override
  int get hashCode => Object.hash(recipeChanges, imageUploads);

  @override
  String toString() =>
      'PendingChanges(recipes: $recipeChanges, images: $imageUploads)';
}

/// Reads and discards a user's queued changes.
abstract class PendingChangesSource {
  Future<PendingChanges> read(String userId);

  /// Throws the user's queued changes away. Only ever called after she chose
  /// "Logga ut och släng ändringarna".
  Future<void> discard(String userId);
}

/// Reads the offline database through the existing queue DAOs (schema 3,
/// P5-U35). The count is the one the queue view and the offline banner use,
/// `AppDatabase.watchQueueCounts` (app_database.dart), so the three surfaces
/// cannot disagree about the number.
class OfflinePendingChangesSource implements PendingChangesSource {
  const OfflinePendingChangesSource();

  OfflineService? _offline() {
    try {
      if (!ServiceLocator.isRegistered<OfflineService>()) return null;
      final service = ServiceLocator.get<OfflineService>();
      return service.isInitialized ? service : null;
    } catch (e) {
      AppLogger.warning('SignOutGuard: offline service unavailable: $e');
      return null;
    }
  }

  @override
  Future<PendingChanges> read(String userId) async {
    final offline = _offline();
    if (offline == null) return PendingChanges.none;
    final db = offline.database;
    final counts = await db.watchQueueCounts(userId).first;
    final draining = await db.syncQueueDao.countPending(userId);
    final failed = await db.syncQueueDao
        .watchPermanentFailureCount(userId)
        .first;
    final recipes = draining + failed;
    final images = counts.waiting - recipes;
    return PendingChanges(
      recipeChanges: recipes,
      imageUploads: images < 0 ? 0 : images,
    );
  }

  @override
  Future<void> discard(String userId) async {
    final offline = _offline();
    if (offline == null) return;
    // Both queues and the device copies they point at go together: a queue
    // entry without its recipe row, or the reverse, is a half-thrown change.
    // `AppDatabase.clearUserData` covers the upload queue too, which
    // `OfflineService.clearUserData` does not.
    await offline.database.clearUserData(userId);
    await offline.refreshSyncState();
  }
}

/// The one choke point every user-initiated sign-out asks first
/// (Q-P6-E16). An automatic sign-out never asks and never clears the queue
/// (produktregler.md:833).
class SignOutGuard {
  SignOutGuard({
    required AuthService authService,
    PendingChangesSource source = const OfflinePendingChangesSource(),
  }) : _authService = authService,
       _source = source;

  final AuthService _authService;
  final PendingChangesSource _source;

  /// What the signed-in user would lose by signing out and discarding.
  ///
  /// Fails open to [PendingChanges.none]: a sign-out never clears the queue
  /// by itself, so a count that cannot be read loses nothing. The entries
  /// stay on the device and sync at this user's next sign-in.
  Future<PendingChanges> pendingForCurrentUser() async {
    final userId = _authService.currentUserId;
    if (userId == null) return PendingChanges.none;
    try {
      return await _source.read(userId);
    } catch (e) {
      AppLogger.warning('SignOutGuard: could not read the queue: $e');
      return PendingChanges.none;
    }
  }

  /// Throws the signed-in user's queued changes away. Call only after the
  /// user chose to.
  Future<void> discardForCurrentUser() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;
    await _source.discard(userId);
    AppLogger.info('SignOutGuard: queued changes discarded by the user');
  }
}
