import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/admin/ops_event.dart';
import 'package:butlery/repositories/ops_log_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel for the admin ops-log tab: recent scheduled-job run events from
/// `system_events`. Read-only. Sparse pre-launch — only cleanup jobs log here.
class OpsLogViewModel extends BaseViewModel {
  final OpsLogRepository _repository;

  List<OpsEvent> _events = const [];

  OpsLogViewModel({OpsLogRepository? repository})
    : _repository = repository ?? ServiceLocator.get<OpsLogRepository>();

  /// Events, newest first.
  List<OpsEvent> get events => _events;
  int get eventCount => _events.length;

  /// The most recent run time. Null when there are no events OR when the newest
  /// event was written without a timestamp — both render as "—".
  DateTime? get lastRun => _events.isEmpty ? null : _events.first.executedAt;

  Future<void> load() async {
    await executeAsyncVoid(
      () async {
        _events = await _repository.getRecentEvents();
      },
      errorPrefix: 'Kunde inte ladda driftloggen',
    );
  }

  Future<void> refresh() => load();
}
