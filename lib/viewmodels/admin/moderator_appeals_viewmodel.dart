import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// What happened to an answer; [alreadyAnswered] also covers an appeal that
/// no longer exists, since either way it has left the queue.
enum AppealAnswerOutcome { answered, alreadyAnswered, failed }

/// The moderator's queue of open appeals (`listOpenAppeals`).
class ModeratorAppealsViewModel extends BaseViewModel {
  ModeratorAppealsViewModel({required ModerationAppealsService service})
    : _service = service;

  final ModerationAppealsService _service;

  List<OpenAppeal> _appeals = const [];
  List<OpenAppeal> get appeals => _appeals;

  Future<bool> load() => executeAsyncVoid(() async {
    _appeals = await _service.listOpenAppeals();
  }, errorPrefix: AppLocale.current.moderatorAppealsLoadFailed);

  /// Answers [appeal]; [AppealAnswerOutcome.failed] leaves it in the list.
  Future<AppealAnswerOutcome> answer(
    OpenAppeal appeal,
    AppealStatus outcome,
  ) async {
    if (isDisposed) return AppealAnswerOutcome.failed;
    var result = AppealAnswerOutcome.answered;
    try {
      await _service.answerAppeal(appealId: appeal.appealId, outcome: outcome);
    } on AnswerAppealException catch (e) {
      if (e.failure == AnswerFailure.other) {
        AppLogger.error('[ModeratorAppealsViewModel] answerAppeal failed', e);
        return AppealAnswerOutcome.failed;
      }
      result = AppealAnswerOutcome.alreadyAnswered;
    } catch (e) {
      AppLogger.error('[ModeratorAppealsViewModel] answerAppeal failed', e);
      return AppealAnswerOutcome.failed;
    }
    if (isDisposed) return result;
    _appeals = [
      for (final a in _appeals)
        if (a.appealId != appeal.appealId) a,
    ];
    notifyListeners();
    return result;
  }
}
