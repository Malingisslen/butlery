// lib/widgets/social/group_shopping_list_actions.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      title: 'Importera inköpslista',
      message:
          'Vill du importera "${shoppingList.name}" till dina egna listor?',
      confirmText: 'Importera',
    );

    if (confirmed == true) {
      try {
        final shoppingService = ServiceLocator.get<UnifiedShoppingService>();

        final personalListId = await shoppingService.createPersonalList(
          '${shoppingList.name} (Kopia)',
          items: shoppingList.items,
        );

        if (personalListId != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('"${shoppingList.name}" importerad till dina listor!'),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: 'Visa',
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
              content: Text('Kunde inte importera listan: $e'),
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
          const SnackBar(
            content: Text('Inköpslista kopierad till urklipp!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte kopiera listan: $e'),
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
                  'Dela inköpslista',
                  style: AppTextStyles.titleBold,
                ),
                const SizedBox(height: AppDimensions.spacingM),
                ListTile(
                  leading: const Icon(Icons.content_copy),
                  title: const Text('Kopierat till urklipp'),
                  subtitle: const Text('Klistra in i valfri app'),
                  trailing: const Icon(Icons.check, color: AppColors.success),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Dela med vänner i Butlery'),
                  subtitle: const Text('Skicka till dina vänner'),
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
            content: Text('Kunde inte dela listan: $e'),
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
          title: const Text('Dela inköpslista'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Dela "${shoppingList.name}" med:'),
              const SizedBox(height: AppDimensions.spacingMd),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Vänner'),
                onTap: () => Navigator.pop(context, 'friends'),
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Grupper'),
                onTap: () => Navigator.pop(context, 'groups'),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Kopiera länk'),
                onTap: () => Navigator.pop(context, 'link'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
          ],
        ),
      );

      if (shareOptions != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delning via $shareOptions kommer snart!'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte öppna delningsmenyn: $e'),
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
          const SnackBar(
            content: Text('Rapport skickad. Tack för din feedback!'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte skicka rapport: $e'),
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
          title: const Text('Rapportera innehåll'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Varför vill du rapportera denna inköpslista?'),
              const SizedBox(height: AppDimensions.spacingMd),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (value) => setState(() => selectedReason = value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    'Olämpligt innehåll',
                    'Spam eller reklam',
                    'Felaktig information',
                    'Upphovsrättsintrång',
                    'Annat'
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
              child: const Text('Avbryt'),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () => Navigator.pop(context, selectedReason)
                  : null,
              child: const Text('Rapportera'),
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
              title: const Text('Kopiera lista'),
              onTap: () {
                Navigator.pop(context);
                copyShoppingList(context, shoppingList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Dela vidare'),
              onTap: () {
                Navigator.pop(context);
                shareShoppingList(context, shoppingList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Rapportera'),
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
