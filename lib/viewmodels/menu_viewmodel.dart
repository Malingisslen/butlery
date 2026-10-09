/// Menu ViewModel for AI meal planning, social sharing, and storage with modular architecture.
/// ```dart
/// final vm = MenuViewModel(); await vm.generateMenu('Veckomeny');

// lib/viewmodels/menu_viewmodel.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';
import 'package:butlery/models/menu/weekly_menu_draft.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/household_service.dart';

// Focused modules
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/viewmodels/menu/menu_storage.dart';
import 'package:butlery/viewmodels/menu/menu_social_manager.dart';
import 'package:butlery/viewmodels/menu/menu_generation_run.dart';
import 'package:butlery/viewmodels/menu/menu_draft_manager.dart';
import 'package:butlery/viewmodels/menu/menu_live_session.dart';

export 'package:butlery/viewmodels/menu/menu_generation_run.dart'
    show MenuGenerationEnd;

/// BUT-2157: what the screen showed when a run began, put back on cancel.
typedef _MenuScreen = ({
  Map<String, List<Recipe>> menu,
  String prompt,
  String? error,
  Map<String, int> requested,
  MenuNoMatchOutcome? noMatch,
});

/// P5-U25: one meal type the generation could not fill.
@immutable
class MenuMissingMeal {
  const MenuMissingMeal({
    required this.mealType,
    required this.found,
    required this.requested,
  });

  /// The meal type as the menu keys it ("middag").
  final String mealType;
  final int found;
  final int requested;

  int get missing => requested - found;
}

/// P5-U25: a generation that found fewer dishes than were asked for.
///
/// produktregler.md:206: "Delresultat mäts i recept, inte i dagar ... Ett
/// delresultat är alltså 1 ≤ n < begärt antal recept." produktregler.md:893:
/// what is missing is named, "ett antal utan namn är ingen upplysning".
@immutable
class MenuPartialOutcome {
  const MenuPartialOutcome({
    required this.found,
    required this.requested,
    required this.missing,
  });

  final int found;
  final int requested;

  /// Each meal type that got fewer than asked, in the order it was asked.
  final List<MenuMissingMeal> missing;
}

/// P6-U01: a generation where nothing matched ("0 recept placerade ->
/// inga matchningar", flows-roles-budget.md:32).
///
/// Skarmar v12 del 1 #veckoingamatch: "Nollresultat säger vad som stoppade
/// det och erbjuder minsta möjliga eftergift — inte en generisk feltext."
/// It is its own outcome and never an error; an empty library stays the
/// error errorNoRecipesAvailable.
@immutable
class MenuNoMatchOutcome {
  const MenuNoMatchOutcome({required this.poolSize, required this.constraints});

  /// How many recipes the generation could choose from.
  final int poolSize;

  /// The requirements the prompt was read as ("Under 30 min",
  /// "Vegetariskt"), in the parser's order. Counts, meal types and days are
  /// left out: they say how many, not what stopped it.
  final List<String> constraints;
}

typedef MenuMapSink = void Function(Map<String, List<Recipe>> menu);

/// Menu ViewModel with focused modules for generation, storage, and social sharing (MVVM).
class MenuViewModel extends BaseViewModel {
  StreamSubscription? _recipeServiceSubscription;
  final UnifiedRecipeService _recipeService;
  final MenuService _menuService;
  final AnalyticsService _analyticsService;

  // Local disposal flag, kept alongside BaseViewModel's own guard. It is set at
  // the very START of dispose() (before super.dispose()) so the module/stream
  // callbacks below (_onStateChanged, _onRecipesChanged) are already inert
  // during teardown, before the base flag flips. BaseViewModel.isDisposed only
  // becomes true inside super.dispose() at the end, which would be too late for
  // this VM's own guarded callbacks.
  bool _isDisposed = false;

  /// P5-U25: how many dishes the last generated prompt asked for, per meal
  /// type (lower-cased). Empty for a menu that was not generated here (a
  /// loaded or shared menu), which then never reads as partial.
  Map<String, int> _requestedByMealType = const {};

  /// P6-U01: set when the last generation matched nothing.
  MenuNoMatchOutcome? _noMatch;

  // Modules
  late final MenuStateManager _stateManager;
  late final MenuGenerator _generator;
  late final MenuStorage _storage;
  late final MenuSocialManager _socialManager;
  late final MenuDraftManager _drafts;
  MenuLiveSession? _live;
  final MenuLiveSession Function(MenuMapSink onMenu)? _liveSessionFactory;
  final MenuGenerationRuns<_MenuScreen> _runs = MenuGenerationRuns();
  late final VoidCallback _onStateChanged;

