// lib/views/unified_shopping/widgets/dialogs/no_friends_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Shown by every shopping-list action that needs friends (share, make
/// collaborative) when there are none: says why, and offers the friends page.
Future<void> showNoFriendsDialog(BuildContext context) {
  return showButleryDialog<void>(
    context: context,
    builder: (dialogContext) => ButleryDialog(
      title: dialogContext.l10n.shoppingNoFriends,
      message: dialogContext.l10n.shoppingNoFriendsDescription,
      actions: [
        // It only closes: Stäng, never OK.
        DialogCancelButton(label: dialogContext.l10n.commonClose),
        ButleryDialogPrimary(
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
