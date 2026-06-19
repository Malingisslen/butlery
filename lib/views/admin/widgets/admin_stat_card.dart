import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// A square summary stat box used across the admin dashboard tabs: a big value
/// over a small label. Mirrors the visual of the import-health summary cards so
/// every admin tab reads the same. Square corners (no radius) per the design
/// language.
class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  const AdminStatCard({super.key, required this.label, required this.value});

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
