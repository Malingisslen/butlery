import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/admin/metrics_tab_viewmodel.dart';
import 'package:butlery/views/admin/metrics_csv.dart';
import 'package:butlery/views/admin/widgets/metric_renderer.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/views/account/data_export_helpers/download_stub.dart'
    if (dart.library.io) 'package:butlery/views/account/data_export_helpers/download_native.dart'
    if (dart.library.js_interop) 'package:butlery/views/account/data_export_helpers/download_web.dart';

/// A registry-driven admin tab: declare a title + the [MetricKey]s to show, and
/// this owns the Scaffold/AppBar/Refresh + loading/error states and renders
/// each metric via [MetricRenderer]. Scalars group into a card row; the other
/// kinds stack below — matching the original hand-built tab layout.
class MetricTabView extends StatefulWidget {
  final String Function(AppLocalizations) title;
  final List<MetricKey> keys;
  const MetricTabView({required this.title, required this.keys, super.key});

  @override
  State<MetricTabView> createState() => _MetricTabViewState();
}

class _MetricTabViewState extends State<MetricTabView> {
  late final MetricsTabViewModel _vm;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _vm = MetricsTabViewModel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // l10n is available here (under MaterialApp); load once.
    if (!_started) {
      _started = true;
      _vm.load(widget.keys, AppLocalizations.of(context));
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MetricsTabViewModel>.value(
      value: _vm,
      child: _MetricTabContent(title: widget.title, keys: widget.keys),
    );
  }
}

class _MetricTabContent extends StatelessWidget {
  final String Function(AppLocalizations) title;
  final List<MetricKey> keys;
  const _MetricTabContent({required this.title, required this.keys});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MetricsTabViewModel>();
    return AdminTabPage(
      title: title(context.l10n),
      actions: [
        AppIconButton(
          icon: ButleryIcons.export,
          semanticLabel: context.l10n.adminMetricExport,
          onPressed: vm.values.isEmpty ? null : () => _export(context, vm),
        ),
        AppIconButton(
          icon: ButleryIcons.refreshCw,
          semanticLabel: context.l10n.adminRefresh,
          onPressed: vm.isLoading ? null : vm.refresh,
        ),
      ],
      body: _body(context, vm),
    );
  }

  Future<void> _export(BuildContext context, MetricsTabViewModel vm) async {
    final l10n = context.l10n;
    final snackBars = CapturedSnackBars.capture(context);
    final csv = buildMetricsCsv(keys, vm.values, l10n);
    final fileName = 'butlery-${keys.first.category.name}.csv';
    try {
      await downloadCsvFile(csv, fileName);
    } catch (_) {
      snackBars.showFailure(what: l10n.adminMetricExportFailed);
    }
  }

  // At large text the cards fill the width one per line, since content-sized
  // cards of different widths ragged the edge down the page.
  Widget _scalarCards(
    BuildContext context,
    MetricsTabViewModel vm,
    List<MetricKey> scalarKeys,
  ) {
    final cards = [
      for (final key in scalarKeys)
        MetricRenderer(metricKey: key, value: vm.valueOf(key)!),
    ];
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.space8,
        children: cards,
      );
    }
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: cards,
    );
  }

  Widget _body(BuildContext context, MetricsTabViewModel vm) {
    if (vm.isLoading && vm.values.isEmpty) {
      return StateWidget.loading(message: context.l10n.loadingMetrics);
    }
    if (vm.error != null && vm.values.isEmpty) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    // Scalars render as a card row; everything else stacks full-width below.
    final scalarKeys = <MetricKey>[];
    final otherKeys = <MetricKey>[];
    for (final key in keys) {
      final value = vm.valueOf(key);
      if (value == null) continue;
      (value is ScalarMetric ? scalarKeys : otherKeys).add(key);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimensions.space16),
      children: [
        if (scalarKeys.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.space12),
            child: _scalarCards(context, vm, scalarKeys),
          ),
        for (final key in otherKeys) ...[
          const SizedBox(height: AppDimensions.space8),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space12,
            ),
            child: MetricRenderer(metricKey: key, value: vm.valueOf(key)!),
          ),
        ],
      ],
    );
  }
}
