import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/admin/pool_inspection.dart';
import 'package:butlery/services/moderation/pool_moderation_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// The admin "Betyg" tab: look at one pooled rating and switch it off or on.
///
/// The response is held only here and dropped with the viewmodel; every
/// change is followed by a fresh read, so the numbers on screen are never
/// older than the last action.
class PoolReviewViewModel extends BaseViewModel {
  PoolReviewViewModel({required PoolModerationService service})
    : _service = service;

  final PoolModerationService _service;

  static final RegExp _poolKeyPattern = RegExp(r'^v\d+:[0-9a-f]{16}$');

  PoolInspection? _inspection;
  PoolModerationFailure? _failure;
  bool _isChanging = false;

  PoolInspection? get inspection => _inspection;

  /// Why the last read or change failed; null when it did not.
  PoolModerationFailure? get failure => _failure;

  /// True while a quarantine change is in flight.
  bool get isChanging => _isChanging;

  static bool isValidPoolKey(String raw) => _poolKeyPattern.hasMatch(raw);

  /// Reads [rawKey] fresh. A key of the wrong shape is refused here, without
  /// a call.
  Future<bool> load(String rawKey) async {
    final key = rawKey.trim();
    _inspection = null;
    _failure = null;
    if (!isValidPoolKey(key)) {
      _failure = PoolModerationFailure.invalidKey;
      notifyListeners();
      return false;
    }
    return executeAsyncVoid(() async {
      try {
        _inspection = await _service.inspect(key);
      } on PoolModerationException catch (e) {
        _failure = e.failure;
        rethrow;
      } catch (_) {
        // The view renders only `failure`, so any other error must land here
        // too or the screen goes blank after "Visa".
        _failure = PoolModerationFailure.other;
        rethrow;
      }
    }, errorPrefix: AppLocale.current.adminPoolLoadFailed);
  }

  Future<bool> quarantine(QuarantineReason reason) =>
      _change(quarantined: true, reason: reason);

  Future<bool> lift() => _change(quarantined: false);

  // True once the change itself went through, even when the re-read after it
  // fails: the view then shows the read error and a retry, never old numbers.
  Future<bool> _change({
    required bool quarantined,
    QuarantineReason? reason,
  }) async {
    final current = _inspection;
    if (current == null || _isChanging || isDisposed) return false;
    _isChanging = true;
    _failure = null;
    notifyListeners();
    try {
      await _service.setQuarantine(
        poolKey: current.poolKey,
        quarantined: quarantined,
        reason: reason,
      );
    } on PoolModerationException catch (e) {
      _failure = e.failure;
      return _endChange(false);
    } catch (e) {
      AppLogger.error('[PoolReviewViewModel] change failed', e);
      _failure = PoolModerationFailure.other;
      return _endChange(false);
    }
    _isChanging = false;
    await load(current.poolKey);
    return true;
  }

  bool _endChange(bool result) {
    _isChanging = false;
    notifyListeners();
    return result;
  }
}
