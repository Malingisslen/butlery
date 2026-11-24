import 'package:clock/clock.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_event.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

enum CookHistoryFilter { all, favorites, lastMonth }

/// One cook with the recipe facts the list shows. [title] is null when the
/// recipe is deleted or not in the loaded collection.
class CookHistoryEntry {
  const CookHistoryEntry({required this.event, this.recipe});

  final CookEvent event;
  final Recipe? recipe;

  String? get title => recipe?.title;

  /// This cook's own verdict, shown on the row.
  int? get rating => event.rating;

  /// The cook's own verdict, else the recipe's current rating: what "Favoriter"
  /// judges by, so a favourite recipe's older cooks still count.
  double? get favoriteRating => event.rating?.toDouble() ?? recipe?.rating;
}

/// Reads the user's cook log one page at a time. Recipe names come from the
/// recipes the app already holds, so a row costs no extra read.
class CookHistoryViewModel extends BaseViewModel {
  CookHistoryViewModel({
    CookEventRepository? cookEvents,
    UnifiedRecipeService? recipes,
  }) : _cookEvents = cookEvents ?? ServiceLocator.get<CookEventRepository>(),
       _recipes = recipes ?? ServiceLocator.get<UnifiedRecipeService>();

  static const int pageSize = 30;
  static const double favoriteThreshold = 4.0;
  static const int frequentMinCooks = 2;
  static const int frequentMax = 5;

  final CookEventRepository _cookEvents;
  final UnifiedRecipeService _recipes;

  final List<CookEvent> _events = [];
  bool _loadingMore = false;
  bool _hasMore = false;
  CookHistoryFilter _filter = CookHistoryFilter.all;

  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  bool get hasFailed => hasError;
  CookHistoryFilter get filter => _filter;

  void setFilter(CookHistoryFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// The loaded cooks the current filter keeps, newest first.
  List<CookHistoryEntry> get entries {
    final byId = {for (final r in _recipes.recipes) r.id: r};
    final cutoff = clock.now().subtract(const Duration(days: 30));
    return [
      for (final e in _events)
        if (_keeps(
          CookHistoryEntry(event: e, recipe: byId[e.recipeId]),
          cutoff,
        ))
          CookHistoryEntry(event: e, recipe: byId[e.recipeId]),
    ];
  }

  bool _keeps(CookHistoryEntry entry, DateTime cutoff) {
    switch (_filter) {
      case CookHistoryFilter.all:
        return true;
      case CookHistoryFilter.favorites:
        final rating = entry.favoriteRating;
        return rating != null && rating >= favoriteThreshold;
      case CookHistoryFilter.lastMonth:
        return !entry.event.cookedAt.isBefore(cutoff);
    }
  }

  /// "Lagas ofta": the most-cooked recipes, from the counter already on each
  /// recipe, so it needs no read.
  List<Recipe> get frequent {
    final cooked = [
      for (final r in _recipes.recipes)
        if (r.cookCount >= frequentMinCooks) r,
    ]..sort((a, b) => b.cookCount.compareTo(a.cookCount));
    return cooked.take(frequentMax).toList();
  }

  Future<void> load() async {
    final ok = await executeAsyncVoid(() async {
      final page = await _cookEvents.fetchRecent(limit: pageSize);
      _events
        ..clear()
        ..addAll(page);
      _hasMore = page.length == pageSize;
    }, errorPrefix: AppLocale.current.cookHistoryLoadError);
    if (!ok) AppLogger.warning('Cook history load failed');
  }

  Future<void> loadMore() async {
    if (isDisposed || _loadingMore || !_hasMore || _events.isEmpty) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _cookEvents.fetchRecent(
        limit: pageSize,
        before: _events.last.cookedAt,
      );
      if (isDisposed) return;
      _events.addAll(page);
      _hasMore = page.length == pageSize;
    } catch (e) {
      AppLogger.warning('Cook history page failed: $e');
    }
    _loadingMore = false;
    notifyListeners();
  }
}
