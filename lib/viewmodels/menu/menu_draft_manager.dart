import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_draft.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';
import 'package:butlery/services/user_service.dart';

/// BUT-2157: a draft brought back onto the screen.
@immutable
class MenuDraftRestore {
  const MenuDraftRestore({
    required this.menu,
    required this.prompt,
    required this.requestedByMealType,
    required this.dropped,
  });

  /// The dishes that are still in the library and still safe for the
  /// household, per meal type in draft order. Empty when none were.
  final Map<String, List<Recipe>> menu;
  final String prompt;
  final Map<String, int> requestedByMealType;

  /// Dishes left out because they were deleted or no longer pass the
  /// household's allergen and diet filter.
  final int dropped;
}

/// BUT-2157: the week generation's local draft (produktregler.md).
///
/// Written after a generation that found dishes, and after a swap or section
/// re-roll of such a menu; never for a loaded or shared menu, a no-match
/// result or a cancelled run. Deleted when the menu is cleared, saved or
/// placed, when it is discarded, when it expires, and at a manual sign-out.
class MenuDraftManager {
  MenuDraftManager({
    required Future<List<Recipe>> Function() safePool,
    WeeklyMenuDraftStore? store,
    String? Function()? ownerId,
  }) : _safePool = safePool,
       _store = store ?? WeeklyMenuDraftStore(),
       _ownerId = ownerId ?? _signedInUserId;

  final Future<List<Recipe>> Function() _safePool;
  final WeeklyMenuDraftStore _store;
  final String? Function() _ownerId;

  /// Whose draft this device keeps, the same owner the overflow tray uses
  /// (WeeklyMenuPlanService.overflowTrayOwnerId).
  static String? _signedInUserId() =>
      ServiceLocator.tryGet<UserService>()?.currentUserProfile?.uid;

  /// Whether the menu on screen is one this device generated, so its later
  /// edits are drafts too.
  bool _tracking = false;

  WeeklyMenuDraft? _pending;

  /// The kept draft found by [check] and not yet restored or discarded.
  WeeklyMenuDraft? get pending => _pending;

  /// Reads the kept draft for the signed-in account into [pending].
  Future<WeeklyMenuDraft?> check() async {
    final owner = _ownerId();
    if (owner == null) return null;
    return _pending = await _store.load(owner);
  }

  /// Keeps [menu] as the draft and marks it as generated here.
  Future<void> record({
    required String prompt,
    required Map<String, List<Recipe>> menu,
    required Map<String, int> requestedByMealType,
  }) async {
    _tracking = true;
    _pending = null;
    await _write(prompt, menu, requestedByMealType);
  }

  /// Keeps an edit of the generated menu; a loaded or shared menu is left
  /// alone.
  Future<void> recordEdit({
    required String prompt,
    required Map<String, List<Recipe>> menu,
    required Map<String, int> requestedByMealType,
  }) async {
    if (!_tracking) return;
    await _write(prompt, menu, requestedByMealType);
  }

  /// The menu on screen is no longer a generated one (a saved or shared menu
  /// was loaded). The kept draft stays: it is still the latest suggestion.
  void stopTracking() => _tracking = false;

  /// Hides [pending] without deleting it, for a discard that can be undone.
  WeeklyMenuDraft? takePending() {
    final draft = _pending;
    _pending = null;
    return draft;
  }

  /// Offers [draft] again after an undone discard.
  void offerAgain(WeeklyMenuDraft draft) => _pending = draft;

  /// Deletes the kept draft. With [only], deletes it only while it is still
  /// that draft, so a discard committed after its undo window cannot delete
  /// a newer generation written in the meantime.
  Future<void> discard({WeeklyMenuDraft? only}) async {
    final owner = _ownerId();
    if (owner == null) return;
    if (only != null) {
      final kept = await _store.load(owner);
      if (kept == null ||
          !kept.lastModifiedAt.isAtSameMomentAs(only.lastModifiedAt)) {
        return;
      }
    }
    if (identical(_pending, only) || only == null) _pending = null;
    await _store.save(owner, null);
  }

  /// The suggestion was saved or placed, so it is no longer a draft. Later
  /// edits on screen are drafts again.
  Future<void> markSaved() async {
    final owner = _ownerId();
    _pending = null;
    if (owner == null) return;
    await _store.save(owner, null);
  }

  /// Brings [pending] back through the allergen-safe household pool, never by
  /// id alone: a dish deleted or made unsafe since is dropped and counted.
  /// Null when there is nothing to restore or the pool could not be read
  /// (the draft is then kept for the next try).
  Future<MenuDraftRestore?> restore() async {
    final draft = _pending;
    final owner = _ownerId();
    if (draft == null || owner == null) return null;
    final List<Recipe> pool;
    try {
      pool = await _safePool();
    } catch (e) {
      AppLogger.warning('MenuDraftManager: pool read failed ($e)');
      return null;
    }
    if (pool.isEmpty) return null;
    final byId = {for (final recipe in pool) recipe.id: recipe};
    final menu = <String, List<Recipe>>{};
    var dropped = 0;
    for (final entry in draft.recipeIdsByMealType.entries) {
      final recipes = <Recipe>[];
      for (final id in entry.value) {
        final recipe = byId[id];
        if (recipe == null) {
          dropped++;
        } else {
          recipes.add(recipe);
        }
      }
      if (recipes.isNotEmpty) menu[entry.key] = recipes;
    }
    _pending = null;
    if (menu.isEmpty) {
      await _store.save(owner, null);
    } else {
      _tracking = true;
      if (dropped > 0) {
        await _write(draft.prompt, menu, draft.requestedByMealType);
      }
    }
    return MenuDraftRestore(
      menu: menu,
      prompt: draft.prompt,
      requestedByMealType: draft.requestedByMealType,
      dropped: dropped,
    );
  }

  Future<void> _write(
    String prompt,
    Map<String, List<Recipe>> menu,
    Map<String, int> requestedByMealType,
  ) async {
    final owner = _ownerId();
    if (owner == null) return;
    final ids = <String, List<String>>{
      for (final entry in menu.entries)
        if (entry.value.isNotEmpty)
          entry.key: [for (final recipe in entry.value) recipe.id],
    };
    if (ids.isEmpty) return;
    await _store.save(
      owner,
      WeeklyMenuDraft(
        prompt: prompt,
        recipeIdsByMealType: ids,
        requestedByMealType: requestedByMealType,
        lastModifiedAt: clock.now(),
      ),
    );
  }
}
