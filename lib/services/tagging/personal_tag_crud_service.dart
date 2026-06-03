import 'package:clock/clock.dart';
import 'dart:async';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Handles CRUD operations for personal tags, groups, and embedded rules.
///
/// Extracted from PersonalTagService to keep each service under 500 lines.
/// Includes tag/group lifecycle, rule management within tags, and
/// cascade operations (rename/delete propagation to recipes).
class PersonalTagCrudService extends BaseService {
  final FirebasePersonalTagRepository _tagRepository;
  final FirebasePersonalTagGroupRepository _groupRepository;

  static const String tagsCacheKey = 'personal_tags';
  static const String groupsCacheKey = 'personal_groups';

  /// Serializes createTag calls to prevent TOCTOU race on name uniqueness.
  Completer<void>? _createTagLock;

  /// BUT-1055: lightweight invalidation signal. Emits once per tag-set
  /// mutation (every write that clears [tagsCacheKey]). Consumers subscribe
  /// to this instead of holding an always-on Firestore `.snapshots()`
  /// listener — on each event they re-`getAllTags()` (cache was just cleared,
  /// so the read is fresh). Broadcast so any number of widgets can listen.
  final StreamController<void> _tagsMutatedController =
      StreamController<void>.broadcast();

  /// Fires after every tag CRUD mutation. See [_invalidateTagsCache].
  Stream<void> get tagsMutated => _tagsMutatedController.stream;

  PersonalTagCrudService({
    required FirebasePersonalTagRepository tagRepository,
    required FirebasePersonalTagGroupRepository groupRepository,
  })  : _tagRepository = tagRepository,
        _groupRepository = groupRepository;

  @override
  String get serviceName => 'PersonalTagCrudService';

  /// Clears the tag-set cache and notifies [tagsMutated] subscribers. Order
  /// matters: the cache is cleared BEFORE the event fires, so a consumer that
  /// re-reads via `getAllTags()` in response gets fresh data, not the stale
  /// pre-mutation snapshot.
  void _invalidateTagsCache() {
    clearCache(tagsCacheKey);
    if (!_tagsMutatedController.isClosed) {
      _tagsMutatedController.add(null);
    }
  }

  @override
  Future<void> onDispose() async {
    await _tagsMutatedController.close();
    await super.onDispose();
  }

  // -- Tag CRUD --

  Future<PersonalTag?> createTag(PersonalTag tag) async {
    // Serialize concurrent creates to prevent duplicate names (TOCTOU)
    while (_createTagLock != null) {
      await _createTagLock!.future;
    }
    _createTagLock = Completer<void>();

    try {
      return await executeServiceOperation(
        () async {
          final nameValidation = PersonalTag.validateName(tag.name);
          if (nameValidation != null) {
            throw ArgumentError(nameValidation);
          }

          if (await _tagRepository.nameExists(tag.name)) {
            throw ArgumentError(AppLocale.current.errorTagNameExists(tag.name));
          }

          if (tag.groupId != null) {
            final group = await _groupRepository.read(tag.groupId!);
            if (group == null) {
              throw ArgumentError(AppLocale.current.errorGroupDoesNotExist);
            }
          }

          await _tagRepository.create(tag);
          _invalidateTagsCache();
          AppLogger.info('Created personal tag: ${tag.name}');
          return tag;
        },
        operationName: 'Create personal tag',
        requiresAuth: true,
      );
    } finally {
      _createTagLock!.complete();
      _createTagLock = null;
    }
  }

  Future<PersonalTag?> getTag(String tagId) async {
    return await executeServiceOperation<PersonalTag?>(
      () async => await _tagRepository.read(tagId),
      operationName: 'Get personal tag',
      requiresAuth: true,
    );
  }

  Future<List<PersonalTag>> getAllTags() async {
    return await getCachedOrExecute(
          tagsCacheKey,
          () => _tagRepository.getAllSorted(),
          cacheDuration: const Duration(minutes: 5),
        ) ??
        [];
  }

