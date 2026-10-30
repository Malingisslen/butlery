import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/viewmodels/photo_import/draft_image_store_stub.dart'
    if (dart.library.io) 'package:butlery/viewmodels/photo_import/draft_image_store_io.dart'
    if (dart.library.js_interop) 'package:butlery/viewmodels/photo_import/draft_image_store_web.dart'
    as image_store;
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';

/// Whether a sign-out is one the user made or one the app made.
///
/// PQ-12 = A: drafts go when the user logs out herself and stay at an
/// automatic logout, so she can finish what she was typing when a token
/// expires. Their owner id keeps another account from reading them.
enum DeviceCleanupReason { explicitSignOut, automaticSignOut }

/// The device drafts that hold a person's text, outside the offline database,
/// and the clearing a sign-out does on them.
///
/// The offline write queue is not here: only `SignOutGuard` may throw it away.
class LocalUserDataRegistry {
  const LocalUserDataRegistry._();

  static const String photoImportDraftKey = 'photo_import_draft_v1';
  static const String textImportDraftKey = 'text_import_draft_v1';
  static const String groupCreationDraftKey = 'group_creation_draft_v1';
  static const String pendingImportUrlKey = 'butlery_pending_import_url';

  /// One comment draft per recipe, so the key carries the recipe id.
  static const String commentDraftKeyPrefix = 'comment_draft_v1_';
  static String commentDraftKey(String recipeId) =>
      '$commentDraftKeyPrefix$recipeId';

  /// Keys written through [AutoSaveManager], each with a sibling owner key.
  static const List<String> autoSavedKeys = [
    photoImportDraftKey,
    textImportDraftKey,
    groupCreationDraftKey,
    pendingImportUrlKey,
  ];

  /// Clears what [reason] allows. Every store it calls logs its own errors
  /// and does not throw, so a sign-out cannot fail on it.
  static Future<void> clearDrafts({
    required String? userId,
    required DeviceCleanupReason reason,
  }) async {
    if (reason == DeviceCleanupReason.automaticSignOut) return;
    await _clearPrefs();
    // Not awaited: a temp-file delete must not hold a sign-out up.
    unawaited(image_store.clearStagedDraftImage());
    await WeeklyMenuOverflowTrayStore.clearAll(userId: userId);
    await WeeklyMenuDraftStore.clearAll(userId: userId);
    await RecipeFormAutoSaveManager.clearDraftsFor(userId);
  }

  static Future<void> _clearPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final doomed = <String>{
        for (final key in autoSavedKeys) ...[
          key,
          AutoSaveManager.ownerKeyFor(key),
        ],
        ...prefs.getKeys().where((k) => k.startsWith(commentDraftKeyPrefix)),
      };
      for (final key in doomed) {
        await prefs.remove(key);
      }
    } catch (e) {
      AppLogger.warning('LocalUserDataRegistry: could not clear drafts ($e)');
    }
  }
}
