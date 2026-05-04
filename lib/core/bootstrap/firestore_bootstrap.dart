/// Firestore bootstrap helper for `main.dart` (BUT-506).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/logger.dart';

const _bootstrapSettings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
);

class FirestoreBootstrap {
  static Future<void> configure({FirebaseFirestore? firestore}) async {
    final db = firestore ?? FirebaseFirestore.instance;
    try {
      db.settings = _bootstrapSettings;

      if (kIsWeb) {
        await _recoverWebPersistenceIfCorrupted(db);
      }
    } catch (_) {
      // Settings already applied — happens on hot restart.
    }
  }

  // Firestore JS SDK 12.x can leave IndexedDB in a stuck state after an
  // unclean shutdown ("INTERNAL ASSERTION FAILED"). Probe a known doc;
  // on a structural failure, recover via terminate + clearPersistence.
  static Future<void> _recoverWebPersistenceIfCorrupted(
    FirebaseFirestore db,
  ) async {
    try {
      await db
          .collection('_health')
          .doc('_')
          .get()
          .timeout(const Duration(seconds: 5));
    } on FirebaseException catch (e) {
      // Structured filter first; substring check is a fallback because
      // the JS SDK sometimes surfaces these as plain Errors with the
      // message embedded in toString(), not as FirebaseException.
      final isStructuralFailure = e.code == 'internal' || e.code == 'unknown';
      if (isStructuralFailure) {
        await _clearAndRetry(db);
      }
      // permission-denied on non-existent doc is expected — ignore.
    } catch (healthError) {
      final msg = healthError.toString();
      if (msg.contains('INTERNAL ASSERTION') ||
          msg.contains('Unexpected state')) {
        await _clearAndRetry(db);
      }
    }
  }

  static Future<void> _clearAndRetry(FirebaseFirestore db) async {
    AppLogger.warning(
      'Firestore web persistence corrupted — clearing IndexedDB',
    );
    await db.terminate();
    await db.clearPersistence();
    db.settings = _bootstrapSettings;
  }
}