  Future<void> updateTag(PersonalTag tag) async {
    await executeServiceOperation(
      () async {
        final nameValidation = PersonalTag.validateName(tag.name);
        if (nameValidation != null) {
          throw ArgumentError(nameValidation);
        }

        if (await _tagRepository.nameExists(tag.name, excludeId: tag.id)) {
          throw ArgumentError(AppLocale.current.errorTagNameExists(tag.name));
        }

        if (tag.groupId != null) {
          final group = await _groupRepository.read(tag.groupId!);
          if (group == null) {
            throw ArgumentError(AppLocale.current.errorGroupDoesNotExist);
          }
        }

        // Detect name change and cascade to recipes BEFORE updating tag
        final existingTag = await _tagRepository.read(tag.id);
        final oldName = existingTag?.name;
        final nameChanged = oldName != null && oldName != tag.name;

        // Update authoritative tag document first — if this fails, nothing changes
        final updated = tag.copyWith(updatedAt: clock.now());
        await _tagRepository.update(updated);

        // Then cascade name to recipes — stale recipe names are recoverable via retag
        if (nameChanged) {
          final recipeRepo = _getRecipeRepository();
          if (recipeRepo != null) {
            final count = await recipeRepo.renamePersonalTagInRecipes(
              tag.id,
              tag.name,
            );
            if (count > 0) {
              AppLogger.info(
                'Cascaded tag rename "$oldName" -> "${tag.name}" to $count recipes',
              );
            }
          }
        }

        _invalidateTagsCache();
        AppLogger.info('Updated personal tag: ${tag.name}');
      },
      operationName: 'Update personal tag',
      requiresAuth: true,
    );
  }

  Future<void> deleteTag(String tagId) async {
    await executeServiceOperation(
      () async {
        final batch = _tagRepository.newWriteBatch();

        final recipeRepo = _getFirebaseRecipeRepository();
        int cascadeCount = 0;
        if (recipeRepo != null) {
          cascadeCount =
              await recipeRepo.addRemovePersonalTagFromRecipesToBatch(
            batch,
            tagId,
          );
        }

        _tagRepository.addDeleteToBatch(batch, tagId);
        await batch.commit();

        if (cascadeCount > 0) {
          AppLogger.info(
            'Atomically deleted tag "$tagId" and cascaded to $cascadeCount recipes',
          );
        }

        _invalidateTagsCache();
        AppLogger.info('Deleted personal tag: $tagId');
      },
      operationName: 'Delete personal tag',
      requiresAuth: true,
    );
  }

  /// BUT-994: bulk-delete multiple tags in one atomic batch — each tag's
  /// recipe-cascade pulls + the tag-doc deletes share the same WriteBatch,
  /// so either every cascade lands or none do.
  ///
  /// Chunks at 100 tags per batch as a safety margin under the Firestore
  /// 500-op limit (each tag may cascade to many recipes; 100 tags × ~4
  /// cascaded recipes each = ~400 ops, comfortably under 500).
  ///
  /// Returns total tag count deleted across all chunks. Per-tag cascade
  /// counts are logged but not surfaced — the caller wanted a bulk-clean,
  /// not a per-tag audit.
  Future<int> bulkDeleteTags(List<String> tagIds) async {
    if (tagIds.isEmpty) return 0;
    final result = await executeServiceOperation<int>(
      () async {
        const chunkSize = 100;
        final recipeRepo = _getFirebaseRecipeRepository();
        var totalDeleted = 0;
        var totalCascaded = 0;

        for (var i = 0; i < tagIds.length; i += chunkSize) {
          final chunk = tagIds.sublist(
            i,
            i + chunkSize > tagIds.length ? tagIds.length : i + chunkSize,
          );
          final batch = _tagRepository.newWriteBatch();
          for (final tagId in chunk) {
            if (recipeRepo != null) {
              totalCascaded +=
                  await recipeRepo.addRemovePersonalTagFromRecipesToBatch(
                batch,
                tagId,
              );
            }
            _tagRepository.addDeleteToBatch(batch, tagId);
          }
          await batch.commit();
          totalDeleted += chunk.length;
        }

        _invalidateTagsCache();
        AppLogger.info(
          'Bulk-deleted $totalDeleted tags; cascaded to $totalCascaded recipe rows',
        );
        return totalDeleted;
      },
      operationName: 'Bulk-delete personal tags',
      requiresAuth: true,
    );
    return result ?? 0;
  }

