// lib/widgets/common/dialogs/group_shopping_list_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Dialog for selecting a shopping list to share with a group.
/// Initializes the shopping service and handles loading/error/empty states.
class GroupShoppingListSelectionDialog extends StatefulWidget {
  final String groupName;

  const GroupShoppingListSelectionDialog({
    super.key,
    required this.groupName,
  });

  @override
  State<GroupShoppingListSelectionDialog> createState() =>
      _GroupShoppingListSelectionDialogState();
}

class _GroupShoppingListSelectionDialogState
    extends State<GroupShoppingListSelectionDialog> {
  late final UnifiedShoppingService _shoppingService;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shoppingService = ServiceLocator.get<UnifiedShoppingService>();
    _initializeShoppingService();
  }

  Future<void> _initializeShoppingService() async {
    if (!mounted) return;

    try {
      if (!_shoppingService.isInitialized) {
        AppLogger.debug(
          '[ShoppingListDialog] Initializing shopping service...',
        );
        await _shoppingService.initialize();
      } else {
        AppLogger.debug(
          '[ShoppingListDialog] Service already initialized, refreshing...',
        );
        await _shoppingService.loadLists();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('[ShoppingListDialog] Initialization failed', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = context.l10n.errorCouldNotLoad('inköpslistor');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.l10n.dialogShareShoppingListWith(widget.groupName),
        style: AppTextStyles.headlineSmall,
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            context.l10n.commonCancel,
            style: AppTextStyles.labelLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingIndicator(),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              context.l10n.shoppingLoadingLists,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return StateWidget.error(
        message: _error!,
        actionLabel: context.l10n.commonRetry,
        onAction: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _initializeShoppingService();
        },
      );
    }

    final lists = _shoppingService.personalLists;

    if (lists.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.dialogNoShoppingLists,
        subtitle: context.l10n.dialogNoShoppingListsToShare,
        icon: Icons.shopping_cart,
      );
    }

    return ListView.builder(
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final list = lists[index];
        return _ShoppingListItem(
          list: list,
          onTap: () => Navigator.pop(context, list),
        );
      },
    );
  }
}

/// Shopping list item widget
class _ShoppingListItem extends StatelessWidget {
  final UnifiedShoppingList list;
  final VoidCallback onTap;

  const _ShoppingListItem({
    required this.list,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = list.items.where((item) => item.bought).length;
    final totalCount = list.items.length;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      leading: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            width: AppDimensions.iconSizeXl,
            height: AppDimensions.iconSizeXl,
            decoration: BoxDecoration(
              color: cs.primary.withValues(
                alpha: AppDimensions.opacityVeryLight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: Icon(
              Icons.shopping_cart,
              color: cs.primary,
              size: AppDimensions.iconSizeAction,
            ),
          );
        },
      ),
      title: Text(
        list.name,
        style: AppTextStyles.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (list.description != null && list.description!.isNotEmpty)
            Text(
              list.description!,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            context.l10n.dialogItemsProgress(completedCount, totalCount),
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: AppDimensions.iconSizeS,
      ),
      onTap: onTap,
    );
  }
}
