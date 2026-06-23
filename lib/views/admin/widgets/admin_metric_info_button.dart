import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/admin/metrics/catalog.dart';
import 'package:butlery/models/admin/metrics/explanations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// A small "i" button that teaches one metric: tapping it opens a dialog with
/// the metric's what / how / why (from the [explanations] registry). The
/// pedagogical layer — every number can explain itself.
class AdminMetricInfoButton extends StatelessWidget {
  final MetricKey metricKey;
  const AdminMetricInfoButton({required this.metricKey, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: const Icon(Icons.info_outline),
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      color: cs.outline,
      tooltip: context.l10n.adminMetricInfo,
      onPressed: () => _show(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  void _show(BuildContext context) {
    final l10n = context.l10n;
    final desc = catalog[metricKey];
    final explanation = explanations[metricKey];
    if (desc == null || explanation == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(),
        title: Text(desc.label(l10n)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Section(
                heading: l10n.adminMetricWhat,
                body: explanation.whatIsIt(l10n),
              ),
              _Section(
                heading: l10n.adminMetricHow,
                body: explanation.howCalculated(l10n),
              ),
              _Section(
                heading: l10n.adminMetricWhy,
                body: explanation.whyImportant(l10n),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(shape: const RoundedRectangleBorder()),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.adminScreenshotClose),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String heading;
  final String body;
  const _Section({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(body, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
