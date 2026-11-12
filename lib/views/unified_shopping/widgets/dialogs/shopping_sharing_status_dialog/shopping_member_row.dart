import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:flutter/material.dart';

class ShoppingMemberRow extends StatelessWidget {
  final String userId;
  final SharedListPermission permission;
  final bool isOwner;
  final Map<String, String> displayNameByUserId;

  const ShoppingMemberRow({
    super.key,
    required this.userId,
    required this.permission,
    required this.isOwner,
    required this.displayNameByUserId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // BUT-1705: an unresolved name is stamped as EMPTY, never omitted and never
    // a placeholder (BUT-1697), so `?? unknown` never fired for it — the member
    // rendered as a blank line under a '?' avatar. Absent, empty and
    // whitespace-only are the same fact here: we do not know who this is.
    final String? knownName = knownStoredName(displayNameByUserId[userId]);
    final String displayName = knownName ?? context.l10n.shoppingUnknownUser;

    String permissionLabel;
    IconData permissionIcon;
    Color permissionColor;
    // Only the role glyph carries the saffron; the words stay ink.
    Color permissionTextColor;

    if (isOwner) {
      permissionLabel = context.l10n.shoppingPermissionOwner;
      permissionIcon = ButleryIcons.crown;
      permissionColor = cs.onSurface;
      permissionTextColor = cs.onSurface;
    } else {
      switch (permission) {
        case SharedListPermission.view:
          permissionLabel = context.l10n.shoppingPermissionView;
          permissionIcon = ButleryIcons.eye;
          permissionColor = cs.onSurfaceVariant;
          permissionTextColor = cs.onSurfaceVariant;
          break;
        case SharedListPermission.edit:
          permissionLabel = context.l10n.shoppingPermissionEdit;
          permissionIcon = ButleryIcons.pencil;
          // Saffron falls under 3:1 on the light surfaces, so only dark mode
          // keeps it.
          permissionColor = cs.brightness == Brightness.dark
              ? cs.secondary
              : cs.onSurface;
          permissionTextColor = cs.onSurface;
          break;
        case SharedListPermission.admin:
          permissionLabel = context.l10n.shoppingPermissionAdmin;
          permissionIcon = ButleryIcons.crown;
          permissionColor = cs.onSurface;
          permissionTextColor = cs.onSurface;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space4),
      child: Row(
        children: [
          // Keyed off the RESOLVED name, not the rendered one: the unknown
          // fallback is a sentence, and its initial ("O" for "Okänd
          // användare") would read as a real person's initial.
          AvatarCircle(
            displayName: knownName.orEmpty(),
          ),
          const SizedBox(width: AppDimensions.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.contentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    ButleryIcon(
                      permissionIcon,
                      size: AppDimensions.iconSizeS,
                      color: permissionColor,
                    ),
                    const SizedBox(width: AppDimensions.space4),
                    Text(
                      permissionLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: permissionTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
