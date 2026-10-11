// lib/widgets/common/indicators/status_pill.dart

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// The neutral status pill (tokens.json controls.statusPill). The caller maps
/// its own status to [label], so the pill stays free of any status enum.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppDimensions.statusPillPadding,
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      // Komponentark v1:297 draws the pill text at 0.5 px tracking.
      child: Text(
        label,
        style: AppTextStyles.overline.copyWith(letterSpacing: 0.5),
      ),
    );
  }
}
