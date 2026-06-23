import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/services/admin/metrics_assembler.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Backs every registry-driven admin tab. Resolves a fixed set of [MetricKey]s
/// via the [MetricsAssembler] and exposes the resolved values for rendering.
class MetricsTabViewModel extends BaseViewModel {
  final MetricsAssembler _assembler;

  Map<MetricKey, MetricValue> _values = const {};
  List<MetricKey> _keys = const [];
  AppLocalizations? _l10n;

  MetricsTabViewModel({MetricsAssembler? assembler})
    : _assembler = assembler ?? ServiceLocator.get<MetricsAssembler>();

  Map<MetricKey, MetricValue> get values => _values;

  /// Resolved value for [key], or null before the first load completes.
  MetricValue? valueOf(MetricKey key) => _values[key];

  Future<void> load(
    List<MetricKey> keys,
    AppLocalizations l10n, {
    bool force = false,
  }) async {
    _keys = keys;
    _l10n = l10n;
    await executeAsyncVoid(
      () async {
        _values = await _assembler.resolve(keys.toSet(), l10n, force: force);
      },
      errorPrefix: 'Kunde inte ladda mätvärden',
    );
  }

  /// Refresh button entry point — re-fetches (bypasses the slice cache).
  Future<void> refresh() async {
    final l10n = _l10n;
    if (l10n == null) return;
    await load(_keys, l10n, force: true);
  }
}
