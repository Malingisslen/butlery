import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tag_override_log_entry.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/repositories/tag_overrides_log_repository.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

/// A real [TagOverridesLogRepository] subclass whose `save` never resolves, used
/// to prove the fire-and-forget capture can't block the synchronous edit result.
/// (A test double subclassing the concrete repo — NOT a mocktail Mock — so the
/// overridden body is legitimate.)
class _NeverCompletingLogRepository extends TagOverridesLogRepository {
  _NeverCompletingLogRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<void> save(TagOverrideLogEntry entry) => Completer<void>().future;
}

void main() {
  late TagEditingService service;

  setUp(() {
    service = TagEditingService();
  });

  TagResult createTagResult({
    Map<String, TriState>? allergenStatus,
    Map<String, TriState>? dietaryStatus,
    Set<String>? tags,
  }) {
    return TagResult(
      tags: tags ?? {'test-tag'},
      allergenStatus:
          allergenStatus ??
          {
            'gluten': TriState.contains,
            'dairy': TriState.free,
            'nuts': TriState.unknown,
          },
      dietaryStatus:
          dietaryStatus ??
          {
            'vegetarisk': TriState.free,
            'vegansk': TriState.contains,
          },
      coverage: 0.85,
      unknownIngredients: [],
      generatorVersion: '3.0.0',
      generatedAt: DateTime.now(),
    );
  }

  group('TagEditingService', () {
    group('applyAllergenOverride', () {
      test('requires confirmation when removing CONTAINS status', () {
        final recipe = RecipeBuilder().withTagResult(createTagResult()).build();

        final result = service.applyAllergenOverride(
          recipe: recipe,
          allergenKey: 'gluten',
          newStatus: TriState.free,
          editedBy: 'test_user',
        );

        expect(result.success, isFalse);
        expect(result.requiresConfirmation, isTrue);
        expect(result.allergenKey, 'gluten');
        expect(result.currentStatus, TriState.contains);
        expect(result.requestedStatus, TriState.free);
      });

      test('allows removing CONTAINS status when confirmed', () {
        final recipe = RecipeBuilder().withTagResult(createTagResult()).build();

        final result = service.applyAllergenOverride(
          recipe: recipe,
          allergenKey: 'gluten',
          newStatus: TriState.free,
          editedBy: 'test_user',
          userConfirmed: true,
        );

        expect(result.success, isTrue);
        expect(result.updatedRecipe, isNotNull);
        expect(
          result.updatedRecipe!.tagOverrides?.allergenOverrides['gluten'],
          TriState.free,
        );
      });

      test('allows setting FREE to CONTAINS without confirmation', () {
        final recipe = RecipeBuilder().withTagResult(createTagResult()).build();

        final result = service.applyAllergenOverride(
          recipe: recipe,
          allergenKey: 'dairy',
          newStatus: TriState.contains,
          editedBy: 'test_user',
        );

        expect(result.success, isTrue);
        expect(result.requiresConfirmation, isFalse);
        expect(
          result.updatedRecipe!.tagOverrides?.allergenOverrides['dairy'],
          TriState.contains,
        );
      });

      test('allows setting UNKNOWN to any status without confirmation', () {
        final recipe = RecipeBuilder().withTagResult(createTagResult()).build();

        final result = service.applyAllergenOverride(
          recipe: recipe,
          allergenKey: 'nuts',
          newStatus: TriState.free,
          editedBy: 'test_user',
        );

        expect(result.success, isTrue);
        expect(result.requiresConfirmation, isFalse);
      });

      test('tracks editedBy and timestamp', () {
        final recipe = RecipeBuilder().withTagResult(createTagResult()).build();

        final result = service.applyAllergenOverride(
          recipe: recipe,
          allergenKey: 'dairy',
          newStatus: TriState.contains,
          editedBy: 'test_user_123',
        );

        expect(result.success, isTrue);
        expect(
          result.updatedRecipe!.tagOverrides?.lastEditedBy,
          'test_user_123',
        );
        expect(
          result.updatedRecipe!.tagOverrides?.lastEditedAt,
          isNotNull,
        );
      });

      // BUT-1473: fire-and-forget capture of the correction into
      // `tag_overrides_log` via ServiceLocator.tryGet<TagOverridesLogRepository>.
      group('override capture (BUT-1473)', () {
        // The service reads the PRODUCTION ServiceLocator (DIContainer over
        // GetIt.instance). Bridging is safe here: applyAllergenOverride's only
        // locator touch is this repository.
        setUp(() {
          prod.ServiceLocator.initialize(DIContainer());
        });

        tearDown(() async {
          await GetIt.instance.reset();
          prod.ServiceLocator.reset();
        });

        Future<void> drainFireAndForget() async {
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        }

        test(
          'captures ONE log entry with the correct correction fields',
          () async {
            final fake = FakeFirebaseFirestore();
            GetIt.instance.registerSingleton<TagOverridesLogRepository>(
              TagOverridesLogRepository(firestore: fake),
            );

            final recipe = RecipeBuilder()
                .withId('recipe-42')
                .withTagResult(
                  TagResult(
                    tags: const {'test-tag'},
                    allergenStatus: const {'gluten': TriState.contains},
                    dietaryStatus: const {},
                    coverage: 1.0,
                    unknownIngredients: const [],
                    generatorVersion: '3.0.0',
                    generatedAt: DateTime.now(),
                    decisions: const [
                      TagDecision(
                        type: 'allergen',
                        key: 'gluten',
                        result: TriState.contains,
                        reason: "Ingredient 'vetemjöl' has property 'gluten'",
                        triggeringIngredients: ['vetemjöl', 'ströbröd'],
                      ),
                    ],
                  ),
                )
                .build();

            final result = service.applyAllergenOverride(
              recipe: recipe,
              allergenKey: 'gluten',
              newStatus: TriState.free,
              editedBy: 'chef_anna',
              userConfirmed: true,
            );

            expect(result.success, isTrue);

            await drainFireAndForget();

            final snapshot = await fake
                .collection(TagOverridesLogRepository.collectionName)
                .get();
            expect(snapshot.docs, hasLength(1));

            final data = snapshot.docs.first.data();
            expect(data['userId'], 'chef_anna');
            expect(data['recipeId'], 'recipe-42');
            expect(data['type'], 'allergen');
            expect(data['tag'], 'gluten');
            expect(data['direction'], 'contains->free');
            expect(
              data['triggeringIngredients'],
              ['vetemjöl', 'ströbröd'],
            );
          },
        );

        test(
          'is a no-op that never throws when no repository is registered',
          () async {
            // DIContainer initialized but no TagOverridesLogRepository → tryGet
            // resolves null (the fire-and-forget guard path).
            final recipe = RecipeBuilder()
                .withTagResult(createTagResult())
                .build();

            final result = service.applyAllergenOverride(
              recipe: recipe,
              allergenKey: 'gluten',
              newStatus: TriState.free,
              editedBy: 'chef_anna',
              userConfirmed: true,
            );

            await drainFireAndForget();

            // The edit still applies; the missing logger is silently skipped.
            expect(result.success, isTrue);
            expect(
              result.updatedRecipe!.tagOverrides?.allergenOverrides['gluten'],
              TriState.free,
            );
          },
        );

        test(
          'never blocks the edit — result returns without awaiting capture',
          () {
            // A repository whose save future never completes. If the edit
            // awaited capture, applyAllergenOverride could not return here.
            GetIt.instance.registerSingleton<TagOverridesLogRepository>(
              _NeverCompletingLogRepository(),
            );

            final recipe = RecipeBuilder()
                .withTagResult(createTagResult())
                .build();

            final result = service.applyAllergenOverride(
              recipe: recipe,
              allergenKey: 'gluten',
              newStatus: TriState.free,
              editedBy: 'chef_anna',
              userConfirmed: true,
            );

            expect(result.success, isTrue);
            expect(result.updatedRecipe, isNotNull);
            expect(
              result.updatedRecipe!.tagOverrides?.allergenOverrides['gluten'],
              TriState.free,
            );
          },
        );
      });
    });

    group('applyDietaryOverride', () {
      test('applies dietary override without confirmation', () {
        final recipe = RecipeBuilder().withTagResult(createTagResult()).build();

        final result = service.applyDietaryOverride(
          recipe: recipe,
          dietaryKey: 'vegetarisk',
          newStatus: TriState.contains,
          editedBy: 'test_user',
        );

        expect(result.success, isTrue);
        expect(
          result.updatedRecipe!.tagOverrides?.dietaryOverrides['vegetarisk'],
          TriState.contains,
        );
      });
    });

    group('addTag', () {
      test('adds a user-defined tag', () {
        final recipe = RecipeBuilder()
            .withTagResult(createTagResult(tags: {'original-tag'}))
            .build();

        final result = service.addTag(
          recipe: recipe,
          tag: 'user-tag',
          editedBy: 'test_user',
        );

        expect(result.success, isTrue);
        expect(
          result.updatedRecipe!.tagOverrides?.addedTags.contains('user-tag'),
          isTrue,
        );
      });

      test('removes tag from removedTags when adding', () {
        final recipe = RecipeBuilder()
            .withTagResult(createTagResult())
            .withTagOverrides(
              const TagOverrides(
                removedTags: {'removed-tag'},
              ),
            )
            .build();

        final result = service.addTag(
          recipe: recipe,
          tag: 'removed-tag',
          editedBy: 'test_user',
        );

        expect(result.success, isTrue);
        expect(
          result.updatedRecipe!.tagOverrides?.removedTags.contains(
            'removed-tag',
          ),
          isFalse,
        );
        expect(
          result.updatedRecipe!.tagOverrides?.addedTags.contains('removed-tag'),
          isTrue,
        );
      });
    });

    group('removeTag', () {
      test('removes a tag from display', () {
        final recipe = RecipeBuilder()
            .withTagResult(createTagResult(tags: {'auto-tag'}))
            .build();

        final result = service.removeTag(
          recipe: recipe,
          tag: 'auto-tag',
          editedBy: 'test_user',
        );

        expect(result.success, isTrue);
        expect(
          result.updatedRecipe!.tagOverrides?.removedTags.contains('auto-tag'),
          isTrue,
        );
      });
    });

    group('clearAllOverrides', () {
      test('clears all overrides', () {
        final recipe = RecipeBuilder()
            .withTagResult(createTagResult())
            .withTagOverrides(
              const TagOverrides(
                allergenOverrides: {'gluten': TriState.free},
                dietaryOverrides: {'vegansk': TriState.free},
                addedTags: {'user-tag'},
                removedTags: {'auto-tag'},
              ),
            )
            .build();

        final result = service.clearAllOverrides(
          recipe: recipe,
          editedBy: 'test_user',
        );

        expect(result.success, isTrue);
        final overrides = result.updatedRecipe!.tagOverrides;
        expect(overrides?.allergenOverrides, isEmpty);
        expect(overrides?.dietaryOverrides, isEmpty);
        expect(overrides?.addedTags, isEmpty);
        expect(overrides?.removedTags, isEmpty);
      });
    });

    group('getEffectiveAllergenStatus', () {
      test('returns auto-generated status when no override', () {
        final recipe = RecipeBuilder().withTagResult(createTagResult()).build();

        final status = service.getEffectiveAllergenStatus(recipe, 'gluten');
        expect(status, TriState.contains);
      });

      test('returns override status when present', () {
        final recipe = RecipeBuilder()
            .withTagResult(createTagResult())
            .withTagOverrides(
              const TagOverrides(
                allergenOverrides: {'gluten': TriState.free},
              ),
            )
            .build();

        final status = service.getEffectiveAllergenStatus(recipe, 'gluten');
        expect(status, TriState.free);
      });
    });

    group('getEffectiveTags', () {
      test('merges auto-generated and user tags', () {
        final recipe = RecipeBuilder()
            .withTagResult(createTagResult(tags: {'auto-tag-1', 'auto-tag-2'}))
            .withTagOverrides(
              const TagOverrides(
                addedTags: {'user-tag'},
                removedTags: {'auto-tag-2'},
              ),
            )
            .build();

        final tags = service.getEffectiveTags(recipe);
        expect(tags, contains('auto-tag-1'));
        expect(tags, contains('user-tag'));
        expect(tags, isNot(contains('auto-tag-2')));
      });
    });

    group('hasManualEdits', () {
      test('returns false when no overrides', () {
        final recipe = RecipeBuilder().withTagResult(createTagResult()).build();

        expect(service.hasManualEdits(recipe), isFalse);
      });

      test('returns true when overrides exist', () {
        final recipe = RecipeBuilder()
            .withTagResult(createTagResult())
            .withTagOverrides(
              const TagOverrides(
                allergenOverrides: {'gluten': TriState.free},
              ),
            )
            .build();

        expect(service.hasManualEdits(recipe), isTrue);
      });
    });

    group('getEffectiveTagData', () {
      test('merges all tag data with overrides', () {
        final recipe = RecipeBuilder()
            .withTagResult(
              createTagResult(
                tags: {'auto-tag'},
                allergenStatus: {'gluten': TriState.contains},
                dietaryStatus: {'vegetarisk': TriState.free},
              ),
            )
            .withTagOverrides(
              const TagOverrides(
                allergenOverrides: {'gluten': TriState.unknown},
                addedTags: {'user-tag'},
              ),
            )
            .build();

        final data = service.getEffectiveTagData(recipe);

        expect(data.tags, contains('auto-tag'));
        expect(data.tags, contains('user-tag'));
        expect(data.allergenStatus['gluten'], TriState.unknown);
        expect(data.dietaryStatus['vegetarisk'], TriState.free);
        expect(data.hasManualEdits, isTrue);
      });

      test('returns empty data when no tagResult', () {
        final recipe = RecipeBuilder().build();

        final data = service.getEffectiveTagData(recipe);

        expect(data.tags, isEmpty);
        expect(data.allergenStatus, isEmpty);
        expect(data.hasManualEdits, isFalse);
      });
    });
  });
}
