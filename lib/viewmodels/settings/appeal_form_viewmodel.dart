import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

class AppealFormViewModel extends BaseViewModel {
  AppealFormViewModel({
    required this.reportId,
    required this.role,
    required ModerationAppealsService service,
  }) : _service = service;

  final String reportId;
  final AppealRole role;
  final ModerationAppealsService _service;

  String _text = '';
  String get text => _text;

  AppealFailure? _failure;
  AppealFailure? get failure => _failure;

  bool get canSubmit {
    final n = _text.trim().length;
    return !isLoading &&
        n >= ModerationAppealsService.minTextLength &&
        n <= ModerationAppealsService.maxTextLength;
  }

  void setText(String value) {
    _text = value;
    notifyListeners();
  }

  /// True when the appeal was accepted; otherwise [failure] says why.
  Future<bool> submit() async {
    if (!canSubmit || isDisposed) return false;
    _failure = null;
    setLoading(true);
    try {
      await _service.submitAppeal(reportId: reportId, role: role, text: _text);
      if (isDisposed) return true;
      setLoading(false);
      return true;
    } on AppealException catch (e) {
      _failure = e.failure;
    } catch (e) {
      AppLogger.error('[AppealFormViewModel] submitAppeal failed', e);
      _failure = AppealFailure.other;
    }
    if (!isDisposed) setLoading(false);
    return false;
  }
}
