import 'package:butlery/core/di/household_links_from_locator.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_dislikes.dart';
import 'package:butlery/services/menu/week_template_apply.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/viewmodels/menu/manual_add_check.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/menu_storage.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

/// One dish of the preview, with what the check found for the meal it lands
/// on. [finding] is null when the recipe is not known, and such a dish has
/// no verdict: it is shown as unchecked, never as fine.
class TemplatePreviewRow {
  final TemplateDish dish;
  final ManualAddFinding? finding;

  const TemplatePreviewRow({required this.dish, this.finding});

  bool get isMissing => dish.state == TemplateDishState.missing;

  bool get isUnchecked =>
      dish.state == TemplateDishState.unverified ||
      (finding?.uncheckedAllergens.isNotEmpty ?? false);
}

/// BUT-2522: saving the calendar's week as a template, renaming one, and
/// putting one onto a week. The week is read and written through the
/// calendar's own viewmodel, so the calendar shows the result without a
/// second read.
class WeekTemplateViewModel extends BaseViewModel {
  WeekTemplateViewModel({
    required WeeklyMenuPlanViewModel calendar,
    required WeeklyMenuPlanService weekService,
    required UnifiedRecipeService recipes,
    MenuStorage? storage,
    String? Function()? currentUserId,
    Future<MealAllergenScope> Function(WeeklyMenuPlan plan)? allergenScope,
    Future<Map<String, Set<String>>> Function()? readDislikes,
  }) : _calendar = calendar,
       _weekService = weekService,
       _recipes = recipes,
       _storage = storage,
       _currentUserId =
           currentUserId ??
           (() => ServiceLocator.get<PermissionService>().currentUserId),
       _allergenScope = allergenScope ?? MealAllergenScope.resolveFromLocator,
       _readDislikes =
           readDislikes ??
           MealDislikesResolver(householdLinksFromLocator()).readDislikes;

  factory WeekTemplateViewModel.fromLocator(
    WeeklyMenuPlanViewModel calendar,
  ) => WeekTemplateViewModel(
    calendar: calendar,
    weekService: ServiceLocator.get<WeeklyMenuPlanService>(),
    recipes: ServiceLocator.get<UnifiedRecipeService>(),
  );

  final WeeklyMenuPlanViewModel _calendar;
  final WeeklyMenuPlanService _weekService;
  final UnifiedRecipeService _recipes;
  MenuStorage? _storage;
  final String? Function() _currentUserId;
  final Future<MealAllergenScope> Function(WeeklyMenuPlan plan) _allergenScope;
  final Future<Map<String, Set<String>>> Function() _readDislikes;

  MenuStorage get _store => _storage ??= MenuStorage();

  List<TemplatePreviewRow> _rows = const [];
  List<TemplatePreviewRow> get rows => _rows;

  DateTime? _targetWeek;
  DateTime? get targetWeek => _targetWeek;

  bool _previewFailed = false;
  bool get previewFailed => _previewFailed;

  /// The week being shown by the calendar, as a template would store it.
  List<WeekTemplateEntry> get visibleWeekEntries {
    final plan = _calendar.plan;
    return plan == null ? const [] : WeekTemplateEntry.fromPlan(plan);
  }

  int get visibleWeekDayCount =>
      visibleWeekEntries.map((e) => e.day).toSet().length;

  DateTime get visibleWeekStart => _calendar.currentWeekStart;

  Future<bool> saveVisibleWeek(String name) async {
    final entries = visibleWeekEntries;
    if (entries.isEmpty || name.trim().isEmpty) return false;
    return executeAsyncVoid(
      () => _store.saveWeekTemplate(name: name, entries: entries),
      errorPrefix: AppLocale.current.weekTemplateSaveFailed,
    );
  }

  Future<bool> rename(String menuId, String name) async {
    if (name.trim().isEmpty) return false;
    return executeAsyncVoid(
      () => _store.renameMenu(menuId, name),
      errorPrefix: AppLocale.current.weekTemplateRenameFailed,
    );
  }

