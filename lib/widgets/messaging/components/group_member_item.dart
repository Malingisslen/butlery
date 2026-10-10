import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

/// Card displaying a group member with avatar, name, and optional remove button.
class GroupMemberItem extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;
  final bool canRemove;
  final VoidCallback? onRemove;

  /// Makes the whole row tappable. [semanticsLabel] names the action only and
  /// is merged into the ListTile's node, so the row is a single focus stop.
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const GroupMemberItem({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.isCurrentUser = false,
    this.canRemove = false,
    this.onRemove,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tile = ListTile(
      leading: UserDisplayWidgets.avatar(
        imageUrl: avatarUrl,
        displayName: displayName,
        size: ImageSize.medium,
        announceName: false,
      ),
      title: Row(
        children: [
          Text(displayName),
          if (isCurrentUser) ...[
            const SizedBox(width: AppDimensions.space4),
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
              icon: const ButleryIcon(ButleryIcons.minus),
              color: cs.error,
              onPressed: onRemove,
              tooltip: context.l10n.groupRemoveMember,
            )
          : null,
      onTap: onTap,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: onTap == null
          ? tile
          : MergeSemantics(
              child: Semantics(
                label: semanticsLabel,
                button: true,
                child: tile,
              ),
            ),
    );
  }
}
