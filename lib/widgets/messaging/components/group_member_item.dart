import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

/// Card displaying a group member with avatar, name, and optional remove button.
class GroupMemberItem extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;
  final bool canRemove;
  final VoidCallback? onRemove;

  const GroupMemberItem({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.isCurrentUser = false,
    this.canRemove = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: ListTile(
        leading: UserDisplayWidgets.avatar(
          imageUrl: avatarUrl,
          displayName: displayName,
          size: ImageSize.medium,
        ),
        title: Row(
          children: [
            Text(displayName),
            if (isCurrentUser) ...[
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                '(${context.l10n.commonYou})',
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: canRemove
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: cs.error,
                onPressed: onRemove,
                tooltip: context.l10n.groupRemoveMember,
              )
            : null,
      ),
    );
  }
}
