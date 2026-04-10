/// ViewModel for the "Skafferiet" (pantry) feature.
///
/// Bridges the [PantryService] business logic to pantry views. Holds
/// the current list of items, filtered projections by location, and
/// state for the ingredient autocomplete used in the add bottom sheet.
library;

import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

class PantryViewModel extends BaseViewModel {
  final PantryService _pantryService;
  final IngredientRepository _ingredientRepository;

  PantryViewModel({
    required PantryService pantryService,
    required IngredientRepository ingredientRepository,
  })  : _pantryService = pantryService,
        _ingredientRepository = ingredientRepository;

  List<PantryItem> _items = [];
  List<PantryItem> get items => _items;

  List<PantryItem> get fridgeItems =>
      _items.where((i) => i.location == PantryLocation.fridge).toList();

  List<PantryItem> get freezerItems =>
      _items.where((i) => i.location == PantryLocation.freezer).toList();

  List<PantryItem> get pantryItems =>
      _items.where((i) => i.location == PantryLocation.pantry).toList();

  List<PantryItem> get spiceRackItems =>
      _items.where((i) => i.location == PantryLocation.spiceRack).toList();

  /// Items that are expired or expiring within the 3-day threshold,
  /// sorted nearest-expiry first. Items without an expiry date are
  /// excluded because their status is always [PantryExpiryStatus.fresh].
  List<PantryItem> get expiringItems {
    final filtered = _items
        .where((i) =>
            i.expiryStatus == PantryExpiryStatus.expiringSoon ||
            i.expiryStatus == PantryExpiryStatus.expired)
        .toList();
    filtered.sort((a, b) => (a.expiryDate ?? DateTime(9999))
        .compareTo(b.expiryDate ?? DateTime(9999)));
    return filtered;
  }

  bool get isEmpty => _items.isEmpty;

  // Ingredient autocomplete state for the add bottom sheet.
  List<IngredientData> _searchResults = [];
  List<IngredientData> get searchResults => _searchResults;

  Timer? _searchDebouncer;

  /// Resolves the current user id at call time. Returning null aborts
  /// the operation silently — views should guard against unauthenticated
  /// state before showing pantry UI, but we defend in depth here.
  String? _currentUserId() =>
      ServiceLocator.get<PermissionService>().currentUserId;

  /// Loads all pantry items for the current user.
  Future<void> loadPantry() async {
    final userId = _currentUserId();
    if (userId == null) return;

    await executeAsyncVoid(
      () async {
        _items = await _pantryService.getAll(userId);
      },
      errorPrefix: 'Kunde inte ladda skafferiet',
    );
  }

  /// Reloads items and notifies listeners. Used after mutations.
  Future<void> _reloadItems() async {
    final userId = _currentUserId();
    if (userId == null) return;
    _items = await _pantryService.getAll(userId);
    if (!isDisposed) notifyListeners();
  }

  Future<void> addItemFromIngredient(
    IngredientData ingredient, {
    double quantity = 1,
    String? unit,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) async {
    final userId = _currentUserId();
    if (userId == null) return;

    await executeAsyncVoid(
      () async {
        await _pantryService.addFromIngredient(
          userId,
          ingredient,
          quantity: quantity,
          unit: unit,
          location: location,
          expiryDate: expiryDate,
          note: note,
        );
        await _reloadItems();
      },
      errorPrefix: 'Kunde inte lägga till i skafferiet',
    );
  }

  Future<void> addItemFromText(
    String rawText, {
    double quantity = 1,
    String? unit,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) async {
    final userId = _currentUserId();
    if (userId == null) return;

    await executeAsyncVoid(
      () async {
        await _pantryService.addFromText(
          userId,
          rawText,
          quantity: quantity,
          unit: unit,
          location: location,
          expiryDate: expiryDate,
          note: note,
        );
        await _reloadItems();
      },
      errorPrefix: 'Kunde inte lägga till i skafferiet',
    );
  }

  /// Removes an item. Optimistically drops it from the local list so the
  /// UI updates immediately, then performs the Firestore delete.
  Future<void> removeItem(String itemId) async {
    final userId = _currentUserId();
    if (userId == null) return;

    await executeAsyncVoid(
      () async {
        await _pantryService.removeItem(userId, itemId);
        _items.removeWhere((i) => i.id == itemId);
      },
      errorPrefix: 'Kunde inte ta bort objektet',
    );
  }

  Future<void> updateItem(PantryItem item) async {
    final userId = _currentUserId();
    if (userId == null) return;

    await executeAsyncVoid(
      () async {
        await _pantryService.updateItem(userId, item);
        await _reloadItems();
      },
      errorPrefix: 'Kunde inte uppdatera objektet',
    );
  }

  /// Debounced ingredient autocomplete for the add bottom sheet.
  ///
  /// Empty query clears results immediately without hitting the
  /// ingredient repository. Non-empty queries wait 300ms before
  /// searching to coalesce rapid keystrokes.
  void searchIngredient(String query) {
    _searchDebouncer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _searchResults = [];
      if (!isDisposed) notifyListeners();
      return;
    }
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results =
            await _ingredientRepository.searchIngredients(trimmed, limit: 10);
        if (isDisposed) return;
        _searchResults = results;
        notifyListeners();
      } catch (_) {
        // Autocomplete failures are non-fatal — surface nothing to the
        // user, just leave previous results in place.
      }
    });
  }

  /// Returns recipes matched against the current pantry contents,
  /// sorted by completeness (most-complete first). Empty pantry or
  /// recipes without normalized ingredients yield an empty list.
  Future<List<({Recipe recipe, double matchPercent})>> filterRecipesByPantry(
    List<Recipe> recipes,
  ) async {
    final userId = _currentUserId();
    if (userId == null) return const [];
    return _pantryService.getMatchingRecipes(userId, recipes);
  }

  @override
  void dispose() {
    _searchDebouncer?.cancel();
    super.dispose();
  }
}
