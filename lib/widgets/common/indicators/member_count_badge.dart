// lib/widgets/common/indicators/member_count_badge.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable member count badge component
/// Shows additional member count in a circular badge.
/// Used for displaying "+X" when member list is truncated.
class MemberCountBadge extends StatelessWidget {
  final int additionalCount;
  final double? size;

  const MemberCountBadge({
    super.key,
    required this.additionalCount,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final badgeSize = size ?? AppDimensions.iconSizeXl;

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.divider,
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      child: Center(
        child: Text(
          '+$additionalCount',
          style: AppTextStyles.metadataEmphasized,
        ),
      ),
    );
  }
}
