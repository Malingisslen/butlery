import 'package:butlery/models/menu/meal_box.dart';

/// The signed-in user's fridge and freezer boxes (BUT-2486, part 5).
abstract class MealBoxRepository {
  /// At most [limit] boxes, unordered.
  Future<List<MealBox>> list({int limit});

  /// Stores a new box and returns its id.
  Future<String> add(MealBox box);

  Future<void> setCount(String id, int count);

  /// Folds the lunch takes [eatenKeys] into [box]'s count: that food is eaten.
  Future<void> foldTakes(MealBox box, Iterable<String> eatenKeys);

  Future<void> delete(String id);

  /// Writes [box] back under its own id, takes included: undoes a [delete].
  Future<void> restore(MealBox box);

  Future<void> setStoredOn(String id, DateTime storedOn);

  /// Moves what is left of [box] into a new box at [to], stored on
  /// [storedOn], and returns its id. The boxes planned lunches take stay in
  /// [box]; with none planned, [box] is deleted. One batch.
  Future<String> move(MealBox box, MealBoxLocation to, DateTime storedOn);

  /// Undoes [move]: deletes [movedId] and writes [original] back. One batch.
  Future<void> undoMove(MealBox original, String movedId);
}
