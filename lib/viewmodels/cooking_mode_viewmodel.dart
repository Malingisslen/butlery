// lib/viewmodels/cooking_mode_viewmodel.dart

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe/ingredient_display_row.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/common/input/portion_scaler_logic.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// ViewModel for cooking mode — manages portion scaling, step tracking, and font scale.
class CookingModeViewModel extends ChangeNotifier {
  final Recipe recipe;

  late int _currentPortions;
  late List<String> _scaledIngredients;
  // Cached section-grouped rows, rebuilt only when the scaled lines change
  // (ctor + updatePortions) so build() stays allocation-free per frame.
  late List<IngredientDisplayRow> _ingredientRows;
  int _currentStepIndex = 0;

  // BUT-802 HIGH-PA4: per-session analytics state. `_sessionId` is generated
  // on the first `onEnter()` so two cooking screens for the same recipe get
  // distinct funnel IDs. `_sessionStartedAt` powers `duration_sec` on
  // completed/abandoned. `_stepsViewed` tracks distinct steps reached (set,
  // not counter) so revisits don't inflate the metric.
  String? _sessionId;
  DateTime? _sessionStartedAt;
  final Set<int> _stepsViewed = <int>{0};

  static const _fontScaleKey = 'butlery_cooking_font_scale';
  static const List<double> fontScaleOptions = [1.0, 1.25, 1.5];
  double _fontScale = 1.0;
  double get fontScale => _fontScale;

  // BUT-1515: UserService reference kept so the boot-race listener can be
  // removed on dispose. `_manualPortionOverride` latches once the user scales
  // by hand so a late profile-load re-apply never clobbers their choice.
  UserService? _userService;
  bool _manualPortionOverride = false;

  // BUT-1613: when cooking mode is opened from a planned weekly-menu meal, the
  // number of members present for that (day, slot) — the effective serving
  // size for this meal. It overrides the household-size default at construction
  // and latches `_presenceSourced` so the boot-race re-apply can't pull a
  // "cook for 3 tonight" back to the whole household when the profile loads
  // late. Null when opened outside the weekly menu → household default, exactly
  // as before.
  final int? presentServings;
  bool _presenceSourced = false;

  CookingModeViewModel({required this.recipe, this.presentServings}) {
    // BUT-1322/BUT-1613: open pre-scaled to the sharpest target available. The
    // recipe's own portions stay the scaling BASE; the manual scaler
    // (updatePortions) is the explicit override. Target priority (each clamped
    // to [minPortions, maxPortions]): this meal's present count > household
    // default > the recipe's own portions (no scaling).
    // Guard (review): only auto-apply when the recipe declares a REAL portion
    // count (> 0). A null/0-portions recipe has no meaningful base — scaling
    // "from 1" would multiply the printed amounts, and scaling from 0 is a
    // no-op that would desync the portion header from the (unscaled) amounts.
    final base = recipe.portions;
    final canScale = base != null && base > 0;
    final present = canScale ? _clampPortions(presentServings) : null;
    final household = (canScale && present == null)
        ? _resolveHouseholdDefault()
        : null;
    _presenceSourced = present != null;
    _currentPortions = present ?? household ?? base ?? 1;

    if (canScale && _currentPortions != base) {
      _scaledIngredients = _scaleTo(
        base,
        _currentPortions,
        present != null ? 'present_count' : 'household_default',
      );
    } else {
      _scaledIngredients = List.from(recipe.ingredients);
    }
    // PR #211: build the section-grouped rows from the FINAL scaled list
    // (after any pre-scaling above).
    _rebuildIngredientRows();
    _loadFontScale();

    // BUT-1515: on a cold deep-link the profile can still be loading when this
    // VM is constructed, so _resolveHouseholdDefault() returned null above and
    // we fell back to the recipe's own portions. Watch UserService and re-apply
    // the household default once the profile loads — unless a present count
    // already set the target (the sharper signal, which must stick).
    try {
      _userService = ServiceLocator.tryGet<UserService>();
      _userService?.addListener(_onUserServiceChanged);
    } catch (_) {}
  }

  /// BUT-1515: re-apply the household-size default after the user profile
  /// finishes loading (boot race). A manual override OR a present-count target
  /// (BUT-1613) always wins, and the null/0-portions guard is preserved.
  /// Idempotent — a no-op once the state already matches, so unrelated
  /// UserService notifications (online status, FCM token, allergen prefs)
  /// don't re-scale or re-log.
  void _onUserServiceChanged() {
    if (_manualPortionOverride || _presenceSourced) return;
    final declared = recipe.portions;
    if (declared == null || declared <= 0) return;
    final household = _resolveHouseholdDefault();
    if (household == null || household == _currentPortions) return;

    _currentPortions = household;
    _scaledIngredients = _scaleTo(declared, household, 'household_default');
    _rebuildIngredientRows();
    notifyListeners();
  }

