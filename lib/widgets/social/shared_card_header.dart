import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:flutter/material.dart';

/// Shared header row used by all shared content cards (recipe, menu, shopping list).
/// Shows avatar, sharer name, timestamp, overflow menu (dismiss/unshare), and unread dot.
class SharedCardHeader extends StatelessWidget {
  const SharedCardHeader({
    required this.displayName,
    required this.timestampText,
    required this.isRead,
    required this.onDismiss,
    required this.onUnshare,
    super.key,
  });

  final String displayName;
  final String timestampText;
  final bool isRead;
  final VoidCallback onDismiss;
  final VoidCallback onUnshare;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        SocialAvatarComponents.avatar(
          size: ImageSize.small,
          displayName: displayName,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.sharedByName(displayName),
                style: isRead
                    ? AppTextStyles.bodySmall.copyWith(color: cs.primary)
                    : AppTextStyles.bodyBold.copyWith(color: cs.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                timestampText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: AppDimensions.iconSizeM,
            color: cs.onSurfaceVariant,
          ),
          shape: const RoundedRectangleBorder(),
          onSelected: (value) {
            switch (value) {
              case 'dismiss':
                onDismiss();
              case 'unshare':
                onUnshare();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'dismiss',
              child: Row(
                children: [
                  Icon(
                    Icons.close,
                    size: AppDimensions.iconSizeM,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(context.l10n.commonHide),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'unshare',
              child: Row(
                children: [
                  Icon(
                    Icons.link_off,
                    size: AppDimensions.iconSizeM,
                    color: cs.error,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    context.l10n.unshareButton,
                    style: TextStyle(color: cs.error),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isRead)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsetsDirectional.only(
              start: AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
