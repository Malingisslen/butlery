import 'package:clock/clock.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/repositories/interfaces/meal_box_repository.dart';

/// The user's fridge and freezer boxes (BUT-2486, part 5). Lunch takes are
/// written with the week they belong to (`WeeklyMenuPlanService.saveRevision`),
/// not here.
class MealBoxService extends BaseService {
  final MealBoxRepository _repository;

  MealBoxService({required MealBoxRepository repository})
    : _repository = repository;

  /// How long an empty box is kept, so a correction can still be undone.
  static const Duration emptyBoxGrace = Duration(days: 30);

  @override
  String get serviceName => 'MealBoxService';

  /// The boxes, with lunches already past folded into the count. A box left
  /// empty for [emptyBoxGrace] is deleted. Tidying failures are logged and
  /// never cost the list.
  Future<List<MealBox>> list() async {
    final boxes = await executeServiceOperation<List<MealBox>>(
      () => _repository.list(),
      operationName: 'list',
    );
    if (boxes == null) throw StateError('MealBoxService.list failed');
    final today = clock.now();
    final shown = <MealBox>[];
    for (final box in boxes) {
      final tidied = await _tidy(box, today);
      if (tidied != null) shown.add(tidied);
    }
    return shown;
  }

  Future<MealBox?> _tidy(MealBox box, DateTime today) async {
    try {
      final eaten = box.pastTakeKeys(today).toList();
      var current = box;
      if (eaten.isNotEmpty) {
        await _repository.foldTakes(box, eaten);
        final left = {...box.takes}..removeWhere((k, _) => eaten.contains(k));
        final eatenCount = eaten.fold(0, (total, k) => total + box.takes[k]!);
        current = MealBox(
          id: box.id,
          recipeId: box.recipeId,
          recipeTitle: box.recipeTitle,
          location: box.location,
          storedOn: box.storedOn,
          count: (box.count - eatenCount).clamp(0, MealBox.maxCount),
          takes: left,
          updatedAt: today,
        );
      }
      final updated = current.updatedAt;
      if (current.count == 0 &&
          current.takes.isEmpty &&
          updated != null &&
          today.difference(updated) > emptyBoxGrace) {
        await _repository.delete(current.id);
        return null;
      }
      return current;
    } catch (e, stack) {
      AppLogger.error('Meal box tidy failed', e, serviceName, stack);
      return box;
    }
  }

  /// Stores [box] and returns its id. A blank title is refused before
  /// anything is written, so the view can ask for a name.
  Future<String> add(MealBox box) async {
    if (box.recipeTitle.trim().isEmpty) {
      throw ArgumentError.value(box.recipeTitle, 'recipeTitle', 'blank');
    }
    final id = await executeServiceOperation<String>(
      () => _repository.add(box),
      operationName: 'add',
    );
    if (id == null) throw StateError('MealBoxService.add failed');
    return id;
  }

  Future<void> setCount(String id, int count) => _write(
    () => _repository.setCount(id, count),
    operationName: 'setCount',
  );

  /// Sets what is left of [box] to [remaining]. The stored count also holds
  /// the boxes planned lunches take, so those are added back.
  Future<void> setRemaining(MealBox box, int remaining) =>
      setCount(box.id, (remaining + box.taken).clamp(0, MealBox.maxCount));

  Future<void> remove(String id) =>
      _write(() => _repository.delete(id), operationName: 'remove');

  /// Puts back a box [remove] deleted, its planned lunches included.
  Future<void> restore(MealBox box) =>
      _write(() => _repository.restore(box), operationName: 'restore');

  /// The day the food was cooked or frozen. Not after today.
  Future<void> setStoredOn(String id, DateTime storedOn) async {
    if (storedOn.isAfter(clock.now())) {
      throw ArgumentError.value(storedOn, 'storedOn', 'in the future');
    }
    await _write(
      () => _repository.setStoredOn(id, storedOn),
      operationName: 'setStoredOn',
    );
  }

  /// Moves what is left of [box] to the other place, dated today, and returns
  /// the new box's id. Lunches already planned keep taking from [box], whose
  /// place and date they carry.
  Future<String> move(MealBox box, MealBoxLocation to) async {
    if (box.remaining < 1 || box.location == to) {
      throw ArgumentError.value(box.id, 'box', 'nothing to move');
    }
    final id = await executeServiceOperation<String>(
      () => _repository.move(box, to, clock.now()),
      operationName: 'move',
    );
    if (id == null) throw StateError('MealBoxService.move failed');
    return id;
  }

  Future<void> undoMove(MealBox original, String movedId) => _write(
    () => _repository.undoMove(original, movedId),
    operationName: 'undoMove',
  );

  /// A void operation whose failure reaches the caller; the base service
  /// would otherwise answer a refused write and a done one alike.
  Future<void> _write(
    Future<void> Function() operation, {
    required String operationName,
  }) async {
    final done = await executeServiceOperation<bool>(() async {
      await operation();
      return true;
    }, operationName: operationName);
    if (done != true) throw StateError('MealBoxService.$operationName failed');
  }

  /// Boxes the list shows: one with nothing left and no lunch planned from it
  /// is hidden (a lunch given back can recreate an emptied box).
  static List<MealBox> shown(List<MealBox> boxes) => [
    for (final box in boxes)
      if (box.count > 0 || box.takes.isNotEmpty) box,
  ];
}
