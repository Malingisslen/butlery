// lib/viewmodels/week_list_follow_notice_manager.dart

import 'package:flutter/foundation.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';

/// The notice of what the week menu did to the list on screen (Malin
/// 2026-10-31, variant A). It is taken when the list comes on screen and is
/// gone once the list is left, closed or undone.
class WeekListFollowNoticeManager extends ChangeNotifier {
  WeekListFollowNoticeManager({MenuShoppingListGenerator? generator})
    : _generator =
          generator ?? ServiceLocator.tryGet<MenuShoppingListGenerator>();

  /// Null where the week menu's generator is not wired: no notice is shown.
  final MenuShoppingListGenerator? _generator;

  WeekListFollowNotice? _notice;
  WeekListFollowNotice? get notice => _notice;

  /// The list on screen, or null while no list is.
  String? _onScreen;

  /// Counts the times a list came on screen, so a take that an A→B→A switch
  /// overtook does not clear the notice the later take showed.
  var _visit = 0;
  var _disposed = false;

  /// [listId] is on screen, or with null no list is. A list that stays on
  /// screen keeps the notice it showed.
  Future<void> onScreen(String? listId) async {
    if (listId == _onScreen) return;
    _onScreen = listId;
    final visit = ++_visit;
    _set(null);
    final generator = _generator;
    if (listId == null || generator == null) return;
    final notice = await generator.takeFollowNotice(listId);
    if (_disposed || visit != _visit) {
      // The list was left while the notice was being taken: it was not seen.
      if (notice != null) await generator.putBackFollowNotice(notice);
      return;
    }
    _set(notice);
  }

  void dismiss() => _set(null);

  /// Returns false when the list could not be put back.
  Future<bool> undo() async {
    final notice = _notice;
    final generator = _generator;
    if (notice == null || generator == null) return true;
    _set(null);
    return generator.undoFollow(notice);
  }

  void _set(WeekListFollowNotice? notice) {
    if (_disposed || identical(notice, _notice)) return;
    _notice = notice;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
