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

  /// Optional top-right control (e.g. the metric info "i" button).
  final Widget? action;

  /// Optional percent change vs the previous period — renders a ↑/↓ chip.
  /// Null = no comparison data (shows nothing).
  final double? deltaPercent;
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    this.action,
    this.deltaPercent,
  });

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(value, style: AppTextStyles.headlineBold),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          if (deltaPercent != null) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            _DeltaChip(deltaPercent: deltaPercent!),
          ],
        ],
      ),
    );
  }
}

/// A small ↑/↓ percent-change indicator. Up is green, down is red, no change is
/// muted. Rounds to a whole percent.
class _DeltaChip extends StatelessWidget {
  final double deltaPercent;
  const _DeltaChip({required this.deltaPercent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rounded = deltaPercent.round();
    final (icon, color) = switch (rounded.sign) {
      1 => (Icons.arrow_upward, cs.primary),
      -1 => (Icons.arrow_downward, cs.error),
      _ => (Icons.remove, cs.outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text('${rounded.abs()} %',
            style: AppTextStyles.bodySmall.copyWith(color: color)),
      ],
    );
  }
}
