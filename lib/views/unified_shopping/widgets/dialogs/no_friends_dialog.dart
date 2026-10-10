// lib/views/unified_shopping/widgets/dialogs/no_friends_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// Shown by every shopping-list action that needs friends (share, make
/// collaborative) when there are none: says why, and offers the friends page.
Future<void> showNoFriendsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.shoppingNoFriends),
      content: Text(dialogContext.l10n.shoppingNoFriendsDescription),
      actions: [
        ActionButtons.secondaryButton(
          dialogContext,
          // It only closes: Stäng, never OK.
          label: dialogContext.l10n.commonClose,
          onPressed: () => Navigator.pop(dialogContext),
        ),
        ActionButtons.primaryButton(
          dialogContext,
          label: dialogContext.l10n.shareAddFriends,
          onPressed: () {
            final navigator = Navigator.of(context);
            Navigator.pop(dialogContext);
            navigator.pushNamed(Routes.friends);
          },
        ),
      ],
    ),
  );
}
