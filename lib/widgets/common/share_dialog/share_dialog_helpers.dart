// lib/widgets/common/share_dialog/share_dialog_helpers.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

class ShareDialogHelpers {
  static String getContentTypeName(
    BuildContext context,
    ShareContentType contentType,
  ) {
    switch (contentType) {
      case ShareContentType.recipe:
        return context.l10n.shareContentTypeRecipe;
      case ShareContentType.menu:
        return context.l10n.shareContentTypeMenu;
      case ShareContentType.shoppingList:
        return context.l10n.shareContentTypeShoppingList;
      case ShareContentType.personalTag:
        return 'tagg';
    }
  }

  static String getShareButtonText(
    BuildContext context,
    ShareContentType contentType,
    ShareMode selectedMode,
    bool supportsRealtimeSharing,
  ) {
    if (selectedMode == ShareMode.realtime && supportsRealtimeSharing) {
      return context.l10n.shareCreateAndShare;
    } else {
      switch (contentType) {
        case ShareContentType.recipe:
          return context.l10n.shareRecipe;
        case ShareContentType.menu:
          return context.l10n.shareMenu;
        case ShareContentType.shoppingList:
          return context.l10n.shareShoppingList;
        case ShareContentType.personalTag:
          return context.l10n.shareTag;
      }
    }
  }

  static bool supportsRealtimeSharing(ShareContentType contentType) {
    switch (contentType) {
      case ShareContentType.recipe:
      case ShareContentType.menu:
      case ShareContentType.shoppingList:
        return true;
      case ShareContentType.personalTag:
        // Tags are always shared as static snapshots
        return false;
    }
  }

  static String getDefaultMessage(
    BuildContext context,
    ShareContentType contentType,
    String contentName,
  ) {
    switch (contentType) {
      case ShareContentType.recipe:
        return context.l10n.shareDefaultMessageRecipe(contentName);
      case ShareContentType.menu:
        return context.l10n.shareDefaultMessageMenu(contentName);
      case ShareContentType.shoppingList:
        return context.l10n.shareDefaultMessageShoppingList(contentName);
      case ShareContentType.personalTag:
        return 'Kolla in min tagg "$contentName"!';
    }
  }

  static String getSuccessMessage(
    BuildContext context, {
    required int friendCount,
    required int groupCount,
    required ShareMode shareMode,
  }) {
    final l10n = context.l10n;
    // A group is one pick but several people, so with a group in the mix the
    // count is not a head count.
    final receipt = groupCount > 0
        ? l10n.shareSuccessMessageGroups(friendCount + groupCount)
        : l10n.shareSuccessMessage(friendCount);
    return shareMode == ShareMode.realtime
        ? '$receipt ${l10n.shareSuccessLiveNote}'
        : receipt;
  }

  static String getShareTitle(
    BuildContext context,
    ShareContentType contentType,
  ) {
    switch (contentType) {
      case ShareContentType.recipe:
        return context.l10n.shareRecipeWithFriends;
      case ShareContentType.menu:
        return context.l10n.shareMenuWithFriends;
      case ShareContentType.shoppingList:
        return context.l10n.shareShoppingList;
      case ShareContentType.personalTag:
        return context.l10n.shareTagWithFriends;
    }
  }

  static String formatSelectionSummary(
    BuildContext context,
    int selectedCount,
    String contentTypeName,
  ) {
    if (selectedCount == 0) {
      return context.l10n.shareSelectAtLeastOne(contentTypeName);
    }
    return context.l10n.shareFriendsSelected(selectedCount);
  }
}