  /// BUT-1613: scale [recipe]'s ingredients from its declared [base] portions to
  /// [target] and log the [source]. The single scale-and-log step shared by the
  /// three portion sources (present count, household default, boot-race
  /// re-apply) so it isn't triplicated. The caller owns `_currentPortions`, the
  /// row rebuild, and notify.
  List<String> _scaleTo(int base, int target, String source) {
    final scaled = PortionScalerLogic.scaleEntries(
      recipe.structuredIngredients,
      base,
      target,
      false,
    );
    _logScalingApplied(source: source, fromPortions: base, toPortions: target);
    return scaled;
  }

  void _rebuildIngredientRows() {
    _ingredientRows = IngredientDisplayRow.build(
      recipe.structuredIngredients,
      _scaledIngredients,
    );
  }

  /// BUT-1322: household-size default from the user profile. `tryGet` keeps
  /// construction safe when UserService isn't registered (tests, degraded
  /// boot); out-of-range values fall back to null (→ recipe's own portions).
  int? _resolveHouseholdDefault() {
    try {
      return _clampPortions(
        ServiceLocator.tryGet<UserService>()?.currentUserProfile?.householdSize,
      );
    } catch (_) {
      return null;
    }
  }

  /// BUT-1613: a portion target is honored only when it's a real count inside
  /// the cooking-mode scaling range; anything else → null (fall through to the
  /// next-priority source).
  int? _clampPortions(int? value) {
    if (value == null || value < minPortions || value > maxPortions) {
      return null;
    }
    return value;
  }

  Future<void> _loadFontScale() async {
    try {
      final persistence = ServiceLocator.get<PersistenceService>();
      final saved = await persistence.getInt(_fontScaleKey);
      if (saved != null && saved >= 0 && saved < fontScaleOptions.length) {
        _fontScale = fontScaleOptions[saved];
        notifyListeners();
      }
    } catch (_) {}
  }

  void cycleFontScale() {
    final currentIndex = fontScaleOptions.indexOf(_fontScale);
    final nextIndex = (currentIndex + 1) % fontScaleOptions.length;
    _fontScale = fontScaleOptions[nextIndex];
    notifyListeners();
    try {
      ServiceLocator.get<PersistenceService>().setInt(_fontScaleKey, nextIndex);
    } catch (_) {}
  }

  int get currentPortions => _currentPortions;
  int get originalPortions => recipe.portions ?? 1;
  double get scaleFactor =>
      originalPortions > 0 ? _currentPortions / originalPortions : 1.0;
  List<String> get scaledIngredients => _scaledIngredients;

  /// Section-grouped rows for rendering (headings + lines). Flat (all lines,
  /// no headings) for recipes without sections.
  List<IngredientDisplayRow> get ingredientRows => _ingredientRows;

  List<String> get instructions => recipe.instructions;
  String get title => recipe.title;

  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => recipe.instructions.length;
  bool get hasNextStep => _currentStepIndex < totalSteps - 1;
  bool get hasPreviousStep => _currentStepIndex > 0;

  void nextStep() {
    if (!hasNextStep) return;
    final from = _currentStepIndex;
    _currentStepIndex++;
    _stepsViewed.add(_currentStepIndex);
    notifyListeners();
    _broadcastStep();
    _logStepAdvanced(from, _currentStepIndex);
  }

  void previousStep() {
    if (!hasPreviousStep) return;
    final from = _currentStepIndex;
    _currentStepIndex--;
    _stepsViewed.add(_currentStepIndex);
    notifyListeners();
    _broadcastStep();
    _logStepAdvanced(from, _currentStepIndex);
  }

  void goToStep(int index) {
    if (index < 0 || index >= totalSteps) return;
    if (index == _currentStepIndex) return;
    final from = _currentStepIndex;
    _currentStepIndex = index;
    _stepsViewed.add(_currentStepIndex);
    notifyListeners();
    _broadcastStep();
    _logStepAdvanced(from, _currentStepIndex);
  }

  /// BUT-1322 (binding monetization condition): scaling telemetry. Best-effort
  /// fire-and-forget — a missing/failing analytics service never breaks the
  /// cook.
  void _logScalingApplied({
    required String source,
    required int fromPortions,
    required int toPortions,
  }) {
    try {
      ServiceLocator.tryGet<AnalyticsService>()
          ?.logPortionScalingApplied(
            recipeId: recipe.id,
            source: source,
            fromPortions: fromPortions,
            toPortions: toPortions,
          )
          .catchError((Object _) {});
    } catch (_) {}
  }

  void _logStepAdvanced(int from, int to) {
    final sid = _sessionId;
    if (sid == null) return;
    try {
      final analytics = ServiceLocator.tryGet<AnalyticsService>();
      analytics?.recipe
          .logCookingStepAdvanced(
            recipeId: recipe.id,
            sessionId: sid,
            fromStep: from,
            toStep: to,
          )
          .catchError((Object _) {});
    } catch (_) {}
  }

