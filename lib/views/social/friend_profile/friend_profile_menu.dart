// lib/views/social/friend_profile/friend_profile_menu.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/common/press_fill.dart';

enum FriendProfileMenuAction { shareProfile, report, block }

/// The profile's only top-bar action: ⋯, opening the sheet of the rarer things
/// (removing the friend is the red line at the foot of the page). The sheet closes first, then the page acts.
class FriendProfileMenuButton extends StatelessWidget {
  const FriendProfileMenuButton({
    super.key,
    required this.friendName,
    required this.canBlock,
    required this.onAction,
  });

  final String friendName;

  /// False for someone already blocked: the action has no meaning twice and
  /// the unblock path lives in privacy settings.
  final bool canBlock;

  final ValueChanged<FriendProfileMenuAction> onAction;

  Future<void> _open(BuildContext context) async {
    final l10n = context.l10n;
    final action = await showButleryListSheet<FriendProfileMenuAction>(
      context,
      title: friendName,
      rows: (sheetContext) => [
        ButleryListRow(
          label: l10n.publicProfileShareButton,
          leading: ButleryIcons.link,
          onTap: () => Navigator.of(
            sheetContext,
          ).pop(FriendProfileMenuAction.shareProfile),
        ),
        ButleryListRow(
          label: l10n.reportContent,
          leading: ButleryIcons.flag,
          onTap: () =>
              Navigator.of(sheetContext).pop(FriendProfileMenuAction.report),
        ),
        if (canBlock)
          ButleryListRow.danger(
            label: l10n.socialBlock,
            onTap: () =>
                Navigator.of(sheetContext).pop(FriendProfileMenuAction.block),
          ),
      ],
    );
    if (action != null) onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    return PressFill(
      surface: PressSurface.base,
      child: AppIconButton(
        icon: ButleryIcons.moreVertical,
        semanticLabel: context.l10n.socialMoreOptions,
        onPressed: () => _open(context),
      ),
    );
  }
}
