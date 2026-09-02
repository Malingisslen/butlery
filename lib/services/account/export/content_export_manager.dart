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
import 'package:butlery/services/account/export/shared_shopping_list_export.dart';

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

  // BUT-1760: logs the real exception and returns the section's failure
  // envelope. Every section here used to return `{'error': e.toString()}`.
  //
  // A stable authored sentence, never `e.toString()`: a raw Firestore /
  // permission string carries another user's uid (composite doc ids), a
  // `create_composite` index URL embedding field paths and the project id, and
  // internal collection paths — into an Art. 15 artifact the data subject may
  // forward to a supervisory authority. The exception itself stays in
  // `AppLogger.error`, so support loses nothing.
  //
  // `error_code` is not decoration: `DataExportService` names the failing
  // section in `export_metadata.warnings` from it, and a precise token says
  // WHICH read failed rather than "something did". Same convention as
  // `social_export_manager.dart`, `shared_shopping_list_export.dart` and
  // `family_export_manager.dart`.
  Map<String, dynamic> _failed(String section, String code, Object e) {
    app_logger.AppLogger.error('[$_logTag] Failed to export $section', e);
    return {'error': 'Could not export $section.', 'error_code': code};
  }

  /// Export all user recipes.
  ///
  /// One source, `users/{userId}/recipes`. A second probe used to read a
  /// top-level `recipes` collection as a "legacy shape"; no rule grants a client
  /// that read, so it threw `permission-denied` INSIDE this try — discarding the
  /// personal recipes already collected above it and returning
  /// `recipes-export-failed` for the whole section. Deterministic, not
  /// intermittent: a list query against a collection with no matching rule is
  /// denied even when it holds nothing (BUT-1801).
  ///
  /// It could never have returned a row for THIS client either: the only rule
  /// reaching that path is the admin-only READ-ONLY collection-group catch-all,
  /// `match /{path=**}/recipes/{recipeId}`, and every recipe the app writes goes
  /// to `users/{userId}/recipes`. An earlier version of this comment said the
  /// rule was "absent" and that this stopped writes — neither is true, and a
  /// read grant would not govern writes in any case. (Cited by match pattern:
  /// the correction before this one cited a line number that had already moved.)
  ///
  /// The amplifier is the shape to watch, not the dead probe: two reads under
  /// one catch means a refusal in the second discards the first's rows.
  /// `exportMenus` below still has it (benign — its second query is granted),
  /// and `shared_shopping_list_export.dart` shows the fix: give a refusable
  /// probe its own inner try.
  Future<Map<String, dynamic>> exportRecipes(String userId) async {
    try {
      final recipes = <Map<String, dynamic>>[];
      // The cap belongs to the query, not to the merged list — comparing a
      // merged length to one cap stamps a complete export as truncated
      // (BUT-1662). Kept as a variable so a second source can OR into it.
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
      }

      return {
        'total_count': recipes.length,
        'recipes': recipes,
        if (truncated) 'truncated': true,
      };
    } catch (e) {
      return _failed('recipes', 'recipes-export-failed', e);
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
      return _failed('menus', 'menus-export-failed', e);
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
      return _failed('shopping lists', 'shopping-lists-export-failed', e);
    }
  }

  /// BUT-1732: shared shopping lists (`unified_shared_shopping_lists`) the user
  /// owns, is a member of, or has contributed rows to — the Art. 15 half of
  /// what the deletion cascade scrubs under Art. 17. Delegated so this manager
  /// stays under the 500-line limit; the minimisation rules and the reason for
  /// each live with the code that applies them.
  Future<Map<String, dynamic>> exportSharedShoppingLists(String userId) =>
      SharedShoppingListExport(_exports).export(userId);

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
      return _failed('personal tags', 'personal-tags-export-failed', e);
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
      return _failed(
        'personal tag groups',
        'personal-tag-groups-export-failed',
        e,
      );
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
      return _failed('cook snaps', 'cook-snaps-export-failed', e);
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
      return _failed('cook events', 'recipe-cook-events-export-failed', e);
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
      return _failed('pantry items', 'pantry-items-export-failed', e);
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
      return _failed('activity events', 'activity-events-export-failed', e);
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
      return _failed(
        'weekly menu plans',
        'weekly-menu-plans-export-failed',
        e,
      );
    }
  }

  // Malin's Art. 15 decisions on a group's weekly menu, 2026-08-29
  // (BUT-1971), both reasoned on their own merits — deriving them from
  // BUT-1732/1772/1774, which decided different collections, is the precise
  // error `accepted-deviations.md` records having made once.
  //
  // Other members' per-dish provenance is KEPT. The reason is that the app
  // shows it: tapping a dish's provenance row opens a sheet naming the voters.
  // That was not true when this decision was first written — the screen drew a
  // COUNT and the bundle shipped names — and rather than reword the reason,
  // Malin chose to make it true. The sheet is what this entry rests on, so a
  // change that removes it reopens the decision.
  //
  // The edit trail is FILTERED to rows where the requester is the ACTOR or the
  // SUBJECT. Another member's edits are third-party behaviour no screen shows —
  // but a row where someone removed the REQUESTER's dish is about the
  // requester, and an actor-only filter would drop it. That second half is why
  // a trail row carries `subjectId` at all.
  //
  // The asymmetry between the two is the decision, not an oversight. Do not
  // harmonise them.
  //
  // One helper, not an inline filter: three sections implementing one decision
  // separately is how they drift.
  Map<String, dynamic> _redactGroupPlan(dynamic source, String userId) {
    if (source is! Map) return <String, dynamic>{};
    final copy = Map<String, dynamic>.from(source);

    final trail = copy['editTrail'];
    if (trail is List) {
      copy['editTrail'] = trail.where((row) {
        // Fails CLOSED per row: a shape we do not recognise is dropped rather
        // than exported on the chance that it concerns someone else.
        if (row is! Map) return false;
        return row['actorId'] == userId || row['subjectId'] == userId;
      }).toList();
    } else if (copy.containsKey('editTrail')) {
      // And fails closed at the CONTAINER. `firestore.rules` bounds the trail
      // with `.get('editTrail', []).size() <= 50`, and `.size()` is polymorphic
      // over list, map and string — a 50-key map is ALLOWED there, measured on
      // the emulator. Without this arm such a value skips the filter and every
      // other participant's bundle ships it whole, which is the opposite of the
      // decision above.
      copy['editTrail'] = const [];
    }

    // `contributorUserIds` is DROPPED. It is an erasure handle, not content:
    // its only job is to let the deletion cascade find this document after the
    // roster no longer names someone, so it accumulates the uids of people who
    // have LEFT the group. No widget renders it, which matters because the
    // decision to keep other members' per-dish provenance was re-grounded on
    // exactly that — the app now shows the voters by name — and that ground
    // does not reach a field the app never shows.
    //
    // Chosen conservatively without asking Malin, the way the `chat_groups`
    // projection was; keeping it is hers to decide. Do not read the identically
    // named field's keep decision on `unified_shared_shopping_lists` as
    // authority: that entry itself records that arguing across collections by
    // field NAME is the error it exists to document.
    copy.remove('contributorUserIds');
    return copy;
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
          'data': sanitizeForJson(_redactGroupPlan(entry['data'], userId)),
        });
      }

      return {
        'total_count': plans.length,
        'group_weekly_menu_plans': plans,
        // A section that withholds rows and says nothing leaves the requester
        // unable to tell a filtered trail from a complete one.
        //
        // The left-group sentence is UNCONDITIONAL, and that is a measurement
        // rather than a shortcut. Since leaving a group now clears the leaver
        // from `memberPermissions`, the query above cannot reach those weeks —
        // and no probe can turn the sentence into a conditional one, because
        // Firestore rules are not filters: a list query is refused unless the
        // rule proves every document it could return is readable, and this
        // collection's read rule tests `memberPermissions`, which implies
        // nothing about `contributorUserIds`. Measured on the emulator, the
        // contributor query is denied even to a CURRENT member of the week it
        // matches (`weekly-menu-plans-rules.test.ts`, the MEASUREMENT
        // cases). A probe would have thrown for every user on every export, so
        // a note derived from one would have told people who have left nothing
        // that they had.
        'data_minimisation':
            'The edit history of each group week has been filtered to the '
            'changes you made yourself and the changes other members made to '
            'your dishes. Who suggested each dish, and who voted for it, is '
            'included in full for the groups you are still a member of. '
            'Weeks in groups you have LEFT are not included at all. Your '
            'name is still removed from them when you delete your account. '
            'The internal list each week keeps of everyone who has been on '
            'it is not included: it exists only so your name '
            'can be erased, and it holds identifiers belonging to others.',
        if (entries.truncated) 'truncated': true,
      };
    } catch (e) {
      return _failed(
        'group weekly menu plans',
        'group-weekly-menu-plans-export-failed',
        e,
      );
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
      return _failed('realtime recipes', 'realtime-recipes-export-failed', e);
    }
  }
}
