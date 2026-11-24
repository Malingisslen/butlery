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

  Future<String> add(MealBox box) async {
    final id = await executeServiceOperation<String>(
      () => _repository.add(box),
      operationName: 'add',
    );
    if (id == null) throw StateError('MealBoxService.add failed');
    return id;
  }

  Future<void> setCount(String id, int count) => executeServiceOperation<void>(
    () => _repository.setCount(id, count),
    operationName: 'setCount',
  );

  Future<void> remove(String id) => executeServiceOperation<void>(
    () => _repository.delete(id),
    operationName: 'remove',
  );
}