  /// Tell the presence module about the current step. The module debounces
  /// internally, so rapid taps only hit RTDB once.
  void _broadcastStep() {
    try {
      final module = ServiceLocator.tryGet<CookingSessionModule>();
      if (module == null) return;
      // `currentStep` broadcast as 1-based to match human-readable subtitle
      // ("steg 3 av 7"); internal _currentStepIndex stays 0-based.
      module.updateStep(
        currentStep: _currentStepIndex + 1,
        totalSteps: totalSteps,
      );
    } catch (e) {
      AppLogger.warning('Cooking session step broadcast failed: $e');
    }
  }

  static const int minPortions = 1;
  static const int maxPortions = 50;

  /// BUT-1322: manual-override analytics fires once per cooking session so
  /// household-default vs override usage stays a per-open signal, not a
  /// tap-counter.
  bool _manualOverrideLogged = false;

  void updatePortions(int newPortions) {
    if (newPortions < minPortions || newPortions > maxPortions) return;
    if (newPortions == _currentPortions) return;

    // BUT-1515: latch the override so a late profile-load re-apply can't
    // overwrite the user's hand-scaled choice.
    _manualPortionOverride = true;

    if (!_manualOverrideLogged) {
      _manualOverrideLogged = true;
      _logScalingApplied(
        source: 'manual_override',
        fromPortions: _currentPortions,
        toPortions: newPortions,
      );
    }

    _currentPortions = newPortions;
    // BUT-444: structured-first scaling (persisted amounts; per-entry
    // string fallback for legacy recipes).
    _scaledIngredients = PortionScalerLogic.scaleEntries(
      recipe.structuredIngredients,
      originalPortions,
      _currentPortions,
      false,
    );
    _rebuildIngredientRows();
    notifyListeners();
  }

  // Called from the view's initState. Broadcasts a live session to every
  // FriendCategory the user is a member of. Failures are swallowed — a
  // dropped broadcast must never interrupt the cook.
  Future<void> onEnter() async {
    // BUT-802 HIGH-PA4: generate session id + fire `cooking_session_started`.
    // Guarded against double-call so a re-entered widget tree doesn't restart
    // the funnel mid-cook.
    if (_sessionId == null) {
      _sessionId = const Uuid().v4();
      _sessionStartedAt = clock.now();
      try {
        final analytics = ServiceLocator.tryGet<AnalyticsService>();
        analytics?.recipe
            .logCookingSessionStarted(
              recipeId: recipe.id,
              sessionId: _sessionId!,
            )
            .catchError((Object _) {});
      } catch (_) {}
    }

    try {
      final module = ServiceLocator.tryGet<CookingSessionModule>();
      await module?.startSession(recipe);
    } catch (e) {
      AppLogger.warning('Cooking session onEnter broadcast failed: $e');
    }
  }

  // Called from the view's dispose. Clears the broadcast from every group;
  // safe to call if no session was ever started (module handles the no-op
  // path). The module's endSession() also cancels its pending step-debounce
  // timer, so no viewmodel-side cleanup is needed here.
  Future<void> onExit() async {
    // BUT-802 HIGH-PA4: fire completed/abandoned based on whether the user
    // reached the last step. The viewmodel can be torn down without onEnter
    // ever firing (rare — e.g. immediate back navigation), so guard on
    // `_sessionId` to avoid emitting an orphan event.
    final sid = _sessionId;
    final startedAt = _sessionStartedAt;
    if (sid != null && startedAt != null) {
      final durationSec = clock.now().difference(startedAt).inSeconds;
      final reachedLast = _currentStepIndex == totalSteps - 1;
      try {
        final analytics = ServiceLocator.tryGet<AnalyticsService>();
        if (analytics != null) {
          if (reachedLast) {
            analytics.recipe
                .logCookingSessionCompleted(
                  recipeId: recipe.id,
                  sessionId: sid,
                  durationSec: durationSec,
                  stepsViewed: _stepsViewed.length,
                )
                .catchError((Object _) {});
          } else {
            analytics.recipe
                .logCookingSessionAbandoned(
                  recipeId: recipe.id,
                  sessionId: sid,
                  durationSec: durationSec,
                  lastStep: _currentStepIndex,
                )
                .catchError((Object _) {});
          }
        }
      } catch (_) {}
      _sessionId = null;
      _sessionStartedAt = null;
    }

    try {
      final module = ServiceLocator.tryGet<CookingSessionModule>();
      await module?.endSession();
    } catch (e) {
      AppLogger.warning('Cooking session onExit cleanup failed: $e');
    }
  }

  @override
  void dispose() {
    // BUT-1515: drop the boot-race listener before tearing down.
    _userService?.removeListener(_onUserServiceChanged);
    super.dispose();
  }
}
