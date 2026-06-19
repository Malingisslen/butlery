import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/repositories/site_config_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel for the admin import-health screen.
///
/// Reads the per-domain parse rollups from `site_configs` (success/failure
/// counts) and surfaces the domains with real import activity, worst first, so
/// an admin can spot which recipe sites are failing. Read-only — no writes.
class ImportHealthViewModel extends BaseViewModel {
  final SiteConfigRepository _repository;

  List<SiteConfig> _stats = const [];

  ImportHealthViewModel({SiteConfigRepository? repository})
      : _repository = repository ?? ServiceLocator.get<SiteConfigRepository>();

  /// Domains with at least one import attempt, worst-performing first.
  List<SiteConfig> get stats => _stats;

  int get totalDomains => _stats.length;
  int get totalSuccess => _stats.fold(0, (sum, c) => sum + c.successCount);
  int get totalFailure => _stats.fold(0, (sum, c) => sum + c.failureCount);

  /// Overall success rate across all domains, 0.0–1.0. Zero when no activity.
  double get overallSuccessRate {
    final total = totalSuccess + totalFailure;
    if (total == 0) return 0;
    return totalSuccess / total;
  }

  Future<void> load() async {
    // executeAsyncVoid (not executeAsync) so a load failure lands in error
    // state instead of rethrowing — load() is called unawaited from initState.
    await executeAsyncVoid(
      () async {
        final all = await _repository.getAllConfigs();
        // Keep only domains with real import activity; a never-attempted
        // default config isn't interesting for import health.
        final active =
            all.where((c) => c.successCount + c.failureCount > 0).toList();
        active.sort(_worstFirst);
        _stats = active;
      },
      errorPrefix: 'loadImportHealth',
    );
  }

  /// Manual reload (the refresh button).
  Future<void> refresh() => load();

  /// Problematic domains on top: any failures first, then lowest success rate,
  /// then most recently active.
  static int _worstFirst(SiteConfig a, SiteConfig b) {
    final aHasFail = a.failureCount > 0;
    final bHasFail = b.failureCount > 0;
    if (aHasFail != bHasFail) return aHasFail ? -1 : 1;

    final rate = a.successRate.compareTo(b.successRate);
    if (rate != 0) return rate;

    final aTime = a.lastUpdated?.millisecondsSinceEpoch ?? 0;
    final bTime = b.lastUpdated?.millisecondsSinceEpoch ?? 0;
    return bTime.compareTo(aTime);
  }
}
