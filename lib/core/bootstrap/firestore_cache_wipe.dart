import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// Empties Firestore's own on-device cache after an explicit sign-out.
///
/// The SDK serves cached documents without asking the rules again, so the
/// next account on the device would otherwise read the previous one's data
/// offline. `clearPersistence` only works before the instance is used, and a
/// `terminate` to get there would leave Firestore unusable until the app is
/// restarted, so sign-out records the request and a later cold start runs it.
///
/// It also deletes writes that were never sent, so a request is only valid
/// until the next sign-in or sign-out decides again, and the start only wipes
/// when nobody is signed in. The flag stays set until a wipe has succeeded.
class FirestoreCacheWipe {
  const FirestoreCacheWipe._();

  static const requestKey = 'butlery_wipe_firestore_cache';

  static Future<void> request() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(requestKey, true);
    } catch (e) {
      AppLogger.warning('FirestoreCacheWipe: could not record request ($e)');
    }
  }

  /// True once every write the signed-in user made has reached the server.
  /// Offline, the wait never ends, so the timeout answers false and the wipe
  /// is not requested.
  static Future<bool> writesSettled(
    Future<void> Function() waitForPendingWrites, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      await waitForPendingWrites().timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reads the first auth event, which is the restored session, so a signed-in
  /// user is not mistaken for nobody while web is still reading it back.
  static Future<bool> nobodyIn(Stream<User?> authEvents) async =>
      (await authEvents.first) == null;

  static Future<void> cancel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(requestKey);
    } catch (e) {
      AppLogger.warning('FirestoreCacheWipe: could not cancel request ($e)');
    }
  }

  static Future<void> runIfRequested(
    FirebaseFirestore db, {
    required Future<bool> Function() noOneSignedIn,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(requestKey) != true) return;
      if (!await noOneSignedIn()) return;
      await db.clearPersistence();
      await prefs.remove(requestKey);
    } catch (e) {
      AppLogger.warning('FirestoreCacheWipe: wipe did not run ($e)');
    }
  }
}
