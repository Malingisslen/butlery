import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/indicators/admin_badge.dart';

/// Card displaying group information: icon, name, member count, creation date, and admin badge.
class GroupInfoCard extends StatelessWidget {
  final String groupTitle;
  final int memberCount;
  final DateTime? createdAt;
  final bool isAdmin;

  const GroupInfoCard({
    super.key,
    required this.groupTitle,
    required this.memberCount,
    this.createdAt,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final createdDateStr = createdAt != null
        ? DateFormat('d MMM yyyy, HH:mm', 'sv_SE').format(createdAt!)
        : context.l10n.commonUnknown;

    return CardContent.standard(
      child: Column(
        children: [
          // Group icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.forestGreen
                  .withValues(alpha: AppDimensions.opacityVeryLight),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group,
              size: 40,
              color: AppColors.forestGreen,
            ),
          ),

          const SizedBox(height: AppDimensions.spacingM),

          // Group name
          Text(
            groupTitle,
            style: AppTextStyles.headlineMedium,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimensions.spacingS),

          // Member count
          Text(
            context.l10n.chatMemberCount(memberCount),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMedium,
            ),
          ),

          const SizedBox(height: AppDimensions.spacingS),

          // Created date
          Text(
            context.l10n.chatCreatedDate(createdDateStr),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
            ),
          ),

          // Admin badge if applicable
          if (isAdmin) ...[
            const SizedBox(height: AppDimensions.spacingM),
            const AdminBadge(),
          ],
        ],
      ),
    );
  }
}
