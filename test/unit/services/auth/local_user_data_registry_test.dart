// Every device draft is cleared by the registry, and none is added behind it.

import 'dart:io';
import 'dart:typed_data';

import 'package:butlery/core/bootstrap/firestore_cache_wipe.dart';
import 'package:butlery/services/auth/local_user_data_registry.dart';
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/services/shopping/week_list_follow_notice.dart';
import 'package:butlery/viewmodels/photo_import/draft_image_store_io.dart'
    as image_store;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object> _everyDraft() {
  final values = <String, Object>{};
  for (final key in LocalUserDataRegistry.autoSavedKeys) {
    values[key] = 'text';
    values[AutoSaveManager.ownerKeyFor(key)] = 'alice';
  }
  final commentKey = LocalUserDataRegistry.commentDraftKey('r1');
  values[commentKey] = 'text';
  values[AutoSaveManager.ownerKeyFor(commentKey)] = 'alice';
  // The notice of what the week menu did to a list names the user's rows.
  values[WeekListFollowNoticeStore.storageKey] = '{}';
  values['unrelated_setting'] = 'keep';
  return values;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(_everyDraft()));

  test('an explicit sign-out clears every draft and owner key', () async {
    await LocalUserDataRegistry.clearDrafts(
      userId: 'alice',
      reason: DeviceCleanupReason.explicitSignOut,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'unrelated_setting'});
  });

  test(
    'an explicit sign-out whose writes were sent asks for the cache wipe',
    () async {
      await LocalUserDataRegistry.clearDrafts(
        userId: 'alice',
        reason: DeviceCleanupReason.explicitSignOut,
        firestoreWritesSettled: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(FirestoreCacheWipe.requestKey), isTrue);
    },
  );

  test('unsent Firestore writes mean no cache wipe is requested', () async {
    await LocalUserDataRegistry.clearDrafts(
      userId: 'alice',
      reason: DeviceCleanupReason.explicitSignOut,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(FirestoreCacheWipe.requestKey), isFalse);
  });

  test(
    'a sign-out that leaves writes unsent withdraws an earlier wipe request',
    () async {
      for (final reason in DeviceCleanupReason.values) {
        SharedPreferences.setMockInitialValues({
          FirestoreCacheWipe.requestKey: true,
        });

        await LocalUserDataRegistry.clearDrafts(
          userId: 'alice',
          reason: reason,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.containsKey(FirestoreCacheWipe.requestKey),
          isFalse,
          reason: '$reason',
        );
      }
    },
  );

  test('an automatic sign-out keeps the drafts (PQ-12 = A)', () async {
    await LocalUserDataRegistry.clearDrafts(
      userId: 'alice',
      reason: DeviceCleanupReason.automaticSignOut,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), _everyDraft().keys.toSet());
    expect(prefs.containsKey(FirestoreCacheWipe.requestKey), isFalse);
  });

  test('an explicit sign-out deletes the staged photo draft file', () async {
    final dir = Directory.systemTemp.createTempSync('draft_img_');
    image_store.debugDraftImageDirOverride = dir;
    addTearDown(() {
      image_store.debugDraftImageDirOverride = null;
      dir.deleteSync(recursive: true);
    });
    final path = await image_store.stageDraftImage(
      Uint8List.fromList([1, 2, 3]),
    );
    expect(File(path!).existsSync(), isTrue);

    await LocalUserDataRegistry.clearDrafts(
      userId: 'alice',
      reason: DeviceCleanupReason.explicitSignOut,
    );
    for (var i = 0; i < 100 && File(path).existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(File(path).existsSync(), isFalse);
  });

  test('no draft key is written outside the registry', () {
    final literal = RegExp(r"'[a-z_]+_draft_v1[a-z_]*'");
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('local_user_data_registry.dart')) continue;
      final hits = literal.allMatches(entity.readAsStringSync());
      if (hits.isNotEmpty) offenders.add(entity.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Take a draft key from LocalUserDataRegistry so a sign-out clears it',
    );
  });
}
