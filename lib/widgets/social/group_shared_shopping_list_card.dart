// lib/widgets/social/group_shared_shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:flutter/services.dart';

/// Group Shared Shopping List Card - Card widget for shopping lists shared to groups
/// Displays shopping list information in a group context with:
/// - List name and description
/// - Item count and completion status
/// - Shared by information
/// - Group-specific actions
class GroupSharedShoppingListCard {
  static Widget build(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) {
    return Material(
      elevation: AppDimensions.elevationMedium,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, shoppingList),
            const SizedBox(height: AppDimensions.spacingM),
            _buildContent(context, shoppingList),
            const SizedBox(height: AppDimensions.spacingM),
            _buildStats(context, shoppingList),
            const SizedBox(height: AppDimensions.spacingM),
            _buildActions(context, viewModel, shoppingList),
          ],
        ),
      ),
    );
  }

  static Widget _buildHeader(BuildContext context, UnifiedShoppingList shoppingList) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: const Icon(
            Icons.shopping_cart,
            size: AppDimensions.iconSizeM,
            color: AppColors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shoppingList.name,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (shoppingList.description != null && shoppingList.description!.isNotEmpty)
                Text(
                  shoppingList.description!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        _buildSharedByInfo(shoppingList),
      ],
    );
  }

  static Widget _buildSharedByInfo(UnifiedShoppingList shoppingList) {
    // Use actual owner information from shopping list metadata
    final ownerName = shoppingList.ownerDisplayName.isNotEmpty 
        ? shoppingList.ownerDisplayName 
        : 'Okänd användare';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        UserAvatar(
          imageUrl: null, // Avatar URLs will be populated when user profile service integration is complete
          displayName: ownerName,
          size: ImageSize.small,
        ),
        const SizedBox(height: 2),
        Text(
          'Delad av $ownerName',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  static Widget _buildContent(BuildContext context, UnifiedShoppingList shoppingList) {
    final totalItems = shoppingList.items.length;
    final boughtItems = shoppingList.items.where((item) => item.bought).length;
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt,
                size: AppDimensions.iconSizeS,
                color: AppColors.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                'Inköpslista',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (shoppingList.isCollaborative)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                  ),
                  child: Text(
                    'Kollaborativ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.info,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingS),
          LinearProgressIndicator(
            value: totalItems > 0 ? boughtItems / totalItems : 0,
            backgroundColor: AppColors.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              boughtItems == totalItems ? AppColors.success : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStats(BuildContext context, UnifiedShoppingList shoppingList) {
    final totalItems = shoppingList.items.length;
    final boughtItems = shoppingList.items.where((item) => item.bought).length;
    final remainingItems = totalItems - boughtItems;
    
    return Row(
      children: [
        _buildStatChip(
          '$totalItems',
          'totalt',
          Icons.format_list_numbered,
          AppColors.primary,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        _buildStatChip(
          '$boughtItems',
          'köpta',
          Icons.check_circle,
          AppColors.success,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        _buildStatChip(
          '$remainingItems',
          'kvar',
          Icons.shopping_cart_outlined,
          AppColors.warning,
        ),
        const Spacer(),
        Text(
          _getShareTimeText(shoppingList),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  static Widget _buildStatChip(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeXs,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildActions(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) {
    return Row(
      children: [
        Expanded(
          child: ActionButtons.secondaryButton(
            context,
            label: 'Visa lista',
            icon: Icons.visibility,
            onPressed: () => _viewShoppingList(context, shoppingList),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: ActionButtons.primaryButton(
            context,
            label: 'Importera',
            icon: Icons.download,
            onPressed: () => _importShoppingList(context, viewModel, shoppingList),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        IconButton(
          onPressed: () => _showMoreActions(context, viewModel, shoppingList),
          icon: const Icon(Icons.more_vert),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  static void _viewShoppingList(BuildContext context, UnifiedShoppingList shoppingList) {
    Navigator.pushNamed(
      context,
      '/shopping-list-detail',
      arguments: {'listId': shoppingList.id},
    );
  }

  static Future<void> _importShoppingList(
    BuildContext context,
    GroupContentViewModel viewModel,
    UnifiedShoppingList shoppingList,
  ) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: 'Importera inköpslista',
      message: 'Vill du importera "${shoppingList.name}" till dina egna listor?',
      confirmText: 'Importera',
    );
    
    if (confirmed == true) {
      try {
        final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
        
        // Create a personal copy of the shopping list
        final personalListId = await shoppingService.createPersonalList(
          '${shoppingList.name} (Kopia)',
          items: shoppingList.items,
        );
        
        if (personalListId != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${shoppingList.name}" importerad till dina listor!'),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: 'Visa',
                onPressed: () {
                  // Navigate to the imported list
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

  static void _showMoreActions(
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
                _copyShoppingList(context, shoppingList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Dela vidare'),
              onTap: () {
                Navigator.pop(context);
                _shareShoppingList(context, shoppingList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Rapportera'),
              onTap: () {
                Navigator.pop(context);
                _reportShoppingList(context, shoppingList);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _copyShoppingList(BuildContext context, UnifiedShoppingList shoppingList) async {
    try {
      // Create a text representation of the shopping list
      final StringBuffer buffer = StringBuffer();
      buffer.writeln(shoppingList.name);
      buffer.writeln('=' * shoppingList.name.length);
      buffer.writeln();
      
      if (shoppingList.description?.isNotEmpty == true) {
        buffer.writeln(shoppingList.description);
        buffer.writeln();
      }
      
      buffer.writeln('Inköpslista (${shoppingList.items.length} varor):');
      
      for (int i = 0; i < shoppingList.items.length; i++) {
        final item = shoppingList.items[i];
        final status = item.bought ? '✓' : '○';
        buffer.writeln('$status ${item.name} (${item.amount} ${item.unit})');
      }
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      
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

  static Future<void> _shareShoppingList(BuildContext context, UnifiedShoppingList shoppingList) async {
    try {
      // Create a shareable text representation
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('📋 ${shoppingList.name}');
      buffer.writeln();
      
      if (shoppingList.description?.isNotEmpty == true) {
        buffer.writeln(shoppingList.description);
        buffer.writeln();
      }
      
      buffer.writeln('🛍️ Inköpslista (${shoppingList.items.length} varor):');
      
      for (final item in shoppingList.items) {
        final emoji = item.bought ? '✓' : '▪️';
        buffer.writeln('$emoji ${item.name} (${item.amount} ${item.unit})');
      }
      
      buffer.writeln();
      buffer.writeln('Delad via Butlery 🍳');
      
      // Copy to clipboard as a fallback sharing method
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      
      if (context.mounted) {
        // Show options for sharing
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dela inköpslista',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                    _shareWithFriends(context, shoppingList);
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
  
  static Future<void> _shareWithFriends(BuildContext context, UnifiedShoppingList shoppingList) async {
    try {
      // Show a sharing dialog using existing dialog patterns
      final shareOptions = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dela inköpslista'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Dela "${shoppingList.name}" med:'),
              const SizedBox(height: 16),
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

  static Future<void> _reportShoppingList(BuildContext context, UnifiedShoppingList shoppingList) async {
    final reason = await _showReportDialog(context);
    
    if (reason != null && context.mounted) {
      try {
        // Log the report using AppLogger for proper tracking
        AppLogger.warning('Content Report - Shopping List: ${shoppingList.id}');
        AppLogger.info('Report reason: $reason');
        AppLogger.info('Reported by user, list owner: ${shoppingList.ownerDisplayName}');
        
        // In a full implementation, this would send to a moderation service
        // For now, we log it properly for monitoring and review
        
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
  
  static Future<String?> _showReportDialog(BuildContext context) async {
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
              const SizedBox(height: 16),
              RadioGroup<String>(
                onChanged: (value) {
                  setState(() => selectedReason = value);
                },
                child: Column(
                  children: [
                    'Olämpligt innehåll',
                    'Spam eller reklam',
                    'Felaktig information',
                    'Upphovsrättsintrång',
                    'Annat'
                  ].map((reason) => RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                  )).toList(),
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

  /// Get formatted share time text from shopping list metadata
  static String _getShareTimeText(UnifiedShoppingList shoppingList) {
    // Use last activity time if available, otherwise fall back to created time
    final shareTime = shoppingList.lastActivityAt ?? shoppingList.createdAt;
    
    final now = DateTime.now();
    final difference = now.difference(shareTime);
    
    if (difference.inMinutes < 1) {
      return 'Delad just nu';
    } else if (difference.inMinutes < 60) {
      return 'Delad ${difference.inMinutes} min sedan';
    } else if (difference.inHours < 24) {
      return 'Delad ${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return 'Delad ${difference.inDays} dag${difference.inDays > 1 ? 'ar' : ''} sedan';
    } else {
      // For older items, show the actual date
      final day = shareTime.day.toString().padLeft(2, '0');
      final month = shareTime.month.toString().padLeft(2, '0');
      return 'Delad $day/$month';
    }
  }
}