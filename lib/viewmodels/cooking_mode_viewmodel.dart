// lib/viewmodels/cooking_mode_viewmodel.dart

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/widgets/common/input/portion_scaler_logic.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// ViewModel for cooking mode — manages portion scaling, step tracking, and font scale.
class CookingModeViewModel extends ChangeNotifier {
  final Recipe recipe;

  late int _currentPortions;
  late List<String> _scaledIngredients;
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

  CookingModeViewModel({required this.recipe}) {
    _currentPortions = recipe.portions ?? 1;
    _scaledIngredients = List.from(recipe.ingredients);
    _loadFontScale();
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

  void updatePortions(int newPortions) {
    if (newPortions < minPortions || newPortions > maxPortions) return;
    if (newPortions == _currentPortions) return;

    _currentPortions = newPortions;
    _scaledIngredients = PortionScalerLogic.scaleIngredients(
      recipe.ingredients,
      originalPortions,
      _currentPortions,
      false,
    );
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
}
