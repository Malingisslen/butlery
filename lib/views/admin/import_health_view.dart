import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/import_health_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only screen showing per-domain recipe-import health (success vs
/// failure counts) read from the `site_configs` rollups. Hosted as a tab in
/// the admin shell.
class ImportHealthView extends StatefulWidget {
  const ImportHealthView({super.key});

  @override
  State<ImportHealthView> createState() => _ImportHealthViewState();
}

class _ImportHealthViewState extends State<ImportHealthView> {
  late final ImportHealthViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ImportHealthViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ImportHealthViewModel>.value(
      value: _vm,
      child: const _ImportHealthContent(),
    );
  }
}

class _ImportHealthContent extends StatelessWidget {
  const _ImportHealthContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ImportHealthViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminImportTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.adminRefresh,
            onPressed: vm.isLoading ? null : vm.refresh,
          ),
        ],
      ),
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, ImportHealthViewModel vm) {
    if (vm.isLoading && vm.stats.isEmpty) {
      return StateWidget.loading();
    }
    if (vm.error != null && vm.stats.isEmpty) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    if (vm.stats.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.adminImportEmpty,
        icon: Icons.cloud_download_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(vm: vm),
        const _HeaderRow(),
        Expanded(
          child: ListView.separated(
            itemCount: vm.stats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _DomainRow(config: vm.stats[i]),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final ImportHealthViewModel vm;
  const _SummaryRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Wrap(
        spacing: AppDimensions.spacingSm,
        runSpacing: AppDimensions.spacingSm,
        children: [
          _SummaryCard(
            label: l10n.adminImportSummaryDomains,
            value: '${vm.totalDomains}',
          ),
          _SummaryCard(
            label: l10n.adminImportSummarySuccess,
            value: '${vm.totalSuccess}',
          ),
          _SummaryCard(
            label: l10n.adminImportSummaryFailure,
            value: '${vm.totalFailure}',
          ),
          _SummaryCard(
            label: l10n.adminImportSummaryRate,
            value: '${(vm.overallSuccessRate * 100).round()} %',
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: AppDimensions.cardWidthSmall,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.headlineBold),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(l10n.adminImportColDomain, style: _h)),
          Expanded(
            flex: 2,
            child: Text(l10n.adminImportColSuccess,
                style: _h, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: Text(l10n.adminImportColFailure,
                style: _h, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: Text(l10n.adminImportColRate,
                style: _h, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  static final TextStyle _h = AppTextStyles.metadataEmphasized;
}

class _DomainRow extends StatelessWidget {
  final SiteConfig config;
  const _DomainRow({required this.config});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFailures = config.failureCount > 0;
    final ratePct = (config.successRate * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              config.domain,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${config.successCount}',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${config.failureCount}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: hasFailures ? cs.error : null,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('$ratePct %',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