  /// [draftStore] and [draftOwnerId] are seams for tests (BUT-2157).
  MenuViewModel({
    UnifiedRecipeService? recipeService,
    MenuService? menuService,
    AnalyticsService? analyticsService,
    WeeklyMenuDraftStore? draftStore,
    String? Function()? draftOwnerId,
    MenuLiveSession Function(MenuMapSink onMenu)? liveSessionFactory,
  }) : _liveSessionFactory = liveSessionFactory,
       _recipeService =
           recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
       _menuService = menuService ?? ServiceLocator.get<MenuService>(),
       _analyticsService =
           analyticsService ?? ServiceLocator.get<AnalyticsService>() {
    // Initialize focused modules
    _stateManager = MenuStateManager();
    _generator = MenuGenerator(
      menuService: _menuService,
      recipeService: _recipeService,
      userService: ServiceLocator.get<UserService>(),
      // BUT-1318: reuse the registered plan service to down-weight recipes
      // used in the last 1-2 weeks. tryGet keeps construction safe in tests
      // that don't register it (recent-use dedup is simply skipped then).
      weeklyMenuPlanService: ServiceLocator.tryGet<WeeklyMenuPlanService>(),
      // BUT-1317 (safety): personal weekly-menu generation must respect the
      // user's tracked allergens/dietary prefs by default, mirroring the group
      // flow. Filtering honors includeUnknownInMenu; the household toggle and
      // prompt-inline constraints still layer on top.
      filterByAllergens: true,
      filterByDietary: true,
    );
    _storage = MenuStorage();
    _drafts = MenuDraftManager(
      safePool: () async {
        await _generator.ensureRecipeServiceInitialized();
        return _generator.getAvailableRecipesAsync();
      },
      store: draftStore,
      ownerId: draftOwnerId,
    );
    _socialManager = MenuSocialManager(
      socialMenuOps: ServiceLocator.get<SocialMenuOperations>(),
    );

    // Forward state manager notifications
    _onStateChanged = () {
      if (!_isDisposed) notifyListeners();
    };
    _stateManager.addListener(_onStateChanged);

    // Listen to recipe service changes
    _recipeServiceSubscription = _recipeService.stateStream.listen(
      (_) => _onRecipesChanged(),
    );

    // Load all menus at startup
    _loadAllMenus();
  }

  // Getters
  Map<String, List<Recipe>> get menu => _stateManager.menu;
  bool get isGenerating => _stateManager.isGenerating;
  // Error state is owned by _stateManager, NOT BaseViewModel's own _error store.
  // These getters (and clearError below) override the base to read _stateManager.
  // Consequence: the INHERITED setError/setLoading/reset write BaseViewModel's
  // inert _error/_isLoading, which nothing here reads — so route menu errors
  // through _stateManager.setError, never the inherited setError, and don't wrap
  // menu ops in executeAsync (its catch calls the inherited setError → a silent,
  // never-displayed error). Cross-cutting cleanup for the delegate-pattern VMs
  // tracked in BUT-1462.
  @override
  String? get error => _stateManager.error;
  @override
  bool get hasError => _stateManager.hasError;
  bool get hasMenu => _stateManager.hasMenu;
  String get lastPrompt => _stateManager.lastPrompt;
  List<SavedMenuInfo> get savedMenus => _stateManager.savedMenus;
  int get totalRecipeCount => _stateManager.totalRecipeCount;

  /// P5-U25: the generated menu has fewer dishes than the prompt asked for
  /// (1 ≤ n < requested, produktregler.md:206), or null. Read from the menu
  /// as it is now, so a re-rolled section that filled the gap clears it.
  MenuPartialOutcome? get partialOutcome {
    if (_requestedByMealType.isEmpty || !hasMenu) return null;
    final foundByType = <String, int>{};
    for (final entry in menu.entries) {
      final key = entry.key.toLowerCase();
      foundByType[key] = (foundByType[key] ?? 0) + entry.value.length;
    }
    var requested = 0;
    var found = 0;
    final missing = <MenuMissingMeal>[];
    for (final entry in _requestedByMealType.entries) {
      final got = foundByType[entry.key] ?? 0;
      requested += entry.value;
      found += got < entry.value ? got : entry.value;
      if (got < entry.value) {
        missing.add(
          MenuMissingMeal(
            mealType: entry.key,
            found: got,
            requested: entry.value,
          ),
        );
      }
    }
    if (found < 1 || found >= requested) return null;
    return MenuPartialOutcome(
      found: found,
      requested: requested,
      missing: List.unmodifiable(missing),
    );
  }

