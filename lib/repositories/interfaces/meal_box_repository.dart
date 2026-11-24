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
}
