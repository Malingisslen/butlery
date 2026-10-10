import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/viewmodels/menu_voting_viewmodel.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';

/// Keeps the weekly-menu screen in step with a shared menu in
/// `realtime_resources` and writes the screen's edits back to it.
///
/// Owned by `MenuViewModel`; [onMenu] hands every snapshot to the screen state.
class MenuLiveSession {
  MenuLiveSession({
    required this.onMenu,
    RealtimeMenuViewModel? realtime,
    RealtimeMenuService? service,
    MenuVotingViewModel Function(String resourceId, ApplyDish applyDish)?
    votingFactory,
  }) : _realtime = realtime ?? ServiceLocator.get<RealtimeMenuViewModel>(),
       _service = service ?? ServiceLocator.get<RealtimeMenuService>(),
       _votingFactory = votingFactory;

  final void Function(Map<String, List<Recipe>> menu) onMenu;
  final RealtimeMenuViewModel _realtime;
  final RealtimeMenuService _service;
  final MenuVotingViewModel Function(String resourceId, ApplyDish applyDish)?
  _votingFactory;

  String? _resourceId;
  bool _listening = false;
  MenuVotingViewModel? _voting;

  String? get resourceId => _resourceId;

  /// The votes on this menu (BUT-2118). A winner is written with
  /// [replaceRecipe], the same write a swap makes.
  MenuVotingViewModel? get voting => _voting;
  bool get isLive => _resourceId != null;

  // Before the first snapshot the viewer's role is unknown, so nothing is
  // editable yet.
  bool get canEdit =>
      isLive && _realtime.currentMenu != null && _realtime.canEdit;

  Future<void> start(String resourceId) async {
    if (_voting?.menuId != resourceId) {
      _voting?.dispose();
      _voting =
          (_votingFactory ??
          (id, apply) => MenuVotingViewModel(menuId: id, applyDish: apply))(
            resourceId,
            replaceRecipe,
          );
      _voting!.subscribe();
    }
    _resourceId = resourceId;
    if (!_listening) {
      _realtime.addListener(_push);
      _listening = true;
    }
    await _realtime.startWatching(resourceId);
  }

  Future<void> replaceRecipe(String category, int index, Recipe recipe) =>
      _service.replaceRecipeInCategory(
        resourceId: _resourceId!,
        categoryName: category,
        recipeIndex: index,
        newRecipe: recipe,
      );

  Future<void> writeSection(String category, List<Recipe> recipes) =>
      _service.updateWholeCategory(
        resourceId: _resourceId!,
        categoryName: category,
        recipes: recipes,
      );

  Future<void> stop() async {
    _detach();
    _disposeVoting();
    _resourceId = null;
    await _realtime.stopWatching();
  }

  void dispose() {
    _detach();
    _disposeVoting();
    _resourceId = null;
    final realtime = _realtime;
    // The stream must be closed before the view model that owns it goes.
    unawaited(
      realtime.stopWatching().catchError((_) {}).whenComplete(realtime.dispose),
    );
  }

  void _detach() {
    if (!_listening) return;
    _realtime.removeListener(_push);
    _listening = false;
  }

  void _disposeVoting() {
    _voting?.dispose();
    _voting = null;
  }

  void _push() {
    final menu = _realtime.currentMenu;
    if (menu == null) return;
    // Only the people on the menu now are counted in its votes.
    _voting?.setParticipants(menu.participantIds.toSet());
    onMenu(_realtime.menuWithOptimisticChanges);
  }
}
