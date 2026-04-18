import 'package:clock/clock.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';

/// Service coordinating the "mark recipe as cooked" action.
///
/// Owns two responsibilities the model layer cannot:
/// 1. Atomic Firestore write via [RecipeRepository.incrementCookCount] — a
///    single `FieldValue.increment(1)` update, no read-modify-write race.
/// 2. Per-session idempotency — rapid double-taps on the same recipe within
///    the same calendar day count once. Guard is process-local; a fresh app
///    launch on the next day naturally counts again.
class RecipeCookingService extends BaseService {
  final RecipeRepository _recipeRepository;

  /// Keyed by `recipeId|YYYY-MM-DD`. Presence = already counted today.
  final Set<_CookEventKey> _cookedThisSession = <_CookEventKey>{};

  RecipeCookingService({required RecipeRepository recipeRepository})
      : _recipeRepository = recipeRepository;

  @override
  String get serviceName => 'RecipeCookingService';

  /// Atomically increment cook count and set lastCookedAt.
  /// Returns true if the write happened; false when rejected by the
  /// session guard (already cooked today) or an underlying write failure.
  Future<bool> markAsCooked(String recipeId) async {
    if (recipeId.isEmpty) return false;

    final now = clock.now();
    final key = _CookEventKey(recipeId, now);

    // Session guard: rapid double-tap protection. Day-bucketed so the
    // counter can legitimately move again after midnight.
    if (_cookedThisSession.contains(key)) {
      AppLogger.info(
          'markAsCooked debounced: $recipeId already counted for ${key.day}');
      return false;
    }

    final ok = await _recipeRepository.incrementCookCount(recipeId, now);
    if (ok) {
      _cookedThisSession.add(key);
    }
    return ok;
  }

  /// Test-only: reset the in-memory dedup set.
  void resetSessionGuardForTesting() {
    _cookedThisSession.clear();
  }

  @override
  Future<void> onDispose() async {
    _cookedThisSession.clear();
  }
}

/// Composite key for the session dedup set — recipe id plus calendar day.
class _CookEventKey {
  final String recipeId;
  final String day; // YYYY-MM-DD

  _CookEventKey(this.recipeId, DateTime at)
      : day = '${at.year.toString().padLeft(4, '0')}-'
            '${at.month.toString().padLeft(2, '0')}-'
            '${at.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is _CookEventKey && other.recipeId == recipeId && other.day == day;

  @override
  int get hashCode => Object.hash(recipeId, day);
}
