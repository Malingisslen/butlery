/// ViewModel for the "Skafferiet" (pantry) feature.
library;

import 'package:butlery/core/mixins/debounce_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

class PantryViewModel extends BaseViewModel with DebounceMixin {
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

  /// BUT-954: undo for the snackbar-undo delete flow — re-persists [item]
  /// (it gets a fresh document ID) and puts it back in the list. Pantry
  /// rows are the reversible-destructive class: swipe deletes immediately,
  /// the snackbar's "Ångra" calls this.
  Future<void> restoreItem(PantryItem item) async {
    final userId = _currentUserId();
    if (userId == null) return;

    await executeAsyncVoid(
      () async {
        final restored = await _pantryService.restoreItem(userId, item);
        _items = [..._items, restored];
      },
      errorPrefix: 'Kunde inte återställa objektet',
    );
  }

  /// BUT-948: bulk delete for multi-select. Removes every id in one pass.
  /// Class-1 reversible (like single swipe) — the view shows one snackbar whose
  /// "Ångra" calls [restoreItems] with the captured items.
  Future<void> bulkRemoveItems(Iterable<String> itemIds) async {
    final userId = _currentUserId();
    if (userId == null) return;
    final ids = itemIds.toSet();
    if (ids.isEmpty) return;

    await executeAsyncVoid(
      () async {
        for (final id in ids) {
          await _pantryService.removeItem(userId, id);
        }
        // Immutable replacement (consistent with every other write here) so a
        // caller holding a pre-delete snapshot of `items` is never mutated.
        _items = _items.where((i) => !ids.contains(i.id)).toList();
      },
      errorPrefix: 'Kunde inte ta bort objekten',
    );
  }

  /// BUT-948: bulk undo counterpart to [bulkRemoveItems] — re-persists each
  /// removed item (each gets a fresh document ID, mirroring [restoreItem]).
  Future<void> restoreItems(List<PantryItem> items) async {
    final userId = _currentUserId();
    if (userId == null || items.isEmpty) return;

    await executeAsyncVoid(
      () async {
        final restored = <PantryItem>[];
        for (final item in items) {
          restored.add(await _pantryService.restoreItem(userId, item));
        }
        _items = [..._items, ...restored];
      },
      errorPrefix: 'Kunde inte återställa objekten',
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

    if (trimmed.isEmpty) {
      cancelDebounce('search');
      _searchResults = [];
      if (!isDisposed) notifyListeners();
      return;
    }
    debounce('search', const Duration(milliseconds: 300), () async {
      final results =
          await _ingredientRepository.searchIngredients(trimmed, limit: 10);
      if (isDisposed) return;
      _searchResults = results;
      notifyListeners();
    });
  }
}
