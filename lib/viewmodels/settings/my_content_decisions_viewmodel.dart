import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Decisions about the signed-in user's own content, read through
/// `getMyContentDecisions`.
class MyContentDecisionsViewModel extends BaseViewModel {
  MyContentDecisionsViewModel({
    required ReportOutcomesService reportOutcomesService,
  }) : _service = reportOutcomesService;

  final ReportOutcomesService _service;

  List<ModerationOutcome> _decisions = const [];
  List<ModerationOutcome> get decisions => _decisions;
  bool get hasDecisions => _decisions.isNotEmpty;

  Future<bool> load() => executeAsyncVoid(() async {
    _decisions = await _service.getMyContentDecisions();
  }, errorPrefix: AppLocale.current.myContentDecisionsLoadFailed);

  Future<bool> refresh() => load();
}
