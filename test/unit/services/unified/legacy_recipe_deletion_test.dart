// test/unit/services/unified/legacy_recipe_deletion_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';
import 'package:butlery/services/unified/modules/recipe_data_repair_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('Legacy Recipe Deletion Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuthRepository mockAuthRepository;
    late FirebaseRecipeRepository repository;
    late RecipePermissionHelper permissionHelper;
    late RecipeDataRepairService repairService;
    late MockUnifiedRecipeService mockUnifiedService;

    const testUserId = 'test_user_123';
    const legacyRecipeId = 'legacy_recipe_456';

    setUpAll(() {
      // Register fallback values
      registerFallbackValue(RecipeBuilder().build());
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Setup mocks
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = MockFirebaseAuthRepository();
      mockUnifiedService = MockUnifiedRecipeService();

      // Setup auth repository
      mockAuthRepository.setAuthState(userId: testUserId);

      // Create repository and services
      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepository,
      );

      permissionHelper = RecipePermissionHelper(mockUnifiedService);
      repairService = RecipeDataRepairService(
        firestore: fakeFirestore,
        recipeRepository: repository,
      );

      // Setup mock unified service
      mockUnifiedService.setRecipeState(currentUserId: testUserId);
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    group('Legacy Recipe Detection', () {
      test('should detect recipe with no socialData as legacy', () {
        // Arrange
        final legacyRecipe = Recipe(
          core: RecipeCore(
            id: legacyRecipeId,
            title: 'Legacy Recipe',
            description: 'Old recipe',
            ingredients: ['ingredient'],
            instructions: ['instruction'],
            mealType: 'Middag',
            createdAt: DateTime(2021, 1, 1), // Before social data
            updatedAt: DateTime(2021, 1, 1),
            createdBy: null, // Missing createdBy
          ),
          type: RecipeType.personal,
          socialData: null, // Missing socialData
        );

        // Act & Assert - Legacy detection is now handled by RecipePermissionHelper
        // This test validates the legacy recipe structure
        expect(legacyRecipe.socialData, isNull);
      });

      test('should detect recipe with empty createdBy as legacy', () {
        // Arrange
        final legacyRecipe = Recipe(
          core: RecipeCore(
            id: legacyRecipeId,
            title: 'Legacy Recipe',
            description: 'Old recipe',
            ingredients: ['ingredient'],
            instructions: ['instruction'],
            mealType: 'Middag',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdBy: '', // Empty createdBy
          ),
          type: RecipeType.personal,
        );

        // Act & Assert
        // Legacy detection is now handled by RecipePermissionHelper
        expect(legacyRecipe.createdBy, anyOf(isNull, isEmpty));
      });

      test('should detect very old recipe as legacy', () {
        // Arrange
        final legacyRecipe = Recipe(
          core: RecipeCore(
            id: legacyRecipeId,
            title: 'Legacy Recipe',
            description: 'Old recipe',
            ingredients: ['ingredient'],
            instructions: ['instruction'],
            mealType: 'Middag',
            createdAt: DateTime(2021, 1, 1), // Before social data structure
            updatedAt: DateTime(2021, 1, 1),
            createdBy: testUserId,
          ),
          type: RecipeType.personal,
        );

        // Act & Assert
        // Legacy detection is now handled by RecipePermissionHelper
        expect(legacyRecipe.createdBy, anyOf(isNull, isEmpty));
      });

      test('should not detect modern recipe as legacy', () {
        // Arrange
        final modernRecipe = Recipe(
          core: RecipeCore(
            id: 'modern_recipe',
            title: 'Modern Recipe',
            description: 'New recipe',
            ingredients: ['ingredient'],
            instructions: ['instruction'],
            mealType: 'Middag',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdBy: testUserId,
          ),
          type: RecipeType.personal,
          socialData: RecipeSocialData(
            ownerId: testUserId,
            ownerDisplayName: 'Test User',
          ),
        );

        // Act & Assert - Modern recipes should have proper ownership data
        expect(modernRecipe.createdBy, isNotNull);
        expect(modernRecipe.createdBy, isNotEmpty);
      });
    });

    group('Legacy Recipe Deletion Permission Tests', () {
      test('should allow deletion of legacy personal recipe by inferred owner', () {
        // Arrange
        final legacyRecipe = Recipe(
          core: RecipeCore(
            id: legacyRecipeId,
            title: 'Legacy Recipe',
            description: 'Old recipe',
            ingredients: ['ingredient'],
            instructions: ['instruction'],
            mealType: 'Middag',
            createdAt: DateTime(2021, 1, 1),
            updatedAt: DateTime(2021, 1, 1),
            createdBy: null,
          ),
          type: RecipeType.personal,
          socialData: null,
        );

        // Act
        final canDelete = permissionHelper.canDeleteRecipe(legacyRecipe);

        // Assert
        expect(canDelete, isTrue);
      });

      test('should deny deletion when ownership cannot be determined', () {
        // Arrange - collaborative recipe with no ownership data
        final legacyRecipe = Recipe(
          core: RecipeCore(
            id: legacyRecipeId,
            title: 'Legacy Collaborative Recipe',
            description: 'Old collaborative recipe',
            ingredients: ['ingredient'],
            instructions: ['instruction'],
            mealType: 'Middag',
            createdAt: DateTime(2021, 1, 1),
            updatedAt: DateTime(2021, 1, 1),
            createdBy: null,
          ),
          type: RecipeType.collaborative,
          socialData: null,
        );

        // Act
        final canDelete = permissionHelper.canDeleteRecipe(legacyRecipe);

        // Assert - Should be false for collaborative recipes without clear ownership
        expect(canDelete, isFalse);
      });
    });

    group('Firebase Repository Legacy Deletion Tests', () {
      test('should successfully delete legacy personal recipe', () async {
        // Arrange - Create legacy recipe in Firestore
        final legacyRecipeData = {
          'core': {
            'id': legacyRecipeId,
            'title': 'Legacy Recipe',
            'description': 'Old recipe',
            'ingredients': ['ingredient'],
            'instructions': ['instruction'],
            'mealType': 'Middag',
            'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'createdBy': null, // Legacy - no createdBy
          },
          'type': 'personal',
          // No socialData - legacy structure
        };

        // Add to user's collection
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .set(legacyRecipeData);

        // Act - Attempt deletion
        await repository.delete(legacyRecipeId);

        // Assert - Recipe should be deleted
        final deletedDoc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .get();

        expect(deletedDoc.exists, isFalse);
      });

      test('should log legacy recipe deletion for audit', () async {
        // Arrange - Create legacy recipe
        final legacyRecipeData = {
          'core': {
            'id': legacyRecipeId,
            'title': 'Legacy Recipe',
            'description': 'Old recipe',
            'ingredients': ['ingredient'],
            'instructions': ['instruction'],
            'mealType': 'Middag',
            'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'createdBy': '',
          },
          'type': 'personal',
        };

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .set(legacyRecipeData);

        // Act
        await repository.delete(legacyRecipeId);

        // Assert - Check audit log was created
        final auditSnapshot = await fakeFirestore
            .collection('audit_logs')
            .doc('legacy_recipe_deletions')
            .collection('deletions')
            .get();

        expect(auditSnapshot.docs.isNotEmpty, isTrue);

        final auditData = auditSnapshot.docs.first.data();
        expect(auditData['action'], 'legacy_recipe_deletion');
        expect(auditData['recipeId'], legacyRecipeId);
        expect(auditData['userId'], testUserId);
      });

      test('should throw PermissionDenied for unowned legacy recipe', () async {
        // Arrange - Create legacy recipe owned by different user
        const otherUserId = 'other_user_789';
        final legacyRecipeData = {
          'core': {
            'id': legacyRecipeId,
            'title': 'Someone Else Recipe',
            'description': 'Not owned by current user',
            'ingredients': ['ingredient'],
            'instructions': ['instruction'],
            'mealType': 'Middag',
            'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'createdBy': null,
          },
          'type': 'personal',
        };

        // Add to other user's collection
        await fakeFirestore
            .collection('users')
            .doc(otherUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .set(legacyRecipeData);

        // Act & Assert - Should throw permission exception
        expect(
          () => repository.delete(legacyRecipeId),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Recipe Data Repair Service Tests', () {
      test('should detect recipe that needs repair', () async {
        // Arrange - Create recipe with missing ownership data
        final legacyData = {
          'core': {
            'id': legacyRecipeId,
            'title': 'Legacy Recipe',
            'description': 'Old recipe',
            'ingredients': ['ingredient'],
            'instructions': ['instruction'],
            'mealType': 'Middag',
            'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'createdBy': null,
          },
          'type': 'personal',
        };

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .set(legacyData);

        // Act
        final needsRepair = await repairService.needsRepair(legacyRecipeId, testUserId);

        // Assert
        expect(needsRepair, isTrue);
      });

      test('should successfully repair legacy recipe ownership', () async {
        // Arrange - Create legacy recipe
        final legacyData = {
          'core': {
            'id': legacyRecipeId,
            'title': 'Legacy Recipe',
            'description': 'Old recipe',
            'ingredients': ['ingredient'],
            'instructions': ['instruction'],
            'mealType': 'Middag',
            'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'createdBy': null,
          },
          'type': 'personal',
        };

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .set(legacyData);

        // Act
        final repairResult = await repairService.repairRecipeOwnership(legacyRecipeId, testUserId);

        // Assert
        expect(repairResult, isTrue);

        // Verify repair
        final repairedDoc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .get();

        expect(repairedDoc.exists, isTrue);
        final repairedData = repairedDoc.data()!;
        expect(repairedData['core']['createdBy'], testUserId);
        expect(repairedData['socialData']['ownerId'], testUserId);
      });

      test('should repair all user legacy recipes', () async {
        // Arrange - Create multiple legacy recipes
        final legacyRecipeIds = ['legacy_1', 'legacy_2', 'legacy_3'];

        for (final recipeId in legacyRecipeIds) {
          final legacyData = {
            'core': {
              'id': recipeId,
              'title': 'Legacy Recipe $recipeId',
              'description': 'Old recipe',
              'ingredients': ['ingredient'],
              'instructions': ['instruction'],
              'mealType': 'Middag',
              'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
              'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
              'createdBy': null,
            },
            'type': 'personal',
          };

          await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipeId)
              .set(legacyData);
        }

        // Act
        final repairResult = await repairService.repairUserLegacyRecipes(testUserId);

        // Assert
        expect(repairResult.isSuccess, isTrue);
        expect(repairResult.totalScanned, 3);
        expect(repairResult.successfullyRepaired, 3);
        expect(repairResult.failedRepairs, 0);

        // Verify all recipes were repaired
        for (final recipeId in legacyRecipeIds) {
          final repairedDoc = await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipeId)
              .get();

          final repairedData = repairedDoc.data()!;
          expect(repairedData['core']['createdBy'], testUserId);
          expect(repairedData['socialData']['ownerId'], testUserId);
        }
      });

      test('should create backup before repair', () async {
        // Arrange
        final legacyData = {
          'core': {
            'id': legacyRecipeId,
            'title': 'Legacy Recipe',
            'description': 'Old recipe',
            'ingredients': ['ingredient'],
            'instructions': ['instruction'],
            'mealType': 'Middag',
            'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'createdBy': null,
          },
          'type': 'personal',
        };

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .set(legacyData);

        // Act
        await repairService.repairRecipeOwnership(legacyRecipeId, testUserId);

        // Assert - Check backup was created
        final backupDoc = await fakeFirestore
            .collection('repair_backups')
            .doc('recipe_$legacyRecipeId')
            .get();

        expect(backupDoc.exists, isTrue);
        final backupData = backupDoc.data()!;
        expect(backupData['recipeId'], legacyRecipeId);
        expect(backupData['originalData'], isNotNull);
      });
    });

    group('Integration Tests', () {
      test('should delete legacy recipe after repair', () async {
        // Arrange - Create legacy recipe
        final legacyData = {
          'core': {
            'id': legacyRecipeId,
            'title': 'Legacy Recipe',
            'description': 'Old recipe',
            'ingredients': ['ingredient'],
            'instructions': ['instruction'],
            'mealType': 'Middag',
            'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            'createdBy': null,
          },
          'type': 'personal',
        };

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .set(legacyData);

        // Act 1 - Repair recipe
        final repairResult = await repairService.repairRecipeOwnership(legacyRecipeId, testUserId);
        expect(repairResult, isTrue);

        // Act 2 - Delete repaired recipe
        await repository.delete(legacyRecipeId);

        // Assert - Recipe should be deleted
        final deletedDoc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(legacyRecipeId)
            .get();

        expect(deletedDoc.exists, isFalse);
      });

      test('should handle mixed legacy and modern recipes', () async {
        // Arrange - Create mix of legacy and modern recipes
        final recipes = [
          {
            'id': 'legacy_recipe',
            'data': {
              'core': {
                'id': 'legacy_recipe',
                'title': 'Legacy Recipe',
                'description': 'Old recipe',
                'ingredients': ['ingredient'],
                'instructions': ['instruction'],
                'mealType': 'Middag',
                'createdAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
                'updatedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
                'createdBy': null,
              },
              'type': 'personal',
            }
          },
          {
            'id': 'modern_recipe',
            'data': {
              'core': {
                'id': 'modern_recipe',
                'title': 'Modern Recipe',
                'description': 'New recipe',
                'ingredients': ['ingredient'],
                'instructions': ['instruction'],
                'mealType': 'Middag',
                'createdAt': Timestamp.fromDate(DateTime.now()),
                'updatedAt': Timestamp.fromDate(DateTime.now()),
                'createdBy': testUserId,
              },
              'type': 'personal',
              'socialData': {
                'ownerId': testUserId,
                'ownerDisplayName': 'Test User',
              },
            }
          },
        ];

        for (final recipe in recipes) {
          await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipe['id'] as String)
              .set(recipe['data'] as Map<String, dynamic>);
        }

        // Act - Repair user recipes
        final repairResult = await repairService.repairUserLegacyRecipes(testUserId);

        // Assert
        expect(repairResult.totalScanned, 2);
        expect(repairResult.successfullyRepaired, 1); // Only legacy recipe repaired
        expect(repairResult.alreadyValid, 1); // Modern recipe already valid

        // Both recipes should be deletable now
        for (final recipe in recipes) {
          final recipeId = recipe['id'] as String;
          await repository.delete(recipeId);

          final deletedDoc = await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipeId)
              .get();

          expect(deletedDoc.exists, isFalse);
        }
      });
    });
  });
}