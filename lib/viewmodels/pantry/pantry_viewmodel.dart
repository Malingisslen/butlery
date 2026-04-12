/// ViewModel for the "Skafferiet" (pantry) feature.
library;

import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
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

  List<PantryItem> itemsByLocation(PantryLocation loc) =>
      _items.where((i) => i.location == loc).toList();

  /// Items expired or within the 3-day threshold, nearest-expiry first.
  /// Items without an expiry date are always fresh, so excluded.
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

  List<IngredientData> _searchResults = [];
  List<IngredientData> get searchResults => _searchResults;

  Timer? _searchDebouncer;
  String? _lastSearchQuery;

  String? _currentUserId() =>
      ServiceLocator.get<PermissionService>().currentUserId;

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
        final added = await _pantryService.addFromIngredient(
          userId,
          ingredient,
          quantity: quantity,
          unit: unit,
          location: location,
          expiryDate: expiryDate,
          note: note,
        );
        _items = [..._items, added];
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
        final added = await _pantryService.addFromText(
          userId,
          rawText,
          quantity: quantity,
          unit: unit,
          location: location,
          expiryDate: expiryDate,
          note: note,
        );
        _items = [..._items, added];
      },
      errorPrefix: 'Kunde inte lägga till i skafferiet',
    );
  }

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
        final idx = _items.indexWhere((i) => i.id == item.id);
        if (idx >= 0) {
          _items = [..._items]..[idx] = item;
        }
      },
      errorPrefix: 'Kunde inte uppdatera objektet',
    );
  }

  /// Debounced ingredient autocomplete. Empty query clears results
  /// synchronously; repeated queries (e.g. backspace-retype) are
  /// short-circuited so the repository isn't hit for the same input twice.
  void searchIngredient(String query) {
    final trimmed = query.trim();
    if (trimmed == _lastSearchQuery) return;
    _lastSearchQuery = trimmed;

    _searchDebouncer?.cancel();
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
        // Autocomplete failures are non-fatal.
      }
    });
  }

  @override
  void dispose() {
    _searchDebouncer?.cancel();
    super.dispose();
  }
}
