import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';

/// Business logic layer for the pantry ("skafferi") feature.
class PantryService extends BaseService {
  final PantryRepository _pantryRepository;
  final IngredientRepository _ingredientRepository;

  PantryService({
    required PantryRepository pantryRepository,
    required IngredientRepository ingredientRepository,
  })  : _pantryRepository = pantryRepository,
        _ingredientRepository = ingredientRepository;

  @override
  String get serviceName => 'PantryService';

  Future<PantryItem> addFromIngredient(
    String userId,
    IngredientData ingredient, {
    double quantity = 1,
    String? unit,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) async {
    final result = await executeServiceOperation<PantryItem>(
      () async {
        _validateInput(ingredient.swedish, quantity);
        final item = _buildItem(
          ingredientId: ingredient.id,
          name: ingredient.swedish,
          quantity: quantity,
          unit: unit ?? ingredient.typicalUnit,
          typicalStorage: ingredient.typicalStorage,
          location: location,
          expiryDate: expiryDate,
          note: note,
        );
        final id = await _pantryRepository.add(userId, item);
        return item.copyWith(id: id);
      },
      operationName: 'addFromIngredient',
    );
    if (result == null) {
      throw StateError('addFromIngredient failed');
    }
    return result;
  }

  /// Adds a pantry item from free-text input, fuzzy-matched against the
  /// ingredient database. Orphan items (no match) store the raw text.
  Future<PantryItem> addFromText(
    String userId,
    String rawText, {
    double quantity = 1,
    String? unit,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) async {
    final result = await executeServiceOperation<PantryItem>(
      () async {
        final trimmed = rawText.trim();
        _validateInput(trimmed, quantity);

        final matches = await _ingredientRepository.searchIngredients(
          trimmed,
          limit: 1,
        );
        final match = matches.isNotEmpty ? matches.first : null;

        final item = _buildItem(
          ingredientId: match?.id,
          name: match?.swedish ?? trimmed,
          quantity: quantity,
          unit: unit ?? match?.typicalUnit,
          typicalStorage: match?.typicalStorage,
          location: location,
          expiryDate: expiryDate,
          note: note,
        );
        final id = await _pantryRepository.add(userId, item);
        return item.copyWith(id: id);
      },
      operationName: 'addFromText',
    );
    if (result == null) {
      throw StateError('addFromText failed');
    }
    return result;
  }

  Future<void> updateItem(String userId, PantryItem item) async {
    _validateInput(item.ingredientName, item.quantity);
    await executeServiceOperation<void>(
      () => _pantryRepository.update(userId, item),
      operationName: 'updateItem',
    );
  }

  Future<void> removeItem(String userId, String itemId) async {
    await executeServiceOperation<void>(
      () => _pantryRepository.remove(userId, itemId),
      operationName: 'removeItem',
    );
  }

  Future<List<PantryItem>> getAll(String userId) async {
    return await executeServiceOperation<List<PantryItem>>(
          () => _pantryRepository.getAll(userId),
          operationName: 'getAll',
          defaultValue: const [],
        ) ??
        const [];
  }

  Stream<List<PantryItem>> watchAll(String userId) {
    return _pantryRepository.watchAll(userId);
  }

  Future<List<PantryItem>> getExpiringSoon(
    String userId, {
    int days = 3,
  }) async {
    return await executeServiceOperation<List<PantryItem>>(
          () => _pantryRepository.getExpiringSoon(userId, days),
          operationName: 'getExpiringSoon',
          defaultValue: const [],
        ) ??
        const [];
  }

  /// Scores [recipes] by pantry ingredient coverage. Recipes without
  /// `ingredientsNormalized` are skipped (pre-MODUL1 legacy). Callers
  /// holding a fresh pantry snapshot can pass it via [pantryItems] to
  /// avoid a duplicate Firestore read.
  Future<List<({Recipe recipe, double matchPercent})>> getMatchingRecipes(
    String userId,
    List<Recipe> recipes, {
    List<PantryItem>? pantryItems,
  }) async {
    final result = await executeServiceOperation<
        List<({Recipe recipe, double matchPercent})>>(() async {
      final items = pantryItems ?? await _pantryRepository.getAll(userId);
      if (items.isEmpty) return const [];

      final pantryIngredientIds =
          items.map((item) => item.ingredientId).whereType<String>().toSet();
      if (pantryIngredientIds.isEmpty) return const [];

      final matches = <({Recipe recipe, double matchPercent})>[];
      for (final recipe in recipes) {
        final normalized = recipe.core.ingredientsNormalized;
        if (normalized == null || normalized.isEmpty) continue;

        final overlap =
            normalized.toSet().intersection(pantryIngredientIds).length;
        if (overlap == 0) continue;

        matches.add((
          recipe: recipe,
          matchPercent: overlap / normalized.length,
        ));
      }

      matches.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
      return matches;
    }, operationName: 'getMatchingRecipes', defaultValue: const []);
    return result ?? const [];
  }

  void _validateInput(String name, double quantity) {
    if (name.trim().isEmpty) {
      throw ValidationException(
        'Ingredient name cannot be empty',
        field: 'ingredientName',
      );
    }
    if (quantity <= 0) {
      throw ValidationException(
        'Quantity must be positive',
        field: 'quantity',
        value: quantity,
      );
    }
  }

  PantryItem _buildItem({
    String? ingredientId,
    required String name,
    required double quantity,
    String? unit,
    String? typicalStorage,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) {
    return PantryItem(
      id: '',
      ingredientId: ingredientId,
      ingredientName: name,
      quantity: quantity,
      unit: unit ?? 'st',
      location: location ?? PantryLocation.fromTypicalStorage(typicalStorage),
      addedAt: DateTime.now().toUtc(),
      expiryDate: expiryDate,
      note: note,
    );
  }
}
