import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

/// Business logic layer for the pantry ("skafferi") feature.
///
/// Responsibilities:
/// - Convert user input (ingredient picks, free text) into [PantryItem]s
/// - Boundary validation (positive quantity, non-empty name)
/// - Recipe matching based on pantry contents
class PantryService extends BaseService {
  final PantryRepository _pantryRepository;
  // Wired now so follow-up work can switch to the richer lookup service
  // without another DI pass. Currently unused by the service itself.
  // ignore: unused_field
  final IngredientLookupService _ingredientLookup;
  final IngredientRepository _ingredientRepository;

  PantryService({
    required PantryRepository pantryRepository,
    required IngredientLookupService ingredientLookup,
    required IngredientRepository ingredientRepository,
  })  : _pantryRepository = pantryRepository,
        _ingredientLookup = ingredientLookup,
        _ingredientRepository = ingredientRepository;

  @override
  String get serviceName => 'PantryService';

  /// Adds a pantry item seeded from a taxonomy ingredient.
  ///
  /// Defaults follow the ingredient's metadata when the caller leaves
  /// params null: [quantity]=1, [unit]=ingredient.typicalUnit (or 'st'),
  /// [location] inferred from ingredient.typicalStorage.
  Future<void> addFromIngredient(
    String userId,
    IngredientData ingredient, {
    double quantity = 1,
    String? unit,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) async {
    await executeServiceOperation<void>(
      () async {
        if (quantity <= 0) {
          throw ValidationException(
            'Quantity must be positive',
            field: 'quantity',
            value: quantity,
          );
        }
        final item = PantryItem(
          id: '',
          ingredientId: ingredient.id,
          ingredientName: ingredient.swedish,
          quantity: quantity,
          unit: unit ?? ingredient.typicalUnit ?? 'st',
          location: location ??
              PantryLocation.fromTypicalStorage(ingredient.typicalStorage),
          addedAt: DateTime.now().toUtc(),
          expiryDate: expiryDate,
          note: note,
        );
        await _pantryRepository.add(userId, item);
      },
      operationName: 'addFromIngredient',
    );
  }

  /// Adds a pantry item from free-text input, attempting a fuzzy match
  /// against the ingredient database. On match the item is linked via
  /// [PantryItem.ingredientId]; otherwise it's stored as an orphan with
  /// the raw text as [PantryItem.ingredientName].
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
        if (trimmed.isEmpty) {
          throw ValidationException(
            'Ingredient name cannot be empty',
            field: 'rawText',
          );
        }
        if (quantity <= 0) {
          throw ValidationException(
            'Quantity must be positive',
            field: 'quantity',
            value: quantity,
          );
        }

        final matches = await _ingredientRepository.searchIngredients(
          trimmed,
          limit: 1,
        );
        final match = matches.isNotEmpty ? matches.first : null;

        final item = PantryItem(
          id: '',
          ingredientId: match?.id,
          ingredientName: match?.swedish ?? trimmed,
          quantity: quantity,
          unit: unit ?? match?.typicalUnit ?? 'st',
          location: location ??
              (match != null
                  ? PantryLocation.fromTypicalStorage(match.typicalStorage)
                  : PantryLocation.pantry),
          addedAt: DateTime.now().toUtc(),
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

  /// Validates at the boundary and persists an update. Throws
  /// [ValidationException] on bad input so ViewModels can surface the
  /// error instead of writing garbage to Firestore.
  Future<void> updateItem(String userId, PantryItem item) async {
    if (item.ingredientName.trim().isEmpty) {
      throw ValidationException(
        'Ingredient name cannot be empty',
        field: 'ingredientName',
      );
    }
    if (item.quantity <= 0) {
      throw ValidationException(
        'Quantity must be positive',
        field: 'quantity',
        value: item.quantity,
      );
    }
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

  /// For each [recipes] entry, computes the fraction of its normalized
  /// ingredients that are present in the user's pantry. Recipes with no
  /// overlap are dropped; the remainder is sorted most-complete first.
  ///
  /// Recipes without [ingredientsNormalized] are skipped — they predate
  /// the MODUL1 migration and can't be matched.
  Future<List<({Recipe recipe, double matchPercent})>> getMatchingRecipes(
    String userId,
    List<Recipe> recipes,
  ) async {
    final result = await executeServiceOperation<
        List<({Recipe recipe, double matchPercent})>>(() async {
      final pantryItems = await _pantryRepository.getAll(userId);
      if (pantryItems.isEmpty) return const [];

      final pantryIngredientIds = pantryItems
          .map((item) => item.ingredientId)
          .whereType<String>()
          .toSet();
      if (pantryIngredientIds.isEmpty) return const [];

      final matches = <({Recipe recipe, double matchPercent})>[];
      for (final recipe in recipes) {
        final normalized = recipe.core.ingredientsNormalized;
        if (normalized == null || normalized.isEmpty) continue;

        final overlap =
            normalized.toSet().intersection(pantryIngredientIds).length;
        if (overlap == 0) continue;

        final percent = overlap / normalized.length;
        matches.add((recipe: recipe, matchPercent: percent));
      }

      matches.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
      return matches;
    }, operationName: 'getMatchingRecipes', defaultValue: const []);
    return result ?? const [];
  }
}
