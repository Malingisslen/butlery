// The two sign-out wirings live in the DI module, which no unit test builds.
// Without them sign-out leaves the recipe cache on disk and drafts carry no
// owner, with every other test still green, so the module's text is pinned.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final module = File(
    'lib/core/di/modules/core_module.dart',
  ).readAsStringSync();

  test('AuthService is handed the read-cache cleaner', () {
    expect(module, contains('readCacheCleaner:'));
    expect(module, contains('clearUserReadCaches('));
  });

  test('the wipe waits for the user\'s unsent Firestore writes', () {
    expect(module, contains('firestoreWritesSettled:'));
    expect(module, contains('FirestoreCacheWipe.writesSettled('));
    expect(
      module.replaceAll(RegExp(r'\s+'), ''),
      contains(
        'container<FirestoreRepository>().firestore.waitForPendingWrites()'
            .replaceAll(' ', ''),
      ),
    );
  });

  test('drafts take their owner from the signed-in AuthService', () {
    expect(module, contains('AutoSaveManager.defaultOwnerIdProvider ='));
  });
}
