import 'dart:async';

import 'package:butlery/core/di/meal_box_feature_from_locator.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/menu/menu_wish.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/lunchbox_days_store.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:clock/clock.dart';

/// BUT-2529: the week menu's saved wishes and "Som förra veckan". The chip
/// row, the "Mina önskemål" sheet and the save prompt share this model.
class MenuWishesViewModel extends BaseViewModel with ErrorHandlingMixin {
  MenuWishesViewModel({
    OwnProfileReader? reader,
    OwnProfileEditor? editor,
    String Function()? newId,
    String? Function()? currentUserId,
    LunchboxDaysStore lunchboxDaysStore = const LunchboxDaysStore(),
    bool Function()? mealBoxesOn,
  }) : offersLunchboxDays = (mealBoxesOn ?? mealBoxesEnabled)(),
       _reader = reader ?? ServiceLocator.get<OwnProfileReader>(),
       _editor = editor ?? ServiceLocator.get<OwnProfileEditor>(),
       _newId = newId ?? _timeId,
       _currentUserId = currentUserId ?? _liveUserId,
       _daysStore = lunchboxDaysStore {
    _reader.addListener(notifyListeners);
    if (offersLunchboxDays) unawaited(_loadLunchboxDays());
  }

  final OwnProfileReader _reader;
  final OwnProfileEditor _editor;
  final String Function() _newId;
  final String? Function() _currentUserId;
  final LunchboxDaysStore _daysStore;

  static String? _liveUserId() =>
      ServiceLocator.tryGet<PermissionService>()?.currentUserId;

  Set<DayOfWeek> _lunchboxDays = const {};
  bool _lunchboxDaysTouched = false;

  /// Whether the empty state shows the lunchbox days: the meal-box switch,
  /// read once when the week menu opens.
  final bool offersLunchboxDays;

  /// BUT-2486 part 6: the weekdays the suggested week fills with fridge and
  /// freezer boxes, remembered on this device from last week.
  Set<DayOfWeek> get lunchboxDays => _lunchboxDays;

  void toggleLunchboxDay(DayOfWeek day) {
    _lunchboxDaysTouched = true;
    final next = {..._lunchboxDays};
    if (!next.remove(day)) next.add(day);
    _lunchboxDays = Set.unmodifiable(next);
    notifyListeners();
    final uid = _currentUserId();
    if (uid != null) unawaited(_daysStore.write(uid, _lunchboxDays));
  }

  Future<void> _loadLunchboxDays() async {
    final uid = _currentUserId();
    if (uid == null) return;
    final days = await _daysStore.read(uid);
    // A tap while the read was out wins over the stored choice.
    if (isDisposed || _lunchboxDaysTouched) return;
    _lunchboxDays = Set.unmodifiable(days);
    notifyListeners();
  }

  static String _timeId() => 'w${clock.now().microsecondsSinceEpoch}';

  // A removed wish leaves the sheet in the same frame, before the write has
  // reached the profile.
  final Set<String> _hiding = {};

  List<MenuWish> get _stored =>
      _reader.currentUserProfile?.savedMenuWishes ?? const [];

  List<MenuWish> get wishes => _hiding.isEmpty
      ? _stored
      : [
          for (final w in _stored)
            if (!_hiding.contains(w.id)) w,
        ];

  LastMenuWish? get lastWish => _reader.currentUserProfile?.lastMenuWish;

  bool isSaved(String text) => MenuWishes.contains(_stored, text);

  bool get isFull => _stored.length >= MenuWishes.maxWishes;

  /// Saves [text] as a new wish. False when it was refused or did not save;
  /// [error] then holds the Swedish message.
  Future<bool> save(String text) async {
    if (isSaved(text)) return true;
    final next = MenuWishes.add(_stored, text, id: _newId());
    if (next == null) {
      setError(
        isFull
            ? AppLocale.current.menuWishLimit(MenuWishes.maxWishes)
            : AppLocale.current.menuWishSaveFailed,
      );
      return false;
    }
    return _write(next);
  }

  Future<bool> rename(MenuWish wish, String name) async {
    final next = MenuWishes.rename(_stored, wish.id, name);
    if (next == null) return false;
    return _write(next);
  }

  /// Removes [wish] at once; [undoRemove] puts it back where it was.
  Future<bool> remove(MenuWish wish) async {
    _hiding.add(wish.id);
    notifyListeners();
    final ok = await _write(MenuWishes.remove(_stored, wish.id));
    _hiding.remove(wish.id);
    notifyListeners();
    return ok;
  }

  Future<bool> undoRemove(MenuWish wish, int index) =>
      _write(MenuWishes.restore(_stored, wish, index));

  /// Called after a menu was generated from the prompt field. A built-in
  /// fill the user did not edit is never remembered: its dish count is
  /// worked out from the weekday, so next week it would be stale.
  Future<void> rememberLast(
    String text, {
    required bool pantryFocus,
    required bool unchangedBuiltIn,
  }) async {
    if (unchangedBuiltIn) return;
    final clean = MenuWishes.clampText(text);
    if (clean.isEmpty) return;
    if (lastWish?.sameAs(clean, pantryFocus: pantryFocus) ?? false) return;
    await safeExecute(
      () => _editor.rememberLastMenuWish(
        LastMenuWish(text: clean, pantryFocus: pantryFocus),
      ),
      operationName: 'Remember the last menu wish',
    );
  }

  Future<bool> _write(List<MenuWish> next) async {
    clearError();
    final saved = await safeExecute(
      () => _editor.setSavedMenuWishes(next),
      operationName: 'Save menu wishes',
      defaultValue: false,
    );
    if (isDisposed) return saved ?? false;
    if (saved != true) {
      setError(AppLocale.current.menuWishSaveFailed);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _reader.removeListener(notifyListeners);
    super.dispose();
  }
}
