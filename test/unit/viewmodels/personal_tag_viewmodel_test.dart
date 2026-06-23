import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('PersonalTagViewModel', () {
    late PersonalTagViewModel viewModel;
    late MockPersonalTagService mockService;
    late MockRecipeRepository mockRecipeRepo;
    late FakePermissionService mockPermissionService;
    late StreamController<PersonalTagsWithGroups> tagsStreamController;

    // Test data
    final now = DateTime(2026, 1, 15);

    final testTag1 = PersonalTag(
      id: 'tag-1',
      name: 'Favoriter',
      createdAt: now,
      updatedAt: now,
      sortOrder: 0,
    );

    final testTag2 = PersonalTag(
      id: 'tag-2',
      name: 'Snabbt',
      createdAt: now,
      updatedAt: now,
      sortOrder: 1,
      groupId: 'group-1',
    );

    final testRule = PersonalTagRule(
      id: 'rule-1',
      tagId: 'tag-3',
      name: 'Fish rule',
      conditions: const [],
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    );

    final testTagWithRule = PersonalTag(
      id: 'tag-3',
      name: 'Fisk',
      createdAt: now,
      updatedAt: now,
      sortOrder: 2,
      rules: [testRule],
    );

    final testGroup = PersonalTagGroup(
      id: 'group-1',
      name: 'Svårighetsgrad',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // Register fallback values for mocktail's any() matcher
      registerFallbackValue(
        PersonalTag(
          id: 'fallback',
          name: 'fallback',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      );
      registerFallbackValue(
        PersonalTagGroup(
          id: 'fallback',
          name: 'fallback',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      );
      registerFallbackValue(
        PersonalTagRule(
          id: 'fallback',
          name: 'fallback',
          conditions: const [],
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      );
      registerFallbackValue(<Recipe>[]);
    });

    setUp(() async {
      await TestServiceLocator.reset();
      await TestServiceLocator.initialize();

      // Bridge production ServiceLocator to test mocks
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      mockService = MockPersonalTagService();
      mockRecipeRepo = MockRecipeRepository();
      mockPermissionService = FakePermissionService();
      tagsStreamController =
          StreamController<PersonalTagsWithGroups>.broadcast();

      // Register in ServiceLocator (needed for internal lookups)
      TestServiceLocator.registerMock<RecipeRepository>(mockRecipeRepo);
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

      // Default stubs
      when(() => mockService.getAllTags()).thenAnswer((_) async => []);
      when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
      when(
        () => mockService.watchTagsWithGroups(),
      ).thenAnswer((_) => tagsStreamController.stream);

      viewModel = PersonalTagViewModel(service: mockService);
    });

    tearDown(() async {
      viewModel.dispose();
      await tagsStreamController.close();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // ---- Initialization ----

    group('initialization', () {
      test('should start with empty state before initialize', () {
        expect(viewModel.tags, isEmpty);
        expect(viewModel.groups, isEmpty);
        expect(viewModel.isLoading, false);
        expect(viewModel.hasError, false);
        expect(viewModel.selectedTagId, isNull);
        expect(viewModel.hasTags, false);
        expect(viewModel.hasGroups, false);
      });

      test('should load tags and groups on initialize', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1, testTag2]);
        when(
          () => mockService.getAllGroups(),
        ).thenAnswer((_) async => [testGroup]);

        await viewModel.initialize();

        expect(viewModel.tags, hasLength(2));
        expect(viewModel.groups, hasLength(1));
        expect(viewModel.hasTags, true);
        expect(viewModel.hasGroups, true);
        expect(viewModel.isLoading, false);
        expect(viewModel.hasError, false);
      });

      test('should subscribe to stream after initialize', () async {
        await viewModel.initialize();

        verify(() => mockService.watchTagsWithGroups()).called(1);
      });

      test('should update state when stream emits data', () async {
        await viewModel.initialize();

        tagsStreamController.add(
          PersonalTagsWithGroups(
            groups: [testGroup],
            tagsByGroup: {
              'group-1': [testTag2],
              null: [testTag1],
            },
            ungroupedTags: [testTag1],
          ),
        );

        // Allow stream event to propagate
        await Future.delayed(Duration.zero);

        expect(viewModel.tags, hasLength(2));
        expect(viewModel.groups, hasLength(1));
      });

      test('should set error on stream error', () async {
        await viewModel.initialize();

        tagsStreamController.addError(Exception('Stream failed'));

        await Future.delayed(Duration.zero);

        expect(viewModel.hasError, true);
      });
    });

    // ---- Tag CRUD ----

    group('tag CRUD', () {
      test('should return true when createTag succeeds', () async {
        when(
          () => mockService.getNextTagSortOrder(),
        ).thenAnswer((_) async => 0);
        when(
          () => mockService.createTag(any()),
        ).thenAnswer((_) async => testTag1);

        final result = await viewModel.createTag(name: 'Favoriter');

        expect(result, true);
        verify(() => mockService.createTag(any())).called(1);
      });

      test('should return false when createTag returns null', () async {
        when(
          () => mockService.getNextTagSortOrder(),
        ).thenAnswer((_) async => 0);
        when(() => mockService.createTag(any())).thenAnswer((_) async => null);

        final result = await viewModel.createTag(name: 'Favoriter');

        expect(result, false);
        expect(viewModel.hasError, true);
      });

      test('should return false when createTag throws', () async {
        when(
          () => mockService.getNextTagSortOrder(),
        ).thenAnswer((_) async => 0);
        when(
          () => mockService.createTag(any()),
        ).thenThrow(Exception('Firestore error'));

        final result = await viewModel.createTag(name: 'Favoriter');

        expect(result, false);
        expect(viewModel.hasError, true);
      });

      test('should pass groupId when creating tag in group', () async {
        when(
          () => mockService.getNextTagSortOrder(),
        ).thenAnswer((_) async => 1);
        when(
          () => mockService.createTag(any()),
        ).thenAnswer((_) async => testTag2);

        await viewModel.createTag(name: 'Snabbt', groupId: 'group-1');

        final captured = verify(
          () => mockService.createTag(captureAny()),
        ).captured;
        final createdTag = captured.first as PersonalTag;
        expect(createdTag.groupId, 'group-1');
      });

      test('should return true when updateTag succeeds', () async {
        when(() => mockService.updateTag(any())).thenAnswer((_) async {});

        final result = await viewModel.updateTag(testTag1);

        expect(result, true);
        verify(() => mockService.updateTag(testTag1)).called(1);
      });

      test('should return false when updateTag throws', () async {
        when(
          () => mockService.updateTag(any()),
        ).thenThrow(Exception('Update failed'));

        final result = await viewModel.updateTag(testTag1);

        expect(result, false);
        expect(viewModel.hasError, true);
      });

      test(
        'should return true when deleteTag succeeds with known tag',
        () async {
          // Populate viewModel with tags first
          when(
            () => mockService.getAllTags(),
          ).thenAnswer((_) async => [testTag1]);
          when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
          await viewModel.initialize();

          when(() => mockService.deleteTag('tag-1')).thenAnswer((_) async {});

          final result = await viewModel.deleteTag('tag-1');

          expect(result, true);
          verify(() => mockService.deleteTag('tag-1')).called(1);
        },
      );

      test(
        'should return false when deleteTag called with unknown id',
        () async {
          final result = await viewModel.deleteTag('nonexistent');

          expect(result, false);
          expect(viewModel.hasError, true);
          verifyNever(() => mockService.deleteTag(any()));
        },
      );

      test('should return true when reorderTags succeeds', () async {
        when(() => mockService.reorderTags(any())).thenAnswer((_) async {});

        final result = await viewModel.reorderTags(['tag-2', 'tag-1']);

        expect(result, true);
      });

      test('should return true when moveTagToGroup succeeds', () async {
        when(
          () => mockService.moveTagToGroup(any(), any()),
        ).thenAnswer((_) async {});

        final result = await viewModel.moveTagToGroup('tag-1', 'group-1');

        expect(result, true);
        verify(() => mockService.moveTagToGroup('tag-1', 'group-1')).called(1);
      });
    });

    // ---- Group CRUD ----

    group('group CRUD', () {
      test('should return true when createGroup succeeds', () async {
        when(
          () => mockService.getNextGroupSortOrder(),
        ).thenAnswer((_) async => 0);
        when(
          () => mockService.createGroup(any()),
        ).thenAnswer((_) async => testGroup);

        final result = await viewModel.createGroup(name: 'Svårighetsgrad');

        expect(result, true);
        verify(() => mockService.createGroup(any())).called(1);
      });

      test('should return false when createGroup returns null', () async {
        when(
          () => mockService.getNextGroupSortOrder(),
        ).thenAnswer((_) async => 0);
        when(
          () => mockService.createGroup(any()),
        ).thenAnswer((_) async => null);

        final result = await viewModel.createGroup(name: 'Test');

        expect(result, false);
        expect(viewModel.hasError, true);
      });

      test('should return true when updateGroup succeeds', () async {
        when(() => mockService.updateGroup(any())).thenAnswer((_) async {});

        final result = await viewModel.updateGroup(testGroup);

        expect(result, true);
      });

      test('should return false when updateGroup throws', () async {
        when(
          () => mockService.updateGroup(any()),
        ).thenThrow(Exception('Update failed'));

        final result = await viewModel.updateGroup(testGroup);

        expect(result, false);
        expect(viewModel.hasError, true);
      });

      test(
        'should return true when deleteGroup succeeds with known group',
        () async {
          when(() => mockService.getAllTags()).thenAnswer((_) async => []);
          when(
            () => mockService.getAllGroups(),
          ).thenAnswer((_) async => [testGroup]);
          await viewModel.initialize();

          when(
            () => mockService.deleteGroup('group-1'),
          ).thenAnswer((_) async {});

          final result = await viewModel.deleteGroup('group-1');

          expect(result, true);
          verify(() => mockService.deleteGroup('group-1')).called(1);
        },
      );

      test(
        'should return false when deleteGroup called with unknown id',
        () async {
          final result = await viewModel.deleteGroup('nonexistent');

          expect(result, false);
          expect(viewModel.hasError, true);
          verifyNever(() => mockService.deleteGroup(any()));
        },
      );

      test('should return true when reorderGroups succeeds', () async {
        when(() => mockService.reorderGroups(any())).thenAnswer((_) async {});

        final result = await viewModel.reorderGroups(['group-2', 'group-1']);

        expect(result, true);
      });
    });

    // ---- Rule CRUD ----

    group('rule CRUD', () {
      test('should return true when createRule succeeds', () async {
        when(
          () => mockService.addRuleToTag(any(), any()),
        ).thenAnswer((_) async {});

        final result = await viewModel.createRule('tag-1', testRule);

        expect(result, true);
        verify(() => mockService.addRuleToTag('tag-1', testRule)).called(1);
      });

      test('should return false when createRule throws', () async {
        when(
          () => mockService.addRuleToTag(any(), any()),
        ).thenThrow(Exception('Rule creation failed'));

        final result = await viewModel.createRule('tag-1', testRule);

        expect(result, false);
        expect(viewModel.hasError, true);
      });

      test('should return true when updateRule succeeds', () async {
        when(
          () => mockService.updateRuleInTag(any(), any()),
        ).thenAnswer((_) async {});

        final result = await viewModel.updateRule('tag-1', testRule);

        expect(result, true);
        verify(() => mockService.updateRuleInTag('tag-1', testRule)).called(1);
      });

      test('should return false when updateRule throws', () async {
        when(
          () => mockService.updateRuleInTag(any(), any()),
        ).thenThrow(Exception('Update failed'));

        final result = await viewModel.updateRule('tag-1', testRule);

        expect(result, false);
        expect(viewModel.hasError, true);
      });

      test('should return true when deleteRule succeeds', () async {
        when(
          () => mockService.removeRuleFromTag(any(), any()),
        ).thenAnswer((_) async {});

        final result = await viewModel.deleteRule('tag-1', 'rule-1');

        expect(result, true);
        verify(
          () => mockService.removeRuleFromTag('tag-1', 'rule-1'),
        ).called(1);
      });

      test('should return false when deleteRule throws', () async {
        when(
          () => mockService.removeRuleFromTag(any(), any()),
        ).thenThrow(Exception('Delete failed'));

        final result = await viewModel.deleteRule('tag-1', 'rule-1');

        expect(result, false);
        expect(viewModel.hasError, true);
      });

      test('should toggle rule enabled state', () async {
        // Populate viewModel with tag that has a rule
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTagWithRule]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        when(
          () => mockService.setRuleEnabled(
            any(),
            any(),
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async {});

        final result = await viewModel.toggleRuleEnabled('tag-3', 'rule-1');

        expect(result, true);
        // Rule was enabled, so toggle should set enabled: false
        verify(
          () => mockService.setRuleEnabled(
            'tag-3',
            'rule-1',
            enabled: false,
          ),
        ).called(1);
      });

      test('should return false when toggling rule for unknown tag', () async {
        final result = await viewModel.toggleRuleEnabled(
          'nonexistent',
          'rule-1',
        );

        expect(result, false);
      });

      test('should return false when toggling unknown rule', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTagWithRule]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        final result = await viewModel.toggleRuleEnabled(
          'tag-3',
          'nonexistent',
        );

        expect(result, false);
      });
    });

    // ---- Merge (BUT-1188) ----

    group('mergeTagsInto', () {
      test(
        'merges N>2 sources into the target sequentially in order',
        () async {
          final calls = <String>[];
          when(() => mockService.mergeTags(any(), any())).thenAnswer((
            inv,
          ) async {
            calls.add(inv.positionalArguments[0] as String);
            return 1; // recipes retagged (ignored by the tags-merged metric)
          });

          final merged = await viewModel.mergeTagsInto(
            'target',
            ['a', 'b', 'c'],
          );

          expect(merged, 3, reason: 'count is source tags merged, not recipes');
          expect(calls, [
            'a',
            'b',
            'c',
          ], reason: 'sequential, preserving order');
          verify(() => mockService.mergeTags('a', 'target')).called(1);
          verify(() => mockService.mergeTags('b', 'target')).called(1);
          verify(() => mockService.mergeTags('c', 'target')).called(1);
        },
      );

      test('never merges the target into itself', () async {
        when(
          () => mockService.mergeTags(any(), any()),
        ).thenAnswer((_) async => 0);

        final merged = await viewModel.mergeTagsInto(
          'target',
          ['a', 'target', 'b'],
        );

        expect(merged, 2);
        verifyNever(() => mockService.mergeTags('target', 'target'));
        verify(() => mockService.mergeTags('a', 'target')).called(1);
        verify(() => mockService.mergeTags('b', 'target')).called(1);
      });

      test('propagates a mid-loop failure (partial merge surfaces)', () async {
        final calls = <String>[];
        when(() => mockService.mergeTags(any(), any())).thenAnswer((inv) async {
          final from = inv.positionalArguments[0] as String;
          calls.add(from);
          if (from == 'b') throw Exception('Firestore error');
          return 1;
        });

        await expectLater(
          viewModel.mergeTagsInto('target', ['a', 'b', 'c']),
          throwsException,
        );

        // 'a' committed, 'b' threw and aborted the loop -> 'c' never ran.
        expect(calls, ['a', 'b']);
        verifyNever(() => mockService.mergeTags('c', 'target'));
      });

      test('filters out empty and duplicate source ids', () async {
        final calls = <String>[];
        when(() => mockService.mergeTags(any(), any())).thenAnswer((inv) async {
          calls.add(inv.positionalArguments[0] as String);
          return 1;
        });

        final merged = await viewModel.mergeTagsInto(
          'target',
          ['a', '', 'a', 'b', 'target', ''],
        );

        expect(
          merged,
          2,
          reason: 'a + b once each; empties/dupes/target dropped',
        );
        expect(calls.toSet(), {'a', 'b'});
        expect(calls.length, 2);
      });

      test('returns 0 when no valid sources remain', () async {
        final merged = await viewModel.mergeTagsInto('target', ['target', '']);

        expect(merged, 0);
        verifyNever(() => mockService.mergeTags(any(), any()));
      });
    });

    // ---- Selection ----

    group('selection', () {
      test('should set selectedTagId on selectTag', () {
        viewModel.selectTag('tag-1');

        expect(viewModel.selectedTagId, 'tag-1');
      });

      test('should clear selectedTagId on selectTag(null)', () {
        viewModel.selectTag('tag-1');
        viewModel.selectTag(null);

        expect(viewModel.selectedTagId, isNull);
      });

      test('should resolve selectedTag from tags list', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1, testTag2]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        viewModel.selectTag('tag-1');

        expect(viewModel.selectedTag, isNotNull);
        expect(viewModel.selectedTag!.name, 'Favoriter');
      });

      test('should return null selectedTag when id not found', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        viewModel.selectTag('nonexistent');

        expect(viewModel.selectedTag, isNull);
      });

      test('should return selected tag rules', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTagWithRule]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        viewModel.selectTag('tag-3');

        expect(viewModel.selectedTagRules, hasLength(1));
        expect(viewModel.selectedTagRules.first.name, 'Fish rule');
      });

      test('should return empty rules when no tag selected', () {
        expect(viewModel.selectedTagRules, isEmpty);
      });

      test('should notify listeners on selectTag', () async {
        int notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        viewModel.selectTag('tag-1');

        expect(notifyCount, 1);
      });
    });

    // ---- Lookup helpers ----

    group('lookup helpers', () {
      setUp(() async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1, testTag2, testTagWithRule]);
        when(
          () => mockService.getAllGroups(),
        ).thenAnswer((_) async => [testGroup]);
        await viewModel.initialize();
      });

      test('should find tag by id', () {
        expect(viewModel.getTagById('tag-1')?.name, 'Favoriter');
        expect(viewModel.getTagById('nonexistent'), isNull);
      });

      test('should find tag by name', () {
        expect(viewModel.getTagByName('favoriter')?.id, 'tag-1');
        expect(viewModel.getTagByName('  Favoriter  ')?.id, 'tag-1');
        expect(viewModel.getTagByName('nonexistent'), isNull);
      });

      test('should find group by id', () {
        expect(viewModel.getGroupById('group-1')?.name, 'Svårighetsgrad');
        expect(viewModel.getGroupById('nonexistent'), isNull);
      });

      test('should get tags for group', () {
        final groupTags = viewModel.getTagsForGroup('group-1');
        expect(groupTags, hasLength(1));
        expect(groupTags.first.name, 'Snabbt');
      });

      test('should get rules for tag', () {
        final rules = viewModel.getRulesForTag('tag-3');
        expect(rules, hasLength(1));
        expect(rules.first.name, 'Fish rule');
      });

      test('should return empty rules for tag without rules', () {
        final rules = viewModel.getRulesForTag('tag-1');
        expect(rules, isEmpty);
      });

      test('should get enabled rules across all tags', () {
        expect(viewModel.enabledRules, hasLength(1));
        expect(viewModel.enabledRules.first.name, 'Fish rule');
      });
    });

    // ---- Statistics ----

    group('statistics', () {
      test('should set isLoadingStats during loadTagStatistics', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        mockPermissionService.setPermissionState(
          currentUserId: 'user-1',
        );
        when(
          () => mockRecipeRepo.fetchAllUserRecipes('user-1'),
        ).thenAnswer((_) async => []);

        bool wasLoadingStats = false;
        viewModel.addListener(() {
          if (viewModel.isLoadingStats) {
            wasLoadingStats = true;
          }
        });

        await viewModel.loadTagStatistics();

        expect(wasLoadingStats, true);
        expect(viewModel.isLoadingStats, false);
      });

      test('should populate tagUsageCounts from recipes', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1, testTag2]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        mockPermissionService.setPermissionState(currentUserId: 'user-1');

        final mockRecipe1 = _createMockRecipe('r1', personalTagIds: ['tag-1']);
        final mockRecipe2 = _createMockRecipe(
          'r2',
          personalTagIds: ['tag-1', 'tag-2'],
        );
        when(
          () => mockRecipeRepo.fetchAllUserRecipes('user-1'),
        ).thenAnswer((_) async => [mockRecipe1, mockRecipe2]);

        await viewModel.loadTagStatistics();

        expect(viewModel.tagUsageCounts['Favoriter'], 2);
        expect(viewModel.tagUsageCounts['Snabbt'], 1);
      });

      test('should skip loadTagStatistics when no tags', () async {
        // viewModel has no tags (default empty setUp)
        await viewModel.loadTagStatistics();

        verifyNever(() => mockRecipeRepo.fetchAllUserRecipes(any()));
      });

      test('should return 0 for getUsageCount of unknown tag', () async {
        expect(viewModel.getUsageCount('Unknown'), 0);
      });

      test('should return 0 for getRuleMatchCount of unknown rule', () {
        expect(viewModel.getRuleMatchCount('nonexistent'), 0);
      });
    });

    // ---- Batch apply ----

    group('batch apply', () {
      test('should return zero-result when no recipes exist', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        mockPermissionService.setPermissionState(currentUserId: 'user-1');
        when(
          () => mockRecipeRepo.fetchAllUserRecipes('user-1'),
        ).thenAnswer((_) async => []);
        when(
          () => mockService.getCurrentTagVersion(),
        ).thenAnswer((_) async => 100);
        when(
          () => mockService.evaluateRulesWithSourcesForRecipes(any()),
        ).thenAnswer((_) async => {});

        final result = await viewModel.applyRulesToExistingRecipes();

        expect(result.recipesProcessed, 0);
        expect(result.recipesModified, 0);
        expect(result.tagsApplied, 0);
        expect(result.hasChanges, false);
      });

      test('should return result when no rules match', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        mockPermissionService.setPermissionState(currentUserId: 'user-1');
        final recipe = _createMockRecipe('r1');
        when(
          () => mockRecipeRepo.fetchAllUserRecipes('user-1'),
        ).thenAnswer((_) async => [recipe]);
        when(
          () => mockService.getCurrentTagVersion(),
        ).thenAnswer((_) async => 100);
        when(
          () => mockService.evaluateRulesWithSourcesForRecipes(any()),
        ).thenAnswer((_) async => {});

        final result = await viewModel.applyRulesToExistingRecipes();

        expect(result.recipesProcessed, 1);
        expect(result.recipesModified, 0);
        expect(result.tagsApplied, 0);
      });

      test('should return empty result when userId is null', () async {
        when(
          () => mockService.getAllTags(),
        ).thenAnswer((_) async => [testTag1]);
        when(() => mockService.getAllGroups()).thenAnswer((_) async => []);
        await viewModel.initialize();

        // No userId set on permission service
        mockPermissionService.setPermissionState(currentUserId: null);
        when(
          () => mockService.getCurrentTagVersion(),
        ).thenAnswer((_) async => 100);
        when(
          () => mockService.evaluateRulesWithSourcesForRecipes(any()),
        ).thenAnswer((_) async => {});

        final result = await viewModel.applyRulesToExistingRecipes();

        expect(result.recipesProcessed, 0);
      });
    });

    // ---- Dispose ----

    group('dispose', () {
      test('should not notify listeners after dispose', () async {
        // Create a separate viewModel for dispose test to avoid double-dispose in tearDown
        final disposableViewModel = PersonalTagViewModel(service: mockService);
        await disposableViewModel.initialize();

        int notifyCount = 0;
        disposableViewModel.addListener(() => notifyCount++);
        disposableViewModel.dispose();

        // Emit on stream after dispose -- should not crash or notify
        tagsStreamController.add(
          PersonalTagsWithGroups(
            groups: [],
            tagsByGroup: {null: []},
            ungroupedTags: [],
          ),
        );

        await Future.delayed(Duration.zero);

        expect(notifyCount, 0);
      });
    });

    // ---- Tag name validation ----

    group('tag name validation', () {
      test('should delegate tagNameExists to service', () async {
        when(
          () => mockService.tagNameExists(
            any(),
            excludeId: any(named: 'excludeId'),
          ),
        ).thenAnswer((_) async => true);

        final result = await viewModel.tagNameExists('Favoriter');

        expect(result, true);
        verify(() => mockService.tagNameExists('Favoriter')).called(1);
      });

      test('should delegate tagNameExists with excludeId', () async {
        when(
          () => mockService.tagNameExists(
            any(),
            excludeId: any(named: 'excludeId'),
          ),
        ).thenAnswer((_) async => false);

        final result = await viewModel.tagNameExists(
          'Favoriter',
          excludeId: 'tag-1',
        );

        expect(result, false);
        verify(
          () => mockService.tagNameExists('Favoriter', excludeId: 'tag-1'),
        ).called(1);
      });
    });
  });
}

/// Helper to create a minimal mock Recipe for statistics tests.
Recipe _createMockRecipe(
  String id, {
  List<String>? personalTagIds,
}) {
  return RecipeFactory.build(
    id: id,
    title: 'Test Recipe $id',
    personalTagIds: personalTagIds ?? [],
  );
}