  /// Reads [weekStart] into the calendar and checks each dish of [entries]
  /// against the people eating that meal that week.
  Future<void> preview(
    List<WeekTemplateEntry> entries,
    DateTime weekStart,
  ) async {
    final target = IsoWeekUtils.weekStartOf(weekStart);
    _targetWeek = target;
    _previewFailed = false;
    _rows = const [];
    setLoading(true);
    await _calendar.loadWeek(target);
    if (isDisposed || _targetWeek != target) return;
    final plan = _calendar.plan;
    if (plan == null || plan.weekStartDate != target) {
      _previewFailed = true;
      setError(AppLocale.current.weekTemplatePreviewFailed);
      return;
    }
    final dishes = await _resolve(entries);
    final scope = await _allergenScope(plan);
    Map<String, Set<String>> dislikesByMember;
    try {
      dislikesByMember = await _readDislikes();
    } catch (e) {
      // A dislike is not a safety control, so its read may fail quietly.
      AppLogger.warning('Template preview: dislikes unreadable ($e)');
      dislikesByMember = const {};
    }
    if (isDisposed || _targetWeek != target) return;
    final dislikes = MealDislikes(
      dislikesByMember: dislikesByMember,
      plan: plan,
    );
    _rows = [
      for (final dish in dishes)
        TemplatePreviewRow(
          dish: dish,
          finding: switch (dish.recipe) {
            final recipe? => ManualAddCheck.findingAt(
              recipe,
              prefs: scope.prefsAt(dish.entry.day, dish.entry.slot),
              dislikes: dislikes,
              day: dish.entry.day,
              slot: dish.entry.slot,
            ),
            null => null,
          },
        ),
    ];
    setLoading(false);
  }

  /// A recipe in the cache is found. One that is not is read once: no
  /// document means it is gone, a failed read means it is unknown.
  Future<List<TemplateDish>> _resolve(List<WeekTemplateEntry> entries) async {
    final uid = _currentUserId();
    final byId = <String, (Recipe?, TemplateDishState)>{};
    for (final id in entries.map((e) => e.recipeId).toSet()) {
      final cached = _recipes.getRecipeById(id);
      if (cached != null) {
        byId[id] = (cached, TemplateDishState.found);
        continue;
      }
      if (uid == null) {
        byId[id] = (null, TemplateDishState.unverified);
        continue;
      }
      try {
        final read = await _recipes.fetchFriendRecipe(
          ownerId: uid,
          recipeId: id,
        );
        byId[id] = read == null
            ? (null, TemplateDishState.missing)
            : (read, TemplateDishState.found);
      } catch (e) {
        AppLogger.warning('Template preview: recipe unreadable ($e)');
        byId[id] = (null, TemplateDishState.unverified);
      }
    }
    return [
      for (final entry in entries)
        TemplateDish(
          entry: entry,
          recipe: byId[entry.recipeId]!.$1,
          state: byId[entry.recipeId]!.$2,
        ),
    ];
  }

  List<TemplateDish> get _dishes => [for (final row in _rows) row.dish];

  /// Whether the target week already has a dish where the template has one,
  /// which is when the person chooses between filling and replacing.
  bool get needsChoice {
    final plan = _shownTarget;
    return plan != null && WeekTemplateApply.overlaps(plan, _dishes);
  }

  WeeklyMenuPlan? get _shownTarget {
    final plan = _calendar.plan;
    return plan != null && plan.weekStartDate == _targetWeek ? plan : null;
  }

  /// Null when nothing was written: the week moved on, or the save failed.
  Future<WeekTemplateApplyResult?> apply(WeekTemplateApplyMode mode) async {
    final plan = _shownTarget;
    if (plan == null) {
      setError(AppLocale.current.weekTemplateApplyFailed);
      return null;
    }
    final result = WeekTemplateApply.apply(
      plan: plan,
      dishes: _dishes,
      mode: mode,
    );
    if (!result.changed) return result;
    final saved = await _write(
      result.plan,
      AppLocale.current.weekTemplateApplyFailed,
      placed: result.addedEntryIds.toSet(),
    );
    return saved ? result : null;
  }

  /// Takes [result] back off the week the calendar shows now, so an edit made
  /// in between to another dish survives.
  Future<bool> undo(WeekTemplateApplyResult result) async {
    final week = result.plan.weekStartDate;
    var current = _calendar.plan;
    if (current == null || current.weekStartDate != week) {
      final read = await _weekService.readWeek(week);
      if (read.readFailed) {
        setError(AppLocale.current.weekTemplateUndoFailed);
        return false;
      }
      current = read.plan;
    }
    return _write(
      WeekTemplateApply.undo(current, result),
      AppLocale.current.weekTemplateUndoFailed,
    );
  }

  /// Saved on the week's revision, so a week changed on another device is
  /// refused rather than overwritten. A calendar holding a tray is refreshed
  /// by the service's own announcement instead, because adopting a plan
  /// empties the tray.
  Future<bool> _write(
    WeeklyMenuPlan plan,
    String errorPrefix, {
    Set<String> placed = const {},
  }) => executeAsyncVoid(() async {
    final shown = _calendar.plan;
    final showsWeek =
        shown != null && shown.weekStartDate == plan.weekStartDate;
    if (!showsWeek || _calendar.hasOverflow) {
      await _weekService.save(plan);
      return;
    }
    final next = plan.nextRevision();
    await _weekService.saveRevisionQueued(next);
    if (!isDisposed) {
      _calendar.adoptPlan(next, recentlyPlacedEntryIds: placed);
    }
  }, errorPrefix: errorPrefix);
}