  /// P5-U25: dishes asked for per meal type, read the same way generation
  /// read the prompt (MenuService.generateMenuFromParsedRequest: each day
  /// pin asks for one, each slot request for its count). Empty when the
  /// prompt cannot be parsed, so a failed parse never invents a gap.
  Future<Map<String, int>> _requestedCountsFor(String prompt) async {
    try {
      final parsed = await _menuService.parsePrompt(prompt);
      if (parsed == null) return const {};
      final counts = <String, int>{};
      for (final pin in parsed.dayPins) {
        final key = pin.mealType.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
      }
      for (final slot in parsed.slotRequests) {
        final key = slot.mealType.toLowerCase();
        counts[key] = (counts[key] ?? 0) + slot.totalCount;
      }
      counts.removeWhere((_, count) => count <= 0);
      return counts;
    } catch (e) {
      AppLogger.error('Could not read the requested dish count', e);
      return const {};
    }
  }

  /// P6-U01: the last generation matched nothing, or null.
  MenuNoMatchOutcome? get noMatchOutcome => hasMenu ? null : _noMatch;

  /// The requirements the prompt was read as, for the no-match state.
  Future<List<String>> _constraintLabelsFor(String prompt) async {
    try {
      final parsed = await _menuService.parsePrompt(prompt);
      if (parsed == null) return const [];
      return [
        for (final entry in parsed.trace.understood)
          if (entry.category != TraceCategory.count &&
              entry.category != TraceCategory.mealType &&
              entry.category != TraceCategory.day)
            entry.label,
      ];
    } catch (e) {
      AppLogger.error('Could not read the requirements of the prompt', e);
      return const [];
    }
  }

  List<Recipe> get availableRecipes => _generator.availableRecipes;
  bool get hasAvailableRecipes => _generator.hasAvailableRecipes;

  /// The pool a user may pick a recipe FROM (vote alternatives): filtered for
  /// the whole household including diner profiles, like generation and swap.
  /// [availableRecipes] filters on the signed-in user alone.
  Future<List<Recipe>> getAvailableRecipesAsync() =>
      _generator.getAvailableRecipesAsync();

  /// Whether the user has a household group configured.
  bool get hasHousehold {
    final service = ServiceLocator.tryGet<HouseholdService>();
    return service?.hasHousehold ?? false;
  }

  /// Whether menu generation uses the whole household's allergens (BUT-1465:
  /// now driven by the persisted per-user opt-out that the generator reads live
  /// from the profile — the settings toggle persists via UserService, so there
  /// is no in-memory setter here anymore).
  bool get useHouseholdAllergens => _generator.useHouseholdAllergens;

  /// Recipes hidden from the last generated pool by the family/household
  /// allergen+dietary filter (BUT-1464, PM condition 1 — a smaller menu must
  /// never look like a bug). 0 until a generation has run.
  int get hiddenByFamilyCount =>
      _generator.lastPoolStats?.hiddenByAllergenFilter ?? 0;

  /// Whose preferences hid those recipes — the hint says "familjens
  /// allergier" only when a household/present union actually filtered; a
  /// solo user's own filter gets neutral wording (BUT-1464 review M2).
  MenuPrefSource get hiddenPrefSource =>
      _generator.lastPoolStats?.prefSource ?? MenuPrefSource.singleUser;

  /// Whether [recipeId] stayed in the last pool despite an UNKNOWN effective
  /// status for a tracked allergen (the `includeUnknownInMenu` soft path) —
  /// the menu card shows an "allergener okända" chip for these.
  bool isUnknownSoft(String recipeId) =>
      _generator.lastPoolStats?.unknownSoftRecipeIds.contains(recipeId) ??
      false;

  // BUT-1820: the pool stats must describe the menu on screen. A loaded menu
  // was never filtered by this session's pool, so a stale roster-incomplete
  // source would put the warning over a friend's menu.
  void _forgetPoolStats() => _generator.lastPoolStats = null;

