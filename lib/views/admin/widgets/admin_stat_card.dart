import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// A summary stat card used across the admin dashboard tabs: a small label in
/// capitals over a big value, as the drawn admin panel sets it.
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
    return ButleryOutlinedBox(
      padding: const EdgeInsets.all(AppDimensions.space16),
      borderColor: cs.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap, not a Row with an Expanded label: the card sits both in
          // a Row of Expanded cards and in an unbounded Wrap.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.overline.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(value, style: AppTextStyles.displaySmall),
          if (deltaPercent != null) ...[
            const SizedBox(height: AppDimensions.space4),
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
      1 => (ButleryIcons.arrowUp, cs.onSurface),
      -1 => (ButleryIcons.arrowDown, cs.error),
      _ => (ButleryIcons.minus, cs.outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ButleryIcon(icon, size: AppDimensions.iconSize14, color: color),
        const SizedBox(width: AppDimensions.space4),
        Text(
          '${rounded.abs()} %',
          style: AppTextStyles.bodySmall.copyWith(color: color),
        ),
      ],
    );
  }
}
