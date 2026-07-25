// lib/services/account/export/content_export_manager.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;

/// Handles export of user content: recipes, menus, shopping lists.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
///
/// BUT-501 (closed): All direct Firestore reads are routed through typed
/// repositories or [FirebaseDataExportRepository] (the residual gateway
/// for collections without typed interfaces). Each repo method enforces
/// `validateOwnership` defence-in-depth on top of Firestore rules.
class ContentExportManager {
  // Test seams: production resolves via ServiceLocator on first use.
  final CookSnapRepository? _cookSnapRepo;
  final CookEventRepository? _cookEventRepo;
  final ActivityEventRepository? _activityEventRepo;
  final WeeklyMenuPlanRepository? _weeklyMenuRepo;
  final GroupWeeklyMenuPlanRepository? _groupMenuRepo;
  final PantryRepository? _pantryRepo;
  final RecipeRepository? _recipeRepo;
  final FirebasePersonalTagRepository? _personalTagRepo;
  final FirebasePersonalTagGroupRepository? _personalTagGroupRepo;
  final FirebaseDataExportRepository? _exportRepo;

  static const String _logTag = 'ContentExportManager';

  ContentExportManager({
    CookSnapRepository? cookSnapRepository,
    CookEventRepository? cookEventRepository,
    ActivityEventRepository? activityEventRepository,
    WeeklyMenuPlanRepository? weeklyMenuPlanRepository,
    GroupWeeklyMenuPlanRepository? groupWeeklyMenuPlanRepository,
    PantryRepository? pantryRepository,
    RecipeRepository? recipeRepository,
    FirebasePersonalTagRepository? personalTagRepository,
    FirebasePersonalTagGroupRepository? personalTagGroupRepository,
    FirebaseDataExportRepository? dataExportRepository,
  }) : _cookSnapRepo = cookSnapRepository,
       _cookEventRepo = cookEventRepository,
       _activityEventRepo = activityEventRepository,
       _weeklyMenuRepo = weeklyMenuPlanRepository,
       _groupMenuRepo = groupWeeklyMenuPlanRepository,
       _pantryRepo = pantryRepository,
       _recipeRepo = recipeRepository,
       _personalTagRepo = personalTagRepository,
       _personalTagGroupRepo = personalTagGroupRepository,
       _exportRepo = dataExportRepository;

  CookSnapRepository get _cookSnaps =>
      _cookSnapRepo ?? ServiceLocator.get<CookSnapRepository>();
  CookEventRepository get _cookEvents =>
      _cookEventRepo ?? ServiceLocator.get<CookEventRepository>();
  ActivityEventRepository get _activityEvents =>
      _activityEventRepo ?? ServiceLocator.get<ActivityEventRepository>();
  WeeklyMenuPlanRepository get _weeklyMenus =>
      _weeklyMenuRepo ?? ServiceLocator.get<WeeklyMenuPlanRepository>();
  GroupWeeklyMenuPlanRepository get _groupMenus =>
      _groupMenuRepo ?? ServiceLocator.get<GroupWeeklyMenuPlanRepository>();
  PantryRepository get _pantry =>
      _pantryRepo ?? ServiceLocator.get<PantryRepository>();
  RecipeRepository get _recipes =>
      _recipeRepo ?? ServiceLocator.get<RecipeRepository>();
  FirebasePersonalTagRepository get _personalTags =>
      _personalTagRepo ?? ServiceLocator.get<FirebasePersonalTagRepository>();
  FirebasePersonalTagGroupRepository get _personalTagGroups =>
      _personalTagGroupRepo ??
      ServiceLocator.get<FirebasePersonalTagGroupRepository>();
  FirebaseDataExportRepository get _exports =>
      _exportRepo ?? ServiceLocator.get<FirebaseDataExportRepository>();