  /// Generates menu from AI prompt
  /// - Menu state update with generated content
  /// **Usage Example:**
  /// ```dart
  /// await menuViewModel.generateMenu(
  ///   'Vegetarisk veckomeny för familj med barn som gillar pasta',
  /// );
  /// ```
  Future<MenuGenerationEnd> generateMenu(String prompt) async {
    _leaveLiveMenu();
    if (!_stateManager.validatePrompt(prompt)) {
      _stateManager.setError(AppLocale.current.errorEnterMenuDescription);
      return MenuGenerationEnd.rejected;
    }

    final run = _runs.start(_screenNow());
    _stateManager.setGenerating(true);
    _stateManager.setLastPrompt(prompt.trim());
    _requestedByMealType = const {};
    _noMatch = null;

    try {
      // Track menu generation started
      await _analyticsService.logMenuGenerationStarted(
        promptLength: prompt.trim().length,
      );
      if (!run.isCurrent) return MenuGenerationEnd.cancelled;

      final startTime = clock.now();
      final generatedMenu = await run.guard(
        _generator.generateMenuFromPrompt(
          prompt.trim(),
          isCancelled: run.isCancelled,
        ),
      );
      if (generatedMenu.isEmpty) {
        // P6-U01: nothing matched. Its own outcome, never an error, and the
        // earlier suggestion gives way to it like any new generation.
        final constraints = await run.guard(
          _constraintLabelsFor(prompt.trim()),
        );
        _noMatch = MenuNoMatchOutcome(
          poolSize: _generator.lastPoolSize,
          constraints: List.unmodifiable(constraints),
        );
        _stateManager.setMenu(const {});
        _stateManager.clearErrorAfterSuccess();
        _drafts.stopTracking();
        await _analyticsService.logMenuGenerationFailed(
          errorCode: 'menu_generation_no_match',
          errorMessage: 'menu_generation_no_match',
        );
        return _endOf(run);
      }
      _requestedByMealType = await run.guard(
        _requestedCountsFor(prompt.trim()),
      );
      _stateManager.setMenu(generatedMenu);
      _stateManager.clearErrorAfterSuccess();

      // Track menu generation success
      final generationTime = clock.now().difference(startTime).inMilliseconds;
      await _analyticsService.logMenuGenerated(
        recipeCount: totalRecipeCount,
        method: 'ai_prompt',
      );

      // Also log the time taken if it was slow
      if (generationTime > 10000) {
        // More than 10 seconds
        await _analyticsService.logSlowOperation(
          operationName: 'menu_generation',
          durationMs: generationTime,
          thresholdMs: 10000,
        );
      }
      // The awaits above leave the cancel button on screen. A cancel that
      // landed there has already put the earlier suggestion back, and that
      // suggestion must neither be recorded as this run's draft nor placed.
      if (!run.isCurrent) return MenuGenerationEnd.cancelled;
      unawaited(
        _drafts.record(
          prompt: lastPrompt,
          menu: menu,
          requestedByMealType: _requestedByMealType,
        ),
      );
      return MenuGenerationEnd.completed;
    } on MenuGenerationCancelled {
      return MenuGenerationEnd.cancelled;
    } on MenuNoRecipesException {
      // P6-U01: an empty library keeps its own message. The sanitizer below
      // would turn it into "Ett fel uppstod".
      _stateManager.setError(AppLocale.current.errorNoRecipesAvailable);
      await _analyticsService.logMenuGenerationFailed(
        errorCode: 'menu_generation_no_recipes',
        errorMessage: 'menu_generation_no_recipes',
      );
      return MenuGenerationEnd.completed;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorImportFailed,
        e,
      );

      // Track menu generation failure — log generic code, not full exception
      await _analyticsService.logMenuGenerationFailed(
        errorCode: 'menu_generation_error',
        errorMessage: 'menu_generation_failed',
      );
      return MenuGenerationEnd.completed;
    } finally {
      // A cancelled or superseded run leaves the busy state to whoever owns
      // the screen now.
      if (_runs.finish(run) && !_isDisposed) {
        _stateManager.setGenerating(false);
      }
    }
  }

  /// BUT-2157: "Avbryt planeringen". Returns at once: steps not yet started
  /// never start, a read already in flight is dropped when it lands, and the
  /// screen goes back to what it showed before the run (the earlier
  /// suggestion, its prompt and outcome). Nothing is written.
  void cancelGeneration() {
    if (_isDisposed) return;
    final before = _runs.cancel();
    if (before == null) return;
    _requestedByMealType = before.requested;
    _noMatch = before.noMatch;
    _stateManager.loadMenuFromData(
      menu: before.menu,
      lastPrompt: before.prompt,
    );
    if (before.error != null) _stateManager.setError(before.error);
    _stateManager.setGenerating(false);
    AnalyticsService.tryLog(AnalyticsEvents.menuGenerationCancelled);
  }

  MenuGenerationEnd _endOf(MenuGenerationRun<_MenuScreen> run) =>
      run.isCurrent ? MenuGenerationEnd.completed : MenuGenerationEnd.cancelled;

  _MenuScreen _screenNow() => (
    menu: {for (final e in menu.entries) e.key: List<Recipe>.of(e.value)},
    prompt: lastPrompt,
    error: error,
    requested: _requestedByMealType,
    noMatch: _noMatch,
  );

  /// BUT-2157: the kept draft found by [checkForDraft], until it is restored
  /// or discarded. A resume prompt binds here.
  WeeklyMenuDraft? get pendingDraft => _drafts.pending;

  /// Looks for a kept draft. Ignored once the screen holds a menu or a run.
  Future<void> checkForDraft() async {
    final draft = await _drafts.check();
    if (_isDisposed || draft == null) return;
    if (hasMenu || isGenerating) {
      _drafts.takePending();
      return;
    }
    notifyListeners();
  }

  /// Puts [pendingDraft] back on screen through the allergen-safe pool.
  /// Returns how many dishes were dropped, or null when nothing was
  /// restored.
  Future<int?> restoreDraft() async {
    _leaveLiveMenu();
    final restored = await _drafts.restore();
    if (_isDisposed || restored == null) return null;
    _requestedByMealType = restored.menu.isEmpty
        ? const {}
        : restored.requestedByMealType;
    _noMatch = null;
    _stateManager.loadMenuFromData(
      menu: restored.menu,
      lastPrompt: restored.prompt,
    );
    return restored.dropped;
  }

  /// Hides [pendingDraft] for a discard with undo; [undoDiscardDraft] offers
  /// it again, [discardDraft] deletes it once the undo window has closed.
  WeeklyMenuDraft? hideDraft() {
    final draft = _drafts.takePending();
    if (draft != null) notifyListeners();
    return draft;
  }

  void undoDiscardDraft(WeeklyMenuDraft draft) {
    if (_isDisposed) return;
    _drafts.offerAgain(draft);
    notifyListeners();
  }

  Future<void> discardDraft(WeeklyMenuDraft draft) =>
      _drafts.discard(only: draft);

  /// The suggestion reached the week or a saved menu, so it is no longer a
  /// draft.
  Future<void> markDraftSaved() => _drafts.markSaved();

  // A draft is personal and must not capture a shared menu.
  Future<void> _recordDraftEdit() => isLiveMenu
      ? Future<void>.value()
      : _drafts.recordEdit(
          prompt: lastPrompt,
          menu: menu,
          requestedByMealType: _requestedByMealType,
        );

  /// Regenerates specific menu section with AI-powered recipe replacement and state coordination.
  /// Re-rolls one section using the original prompt constraints.
  Future<void> regenerateSection(String section) async {
    if (!hasMenu || !canEditMenu) return;

    final run = _runs.start(_screenNow());
    _stateManager.setGenerating(true);

    try {
      final newRecipes = await run.guard(
        _generator.regenerateMenuSection(
          section,
          menu,
          originalPrompt: _stateManager.lastPrompt.isNotEmpty
              ? _stateManager.lastPrompt
              : null,
          isCancelled: run.isCancelled,
        ),
      );

      if (newRecipes != null) {
        if (isLiveMenu) {
          await _live!.writeSection(section, newRecipes);
        } else {
          _stateManager.updateMenuSection(section, newRecipes);
        }
        _stateManager.clearErrorAfterSuccess();
        unawaited(_recordDraftEdit());
      }
    } on MenuGenerationCancelled {
      return;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotUpdate(section),
        e,
      );
    } finally {
      if (_runs.finish(run) && !_isDisposed) {
        _stateManager.setGenerating(false);
      }
    }
  }

  /// Swaps a single recipe with the best-scoring alternative.
  /// Returns a [SwapResult] with the replacement and alternatives count.
  /// When no replacement is found, [SwapResult.recipe] is null and
  /// [SwapResult.exhaustedMessage] contains an informative message.
  Future<SwapResult> swapRecipe(Recipe recipe, String category) async {
    if (!hasMenu || !canEditMenu) {
      return SwapResult(
        recipe: null,
        alternativesRemaining: 0,
        exhaustedMessage: AppLocale.current.errorNoMoreRecipesForSwap,
      );
    }

    // BUT-1464: async — the swap pool is the allergen-safe household pool.
    final result = await _generator.swapSingleRecipe(recipe, category, menu);
    if (result.recipe == null) {
      _stateManager.setError(
        result.exhaustedMessage ?? AppLocale.current.errorNoMoreRecipesForSwap,
      );
      return result;
    }

    // Update the menu with the swapped recipe
    final updatedRecipes = List<Recipe>.from(menu[category] ?? []);
    final index = updatedRecipes.indexWhere((r) => r.id == recipe.id);
    if (index != -1) {
      final before = menu[category];
      updatedRecipes[index] = result.recipe!;
      _stateManager.updateMenuSection(category, updatedRecipes);
      unawaited(_recordDraftEdit());
      if (isLiveMenu) {
        try {
          await _live!.replaceRecipe(category, index, result.recipe!);
        } catch (e) {
          // A snapshot that arrived meanwhile has replaced the list, and must stay.
          if (before != null && identical(menu[category], updatedRecipes)) {
            _stateManager.updateMenuSection(category, before);
          }
          _stateManager.handleOperationError(
            AppLocale.current.errorCouldNotUpdate(category),
            e,
          );
        }
      }
    }

    return result;
  }

  /// BUT-1241: parsed constraint trace for the last generation prompt, used
  /// to thread day pins ("tacofredag") and the extraction-chip strip into
  /// the calendar distribution. Re-parses on demand — the parser is
  /// deterministic and lexicon-cached, so this costs no LLM call and stays
  /// consistent with what generation saw.
  Future<ParsedMenuRequest?> parsedRequestForLastPrompt() async {
    final prompt = lastPrompt;
    if (prompt.isEmpty) return null;
    try {
      return await _menuService.parsePrompt(prompt);
    } catch (e) {
      AppLogger.error('Could not re-parse menu prompt', e);
      return null;
    }
  }

  /// Clears current menu state for new generation or menu reset operations.
  /// Delegates to MenuStateManager for complete menu state cleanup
  /// enabling fresh menu generation and state reset functionality.
  void clearMenu() {
    _leaveLiveMenu();
    _requestedByMealType = const {};
    _noMatch = null;
    _stateManager.clearMenu();
    unawaited(_drafts.discard());
  }

  /// Clears current error state for error recovery and clean state management.
  /// Delegates to MenuStateManager for error state cleanup enabling
  /// error recovery and clean user experience after error resolution.
  @override
  void clearError() {
    // dispose() disposes _stateManager, so an unguarded call after disposal
    // notifies a dead ChangeNotifier and throws.
    if (isDisposed) return;

    _stateManager.clearError();
  }

  /// Loads menu content from a SharedMenu for viewing/editing.
  /// Used when navigating to VeckomenyView with a shared menu from social features.
  void loadFromSharedMenu(SharedMenu sharedMenu) {
    _leaveLiveMenu();
    _requestedByMealType = const {};
    _forgetPoolStats();
    _drafts.stopTracking();
    _stateManager.setMenu(sharedMenu.menuSnapshot);
    AppLogger.info('Loaded shared menu: ${sharedMenu.menuTitle}');
  }

  bool get isLiveMenu => _live?.isLive ?? false;
  String? get liveMenuId => _live?.resourceId;

  /// Not live: the user's own menu, always editable. Live: the viewer's role.
  bool get canEditMenu => !isLiveMenu || _live!.canEdit;

  Future<void> startLiveMenu(String resourceId) async {
    _requestedByMealType = const {};
    _forgetPoolStats();
    _drafts.stopTracking();
    _live ??= (_liveSessionFactory ?? (sink) => MenuLiveSession(onMenu: sink))(
      (menu) {
        if (!_isDisposed) _stateManager.setMenu(menu);
      },
    );
    await _live!.start(resourceId);
  }

  // Putting another menu on screen ends the live session first, so its edits
  // are never written into the shared menu.
  void _leaveLiveMenu() {
    if (isLiveMenu) unawaited(_live!.stop());
  }

  /// Saves menu with comprehensive metadata and optional social sharing coordination.
  /// [menuName] Display name for saved menu identification
  /// [comment] User comment describing menu characteristics
  /// [shareWithFriends] Whether to share menu with selected friends
  /// [selectedFriendIds] List of friend user IDs for sharing
  /// [shareMessage] Optional custom message for social sharing
  /// Returns true if save operation succeeds, false if validation fails or save errors occur.
  /// Performs complete menu save flow including validation, local storage, social sharing coordination,
  /// and saved menus list refresh for comprehensive menu persistence management.
  /// **Save Process:**
  /// - Menu and name validation with Swedish localized feedback
  /// - Local menu storage with metadata and recipe content
  /// - Optional social sharing with friend coordination
  /// - Saved menus list refresh for UI synchronization
  /// **Usage Example:**
  /// ```dart
  /// final saved = await menuViewModel.saveMenuWithNameAndComment(
  ///   'Familjevänlig Veckomeny',
  ///   'Näringsrik meny som barnen älskar',
  ///   shareWithFriends: true,
  ///   selectedFriendIds: ['friend1', 'friend2'],
  ///   shareMessage: 'Perfekt meny för familjer!',
  /// );
  /// ```
  Future<bool> saveMenuWithNameAndComment(
    String menuName,
    String comment, {
    bool shareWithFriends = false,
    List<String>? selectedFriendIds,
    String? shareMessage,
  }) async {
    final l = AppLocale.current;
    if (!_stateManager.validateMenuForSaving()) {
      _stateManager.setError(l.errorNoMenuToSave);
      return false;
    }

    if (!_storage.validateMenuName(menuName)) {
      _stateManager.setError(l.errorEnterMenuName);
      return false;
    }

    try {
      // Save to Firestore
      final menuId = await _storage.saveMenu(
        menuName: menuName,
        comment: comment,
        menu: menu,
        lastPrompt: lastPrompt,
        totalRecipeCount: totalRecipeCount,
      );

      // Track menu saved analytics
      await _analyticsService.logMenuSaved(
        menuId: menuId,
        recipeCount: totalRecipeCount,
        isShared: shareWithFriends && (selectedFriendIds?.isNotEmpty ?? false),
      );

      // First-meal-plan milestone fires at most once per user (BUT-576).
      final userService = ServiceLocator.tryGet<UserService>();
      await _analyticsService.menu.logFirstMealPlanIfMilestone(
        userId: userService?.currentUserId,
        recipeCountInPlan: totalRecipeCount,
        joinedAt: userService?.currentUserProfile?.joinedAt,
      );

      // Handle social sharing if requested
      if (shareWithFriends &&
          selectedFriendIds != null &&
          selectedFriendIds.isNotEmpty) {
        try {
          final shareSuccess = await _socialManager.shareMenuWithFriends(
            menu: menu,
            friendUserIds: selectedFriendIds,
            menuName: menuName,
            shareMessage: shareMessage,
          );

          if (shareSuccess) {
            // Track menu shared analytics
            await _analyticsService.logMenuShared(
              menuId: menuId,
              recipientCount: selectedFriendIds.length,
              shareMethod: 'social',
            );
          } else {
            _stateManager.setError(AppLocale.current.errorSomeSharesFailed);
          }
        } catch (e) {
          _stateManager.setError(AppLocale.current.errorSomeSharesFailed);
        }
      }

      await markDraftSaved();

      // Refresh saved menus list
      await _loadAllMenus();
      return true;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotSaveRecipe,
        e,
      );
      return false;
    }
  }

  /// Loads saved menu with comprehensive source detection and state coordination.
  /// [menuKey] Unique identifier for saved menu retrieval
  /// Returns true if menu loads successfully, false if menu not found or load errors occur.
  /// Performs intelligent menu loading attempting local storage first, then imported menus,
  /// with automatic state management and error handling for seamless menu retrieval.
  /// **Load Process:**
  /// - Local storage menu retrieval attempt
  /// - Imported menu fallback for social menu access
  /// - Menu state coordination with recipe and prompt data
  /// - Error handling with Swedish localized feedback
  /// **Usage Example:**
  /// ```dart
  /// final loaded = await menuViewModel.loadSavedMenu('menu_key_123');
  /// if (loaded) {
  ///   // Menu loaded successfully, update UI
  /// } else {
  ///   // Handle load failure
  /// }
  /// ```
  Future<bool> loadSavedMenu(String menuKey) async {
    _leaveLiveMenu();
    try {
      // Try loading from local storage first
      final localMenuData = await _storage.loadMenuByKey(menuKey);
      if (localMenuData != null) {
        _requestedByMealType = const {};
        _forgetPoolStats();
        _drafts.stopTracking();
        _stateManager.loadMenuFromData(
          menu: localMenuData.menu,
          lastPrompt: localMenuData.lastPrompt,
        );
        return true;
      }

      // Try loading from imported menus
      final importedMenuData = await _socialManager.loadImportedMenuData(
        menuKey,
      );
      if (importedMenuData != null) {
        _requestedByMealType = const {};
        _forgetPoolStats();
        _drafts.stopTracking();
        _stateManager.loadMenuFromData(
          menu: importedMenuData.menu,
          lastPrompt: importedMenuData.lastPrompt,
        );
        return true;
      }

      _stateManager.setError(AppLocale.current.errorMenuNotFound);
      return false;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotLoad('meny'),
        e,
      );
      return false;
    }
  }

  /// Deletes saved menu with automatic list refresh and comprehensive error handling.
  /// [menuKey] Unique identifier for menu deletion
  /// Returns true if deletion succeeds, false if operation fails.
  /// Performs menu deletion through MenuStorage with automatic saved menus list refresh
  /// for immediate UI synchronization and comprehensive error handling.
  /// **Usage Example:**
  /// ```dart
  /// final deleted = await menuViewModel.deleteSavedMenu('menu_key_123');
  /// ```
  Future<bool> deleteSavedMenu(String menuKey) async {
    try {
      final success = await _storage.deleteMenuByKey(menuKey);
      if (success) {
        await _loadAllMenus();
      }
      return success;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotDelete('meny'),
        e,
      );
      return false;
    }
  }

  /// Marks menu as modified for change tracking and version management.
  /// [menuKey] Unique identifier for menu modification marking
  /// Returns true if marking succeeds, false if operation fails.
  /// Delegates to MenuStorage for modification tracking enabling
  /// menu version management and change detection capabilities.
  Future<bool> markMenuAsModified(String menuKey) async {
    try {
      return await _storage.markMenuAsModified(menuKey);
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotUpdate('meny'),
        e,
      );
      return false;
    }
  }

  /// Retrieves available shared menus from social network with comprehensive error handling.
  /// Returns list of shared menu metadata for social menu discovery and import functionality.
  /// Delegates to MenuSocialManager for social menu retrieval with automatic error handling
  /// and empty list fallback for robust social feature integration.
  /// **Usage Example:**
  /// ```dart
  /// final sharedMenus = await menuViewModel.getAvailableSharedMenus();
  /// for (final menuData in sharedMenus) {
  ///   // Display shared menu information
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> getAvailableSharedMenus() async {
    try {
      return await _socialManager.getAvailableSharedMenus();
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotLoad('delade menyer'),
        e,
      );
      return <Map<String, dynamic>>[];
    }
  }

  /// Imports shared menu with automatic list refresh and comprehensive state management.
  /// [sharedMenuId] Unique identifier for shared menu import
  /// Returns true if import succeeds, false if operation fails.
  /// Performs shared menu import through MenuSocialManager with automatic saved menus refresh
  /// for immediate UI synchronization and comprehensive error handling with Swedish feedback.
  /// **Usage Example:**
  /// ```dart
  /// final imported = await menuViewModel.importSharedMenu('shared_menu_123');
  /// if (imported) {
  ///   // Menu imported successfully, update UI
  /// }
  /// ```
  Future<bool> importSharedMenu(String sharedMenuId) async {
    try {
      final success = await _socialManager.importSharedMenu(sharedMenuId);
      if (success) {
        await _loadAllMenus();
      }
      return success;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotImportRecipes,
        e,
      );
      return false;
    }
  }

  /// Marks shared menu as viewed for social engagement tracking and notification management.
  /// [sharedMenuId] Unique identifier for shared menu view tracking
  /// Delegates to MenuSocialManager for view tracking enabling social engagement metrics
  /// and notification management for shared menu interactions.
  Future<void> markSharedMenuAsViewed(String sharedMenuId) async {
    await _socialManager.markSharedMenuAsViewed(sharedMenuId);
  }

  /// Retrieves comprehensive sharing statistics for social engagement insights.
  /// Returns sharing statistics data for social engagement analysis and user insights.
  /// Delegates to MenuSocialManager for comprehensive sharing metrics including
  /// share counts, view statistics, and engagement data for social feature optimization.
  Future<Map<String, dynamic>> getSharingStats() async {
    return await _socialManager.getSharingStats();
  }

  /// Refreshes saved menus list for UI synchronization and data consistency.
  /// Reloads complete saved menus list including local and imported menus
  /// with sorting and organization for UI display and menu management operations.
  Future<void> refreshSavedMenus() async {
    await _loadAllMenus();
  }

  /// Handles reactive updates from recipe service changes with automatic UI synchronization.
  /// Provides seamless state synchronization between UnifiedRecipeService and ViewModel ensuring
  /// all recipe availability changes are immediately reflected in menu generation capabilities
  /// for consistent user experience and real-time recipe status updates.
  void _onRecipesChanged() {
    if (_isDisposed) return;
    notifyListeners();
  }

  /// Loads all saved menus with comprehensive organization and intelligent sorting.
  /// Performs complete menu loading from both local storage and social imports
  /// with intelligent sorting prioritizing user-owned menus and chronological organization.
  /// Includes comprehensive error handling and success logging for menu management operations.
  /// **Loading Process:**
  /// - Local menus retrieval from MenuStorage
  /// - Imported menus retrieval from MenuSocialManager
  /// - Intelligent sorting with ownership priority and date organization
  /// - State management update with organized menu list
  Future<void> _loadAllMenus() async {
    try {
      final localMenus = await _storage.loadUserMenus();
      final importedMenus = await _socialManager.loadImportedMenus();

      // Combine and sort menus
      final allMenus = <SavedMenuInfo>[...localMenus, ...importedMenus];
      allMenus.sort((a, b) {
        // Own menus first
        if (a.isOwned && !b.isOwned) return -1;
        if (!a.isOwned && b.isOwned) return 1;

        // Within same type, sort by date (newest first)
        return b.savedDate.compareTo(a.savedDate);
      });

      _stateManager.setSavedMenus(allMenus);

      AppLogger.success(
        '✅ Alla menyer laddade: ${localMenus.length} lokala, ${importedMenus.length} importerade',
      );
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av menyer: $e');
    }
  }

  /// Performs comprehensive ViewModel disposal with module cleanup and memory management.
  /// Disposes all focused modules, removes service listeners, and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic menu management scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _isDisposed = true;
    _runs.cancel();
    _live?.dispose();
    _stateManager.removeListener(_onStateChanged);
    _stateManager.dispose();
    _recipeServiceSubscription?.cancel();
    super.dispose();
  }
}
