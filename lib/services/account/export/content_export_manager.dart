// lib/services/account/export/content_export_manager.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
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
    ActivityEventRepository? activityEventRepository,
    WeeklyMenuPlanRepository? weeklyMenuPlanRepository,
    GroupWeeklyMenuPlanRepository? groupWeeklyMenuPlanRepository,
    PantryRepository? pantryRepository,
    RecipeRepository? recipeRepository,
    FirebasePersonalTagRepository? personalTagRepository,
    FirebasePersonalTagGroupRepository? personalTagGroupRepository,
    FirebaseDataExportRepository? dataExportRepository,
  })  : _cookSnapRepo = cookSnapRepository,
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
      final recipeLimit = ExportPaginationHelper.getLimitForType('recipes');

      // Personal recipes in user's subcollection — RecipeRepository concrete.
      final repoConcrete = _recipes;
      if (repoConcrete is FirebaseRecipeRepository) {
        final personal = await repoConcrete.exportPersonalRecipesByUser(
          userId,
          maxDocuments: recipeLimit,
        );
        for (final entry in personal) {
          recipes.add({
            'recipe_id': entry['id'],
            'type': 'personal',
            'data': sanitizeForJson(entry['data']),
          });
        }

        // Top-level recipes where user is owner (legacy `userId` field).
        final unified = await repoConcrete.exportTopLevelRecipesByOwner(
          userId,
          maxDocuments: recipeLimit,
        );
        for (final entry in unified) {
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
        if (recipes.length >= recipeLimit) 'truncated': true,
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
      final menuLimit = ExportPaginationHelper.getLimitForType('menus');

      // Personal menus subcollection.
      final personal = await _exports.exportPersonalMenus(
        userId,
        maxDocuments: menuLimit,
      );
      for (final entry in personal) {
        menus.add({
          'menu_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      // Top-level menus where the user is owner (sharedByUserId == userId).
      final shared = await _exports.exportSharedMenusByOwner(
        userId,
        maxDocuments: menuLimit,
      );
      for (final entry in shared) {
        menus.add({
          'menu_id': entry['id'],
          'type': 'shared',
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': menus.length,
        'menus': menus,
        if (menus.length >= menuLimit) 'truncated': true,
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
      final listLimit =
          ExportPaginationHelper.getLimitForType('shopping_lists');

      final results = await _exports.exportPersonalShoppingLists(
        userId,
        maxLists: listLimit,
      );

      for (final entry in results) {
        final items = (entry['items'] as List)
            .cast<Map<String, dynamic>>()
            .map((item) => {
                  'item_id': item['id'],
                  'data': sanitizeForJson(item['data']),
                })
            .toList();

        lists.add({
          'list_id': entry['id'],
          'list_info': entry['data'],
          'items': items,
        });
      }

      return {
        'total_count': lists.length,
        'shopping_lists': lists,
        if (lists.length >= listLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export shopping lists', e);
      return {'error': e.toString()};
    }
  }

  /// Export all personal tags with embedded rules (GDPR Article 20).
  Future<Map<String, dynamic>> exportPersonalTags(String userId) async {
    try {
      final tags = <Map<String, dynamic>>[];
      final tagLimit = ExportPaginationHelper.getLimitForType('personal_tags');

      final entries = await _personalTags.exportAllByUser(
        userId,
        maxDocuments: tagLimit,
      );
      for (final entry in entries) {
        tags.add({
          'tag_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': tags.length,
        'personal_tags': tags,
        if (tags.length >= tagLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export personal tags', e);
      return {'error': e.toString()};
    }
  }

  /// Export all personal tag groups (GDPR Article 20)
  Future<Map<String, dynamic>> exportPersonalTagGroups(String userId) async {
    try {
      final groups = <Map<String, dynamic>>[];
      final groupLimit =
          ExportPaginationHelper.getLimitForType('personal_tag_groups');

      final entries = await _personalTagGroups.exportAllByUser(
        userId,
        maxDocuments: groupLimit,
      );
      for (final entry in entries) {
        groups.add({
          'group_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': groups.length,
        'personal_tag_groups': groups,
        if (groups.length >= groupLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export personal tag groups', e);
      return {'error': e.toString()};
    }
  }

  /// Export all cook snaps (GDPR Article 20)
  Future<Map<String, dynamic>> exportCookSnaps(String userId) async {
    try {
      final snaps = <Map<String, dynamic>>[];
      final snapLimit = ExportPaginationHelper.getLimitForType('cook_snaps');

      final entries = await _cookSnaps.exportCookSnapsByUser(
        userId,
        maxDocuments: snapLimit,
      );

      for (final entry in entries) {
        snaps.add({
          'snap_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': snaps.length,
        'cook_snaps': snaps,
        if (snaps.length >= snapLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export cook snaps', e);
      return {'error': e.toString()};
    }
  }

  /// Export all pantry items (GDPR Article 20)
  Future<Map<String, dynamic>> exportPantryItems(String userId) async {
    try {
      final items = <Map<String, dynamic>>[];
      final pantryLimit =
          ExportPaginationHelper.getLimitForType('pantry_items');

      final entries = await _pantry.exportAllByUser(userId);

      for (final entry in entries) {
        items.add({
          'item_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': items.length,
        'pantry_items': items,
        if (items.length >= pantryLimit) 'truncated': true,
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
      final eventLimit =
          ExportPaginationHelper.getLimitForType('activity_events');

      final entries = await _activityEvents.exportEventsByUser(
        userId,
        maxDocuments: eventLimit,
      );

      for (final entry in entries) {
        events.add({
          'event_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': events.length,
        'activity_events': events,
        if (events.length >= eventLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export activity events', e);
      return {'error': e.toString()};
    }
  }

  /// Export all weekly menu plans (BUT-211, GDPR Article 20).
  Future<Map<String, dynamic>> exportWeeklyMenuPlans(String userId) async {
    try {
      final plans = <Map<String, dynamic>>[];
      final planLimit =
          ExportPaginationHelper.getLimitForType('weekly_menu_plans');

      final entries = await _weeklyMenus.exportAllByUser(
        userId,
        maxDocuments: planLimit,
      );

      for (final entry in entries) {
        plans.add({
          'plan_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': plans.length,
        'weekly_menu_plans': plans,
        if (plans.length >= planLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export weekly menu plans', e);
      return {'error': e.toString()};
    }
  }

  /// Export all group weekly menu plans the user is a participant on.
  Future<Map<String, dynamic>> exportGroupWeeklyMenuPlans(String userId) async {
    try {
      final plans = <Map<String, dynamic>>[];
      final planLimit =
          ExportPaginationHelper.getLimitForType('weekly_menu_plans');

      final entries = await _groupMenus.exportPlansForParticipant(
        userId,
        maxDocuments: planLimit,
      );

      for (final entry in entries) {
        plans.add({
          'plan_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      return {
        'total_count': plans.length,
        'group_weekly_menu_plans': plans,
        if (plans.length >= planLimit) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export group weekly menu plans', e);
      return {'error': e.toString()};
    }
  }
}
