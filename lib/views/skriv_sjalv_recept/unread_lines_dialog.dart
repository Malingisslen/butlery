import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

/// Asks whether to save while [unreadCount] ingredient lines the import could
/// not read are still unfilled. True means "Spara ändå"; closing the dialog
/// counts as "Fyll i" so a stray tap never saves an incomplete recipe.
Future<bool> confirmSaveWithUnreadLines(
  BuildContext context,
  int unreadCount,
) async {
  final l10n = context.l10n;
  final result = await ConfirmationDialog.show(
    context,
    title: l10n.unreadSaveTitle(unreadCount),
    message: l10n.unreadSaveBody(unreadCount),
    primaryActionText: l10n.unreadSaveAnyway,
    secondaryActionText: l10n.unreadSaveFillIn,
  );
  return result ?? false;
}
