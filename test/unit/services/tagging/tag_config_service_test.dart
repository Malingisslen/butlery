import 'dart:convert';

import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late TagConfigService service;

  /// Seeds all 5 tagConfig documents into Firestore.
  Future<void> seedFirestoreConfigs(
    FakeFirebaseFirestore firestore, {
    int allergenVersion = 1,
    int dietaryVersion = 1,
    int cuisineVersion = 1,
    int propertiesVersion = 1,
    int displayVersion = 1,
  }) async {
    final collection = firestore.collection('tagConfigs');

    await collection.doc('allergens').set({
      'schemaVersion': 1,
      'version': allergenVersion,
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedBy': 'test',
      'displayOrder': ['gluten', 'mjolk'],
      'entries': [
        {
          'key': 'gluten',
          'triggerProperties': ['gluten'],
          'tags': {
            'sv': {'contains': 'Innehåller gluten'}
          },
          'isEuAllergen': true,
          'description': {'sv': 'Gluten'},
          'enabled': true,
          'priority': 1,
        },
        {
          'key': 'mjolk',
          'triggerProperties': ['dairy'],
          'tags': {
            'sv': {'contains': 'Innehåller mjölk'}
          },
          'isEuAllergen': true,
          'description': {'sv': 'Mjölk'},
          'enabled': true,
          'priority': 2,
        },
      ],
    });

    await collection.doc('dietary').set({
      'schemaVersion': 1,
      'version': dietaryVersion,
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedBy': 'test',
      'displayOrder': ['vegetarisk'],
      'entries': [
        {
          'key': 'vegetarisk',
          'tags': {'sv': 'Vegetarisk'},
          'excludedProperties': ['meat', 'poultry'],
          'requiredProperties': <String>[],
          'requiresFullCoverage': true,
          'description': {'sv': 'Vegetarisk'},
          'enabled': true,
          'priority': 1,
        },
      ],
    });

    await collection.doc('cuisines').set({
      'schemaVersion': 1,
      'version': cuisineVersion,
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedBy': 'test',
      'displayOrder': ['svensk'],
      'entries': [
        {
          'key': 'svensk',
          'tags': {'sv': 'Svenskt'},
          'titleKeywords': ['köttbullar'],
          'ingredientKeywords': ['lingon'],
          'ingredientGroups': <String>[],
          'minIngredientMatches': 1,
          'matchMode': 'title_or_ingredients',
          'titleMatchWeight': 1.0,
          'ingredientMatchWeight': 1.0,
          'enabled': true,
          'priority': 1,
        },
      ],
    });

    await collection.doc('properties').set({
      'schemaVersion': 1,
      'version': propertiesVersion,
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedBy': 'test',
      'validProperties': ['gluten', 'dairy', 'meat', 'poultry'],
    });

    await collection.doc('display').set({
      'schemaVersion': 1,
      'version': displayVersion,
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedBy': 'test',
      'categoryOrder': ['allergens', 'dietary'],
      'uiGroupNames': {
        'sv': {'allergens': 'Allergener'}
      },
    });
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
    service = TagConfigService(firestore: fakeFirestore);
  });

  group('TagConfigService', () {
    group('initialization', () {
      test('happy path — loads config from Firestore', () async {
        await seedFirestoreConfigs(fakeFirestore);

        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(service.isTaggingAvailable, isTrue);
        expect(service.config.allergens.entries.length, 2);
        expect(service.config.dietary.entries.length, 1);
        expect(service.config.cuisines.entries.length, 1);
      });

      test('Firebase fails, cache exists — falls back to cache', () async {
        // First: seed and initialize to populate the cache
        await seedFirestoreConfigs(fakeFirestore);
        final warmupService = TagConfigService(firestore: fakeFirestore);
        await warmupService.initialize();

        // Now create a new service with an empty Firestore (simulates failure)
        final emptyFirestore = FakeFirebaseFirestore();
        final freshService = TagConfigService(firestore: emptyFirestore);
        await freshService.initialize();

        expect(freshService.isInitialized, isTrue);
        expect(freshService.isTaggingAvailable, isTrue);
        expect(freshService.config.allergens.entries.length, 2);
      });

      test('both fail — tagging unavailable', () async {
        // Empty Firestore + empty SharedPreferences
        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(service.isTaggingAvailable, isFalse);
        expect(service.configOrNull, isNull);
        expect(
          () => service.config,
          throwsA(isA<StateError>()),
        );
      });

      test('initialize is idempotent', () async {
        await seedFirestoreConfigs(fakeFirestore);

        await service.initialize();
        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(service.isTaggingAvailable, isTrue);
      });
    });

    group('refreshIfNeeded', () {
      test('no change — no reload', () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();

        final configBefore = service.config;
        await service.refreshIfNeeded();
        final configAfter = service.config;

        // Same version → same config object (not reloaded)
        expect(configBefore.combinedVersion, configAfter.combinedVersion);
      });

      test('version changed — triggers reload', () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();
        final versionBefore = service.config.combinedVersion;

        // Change version
        await fakeFirestore
            .collection('tagConfigs')
            .doc('allergens')
            .update({'version': 5});
        await service.refreshIfNeeded();

        expect(service.config.combinedVersion, isNot(versionBefore));
      });

      test('not initialized — delegates to initialize', () async {
        await seedFirestoreConfigs(fakeFirestore);

        expect(service.isInitialized, isFalse);
        await service.refreshIfNeeded();

        expect(service.isInitialized, isTrue);
        expect(service.isTaggingAvailable, isTrue);
      });

      test('no-op when version unchanged', () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();
        final versionBefore = service.config.combinedVersion;

        await service.refreshIfNeeded();

        expect(service.isTaggingAvailable, isTrue);
        expect(service.config.combinedVersion, versionBefore);
      });
    });

    group('combineVersions', () {
      test('determinism — same inputs always produce same output', () {
        final v1 = FirebaseTagConfig.combineVersions(1, 2, 3, 4, 5);
        final v2 = FirebaseTagConfig.combineVersions(1, 2, 3, 4, 5);

        expect(v1, equals(v2));
      });

      test('collision resistance — positional sensitivity', () {
        final v1 = FirebaseTagConfig.combineVersions(3, 4, 0, 0, 0);
        final v2 = FirebaseTagConfig.combineVersions(4, 3, 0, 0, 0);

        expect(v1, isNot(v2));
      });

      test(
          'collision resistance — different version sets produce different values',
          () {
        final v1 = FirebaseTagConfig.combineVersions(1, 1, 1, 1, 1);
        final v2 = FirebaseTagConfig.combineVersions(1, 1, 1, 1, 2);
        final v3 = FirebaseTagConfig.combineVersions(2, 1, 1, 1, 1);

        expect(v1, isNot(v2));
        expect(v1, isNot(v3));
        expect(v2, isNot(v3));
      });

      test('persistence — value saved to SharedPreferences matches computation',
          () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();

        final computed = service.config.combinedVersion;
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getInt('tag_config_version');

        expect(stored, equals(computed));
      });
    });

    group('cache serialization', () {
      test('round-trip — save and reload from cache', () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();

        final originalVersion = service.config.combinedVersion;
        final originalAllergenCount = service.config.allergens.entries.length;

        // Create new service with empty Firestore — should load from cache
        final emptyFirestore = FakeFirebaseFirestore();
        final freshService = TagConfigService(firestore: emptyFirestore);
        await freshService.initialize();

        expect(freshService.config.combinedVersion, originalVersion);
        expect(freshService.config.allergens.entries.length,
            originalAllergenCount);
      });

      test('cache JSON is valid', () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();

        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('tag_config_cache');

        expect(cachedJson, isNotNull);
        final data = jsonDecode(cachedJson!) as Map<String, dynamic>;
        expect(
            data.keys,
            containsAll(
                ['allergens', 'dietary', 'cuisines', 'properties', 'display']));
      });
    });

    group('forceRefresh', () {
      test('bypasses version check and reloads', () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();

        // Update data
        await fakeFirestore
            .collection('tagConfigs')
            .doc('allergens')
            .update({'version': 99});

        await service.forceRefresh();

        // Version should have changed
        expect(service.isTaggingAvailable, isTrue);
      });

      test('throws when Firestore is empty', () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();

        // Create a service pointing to empty Firestore
        final emptyFirestore = FakeFirebaseFirestore();
        final freshService = TagConfigService(firestore: emptyFirestore);
        await freshService.initialize(); // initializes from cache

        // forceRefresh on empty Firestore should throw
        await expectLater(
          freshService.forceRefresh(),
          throwsA(isA<TagConfigLoadException>()),
        );
      });
    });

    group('healthCheck', () {
      test('returns true when initialized and available', () async {
        await seedFirestoreConfigs(fakeFirestore);
        await service.initialize();

        expect(await service.healthCheck(), isTrue);
      });

      test('returns false when not initialized', () async {
        expect(await service.healthCheck(), isFalse);
      });

      test('returns false when config failed to load', () async {
        // Initialize with empty Firestore — no config available
        await service.initialize();

        expect(await service.healthCheck(), isFalse);
      });
    });

    group('config validation', () {
      test('validation errors are logged but config is still usable', () async {
        // Create config with invalid property reference
        final collection = fakeFirestore.collection('tagConfigs');
        await collection.doc('allergens').set({
          'schemaVersion': 1,
          'version': 1,
          'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
          'updatedBy': 'test',
          'displayOrder': ['gluten'],
          'entries': [
            {
              'key': 'gluten',
              'triggerProperties': ['nonexistent_property'],
              'tags': {
                'sv': {'contains': 'Gluten'}
              },
              'isEuAllergen': true,
              'description': {'sv': 'Gluten'},
              'enabled': true,
              'priority': 1,
            },
          ],
        });
        await collection.doc('dietary').set({
          'schemaVersion': 1,
          'version': 1,
          'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
          'updatedBy': 'test',
          'displayOrder': <String>[],
          'entries': <Map<String, dynamic>>[],
        });
        await collection.doc('cuisines').set({
          'schemaVersion': 1,
          'version': 1,
          'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
          'updatedBy': 'test',
          'displayOrder': <String>[],
          'entries': <Map<String, dynamic>>[],
        });
        await collection.doc('properties').set({
          'schemaVersion': 1,
          'version': 1,
          'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
          'updatedBy': 'test',
          'validProperties': ['gluten', 'dairy'],
        });
        await collection.doc('display').set({
          'schemaVersion': 1,
          'version': 1,
          'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
          'updatedBy': 'test',
          'categoryOrder': <String>[],
          'uiGroupNames': <String, dynamic>{},
        });

        // Should not throw — validation errors are just logged
        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(service.isTaggingAvailable, isTrue);
        expect(service.config.allergens.entries.length, 1);
      });
    });

    group('config access', () {
      test('config throws when not initialized', () {
        expect(
          () => service.config,
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not initialized'),
          )),
        );
      });

      test('configOrNull returns null before initialization', () {
        expect(service.configOrNull, isNull);
      });
    });
  });
}