  /// BUT-1042: merges [fromId] into [toId] in one atomic batch — every recipe
  /// carrying [fromId] is retagged to [toId] (rich `personalTags` entry
  /// rewritten to point at the destination tag) and the [fromId] tag document
  /// is deleted, so either the whole merge lands or none of it does.
  ///
  /// Returns the number of recipes retagged. A no-op (`0`) when ids are equal
  /// or empty — nothing to merge.
  Future<int> mergeTags(String fromId, String toId) async {
    if (fromId.isEmpty || toId.isEmpty || fromId == toId) return 0;

    final result = await executeServiceOperation<int>(
      () async {
        final toTag = await _tagRepository.read(toId);
        if (toTag == null) {
          throw ArgumentError(AppLocale.current.errorTagDoesNotExist);
        }

        // Destination rich-entry written onto recipes that lacked toId.
        // 'manual' source: a merge is a user-driven retag, not a rule match.
        final toRichEntry = RecipePersonalTag.manual(
          tagId: toTag.id,
          name: toTag.name,
        ).toMap();

        final batch = _tagRepository.newWriteBatch();

        var retagged = 0;
        final recipeRepo = _getFirebaseRecipeRepository();
        if (recipeRepo != null) {
          retagged = await recipeRepo.addReplaceTagInRecipesToBatch(
            batch,
            fromId,
            toId,
            toRichEntry,
          );
        }

        _tagRepository.addDeleteToBatch(batch, fromId);
        await batch.commit();

        _invalidateTagsCache();
        AppLogger.info(
          'Merged tag "$fromId" into "$toId"; retagged $retagged recipes',
        );
        return retagged;
      },
      operationName: 'Merge personal tags',
      requiresAuth: true,
    );
    return result ?? 0;
  }

  Stream<List<PersonalTag>> watchTags() {
    return _tagRepository.watchAllSorted();
  }

  Future<bool> tagNameExists(String name, {String? excludeId}) async {
    return await executeServiceOperation(
          () => _tagRepository.nameExists(name, excludeId: excludeId),
          operationName: 'Check tag name exists',
          requiresAuth: true,
        ) ??
        false;
  }

  Future<int> getNextTagSortOrder() async {
    return await executeServiceOperation(
          () => _tagRepository.getNextSortOrder(),
          operationName: 'Get next tag sort order',
          requiresAuth: true,
        ) ??
        0;
  }

  Future<void> reorderTags(List<String> tagIds) async {
    await executeServiceOperation(
      () async {
        await _tagRepository.reorder(tagIds);
        _invalidateTagsCache();
        AppLogger.info('Reordered ${tagIds.length} personal tags');
      },
      operationName: 'Reorder personal tags',
      requiresAuth: true,
    );
  }

  Future<void> moveTagToGroup(String tagId, String? groupId) async {
    await executeServiceOperation(
      () async {
        if (groupId != null) {
          final group = await _groupRepository.read(groupId);
          if (group == null) {
            throw ArgumentError(AppLocale.current.errorGroupDoesNotExist);
          }
        }

        await _tagRepository.moveToGroup(tagId, groupId);
        _invalidateTagsCache();
        AppLogger.info('Moved tag $tagId to group ${groupId ?? "ungrouped"}');
      },
      operationName: 'Move tag to group',
      requiresAuth: true,
    );
  }

