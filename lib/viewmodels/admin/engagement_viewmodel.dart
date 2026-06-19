import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/admin/engagement_stats.dart';
import 'package:butlery/repositories/engagement_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel for the admin engagement tab. Loads the user count and the recent
/// daily feature-retention aggregates. Read-only; no writes.
///
/// Pre-launch these numbers are ~0 by design — the nightly jobs write the
/// structure, the values fill in as real users become active.
class EngagementViewModel extends BaseViewModel {
  final EngagementRepository _repository;

  int _userCount = 0;
  List<DailyEngagement> _days = const [];

  EngagementViewModel({EngagementRepository? repository})
      : _repository = repository ?? ServiceLocator.get<EngagementRepository>();

  int get userCount => _userCount;

  /// Daily aggregates, newest first.
  List<DailyEngagement> get days => _days;

  /// "Active" proxies from the latest day (max across features — a floor on
  /// distinct active users, see [FeatureCounts.max]). Zero when no data.
  int get activeToday => _days.isEmpty ? 0 : _days.first.dau.max;
  int get active7d => _days.isEmpty ? 0 : _days.first.wau7d.max;
  int get active28d => _days.isEmpty ? 0 : _days.first.wau28d.max;

  Future<void> load() async {
    await executeAsyncVoid(
      () async {
        final count = await _repository.getUserCount();
        final days = await _repository.getDailyFeatureRetention();
        _userCount = count;
        _days = days;
      },
      errorPrefix: 'Kunde inte ladda engagemangsdata',
    );
  }

  Future<void> refresh() => load();
}
