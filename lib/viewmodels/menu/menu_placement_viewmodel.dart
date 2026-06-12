/// BUT-1241: ViewModel for the manual placement mode ("placera i veckan").
///
/// Holds a working copy of one week's [WeeklyMenuPlan] plus the generated
/// recipes as placeable items. All placement happens in memory; nothing is
/// persisted until [confirm] runs exactly one batched save. Backing out of
/// the view therefore discards everything for free.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// One generated recipe waiting to be placed (or already placed) on the
/// week grid. [mealType] is the raw category key from the generated map so
/// the auto-rest path can rebuild a `Map<mealType, List<Recipe>>` subset.
class MenuPlacementItem {
  final String mealType;
  final MealSlot slot;
  final Recipe recipe;

  /// Id of the working-plan entry this item occupies, or null when unplaced.
  String? placedEntryId;

  MenuPlacementItem({
    required this.mealType,
    required this.slot,
    required this.recipe,
  });

  bool get isPlaced => placedEntryId != null;
}

/// What [MenuPlacementViewModel.confirm] hands back on success: the count
/// for the snackbar, plus the persisted plan and the session's entry ids so
/// the calendar can adopt them without a Firestore read-back.
typedef PlacementSaveResult = ({
  int placed,
  WeeklyMenuPlan plan,
  Set<String> sessionEntryIds,
});

class MenuPlacementViewModel extends BaseViewModel {
  final WeeklyMenuPlanService _service;
  final ParsedMenuRequest? _parsedRequest;

  /// ÄNDRA-after-auto-placement path: the saved plan already contains the
  /// auto layout being redone, so the working week starts empty (matching
  /// the replace semantics the auto path applied). Week navigation is
  /// disabled for these sessions — redoing "this week's layout" on another
  /// week would duplicate the menu across both weeks.
  final bool startFromEmptyWeek;
  final DateTime _originalWeekStart;

  WeeklyMenuPlan? _plan;
  late final List<MenuPlacementItem> _items;
  late final List<MenuPlacementItem> _itemsView = List.unmodifiable(_items);
  int? _selectedIndex;

  MenuPlacementViewModel({
    required WeeklyMenuPlanService service,
    required Map<String, List<Recipe>> generated,
    required DateTime weekStart,
    ParsedMenuRequest? parsedRequest,
    this.startFromEmptyWeek = false,
  })  : _service = service,
        _parsedRequest = parsedRequest,
        _originalWeekStart = IsoWeekUtils.weekStartOf(weekStart) {
    _items = [
      for (final entry in generated.entries)
        for (final recipe in entry.value)
          MenuPlacementItem(
            mealType: entry.key,
            slot: mapMealTypeToSlot(entry.key),
            recipe: recipe,
          ),
    ];
  }

  WeeklyMenuPlan? get plan => _plan;
  List<MenuPlacementItem> get items => _itemsView;
  DateTime get weekStart => _plan?.weekStartDate ?? _originalWeekStart;

  MenuPlacementItem? get selectedItem =>
      _selectedIndex == null ? null : _items[_selectedIndex!];
  int? get selectedIndex => _selectedIndex;

  int get placedCount => _items.where((i) => i.isPlaced).length;
  int get totalCount => _items.length;
  bool get allPlaced => placedCount == totalCount;
  bool get hasPlacements => placedCount > 0;

  bool get canNavigateWeeks => !startFromEmptyWeek;

  Future<void> init() => _loadWeek(_originalWeekStart);

  /// Week navigation mirrors the BUT-999 picker contract: a placement
  /// session targets exactly one week (single batched save), so moving to
  /// another week resets every placement. Date-component arithmetic — not
  /// `Duration(days: 7)` — so the shift survives DST transitions (a 168h
  /// add across the autumn fall-back lands on Sunday 23:00 of the SAME
  /// week and the navigation would silently no-op).
  Future<void> nextWeek() => _loadWeek(_shiftWeeks(weekStart, 1));

  Future<void> previousWeek() => _loadWeek(_shiftWeeks(weekStart, -1));

