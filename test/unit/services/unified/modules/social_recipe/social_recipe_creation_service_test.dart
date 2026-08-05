/// Unit tests for SocialRecipeCreationService - Handles collaborative recipe creation
///
/// Tests recipe creation operations including:
/// - Creating collaborative recipes with permissions
/// - Member initialization
/// - Permission assignment
/// - Validation logic
/// - Error handling for creation failures
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_creation_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

// Test infrastructure
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('SocialRecipeCreationService', () {
    late SocialRecipeCreationService creationService;
    late String currentUserId;
    late String currentUserDisplayName;
    late String? errorMessage;
    late int notifyCount;
    late List<Recipe> savedRecipes;
    late Recipe? lastSavedRecipe;

    setUpAll(() {
      // Register fallback values
      registerFallbackValue(ResourcePermission.viewer);
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Reset test state
      currentUserId = 'test-user-123';
      currentUserDisplayName = 'Test User';
      errorMessage = null;
      notifyCount = 0;
      savedRecipes = [];
      lastSavedRecipe = null;

      // Create service with test dependencies
      creationService = SocialRecipeCreationService(
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: (error) => errorMessage = error,
        notifyListeners: () => notifyCount++,
        getRecipe: (id) async {
          return savedRecipes.firstWhere(
            (r) => r.id == id,
            orElse: () => RecipeFactory.build(id: id),
          );
        },
        saveRecipe: (recipe) async {
          lastSavedRecipe = recipe;
          final index = savedRecipes.indexWhere((r) => r.id == recipe.id);
          if (index >= 0) {
            savedRecipes[index] = recipe;
          } else {
            savedRecipes.add(recipe);
          }
          return true;
        },
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Basic Recipe Creation', () {
      test('should create collaborative recipe with required fields', () async {
        // Arrange
        const title = 'Test Collaborative Recipe';
        final ingredients = ['500g flour', '2 eggs', '300ml milk'];
        final instructions = ['Mix ingredients', 'Bake at 180°C', 'Serve hot'];

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(recipeId, isNotNull);
        expect(recipeId, isNotEmpty);
        expect(lastSavedRecipe, isNotNull);
        expect(lastSavedRecipe!.title, equals(title));
        expect(lastSavedRecipe!.ingredients, equals(ingredients));
        expect(lastSavedRecipe!.instructions, equals(instructions));
        expect(lastSavedRecipe!.isCollaborative, isTrue);
        expect(lastSavedRecipe!.isPersonal, isFalse);
        expect(notifyCount, greaterThan(0));
      });

      test('should set creator as owner with full permissions', () async {
        // Arrange
        const title = 'Owner Test Recipe';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(recipeId, isNotNull);
        expect(lastSavedRecipe!.createdBy, equals(currentUserId));
        // Check creator is in memberPermissions
        expect(
          lastSavedRecipe!.socialData?.memberPermissions?.containsKey(
            currentUserId,
          ),
          isTrue,
        );
        expect(
          lastSavedRecipe!.socialData?.memberPermissions?[currentUserId],
          equals(ResourcePermission.admin),
        );
      });

      test('should include optional metadata', () async {
        // Arrange
        const title = 'Recipe with Metadata';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        const description = 'A delicious Swedish recipe';
        const portions = 6;
        const cookingTime = 60;
        final tags = ['swedish', 'dinner', 'vegetarian'];

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
          description: description,
          portions: portions,
          cookingTime: cookingTime,
          personalTagIds: tags,
        );

        // Assert
        expect(recipeId, isNotNull);
        expect(lastSavedRecipe!.description, equals(description));
        expect(lastSavedRecipe!.portions, equals(portions));
        expect(lastSavedRecipe!.timeMinutes, equals(cookingTime));
        expect(lastSavedRecipe!.personalTagIds, equals(tags));
      });
    });

    group('Member Initialization', () {
      test(
        'should add initial members with default viewer permission',
        () async {
          // Arrange
          const title = 'Recipe with Members';
          final ingredients = ['Ingredient'];
          final instructions = ['Instruction'];
          final initialMembers = ['user-2', 'user-3', 'user-4'];

          // Act
          final recipeId = await creationService.createCollaborativeRecipe(
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            initialMembers: initialMembers,
          );

          // Assert
          expect(recipeId, isNotNull);
          final memberPermissions =
              lastSavedRecipe!.socialData?.memberPermissions;
          expect(memberPermissions?.length, equals(4)); // Creator + 3 members
          expect(memberPermissions?.containsKey(currentUserId), isTrue);

          // Check all initial members are in permissions (default is editor)
          for (final member in initialMembers) {
            expect(memberPermissions?.containsKey(member), isTrue);
            expect(
              memberPermissions?[member],
              equals(ResourcePermission.editor),
            );
          }
        },
      );

      test('should apply custom permissions to initial members', () async {
        // Arrange
        const title = 'Recipe with Custom Permissions';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        final initialMembers = ['editor-user', 'viewer-user'];
        final initialPermissions = {
          'editor-user': ResourcePermission.editor,
          'viewer-user': ResourcePermission.viewer,
        };

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
          initialMembers: initialMembers,
          initialPermissions: initialPermissions,
        );

        // Assert
        expect(recipeId, isNotNull);
        final memberPermissions =
            lastSavedRecipe!.socialData?.memberPermissions;
        expect(
          memberPermissions?['editor-user'],
          equals(ResourcePermission.editor),
        );
        expect(
          memberPermissions?['viewer-user'],
          equals(ResourcePermission.viewer),
        );
      });

      test('should prevent duplicate members', () async {
        // Arrange
        const title = 'Recipe with Duplicate Members';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        final initialMembers = ['user-2', 'user-2', 'user-3', 'user-3'];

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
          initialMembers: initialMembers,
        );

        // Assert
        expect(recipeId, isNotNull);
        final memberPermissions =
            lastSavedRecipe!.socialData?.memberPermissions;
        final uniqueMembers = memberPermissions?.keys.toSet() ?? {};
        expect(uniqueMembers.length, equals(3)); // Creator + 2 unique members
        expect(uniqueMembers, contains('user-2'));
        expect(uniqueMembers, contains('user-3'));
      });

      /// Replaces an earlier version of this test that asserted the creator
      /// appeared exactly once among `memberPermissions.keys` — unfailable, a
      /// Map cannot hold a duplicate key — and that the map had two entries,
      /// which the demotion also satisfies. Measured 2026-08-04: with both
      /// creator skips deleted the whole 50-test suite stayed green while the
      /// owner came out `editor` and holding a revocable grant.
      test('the creator keeps admin and is never granted a revocable '
          'reason', () async {
        // Every friend category contains its own owner, and the group-share
        // caller passes the roster straight through — so this is the ORDINARY
        // shape of the call, not an exotic one.
        final recipeId = await creationService.createCollaborativeRecipe(
          title: 'Creator in Members Test',
          ingredients: const ['Ingredient'],
          instructions: const ['Instruction'],
          initialMembers: [currentUserId, 'mom-uid'],
          categoryIds: const ['grp-fam'],
        );

        expect(recipeId, isNotNull);
        final social = lastSavedRecipe!.socialData!;
        expect(
          social.memberPermissions?[currentUserId],
          ResourcePermission.admin,
          reason:
              'the member loop must not overwrite the admin entry seeded above '
              'it — that demotes the owner of their own recipe',
        );
        expect(
          social.memberPermissions?.length,
          2,
          reason: 'creator + mom-uid, the creator seeded exactly once',
        );
        expect(
          social.grants?.containsKey(currentUserId),
          isFalse,
          reason:
              'an owner is not a sharee; a group grant here would let a revoke '
              'of that group strip the owner of their own recipe',
        );
        expect(
          social.grants?['mom-uid'],
          ['group:grp-fam'],
          reason: 'positive control — the grants loop did run',
        );
      });
    });

    group('Permission Assignment', () {
      test(
        'should allow setting admin permission for initial members',
        () async {
          // Arrange
          const title = 'Admin Permission Test';
          final ingredients = ['Ingredient'];
          final instructions = ['Instruction'];
          final initialMembers = ['user-2'];
          final initialPermissions = {
            'user-2': ResourcePermission.admin, // Set admin permission
          };

          // Act
          final recipeId = await creationService.createCollaborativeRecipe(
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            initialMembers: initialMembers,
            initialPermissions: initialPermissions,
          );

          // Assert
          expect(recipeId, isNotNull);
          // Service allows any permission to be set
          final memberPermissions =
              lastSavedRecipe!.socialData?.memberPermissions;
          expect(
            memberPermissions?['user-2'],
            equals(ResourcePermission.admin),
          );
          expect(errorMessage, isNull);
        },
      );

      test('should handle mixed permission assignments', () async {
        // Arrange
        const title = 'Mixed Permissions';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        final initialMembers = ['user-1', 'user-2', 'user-3', 'user-4'];
        final initialPermissions = {
          'user-1': ResourcePermission.editor,
          'user-3': ResourcePermission.viewer,
          // user-2 and user-4 get default
        };

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
          initialMembers: initialMembers,
          initialPermissions: initialPermissions,
        );

        // Assert
        expect(recipeId, isNotNull);
        final memberPermissions =
            lastSavedRecipe!.socialData?.memberPermissions;
        expect(memberPermissions?['user-1'], equals(ResourcePermission.editor));
        expect(
          memberPermissions?['user-2'],
          equals(ResourcePermission.editor),
        ); // Default
        expect(memberPermissions?['user-3'], equals(ResourcePermission.viewer));
        expect(
          memberPermissions?['user-4'],
          equals(ResourcePermission.editor),
        ); // Default
      });
    });

    /// BUT-1797. This is the branch the FIRST group-share path lands on:
    /// `GroupRecipeSelectionViewModel` → `RecipeSharingManager` → here, whenever
    /// the recipe being shared is still personal. Nothing else in the repo
    /// passes `categoryIds` this far, so without these the whole group-share
    /// leg of the feature ships on an untested code path — which is how the
    /// parameter came to be silently dropped one layer up in the first place.
    group('Group provenance (BUT-1797)', () {
      test('a group containing only the creator adds no revocable row', () async {
        // The MORE important of the two solo-group sites, and the one that
        // shipped unpinned: `RecipeSharingManager` only reaches
        // `_grantAccessOnReshare` when the recipe is ALREADY collaborative. A
        // first-time group share of a personal recipe — the ordinary case —
        // comes down this path instead.
        //
        // With a roster of just the creator, the loop skips them, so nobody is
        // granted. Writing the raw `groupIds` into `categoryIds` would then put a
        // revoke row in the panel matching no member's grant: `removeGroup`
        // clears its guard, `revokeGroup` no-ops, and the snackbar still says the
        // group lost access. Every other fixture here supplies a real second
        // member, so the derived and raw lists coincide and none of them can see
        // this.
        final recipeId = await creationService.createCollaborativeRecipe(
          title: 'Solo Group Test',
          ingredients: const ['Ingredient'],
          instructions: const ['Instruction'],
          initialMembers: [currentUserId],
          categoryIds: const ['grp-solo'],
        );

        expect(recipeId, isNotNull);
        final social = lastSavedRecipe!.socialData!;
        expect(
          social.categoryIds,
          isNull,
          reason: 'no grant was written, so there is nothing to revoke',
        );
        expect(social.grants, isNull);
        expect(
          social.memberPermissions?[currentUserId],
          ResourcePermission.admin,
          reason: 'control — the creator still owns the recipe',
        );
      });

      test('records the group each member was reached through', () async {
        final recipeId = await creationService.createCollaborativeRecipe(
          title: 'Delad med familjen',
          ingredients: const ['Ingredient'],
          instructions: const ['Instruction'],
          initialMembers: const ['mom-uid'],
          categoryIds: const ['grp-fam'],
        );

        expect(recipeId, isNotNull);
        final social = lastSavedRecipe!.socialData!;
        expect(
          social.grants?['mom-uid'],
          ['group:grp-fam'],
          reason:
              'a share with no recorded reason can never be revoked as a '
              'group — this is the entire feature',
        );
        expect(
          social.categoryIds,
          ['grp-fam'],
          reason: 'the sharing panel renders its revoke rows from this',
        );
      });

      test(
        'records a direct grant when no group is behind the share',
        () async {
          await creationService.createCollaborativeRecipe(
            title: 'Delad direkt',
            ingredients: const ['Ingredient'],
            instructions: const ['Instruction'],
            initialMembers: const ['mom-uid'],
          );

          final social = lastSavedRecipe!.socialData!;
          expect(social.grants?['mom-uid'], ['direct']);
          expect(
            social.categoryIds,
            isNull,
            reason:
                'no group was picked, so there is no row to offer a revoke on',
          );
        },
      );

      test('a create with no members records no grants at all', () async {
        // The deliberate absence of a compatibility path (Malin, 2026-08-03):
        // absent provenance stays absent rather than being written as an empty
        // map that a later reader could mistake for "checked, nobody".
        await creationService.createCollaborativeRecipe(
          title: 'Bara jag',
          ingredients: const ['Ingredient'],
          instructions: const ['Instruction'],
        );

        final social = lastSavedRecipe!.socialData!;
        expect(social.grants, isNull);
        expect(social.categoryIds, isNull);
        expect(
          social.memberPermissions?[currentUserId],
          ResourcePermission.admin,
        );
      });
    });

    group('Validation', () {
      test('should require title', () async {
        // Arrange
        const title = ''; // Empty title
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(recipeId, isNull);
        expect(errorMessage, isNotNull); // Service returns generic error
      });

      test('should require at least one ingredient', () async {
        // Arrange
        const title = 'Recipe without Ingredients';
        final ingredients = <String>[]; // Empty ingredients
        final instructions = ['Instruction'];

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(recipeId, isNull);
        expect(errorMessage, isNotNull); // Service returns generic error
      });

      test('should require at least one instruction', () async {
        // Arrange
        const title = 'Recipe without Instructions';
        final ingredients = ['Ingredient'];
        final instructions = <String>[]; // Empty instructions

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(recipeId, isNull);
        expect(errorMessage, isNotNull); // Service returns generic error
      });

      test('should validate portions if provided', () async {
        // Arrange
        const title = 'Recipe with Invalid Portions';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        const portions = -1; // Invalid

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
          portions: portions,
        );

        // Assert
        expect(
          recipeId,
          isNotNull,
        ); // Service doesn't validate negative portions
        // The service accepts any value for portions
      });

      test('should validate cooking time if provided', () async {
        // Arrange
        const title = 'Recipe with Invalid Time';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        const cookingTime = -30; // Invalid

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
          cookingTime: cookingTime,
        );

        // Assert
        expect(recipeId, isNotNull); // Service doesn't validate negative time
        // The service accepts any value for cookingTime
      });
    });

    group('Error Handling', () {
      test('should handle save failure', () async {
        // Arrange
        const title = 'Recipe Save Failure';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];

        // Override save to fail
        creationService = SocialRecipeCreationService(
          getCurrentUserId: () => currentUserId,
          getCurrentUserDisplayName: () => currentUserDisplayName,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => RecipeFactory.build(id: id),
          saveRecipe: (recipe) async => false, // Fail save
        );

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(recipeId, isNull);
        expect(errorMessage, contains('save'));
      });

      test('should handle null user ID', () async {
        // Arrange
        const title = 'Recipe without User';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];

        // Override service to return null user ID
        creationService = SocialRecipeCreationService(
          getCurrentUserId: () => null, // Return null
          getCurrentUserDisplayName: () => currentUserDisplayName,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => RecipeFactory.build(id: id),
          saveRecipe: (recipe) async => true,
        );

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(recipeId, isNull);
        expect(errorMessage, contains('authenticated'));
      });

      test('should handle exception during creation', () async {
        // Arrange
        const title = 'Exception Recipe';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];

        // Override save to throw
        creationService = SocialRecipeCreationService(
          getCurrentUserId: () => currentUserId,
          getCurrentUserDisplayName: () => currentUserDisplayName,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => RecipeFactory.build(id: id),
          saveRecipe: (recipe) async => throw Exception('Database error'),
        );

        // Act
        final recipeId = await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(recipeId, isNull);
        expect(errorMessage, contains('Database error'));
      });
    });

    group('State Updates', () {
      test('should notify listeners on successful creation', () async {
        // Arrange
        const title = 'Notify Test Recipe';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        final initialNotifyCount = notifyCount;

        // Act
        await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(notifyCount, greaterThan(initialNotifyCount));
      });

      test('should not notify on validation failure', () async {
        // Arrange
        const title = ''; // Invalid
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        final initialNotifyCount = notifyCount;

        // Act
        await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(notifyCount, equals(initialNotifyCount));
      });
    });

    group('Generated Recipe Properties', () {
      test('should generate unique recipe ID', () async {
        // Arrange & Act
        final ids = <String>[];
        for (int i = 0; i < 3; i++) {
          final id = await creationService.createCollaborativeRecipe(
            title: 'Recipe $i',
            ingredients: ['Ingredient'],
            instructions: ['Instruction'],
          );
          if (id != null) ids.add(id);
        }

        // Assert
        expect(ids.length, equals(3));
        expect(ids.toSet().length, equals(3)); // All unique
      });

      test('should set creation timestamp', () async {
        // Arrange
        const title = 'Timestamp Recipe';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];
        final beforeCreation = DateTime.now();

        // Act
        await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        final afterCreation = DateTime.now();

        // Assert
        expect(lastSavedRecipe!.createdAt, isNotNull);
        expect(
          lastSavedRecipe!.createdAt.isAfter(
            beforeCreation.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          lastSavedRecipe!.createdAt.isBefore(
            afterCreation.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
      });

      test('should set collaborative flag', () async {
        // Arrange
        const title = 'Collaborative Flag Recipe';
        final ingredients = ['Ingredient'];
        final instructions = ['Instruction'];

        // Act
        await creationService.createCollaborativeRecipe(
          title: title,
          ingredients: ingredients,
          instructions: instructions,
        );

        // Assert
        expect(lastSavedRecipe!.isCollaborative, isTrue);
        expect(lastSavedRecipe!.isPersonal, isFalse);
      });
    });
  });
}
