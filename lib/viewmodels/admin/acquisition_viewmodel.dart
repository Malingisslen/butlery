import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/admin/acquisition_tally.dart';
import 'package:butlery/repositories/daily_snapshot_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Admin channel tab: the last 30 days of `analytics/acquisition/daily`.
/// One read per day on load and on refresh, nothing on a timer.
class AcquisitionViewModel extends BaseViewModel {
  static const int windowDays = 30;

  final DailySnapshotRepository _repository;
  AcquisitionTally? _tally;

  AcquisitionViewModel({DailySnapshotRepository? repository})
    : _repository = repository ?? ServiceLocator.get<DailySnapshotRepository>();

  AcquisitionTally? get tally => _tally;

  Future<void> load() async {
    await executeAsyncVoid(
      () async {
        final days = await _repository.getRecent(
          'acquisition',
          days: windowDays,
        );
        _tally = AcquisitionTally.fromDays(days);
      },
      errorPrefix: AppLocale.current.adminAcquisitionLoadFailed,
    );
  }

  Future<void> refresh() => load();
}