  /// Export all user recipes (personal subcollection + top-level legacy shape).
  Future<Map<String, dynamic>> exportRecipes(String userId) async {
    try {
      final recipes = <Map<String, dynamic>>[];
      // Each sub-query carries its own cap, so truncation is the OR of the two
      // probes — comparing the MERGED length to one cap would stamp a complete
      // export as truncated as soon as the two halves happened to add up to
      // the cap (BUT-1662).
      var truncated = false;

      // Personal recipes in user's subcollection — RecipeRepository concrete.
      final repoConcrete = _recipes;
      if (repoConcrete is FirebaseRecipeRepository) {
        final personal = await ExportPaginationHelper.fetchCapped(
          type: 'recipes',
          fetch: (max) => repoConcrete.exportPersonalRecipesByUser(
            userId,
            maxDocuments: max,
          ),
        );
        truncated = truncated || personal.truncated;
        for (final entry in personal.items) {
          recipes.add({
            'recipe_id': entry['id'],
            'type': 'personal',
            'data': sanitizeForJson(entry['data']),
          });
        }

        // Top-level recipes where user is owner (legacy `userId` field).
        final unified = await ExportPaginationHelper.fetchCapped(
          type: 'recipes',
          fetch: (max) => repoConcrete.exportTopLevelRecipesByOwner(
            userId,
            maxDocuments: max,
          ),
        );
        truncated = truncated || unified.truncated;
        for (final entry in unified.items) {
          recipes.add({
            'recipe_id': entry['id'],
            'type': 'unified',
            'data': sanitizeForJson(entry['data']),
          });
        }
      }

      return {
        'total_count': recipes.length,
        'recipes': recipes,
        if (truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export recipes', e);
      return {'error': e.toString()};
    }
  }

  /// Export all user menus (personal subcollection + shared top-level).
  Future<Map<String, dynamic>> exportMenus(String userId) async {
    try {
      final menus = <Map<String, dynamic>>[];

      // Personal menus subcollection.
      final personal = await ExportPaginationHelper.fetchCapped(
        type: 'menus',
        fetch: (max) => _exports.exportPersonalMenus(userId, maxDocuments: max),
      );
      for (final entry in personal.items) {
        menus.add({
          'menu_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      // Top-level menus where the user is owner (sharedByUserId == userId).
      final shared = await ExportPaginationHelper.fetchCapped(
        type: 'menus',
        fetch: (max) =>
            _exports.exportSharedMenusByOwner(userId, maxDocuments: max),
      );
      for (final entry in shared.items) {
        menus.add({
          'menu_id': entry['id'],
          'type': 'shared',
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': menus.length,
        'menus': menus,
        // Per-sub-query flags, not merged-length-vs-one-cap (BUT-1662).
        if (personal.truncated || shared.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export menus', e);
      return {'error': e.toString()};
    }
  }

  /// Export all user shopping lists with items.
  Future<Map<String, dynamic>> exportShoppingLists(String userId) async {
    try {
      final lists = <Map<String, dynamic>>[];
      final results = await ExportPaginationHelper.fetchCapped(
        type: 'shopping_lists',
        fetch: (max) =>
            _exports.exportPersonalShoppingLists(userId, maxLists: max),
      );

      for (final entry in results.items) {
        final items = (entry['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (item) => {
                'item_id': item['id'],
                'data': sanitizeForJson(item['data']),
              },
            )
            .toList();

        lists.add({
          'list_id': entry['id'],
          // Raw Firestore doc map: a Timestamp/GeoPoint left in here throws
          // out of the ENTIRE GDPR export at jsonEncode, not just this section.
          'list_info': sanitizeForJson(entry['data']),
          'items': items,
        });
      }

      return {
        'total_count': lists.length,
        'shopping_lists': lists,
        if (results.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export shopping lists',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// Export all personal tags with embedded rules (GDPR Article 20).
  Future<Map<String, dynamic>> exportPersonalTags(String userId) async {
    try {
      final tags = <Map<String, dynamic>>[];
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'personal_tags',
        fetch: (max) =>
            _personalTags.exportAllByUser(userId, maxDocuments: max),
      );
      for (final entry in entries.items) {
        tags.add({
          'tag_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': tags.length,
        'personal_tags': tags,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export personal tags',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// Export all personal tag groups (GDPR Article 20)
  Future<Map<String, dynamic>> exportPersonalTagGroups(String userId) async {
    try {
      final groups = <Map<String, dynamic>>[];
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'personal_tag_groups',
        fetch: (max) =>
            _personalTagGroups.exportAllByUser(userId, maxDocuments: max),
      );
      for (final entry in entries.items) {
        groups.add({
          'group_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': groups.length,
        'personal_tag_groups': groups,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export personal tag groups',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// Export all cook snaps (GDPR Article 20)
  Future<Map<String, dynamic>> exportCookSnaps(String userId) async {
    try {
      final snaps = <Map<String, dynamic>>[];
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'cook_snaps',
        fetch: (max) =>
            _cookSnaps.exportCookSnapsByUser(userId, maxDocuments: max),
      );

      for (final entry in entries.items) {
        snaps.add({
          'snap_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': snaps.length,
        'cook_snaps': snaps,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export cook snaps', e);
      return {'error': e.toString()};
    }
  }

  /// Export all cook events (GDPR Articles 15/20)
  Future<Map<String, dynamic>> exportCookEvents(String userId) async {
    try {
      final events = <Map<String, dynamic>>[];
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'recipe_cook_events',
        fetch: (max) => _cookEvents.exportCookEventsByUser(userId, limit: max),
      );

      for (final entry in entries.items) {
        events.add({
          'event_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': events.length,
        'recipe_cook_events': events,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export cook events', e);
      return {'error': e.toString()};
    }
  }

  /// Export all pantry items (GDPR Article 20)
  Future<Map<String, dynamic>> exportPantryItems(String userId) async {
    try {
      final items = <Map<String, dynamic>>[];
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'pantry_items',
        fetch: (max) => _pantry.exportAllByUser(userId, maxDocuments: max),
      );

      for (final entry in entries.items) {
        items.add({
          'item_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': items.length,
        'pantry_items': items,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export pantry items', e);
      return {'error': e.toString()};
    }
  }

  /// Export all activity events (GDPR Article 20)
  Future<Map<String, dynamic>> exportActivityEvents(String userId) async {
    try {
      final events = <Map<String, dynamic>>[];
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'activity_events',
        fetch: (max) =>
            _activityEvents.exportEventsByUser(userId, maxDocuments: max),
      );

      for (final entry in entries.items) {
        events.add({
          'event_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': events.length,
        'activity_events': events,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export activity events',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// Export all weekly menu plans (BUT-211, GDPR Article 20).
  Future<Map<String, dynamic>> exportWeeklyMenuPlans(String userId) async {
    try {
      final plans = <Map<String, dynamic>>[];
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'weekly_menu_plans',
        fetch: (max) => _weeklyMenus.exportAllByUser(userId, maxDocuments: max),
      );

      for (final entry in entries.items) {
        plans.add({
          'plan_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': plans.length,
        'weekly_menu_plans': plans,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export weekly menu plans',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// Export all group weekly menu plans the user is a participant on.
  Future<Map<String, dynamic>> exportGroupWeeklyMenuPlans(String userId) async {
    try {
      final plans = <Map<String, dynamic>>[];
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'weekly_menu_plans',
        fetch: (max) =>
            _groupMenus.exportPlansForParticipant(userId, maxDocuments: max),
      );

      for (final entry in entries.items) {
        plans.add({
          'plan_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': plans.length,
        'group_weekly_menu_plans': plans,
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export group weekly menu plans',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// BUT-1396: Export collaborative recipes the user owns (`realtime_recipes`
  /// where `ownerId == uid`). The deletion cascade erases these, so Art. 15
  /// requires them in the export.
  Future<Map<String, dynamic>> exportRealtimeRecipes(String userId) async {
    try {
      final recipes = await _exports.exportRealtimeRecipesByOwner(userId);
      return {
        'realtime_recipes': recipes
            .map(
              (entry) => {
                'recipe_id': entry['id'],
                'data': sanitizeForJson(entry['data']),
              },
            )
            .toList(),
        'total_count': recipes.length,
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export realtime recipes',
        e,
      );
      return {'error': e.toString()};
    }
  }
}
