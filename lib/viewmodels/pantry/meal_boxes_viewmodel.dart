/// The fridge and freezer boxes shown at the top of "Skafferiet"
/// (BUT-2486, part 5).
library;

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/menu/meal_box_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/di/meal_box_feature_from_locator.dart';

class MealBoxesViewModel extends BaseViewModel {
  MealBoxesViewModel({MealBoxService Function()? service})
    : _service = service ?? ServiceLocator.get<MealBoxService>;

  final MealBoxService Function() _service;

  List<MealBox> _boxes = const [];
  bool _loaded = false;

  /// True once a read has finished, so a later refresh keeps the list.
  bool get loaded => _loaded;

  /// The boxes on screen: one with nothing left and no lunch planned from it
  /// is hidden.
  List<MealBox> get boxes => MealBoxService.shown(_boxes);

  /// The stored box with [id], hidden or not: an open edit sheet keeps
  /// showing a box the stepper just took to 0.
  MealBox? byId(String id) => _boxes.where((b) => b.id == id).firstOrNull;

  int get totalRemaining => boxes.fold(0, (sum, box) => sum + box.remaining);

  Future<void> load() async {
    final ok = await executeAsyncVoid(
      () async => _boxes = await _service().list(),
      errorPrefix: AppLocale.current.mealBoxesLoadFailed,
    );
    if (ok) _loaded = true;
  }

  /// Sets what is left of [box] to [remaining] (clamped to what the stored
  /// count allows), showing the change at once. A refused write puts the old
  /// value back and returns false.
  Future<bool> setRemaining(MealBox box, int remaining) async {
    final target = remaining.clamp(0, MealBox.maxCount - box.taken);
    final before = _boxes;
    _replace(box, _copy(box, count: target + box.taken));
    notifyListeners();
    try {
      await _service().setRemaining(box, target);
    } catch (e) {
      AppLogger.error('Meal box count change failed: $e');
      // A newer tap on the same box has already moved on; leave its value.
      final now = _boxes.where((b) => b.id == box.id).firstOrNull;
      if (now != null && now.count == target + box.taken) {
        _boxes = before;
        notifyListeners();
      }
      return false;
    }
    logMealBoxEvent(AnalyticsEvents.mealBoxCountCorrected);
    return true;
  }

  /// Takes [box] out of the list at once and deletes it; a refused delete
  /// puts it back.
  Future<bool> remove(MealBox box) async {
    final before = _boxes;
    _boxes = [
      for (final b in _boxes)
        if (b.id != box.id) b,
    ];
    notifyListeners();
    try {
      await _service().remove(box.id);
      return true;
    } catch (e) {
      AppLogger.error('Meal box remove failed: $e');
      _boxes = before;
      notifyListeners();
      return false;
    }
  }

  /// Puts back a box [remove] deleted, with its planned lunches.
  Future<bool> restore(MealBox box) async {
    try {
      await _service().restore(box);
    } catch (e) {
      AppLogger.error('Meal box restore failed: $e');
      return false;
    }
    _boxes = [..._boxes.where((b) => b.id != box.id), box];
    notifyListeners();
    return true;
  }

  /// Moves what is left of [box] to the other place, dated today. Returns
  /// the new box's id, or null when the move failed.
  Future<String?> move(MealBox box, MealBoxLocation to) async {
    try {
      final id = await _service().move(box, to);
      await _refresh();
      return id;
    } catch (e) {
      AppLogger.error('Meal box move failed: $e');
      return null;
    }
  }

  Future<bool> undoMove(MealBox original, String movedId) async {
    try {
      await _service().undoMove(original, movedId);
    } catch (e) {
      AppLogger.error('Meal box undo move failed: $e');
      return false;
    }
    await _refresh();
    return true;
  }

  Future<bool> setStoredOn(MealBox box, DateTime date) async {
    final before = _boxes;
    _replace(box, _copy(box, storedOn: date));
    notifyListeners();
    try {
      await _service().setStoredOn(box.id, date);
      return true;
    } catch (e) {
      AppLogger.error('Meal box date change failed: $e');
      _boxes = before;
      notifyListeners();
      return false;
    }
  }

  /// Reads the list again without the loading state, keeping what is shown
  /// when the read fails.
  Future<void> _refresh() async {
    try {
      _boxes = await _service().list();
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Meal box refresh failed: $e');
    }
  }

  void _replace(MealBox box, MealBox next) {
    _boxes = [for (final b in _boxes) b.id == box.id ? next : b];
  }

  MealBox _copy(MealBox box, {int? count, DateTime? storedOn}) => MealBox(
    id: box.id,
    recipeId: box.recipeId,
    recipeTitle: box.recipeTitle,
    location: box.location,
    storedOn: storedOn ?? box.storedOn,
    count: count ?? box.count,
    takes: box.takes,
    updatedAt: box.updatedAt,
  );
}