  static DateTime _shiftWeeks(DateTime weekStart, int weeks) =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + 7 * weeks);

  Future<void> _loadWeek(DateTime target) async {
    final normalized = IsoWeekUtils.weekStartOf(target);
    if (!canNavigateWeeks && normalized != _originalWeekStart) return;
    await executeAsyncVoid(
      () async {
        var fetched = await _service.getWeek(normalized);
        if (isDisposed) return;
        // The redo base only applies to the week the redo was started for.
        if (startFromEmptyWeek && normalized == _originalWeekStart) {
          fetched = fetched.copyWith(entries: const []);
        }
        _plan = fetched;
        for (final item in _items) {
          item.placedEntryId = null;
        }
        _selectedIndex = _firstUnplacedIndex();
        notifyListeners();
      },
      errorPrefix: 'Kunde inte ladda veckomenyn',
    );
  }

  /// Tray-card tap: select an unplaced item; un-place a placed one (its
  /// grid entry is removed and the item becomes the selection again), so an
  /// accidental placement is one tap to undo.
  void tapItem(int index) {
    final current = _plan;
    if (current == null) return;
    final item = _items[index];
    if (item.isPlaced) {
      _plan = _service.removeEntry(plan: current, entryId: item.placedEntryId!);
      item.placedEntryId = null;
      _selectedIndex = index;
    } else {
      _selectedIndex = _selectedIndex == index ? null : index;
    }
    notifyListeners();
  }

  /// Whether [entryId] was placed during this session (renders the NY badge
  /// and makes the cell tappable to un-place).
  bool isSessionEntry(String entryId) =>
      _items.any((i) => i.placedEntryId == entryId);

  /// Grid-cell tap on a session-placed entry: un-place it and make its item
  /// the selection again.
  void unplaceEntry(String entryId) {
    final index = _items.indexWhere((i) => i.placedEntryId == entryId);
    if (index != -1) tapItem(index);
  }

  /// Whether (day, slot) can receive the currently selected item.
  bool isEligible(DayOfWeek day, MealSlot slot) {
    final item = selectedItem;
    final current = _plan;
    if (item == null || current == null || slot != item.slot) return false;
    return slot.isMulti || current.entryAt(day, slot) == null;
  }

  /// Place the selected item on [day] (slot is implied by the item).
  /// Auto-advances the selection to the next unplaced item.
  void placeSelectedAt(DayOfWeek day) {
    final item = selectedItem;
    final current = _plan;
    if (item == null || current == null || !isEligible(day, item.slot)) return;
    final updated = _service.addEntry(
      plan: current,
      day: day,
      slot: item.slot,
      recipe: item.recipe,
    );
    // addEntry appends the new entry last — for multi slots earlier entries
    // at the same cell survive, so "last at the cell" is always ours.
    item.placedEntryId = updated.entriesAt(day, item.slot).last.id;
    _plan = updated;
    _selectedIndex = _firstUnplacedIndex();
    notifyListeners();
  }

  /// "Placera resten automatiskt": run the today-anchored distribution on
  /// the unplaced items only, layered on top of the manual placements.
  /// Returns the number of recipes that did not fit (overflow).
  int placeRemainingAutomatically() {
    final current = _plan;
    if (current == null) return 0;
    final remaining = <String, List<Recipe>>{};
    final unplaced = _items.where((i) => !i.isPlaced).toList();
    for (final item in unplaced) {
      (remaining[item.mealType] ??= []).add(item.recipe);
    }
    if (remaining.isEmpty) return 0;

    final beforeIds = current.entries.map((e) => e.id).toSet();
    final result = _service.distributeFromGeneratedMenu(
      generated: remaining,
      weekStart: weekStart,
      existing: current,
      now: clock.now(),
      dayPins: _parsedRequest?.dayPins ?? const [],
    );

    // Map each new entry back to the item it placed: first unclaimed
    // unplaced item with the same recipe AND slot — recipeId alone would
    // cross-wire a recipe generated under two meal types (un-placing the
    // lunch card would then remove the dinner cell).
    final newEntries =
        result.plan.entries.where((e) => !beforeIds.contains(e.id));
    for (final entry in newEntries) {
      for (final item in unplaced) {
        if (!item.isPlaced &&
            item.recipe.id == entry.recipeId &&
            item.slot == entry.slot) {
          item.placedEntryId = entry.id;
          break;
        }
      }
    }
    _plan = result.plan;
    _selectedIndex = _firstUnplacedIndex();
    notifyListeners();
    return result.overflow.length;
  }

  /// Persist the working plan — exactly one save for the whole session.
  /// Returns the save result on success, null on failure / no placements.
  Future<PlacementSaveResult?> confirm() async {
    final current = _plan;
    if (current == null || !hasPlacements) return null;
    final ok = await executeAsyncVoid(
      () => _service.save(current),
      errorPrefix: 'Kunde inte spara veckomenyn',
    );
    if (!ok) return null;
    return (
      placed: placedCount,
      plan: current,
      sessionEntryIds: {
        for (final item in _items)
          if (item.placedEntryId != null) item.placedEntryId!,
      },
    );
  }

  int? _firstUnplacedIndex() {
    final idx = _items.indexWhere((i) => !i.isPlaced);
    return idx == -1 ? null : idx;
  }
}
