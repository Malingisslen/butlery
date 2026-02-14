// lib/widgets/social/group_shopping_list_actions.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/utils/shopping_list_formatter.dart';

/// Action handlers for group shared shopping list cards.
class GroupShoppingListActions {
  /// Navigate to view the shopping list details.
  static void viewShoppingList(
      BuildContext context, UnifiedShoppingList shoppingList) {
    Navigator.pushNamed(
      context,
      '/shopping-list-detail',
      arguments: {'listId': shoppingList.id},
    );
  }

  /// Import the shopping list to user's personal lists.
  static Future<void> importShoppingList(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.groupImportShoppingList,
      message: context.l10n.groupImportShoppingListConfirm(shoppingList.name),
      confirmText: context.l10n.groupImport,
    );

    if (confirmed == true) {
      try {
        final shoppingService = ServiceLocator.get<UnifiedShoppingService>();

        final personalListId = await shoppingService.createPersonalList(
          context.l10n.groupListCopyName(shoppingList.name),
          items: shoppingList.items,
        );

        if (personalListId != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.groupListImported(shoppingList.name)),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: context.l10n.groupView,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/inkopslista',
                    arguments: {'listId': personalListId},
                  );
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.groupCouldNotImportList(e.toString())),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  /// Copy shopping list to clipboard.
  static Future<void> copyShoppingList(
    BuildContext context,
    UnifiedShoppingList shoppingList,
  ) async {
    try {
      final text = ShoppingListFormatter.formatForClipboard(shoppingList);
      await Clipboard.setData(ClipboardData(text: text));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupListCopiedToClipboard),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupCouldNotCopyList(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Share shopping list - shows sharing options.
  static Future<void> shareShoppingList(
    BuildContext context,
    UnifiedShoppingList shoppingList,
  ) async {
    try {
      final text = ShoppingListFormatter.formatForSharing(shoppingList);
      await Clipboard.setData(ClipboardData(text: text));

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.groupShareShoppingList,
                  style: AppTextStyles.titleBold,
                ),
                const SizedBox(height: AppDimensions.spacingM),
                ListTile(
                  leading: const Icon(Icons.content_copy),
                  title: Text(context.l10n.groupCopiedToClipboard),
                  subtitle: Text(context.l10n.groupPasteInAnyApp),
                  trailing: const Icon(Icons.check, color: AppColors.success),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(context.l10n.groupShareWithFriendsInButlery),
                  subtitle: Text(context.l10n.groupSendToFriends),
                  onTap: () {
                    Navigator.pop(context);
                    shareWithFriends(context, shoppingList);
                  },
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shoppingCouldNotShareList(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Share with friends in Butlery.
  static Future<void> shareWithFriends(
    BuildContext context,
    UnifiedShoppingList shoppingList,
  ) async {
    try {
      final shareOptions = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.shoppingShareShoppingList),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.shoppingShareListWith(shoppingList.name)),
              const SizedBox(height: AppDimensions.spacingMd),
              ListTile(
                leading: const Icon(Icons.people),
                title: Text(context.l10n.socialFriends),
                onTap: () => Navigator.pop(context, 'friends'),
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: Text(context.l10n.socialGroups),
                onTap: () => Navigator.pop(context, 'groups'),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(context.l10n.shoppingCopyLink),
                onTap: () => Navigator.pop(context, 'link'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
          ],
        ),
      );

      if (shareOptions != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shoppingSharingComingSoon(shareOptions)),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.shoppingCouldNotOpenShareMenu(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Report shopping list content.
  static Future<void> reportShoppingList(
    BuildContext context,
    UnifiedShoppingList shoppingList,
  ) async {
    final reason = await showReportDialog(context);

    if (reason != null && context.mounted) {
      try {
        AppLogger.warning('Content Report - Shopping List: ${shoppingList.id}');
        AppLogger.info('Report reason: $reason');
        AppLogger.info(
            'Reported by user, list owner: ${shoppingList.ownerDisplayName}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.socialReportSent),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.socialCouldNotSendReport(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Show report dialog with reason selection.
  static Future<String?> showReportDialog(BuildContext context) async {
    String? selectedReason;

    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.socialReportContent),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.socialReportShoppingListReason),
              const SizedBox(height: AppDimensions.spacingMd),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (value) => setState(() => selectedReason = value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    context.l10n.socialReportInappropriate,
                    context.l10n.socialReportSpam,
                    context.l10n.socialReportIncorrectInfo,
                    context.l10n.socialReportCopyright,
                    context.l10n.socialReportOther,
                  ]
                      .map((reason) => RadioListTile<String>(
                            title: Text(reason),
                            value: reason,
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () => Navigator.pop(context, selectedReason)
                  : null,
              child: Text(context.l10n.socialReport),
            ),
          ],
        ),
      ),
    );
  }

  /// Show more actions bottom sheet.
  static void showMoreActions(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(context.l10n.shoppingCopyList),
              onTap: () {
                Navigator.pop(context);
                copyShoppingList(context, shoppingList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.shoppingShareForward),
              onTap: () {
                Navigator.pop(context);
                shareShoppingList(context, shoppingList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: Text(context.l10n.socialReport),
              onTap: () {
                Navigator.pop(context);
                reportShoppingList(context, shoppingList);
              },
            ),
          ],
        ),
      ),
    );
  }
}