  Future<List<PersonalTag>> getTagsByGroup(String? groupId) async {
    return await executeServiceOperation(
          () => _tagRepository.getByGroupId(groupId),
          operationName: 'Get tags by group',
          requiresAuth: true,
        ) ??
        [];
  }

  Stream<List<PersonalTag>> watchTagsByGroup(String? groupId) {
    return _tagRepository.watchByGroupId(groupId);
  }

  Future<List<PersonalTag>> getTagsByIds(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];

    return await executeServiceOperation(
          () => _tagRepository.getByIds(tagIds),
          operationName: 'Get tags by IDs',
          requiresAuth: true,
        ) ??
        [];
  }

  // -- Group CRUD --

  Future<PersonalTagGroup?> createGroup(PersonalTagGroup group) async {
    return await executeServiceOperation(
      () async {
        final nameValidation = PersonalTagGroup.validateName(group.name);
        if (nameValidation != null) {
          throw ArgumentError(nameValidation);
        }

        if (await _groupRepository.nameExists(group.name)) {
          throw ArgumentError(
            AppLocale.current.errorGroupNameExistsWithName(group.name),
          );
        }

        await _groupRepository.create(group);
        clearCache(groupsCacheKey);
        AppLogger.info('Created personal tag group: ${group.name}');
        return group;
      },
      operationName: 'Create personal tag group',
      requiresAuth: true,
    );
  }

  Future<PersonalTagGroup?> getGroup(String groupId) async {
    return await executeServiceOperation<PersonalTagGroup?>(
      () async => await _groupRepository.read(groupId),
      operationName: 'Get personal tag group',
      requiresAuth: true,
    );
  }

  Future<List<PersonalTagGroup>> getAllGroups() async {
    return await getCachedOrExecute(
          groupsCacheKey,
          () => _groupRepository.getAllSorted(),
          cacheDuration: const Duration(minutes: 5),
        ) ??
        [];
  }

  Future<void> updateGroup(PersonalTagGroup group) async {
    await executeServiceOperation(
      () async {
        final nameValidation = PersonalTagGroup.validateName(group.name);
        if (nameValidation != null) {
          throw ArgumentError(nameValidation);
        }

        if (await _groupRepository.nameExists(group.name,
            excludeId: group.id)) {
          throw ArgumentError(
            AppLocale.current.errorGroupNameExistsWithName(group.name),
          );
        }

        final updated = group.copyWith(updatedAt: clock.now());
        await _groupRepository.update(updated);
        clearCache(groupsCacheKey);
        AppLogger.info('Updated personal tag group: ${group.name}');
      },
      operationName: 'Update personal tag group',
      requiresAuth: true,
    );
  }

  /// Deletes a group atomically: clears groupId from tags and deletes the group
  /// in a single batch to ensure data consistency.
  Future<void> deleteGroup(String groupId) async {
    await executeServiceOperation(
      () async {
        final batch = _tagRepository.newWriteBatch();

        final clearedCount =
            await _tagRepository.addClearGroupToBatch(batch, groupId);

        _groupRepository.addDeleteToBatch(batch, groupId);

        await batch.commit();

        if (clearedCount > 0) {
          AppLogger.info('Atomically cleared group from $clearedCount tags');
        }

        clearCache(groupsCacheKey);
        _invalidateTagsCache();
        AppLogger.info('Deleted personal tag group: $groupId');
      },
      operationName: 'Delete personal tag group',
      requiresAuth: true,
    );
  }

  Stream<List<PersonalTagGroup>> watchGroups() {
    return _groupRepository.watchAllSorted();
  }

  Future<int> getNextGroupSortOrder() async {
    return await executeServiceOperation(
          () => _groupRepository.getNextSortOrder(),
          operationName: 'Get next group sort order',
          requiresAuth: true,
        ) ??
        0;
  }

  Future<void> reorderGroups(List<String> groupIds) async {
    await executeServiceOperation(
      () async {
        await _groupRepository.reorder(groupIds);
        clearCache(groupsCacheKey);
        AppLogger.info('Reordered ${groupIds.length} personal tag groups');
      },
      operationName: 'Reorder personal tag groups',
      requiresAuth: true,
    );
  }

  // -- Rule CRUD (embedded in tags) --

  Future<void> addRuleToTag(String tagId, PersonalTagRule rule) async {
    await executeServiceOperation(
      () async {
        final validation = PersonalTagRule.validate(rule, requireTagId: false);
        if (validation != null) {
          throw ArgumentError(validation);
        }

        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError(AppLocale.current.errorTagDoesNotExist);
        }

        final updatedRules = [...tag.rules, rule];
        final updatedTag = tag.copyWith(rules: updatedRules);
        await _tagRepository.update(updatedTag);
        _invalidateTagsCache();
        AppLogger.info('Added rule "${rule.name}" to tag "${tag.name}"');
      },
      operationName: 'Add rule to tag',
      requiresAuth: true,
    );
  }

  Future<void> updateRuleInTag(String tagId, PersonalTagRule rule) async {
    await executeServiceOperation(
      () async {
        final validation = PersonalTagRule.validate(rule, requireTagId: false);
        if (validation != null) {
          throw ArgumentError(validation);
        }

        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError(AppLocale.current.errorTagDoesNotExist);
        }

        final ruleIndex = tag.rules.indexWhere((r) => r.id == rule.id);
        if (ruleIndex == -1) {
          throw ArgumentError(AppLocale.current.errorRuleDoesNotExist);
        }

        final updatedRules = [...tag.rules];
        updatedRules[ruleIndex] = rule.copyWith(updatedAt: clock.now());
        final updatedTag = tag.copyWith(rules: updatedRules);
        await _tagRepository.update(updatedTag);
        _invalidateTagsCache();
        AppLogger.info('Updated rule "${rule.name}" in tag "${tag.name}"');
      },
      operationName: 'Update rule in tag',
      requiresAuth: true,
    );
  }

  Future<void> removeRuleFromTag(String tagId, String ruleId) async {
    await executeServiceOperation(
      () async {
        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError(AppLocale.current.errorTagDoesNotExist);
        }

        final updatedRules = tag.rules.where((r) => r.id != ruleId).toList();
        final updatedTag = tag.copyWith(rules: updatedRules);
        await _tagRepository.update(updatedTag);
        _invalidateTagsCache();
        AppLogger.info('Removed rule $ruleId from tag "${tag.name}"');
      },
      operationName: 'Remove rule from tag',
      requiresAuth: true,
    );
  }

  Future<void> setRuleEnabled(
    String tagId,
    String ruleId, {
    required bool enabled,
  }) async {
    await executeServiceOperation(
      () async {
        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError(AppLocale.current.errorTagDoesNotExist);
        }

        final ruleIndex = tag.rules.indexWhere((r) => r.id == ruleId);
        if (ruleIndex == -1) {
          throw ArgumentError(AppLocale.current.errorRuleDoesNotExist);
        }

        final updatedRules = [...tag.rules];
        updatedRules[ruleIndex] = updatedRules[ruleIndex].copyWith(
          isEnabled: enabled,
          updatedAt: clock.now(),
        );
        final updatedTag = tag.copyWith(rules: updatedRules);
        await _tagRepository.update(updatedTag);
        _invalidateTagsCache();
        AppLogger.info('Set rule $ruleId enabled: $enabled');
      },
      operationName: 'Set rule enabled',
      requiresAuth: true,
    );
  }

  RecipeRepository? _getRecipeRepository() {
    try {
      return ServiceLocator.get<RecipeRepository>();
    } catch (e) {
      AppLogger.warning(
        'RecipeRepository unavailable for tag cascade — '
        'recipe documents may retain stale tag data until next retag. '
        'Error: $e',
      );
      return null;
    }
  }

  FirebaseRecipeRepository? _getFirebaseRecipeRepository() {
    final repo = _getRecipeRepository();
    return repo is FirebaseRecipeRepository ? repo : null;
  }
}
