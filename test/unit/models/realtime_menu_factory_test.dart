// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/realtime_menu_factory.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RealtimeMenuFactory', () {
    late Recipe testRecipe1;
    late Recipe testRecipe2;
    late Map<String, List<Recipe>> testMenuSnapshot;

    setUp(() {
      testRecipe1 = RecipeFactory.build(id: 'recipe_1', title: 'Köttbullar');
      testRecipe2 = RecipeFactory.build(id: 'recipe_2', title: 'Pannkakor');

      testMenuSnapshot = <String, List<Recipe>>{
        'Måndag': [testRecipe1],
        'Tisdag': [testRecipe2],
        'Onsdag': <Recipe>[],
      };
    });

    group('createFromMenuCategories', () {
      test('should create new menu with required parameters', () {
        final result = RealtimeMenuFactory.createFromMenuCategories(
          menuTitle: 'Veckans meny',
          menuSnapshot: testMenuSnapshot,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
        );

        expect(result['id'], isNotNull);
        expect(result['id'], isA<String>());
        expect(result['id'].length, greaterThan(20)); // UUID v4 length
        expect(result['ownerId'], equals('user_123'));
        expect(result['ownerDisplayName'], equals('Anna Andersson'));
        expect(result['lastEditedBy'], equals('user_123'));
        expect(result['lastEditedByDisplayName'], equals('Anna Andersson'));

        final data = result['data'] as RealtimeMenuData;
        expect(data.menuTitle, equals('Veckans meny'));
        expect(data.menuSnapshot, equals(testMenuSnapshot));

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        expect(participants['user_123'], equals(ResourcePermission.owner));
      });

      test('should create menu with editors and viewers', () {
        final result = RealtimeMenuFactory.createFromMenuCategories(
          menuTitle: 'Delad meny',
          menuSnapshot: testMenuSnapshot,
          ownerId: 'owner_123',
          ownerDisplayName: 'Owner Name',
          editorUserIds: ['editor_1', 'editor_2'],
          viewerUserIds: ['viewer_1', 'viewer_2', 'viewer_3'],
        );

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        expect(
            participants.length, equals(6)); // 1 owner + 2 editors + 3 viewers
        expect(participants['owner_123'], equals(ResourcePermission.owner));
        expect(participants['editor_1'], equals(ResourcePermission.editor));
        expect(participants['editor_2'], equals(ResourcePermission.editor));
        expect(participants['viewer_1'], equals(ResourcePermission.viewer));
        expect(participants['viewer_2'], equals(ResourcePermission.viewer));
        expect(participants['viewer_3'], equals(ResourcePermission.viewer));
      });

      test('should create menu with all optional parameters', () {
        final createdForDate = DateTime(2025, 1, 20);

        final result = RealtimeMenuFactory.createFromMenuCategories(
          menuTitle: 'Full meny',
          menuSnapshot: testMenuSnapshot,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          editorUserIds: ['editor_1'],
          viewerUserIds: ['viewer_1'],
          menuNotes: 'Extra grönsaker till barnen',
          favoriteRecipeIds: ['recipe_1'],
          originalPrompt: 'Skapa en barnvänlig veckomeny',
          createdForDate: createdForDate,
        );

        final data = result['data'] as RealtimeMenuData;
        expect(data.menuNotes, equals('Extra grönsaker till barnen'));
        expect(data.favoriteRecipeIds, equals(['recipe_1']));
        expect(data.originalPrompt, equals('Skapa en barnvänlig veckomeny'));
        expect(data.createdForDate, equals(createdForDate));
      });

      test('should use current date when createdForDate not provided', () {
        final before = DateTime.now();

        final result = RealtimeMenuFactory.createFromMenuCategories(
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
        );

        final after = DateTime.now();

        final data = result['data'] as RealtimeMenuData;
        expect(
            data.createdForDate.isAfter(before) ||
                data.createdForDate.isAtSameMomentAs(before),
            isTrue);
        expect(
            data.createdForDate.isBefore(after) ||
                data.createdForDate.isAtSameMomentAs(after),
            isTrue);
      });

      test('should generate unique IDs', () {
        final ids = <String>{};

        for (int i = 0; i < 100; i++) {
          final result = RealtimeMenuFactory.createFromMenuCategories(
            menuTitle: 'Menu $i',
            menuSnapshot: testMenuSnapshot,
            ownerId: 'user_$i',
            ownerDisplayName: 'User $i',
          );
          ids.add(result['id'] as String);
        }

        expect(ids.length, equals(100)); // All IDs should be unique
      });
    });

    group('parseRepositoryData', () {
      late Map<String, dynamic> repositoryData;

      setUp(() {
        repositoryData = {
          'ownerId': 'user_456',
          'ownerDisplayName': 'Erik Eriksson',
          'participants': {
            'user_456': 'owner',
            'user_789': 'editor',
            'user_abc': 'viewer',
          },
          'createdAt': DateTime(2025, 1, 1),
          'lastEditedAt': DateTime(2025, 1, 15),
          'lastEditedBy': 'user_789',
          'lastEditedByDisplayName': 'Lars Larsson',
          'editCount': 5,
          'isActive': true,
          'metadata': {'key': 'value'},
          'menuTitle': 'Repository Menu',
          'createdForDate': Timestamp(1736899200, 0), // Firestore timestamp
          'menuSnapshot': {
            'Måndag': [testRecipe1.toFirestore()],
          },
        };
      });

      test('should parse repository data correctly', () {
        final result =
            RealtimeMenuFactory.parseRepositoryData('menu_123', repositoryData);

        expect(result['id'], equals('menu_123'));
        expect(result['ownerId'], equals('user_456'));
        expect(result['ownerDisplayName'], equals('Erik Eriksson'));
        expect(result['createdAt'], equals(DateTime(2025, 1, 1)));
        expect(result['lastEditedAt'], equals(DateTime(2025, 1, 15)));
        expect(result['lastEditedBy'], equals('user_789'));
        expect(result['lastEditedByDisplayName'], equals('Lars Larsson'));
        expect(result['editCount'], equals(5));
        expect(result['isActive'], isTrue);
        expect(result['metadata'], equals({'key': 'value'}));

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        expect(participants['user_456'], equals(ResourcePermission.owner));
        expect(participants['user_789'], equals(ResourcePermission.editor));
        expect(participants['user_abc'], equals(ResourcePermission.viewer));

        final data = result['data'] as RealtimeMenuData;
        expect(data.menuTitle, equals('Repository Menu'));
      });

      test('should handle missing optional fields', () {
        final minimalData = {
          'ownerId': 'user_123',
          'ownerDisplayName': 'Test User',
          'lastEditedBy': 'user_123',
          'lastEditedByDisplayName': 'Test User',
          'createdAt': DateTime.now(),
          'lastEditedAt': DateTime.now(),
          'createdForDate': Timestamp(1736899200, 0),
        };

        final result =
            RealtimeMenuFactory.parseRepositoryData('menu_456', minimalData);

        expect(result['editCount'], equals(0)); // Default value
        expect(result['isActive'], isTrue); // Default value
        expect(result['metadata'], equals({})); // Default empty map

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        expect(participants, isEmpty); // No participants data provided
      });

      test('should handle invalid permission values', () {
        final dataWithInvalidPermission = {
          'ownerId': 'user_123',
          'ownerDisplayName': 'Test',
          'participants': {
            'user_123': 'owner',
            'user_456': 'invalid_permission',
            'user_789': 'admin', // Valid permission
          },
          'createdAt': DateTime.now(),
          'lastEditedAt': DateTime.now(),
          'lastEditedBy': 'user_123',
          'lastEditedByDisplayName': 'Test',
          'createdForDate': Timestamp(1736899200, 0),
        };

        final result = RealtimeMenuFactory.parseRepositoryData(
            'test_id', dataWithInvalidPermission);

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        expect(participants['user_123'], equals(ResourcePermission.owner));
        expect(participants['user_456'],
            equals(ResourcePermission.viewer)); // Defaults to viewer
        expect(participants['user_789'], equals(ResourcePermission.admin));
      });
    });

    group('parseJsonData', () {
      late Map<String, dynamic> jsonData;

      setUp(() {
        jsonData = {
          'id': 'json_menu_123',
          'ownerId': 'user_json',
          'ownerDisplayName': 'JSON User',
          'participants': {
            'user_json': 'owner',
            'user_editor': 'editor',
          },
          'createdAt': '2025-01-01T10:00:00.000',
          'lastEditedAt': '2025-01-15T14:30:00.000',
          'lastEditedBy': 'user_editor',
          'lastEditedByDisplayName': 'Editor Name',
          'editCount': 10,
          'isActive': false,
          'metadata': {'source': 'json'},
          'menuTitle': 'JSON Menu',
          'createdForDate': '2025-01-20T00:00:00.000',
          'menuSnapshot': {
            'Tisdag': [testRecipe2.toFirestore()],
          },
        };
      });

      test('should parse JSON data correctly', () {
        final result = RealtimeMenuFactory.parseJsonData(jsonData);

        expect(result['id'], equals('json_menu_123'));
        expect(result['ownerId'], equals('user_json'));
        expect(result['ownerDisplayName'], equals('JSON User'));
        expect(result['createdAt'], equals(DateTime(2025, 1, 1, 10, 0)));
        expect(result['lastEditedAt'], equals(DateTime(2025, 1, 15, 14, 30)));
        expect(result['lastEditedBy'], equals('user_editor'));
        expect(result['lastEditedByDisplayName'], equals('Editor Name'));
        expect(result['editCount'], equals(10));
        expect(result['isActive'], isFalse);
        expect(result['metadata'], equals({'source': 'json'}));

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        expect(participants['user_json'], equals(ResourcePermission.owner));
        expect(participants['user_editor'], equals(ResourcePermission.editor));

        final data = result['data'] as RealtimeMenuData;
        expect(data.menuTitle, equals('JSON Menu'));
        expect(data.createdForDate, equals(DateTime(2025, 1, 20)));
      });

      test('should handle missing optional fields in JSON', () {
        final minimalJson = {
          'id': 'minimal_id',
          'ownerId': 'user_min',
          'ownerDisplayName': 'Minimal User',
          'createdAt': '2025-01-01T00:00:00.000',
          'lastEditedAt': '2025-01-01T00:00:00.000',
          'lastEditedBy': 'user_min',
          'lastEditedByDisplayName': 'Minimal User',
          'createdForDate': '2025-01-01T00:00:00.000',
        };

        final result = RealtimeMenuFactory.parseJsonData(minimalJson);

        expect(result['editCount'], equals(0));
        expect(result['isActive'], isTrue);
        expect(result['metadata'], equals({}));

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        expect(participants, isEmpty);
      });

      // BUT-1089: parseJsonData must throw on missing truly-required
      // fields instead of silently defaulting to clock.now()/empty. A
      // corrupted cache entry should NOT re-materialize as a "freshly
      // edited" menu.
      Map<String, dynamic> validJsonData() => {
            'ownerId': 'u_1',
            'ownerDisplayName': 'Anna',
            'createdAt': '2026-01-01T00:00:00.000',
            'lastEditedAt': '2026-01-02T00:00:00.000',
            'lastEditedBy': 'u_1',
            'lastEditedByDisplayName': 'Anna',
            'createdForDate': '2026-01-03T00:00:00.000',
            'menuTitle': 'Test',
          };

      test('parseJsonData throws on missing ownerId (BUT-1089)', () {
        final data = validJsonData()..remove('ownerId');
        expect(() => RealtimeMenuFactory.parseJsonData(data),
            throwsA(isA<FormatException>()));
      });

      test('parseJsonData throws on missing createdAt (BUT-1089)', () {
        final data = validJsonData()..remove('createdAt');
        expect(() => RealtimeMenuFactory.parseJsonData(data),
            throwsA(isA<FormatException>()));
      });

      test('parseJsonData throws on missing lastEditedBy (BUT-1089)', () {
        final data = validJsonData()..remove('lastEditedBy');
        expect(() => RealtimeMenuFactory.parseJsonData(data),
            throwsA(isA<FormatException>()));
      });
    });

    group('parseRepositoryData hardening', () {
      // BUT-1089: same fail-loud contract as parseJsonData, for the
      // Firestore-payload variant. Mirrors RealtimeRecipe.fromMap fix
      // (BUT-1071) so corrupted docs can't silently parse.
      Map<String, dynamic> validRepoData() => {
            'ownerId': 'u_1',
            'ownerDisplayName': 'Anna',
            'createdAt': DateTime(2026, 1, 1),
            'lastEditedAt': DateTime(2026, 1, 2),
            'lastEditedBy': 'u_1',
            'lastEditedByDisplayName': 'Anna',
            'createdForDate': Timestamp.fromDate(DateTime(2026, 1, 3)),
            'menuTitle': 'Test',
          };

      test('throws on missing ownerId', () {
        final data = validRepoData()..remove('ownerId');
        expect(() => RealtimeMenuFactory.parseRepositoryData('m_x', data),
            throwsA(isA<FormatException>()));
      });

      test('throws on empty ownerId', () {
        final data = validRepoData()..['ownerId'] = '';
        expect(() => RealtimeMenuFactory.parseRepositoryData('m_x', data),
            throwsA(isA<FormatException>()));
      });

      test('throws on missing createdAt', () {
        final data = validRepoData()..remove('createdAt');
        expect(() => RealtimeMenuFactory.parseRepositoryData('m_x', data),
            throwsA(isA<FormatException>()));
      });

      test('throws on missing lastEditedAt', () {
        final data = validRepoData()..remove('lastEditedAt');
        expect(() => RealtimeMenuFactory.parseRepositoryData('m_x', data),
            throwsA(isA<FormatException>()));
      });

      test('throws on missing lastEditedBy', () {
        final data = validRepoData()..remove('lastEditedBy');
        expect(() => RealtimeMenuFactory.parseRepositoryData('m_x', data),
            throwsA(isA<FormatException>()));
      });

      test('soft-defaults ownerDisplayName (BUT-1089: display-name stays soft)',
          () {
        final data = validRepoData()..remove('ownerDisplayName');
        final result = RealtimeMenuFactory.parseRepositoryData('m_x', data);
        expect(result['ownerDisplayName'], isEmpty);
      });
    });

    group('createCopyParameters', () {
      test('should create copy parameters with updated values', () {
        final originalCreatedAt = DateTime(2025, 1, 1);
        final originalLastEditedAt = DateTime(2025, 1, 10);
        final originalParticipants = {
          'user_123': ResourcePermission.owner,
          'user_456': ResourcePermission.editor,
        };
        final originalData = RealtimeMenuData(
          menuTitle: 'Original',
          createdForDate: DateTime(2025, 1, 5),
          menuSnapshot: testMenuSnapshot,
        );

        final before = DateTime.now();

        final result = RealtimeMenuFactory.createCopyParameters(
          id: 'menu_copy',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: originalParticipants,
          createdAt: originalCreatedAt,
          lastEditedAt: originalLastEditedAt,
          lastEditedBy: 'user_456',
          lastEditedByDisplayName: 'Erik',
          editCount: 5,
          isActive: true,
          metadata: {'key': 'value'},
          data: originalData,
          newLastEditedBy: 'user_789',
          newLastEditedByDisplayName: 'Lars Larsson',
        );

        final after = DateTime.now();

        expect(result['id'], equals('menu_copy'));
        expect(result['ownerId'], equals('user_123'));
        expect(result['ownerDisplayName'], equals('Anna'));
        expect(result['participants'], equals(originalParticipants));
        expect(result['createdAt'], equals(originalCreatedAt));
        expect(result['lastEditedBy'], equals('user_789'));
        expect(result['lastEditedByDisplayName'], equals('Lars Larsson'));
        expect(result['editCount'], equals(6)); // Incremented
        expect(result['isActive'], isTrue);
        expect(result['metadata'], equals({'key': 'value'}));
        expect(result['data'], equals(originalData));

        // Check lastEditedAt was updated to now
        final lastEditedAt = result['lastEditedAt'] as DateTime;
        expect(lastEditedAt.isAfter(originalLastEditedAt), isTrue);
        expect(
            lastEditedAt.isAfter(before) ||
                lastEditedAt.isAtSameMomentAs(before),
            isTrue);
        expect(
            lastEditedAt.isBefore(after) ||
                lastEditedAt.isAtSameMomentAs(after),
            isTrue);
      });

      test('should preserve original data while updating edit metadata', () {
        final originalData = RealtimeMenuData(
          menuTitle: 'Original Menu',
          createdForDate: DateTime(2025, 1, 1),
          menuSnapshot: testMenuSnapshot,
          menuNotes: 'Original notes',
          favoriteRecipeIds: ['recipe_1'],
          originalPrompt: 'Original prompt',
        );

        final result = RealtimeMenuFactory.createCopyParameters(
          id: 'same_id',
          ownerId: 'owner_id',
          ownerDisplayName: 'Owner',
          participants: {},
          createdAt: DateTime(2025, 1, 1),
          lastEditedAt: DateTime(2025, 1, 5),
          lastEditedBy: 'old_editor',
          lastEditedByDisplayName: 'Old Editor',
          editCount: 10,
          isActive: false,
          metadata: {'old': 'data'},
          data: originalData,
          newLastEditedBy: 'new_editor',
          newLastEditedByDisplayName: 'New Editor',
        );

        // Data should be preserved exactly
        final preservedData = result['data'] as RealtimeMenuData;
        expect(preservedData.menuTitle, equals('Original Menu'));
        expect(preservedData.menuNotes, equals('Original notes'));
        expect(preservedData.favoriteRecipeIds, equals(['recipe_1']));
        expect(preservedData.originalPrompt, equals('Original prompt'));

        // Only edit metadata should change
        expect(result['lastEditedBy'], equals('new_editor'));
        expect(result['lastEditedByDisplayName'], equals('New Editor'));
        expect(result['editCount'], equals(11));

        // Other metadata preserved
        expect(result['isActive'], isFalse);
        expect(result['metadata'], equals({'old': 'data'}));
      });
    });

    group('Edge Cases', () {
      test('should handle empty menu snapshot', () {
        final result = RealtimeMenuFactory.createFromMenuCategories(
          menuTitle: 'Empty Menu',
          menuSnapshot: {},
          ownerId: 'user_123',
          ownerDisplayName: 'User',
        );

        final data = result['data'] as RealtimeMenuData;
        expect(data.menuSnapshot, isEmpty);
        expect(data.allUniqueRecipes, isEmpty);
      });

      test('should handle Swedish characters in names and titles', () {
        final result = RealtimeMenuFactory.createFromMenuCategories(
          menuTitle: 'Åsas veckomeny med ÄÖÅ',
          menuSnapshot: testMenuSnapshot,
          ownerId: 'user_åsa',
          ownerDisplayName: 'Åsa Öström',
        );

        expect(result['ownerDisplayName'], equals('Åsa Öström'));
        final data = result['data'] as RealtimeMenuData;
        expect(data.menuTitle, equals('Åsas veckomeny med ÄÖÅ'));
      });

      test('should handle very large participant lists', () {
        final editorIds = List.generate(100, (i) => 'editor_$i');
        final viewerIds = List.generate(200, (i) => 'viewer_$i');

        final result = RealtimeMenuFactory.createFromMenuCategories(
          menuTitle: 'Large Team Menu',
          menuSnapshot: testMenuSnapshot,
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
          editorUserIds: editorIds,
          viewerUserIds: viewerIds,
        );

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        expect(participants.length,
            equals(301)); // 1 owner + 100 editors + 200 viewers

        // Check some random participants
        expect(participants['editor_50'], equals(ResourcePermission.editor));
        expect(participants['viewer_150'], equals(ResourcePermission.viewer));
      });

      test('should handle duplicate user IDs in different permission lists',
          () {
        final result = RealtimeMenuFactory.createFromMenuCategories(
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
          editorUserIds: ['user_1', 'user_2'],
          viewerUserIds: ['user_2', 'user_3'], // user_2 appears in both
        );

        final participants =
            result['participants'] as Map<String, ResourcePermission>;
        // user_2 should have viewer permission (last one wins)
        expect(participants['user_2'], equals(ResourcePermission.viewer));
        expect(participants['user_1'], equals(ResourcePermission.editor));
        expect(participants['user_3'], equals(ResourcePermission.viewer));
      });
    });
  });
}
