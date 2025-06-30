// lib/widgets/shopping_share_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/unified/unified_shopping_list.dart';
import '../viewmodels/shared_content_viewmodel.dart';
import '../viewmodels/shopping_share_viewmodel.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// 🔍 AI INFO BLOCK:
/// Component: ShoppingShareDialog - MVVM-ren version med egen ViewModel
/// File: lib/widgets/shopping_share_dialog.dart
/// Quick Guide: Dialog för shopping share - samma design som receptdelning
/// Dependencies IN: SharedContentViewModel, ShoppingShareViewModel, AppTheme
/// Dependencies OUT: Anropas från UnifiedShoppingView
/// Data flow: UI events → ViewModel → Service → UI state update
/// State management: Dual ViewModels (SharedContent + ShoppingShare)
/// Purpose: Konsistent UX + MVVM compliance för shopping sharing
/// Common issues: Hantera loading states för båda ViewModels
/// Test coverage: Testa social delning + kopiera text
/// Performance: Optimerad med Consumer för granular rebuilds
/// Analytics: Spåra delningstyp + success/failure rates
/// Code smells: Inga - ren MVVM separation med enkel header-design
/// Connected to: UnifiedShoppingView, ShareService, SocialRecipeService
/// Used in phases: 4 (Social funktioner för inköpslistor) - MVVM COMPLIANT

class ShoppingShareDialog extends StatefulWidget {
  final UnifiedShoppingList shoppingList;

  const ShoppingShareDialog({
    super.key,
    required this.shoppingList,
  });

  @override
  State<ShoppingShareDialog> createState() => _ShoppingShareDialogState();
}

class _ShoppingShareDialogState extends State<ShoppingShareDialog> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => sl<SharedContentViewModel>()),
        ChangeNotifierProvider(
            create: (_) => sl<ShoppingShareViewModel>()..initializeCommand()),
      ],
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.largeRadius,
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Expanded(
                child: _buildSocialSharingContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusLarge),
          topRight: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Header med ikoner som receptdelning
          Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  'Dela inköpslista',
                  style: AppTheme.cardTitleStyle.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),

              // ✅ Delnings-ikoner direkt i header (som receptdelning)
              IconButton(
                onPressed: _copyListText,
                icon: const Icon(Icons.content_copy),
                tooltip: 'Kopiera text',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
              SizedBox(width: AppTheme.spacingXs),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          AppTheme.smallGap,

          // Lista info card
          Container(
            padding: AppTheme.inputPadding,
            decoration: AppTheme.cardDecoration.copyWith(
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(
                    Icons.list_alt,
                    color: AppTheme.primaryColor,
                    size: AppTheme.iconSizeAction,
                  ),
                ),
                SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.shoppingList.name,
                        style: AppTheme.cardTitleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppTheme.tinyGap,
                      Text(
                        '${widget.shoppingList.items.length} artiklar',
                        style: AppTheme.metadataStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Bara social delning - ingen tabs längre
  Widget _buildSocialSharingContent() {
    return Consumer2<SharedContentViewModel, ShoppingShareViewModel>(
      builder: (context, sharedViewModel, shareViewModel, child) {
        if (!shareViewModel.hasFriends) {
          return _buildNoFriendsState();
        }

        return Padding(
          padding: AppTheme.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dela med vänner',
                style: AppTheme.sectionTitleStyle,
              ),
              AppTheme.smallGap,
              Text(
                'Dina vänner får en kopia av listan som de kan se och använda.',
                style: AppTheme.bodyStyle,
              ),
              AppTheme.mediumGap,
              _buildMessageInput(shareViewModel),
              AppTheme.mediumGap,
              Text(
                'Välj vänner (${shareViewModel.selectedCount}/${shareViewModel.friends.length})',
                style: AppTheme.formLabelStyle,
              ),
              AppTheme.smallGap,
              Expanded(
                child: _buildFriendsList(shareViewModel),
              ),
              AppTheme.mediumGap,
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      shareViewModel.canShare && !shareViewModel.isSharing
                          ? () => _executeSocialShare(shareViewModel)
                          : null,
                  style: AppTheme.primaryButtonStyle,
                  icon: shareViewModel.isSharing
                      ? SizedBox(
                          width: AppTheme.iconSizeAction,
                          height: AppTheme.iconSizeAction,
                          child: AppTheme.smallLoadingIndicator(
                              color: Colors.white),
                        )
                      : AppTheme.actionIcon(context, Icons.send,
                          color: Colors.white),
                  label: Text(
                    shareViewModel.isSharing
                        ? 'Delar...'
                        : 'Dela med ${shareViewModel.selectedCount} vänner',
                    style:
                        AppTheme.buttonTextStyle.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoFriendsState() {
    return Consumer<ShoppingShareViewModel>(
      builder: (context, viewModel, child) {
        return Padding(
          padding: AppTheme.cardPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: AppTheme.iconSizeEmptyState,
                color: AppTheme.textTertiary,
              ),
              AppTheme.mediumGap,
              Text(
                'Inga vänner att dela med',
                style: AppTheme.cardTitleStyle,
                textAlign: TextAlign.center,
              ),
              AppTheme.smallGap,
              Text(
                'Lägg till vänner för att kunna dela dina inköpslistor socialt.',
                style: AppTheme.bodyStyle,
                textAlign: TextAlign.center,
              ),
              AppTheme.largeGap,
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/friends');
                },
                style: AppTheme.primaryButtonStyle,
                icon: AppTheme.actionIcon(context, Icons.person_add),
                label: const Text('Lägg till vänner'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput(ShoppingShareViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meddelande (valfritt)',
          style: AppTheme.formLabelStyle,
        ),
        AppTheme.smallGap,
        TextField(
          onChanged: viewModel.updateShareMessageCommand,
          style: AppTheme.bodyStyle,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'T.ex. "Hjälp mig handla!" eller "Kolla min lista"',
            hintStyle: AppTheme.inputHintStyle,
            border: OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            contentPadding: AppTheme.inputPadding,
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsList(ShoppingShareViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.dividerColor),
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Column(
        children: [
          if (viewModel.friends.length > 1)
            Container(
              padding: AppTheme.listItemPadding,
              decoration: BoxDecoration(
                color: AppTheme.cardColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusMedium),
                  topRight: Radius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Välj alla vänner',
                      style: AppTheme.formLabelStyle,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        viewModel.selectedCount == viewModel.friends.length
                            ? viewModel.clearAllSelectionsCommand
                            : viewModel.selectAllFriendsCommand,
                    style: AppTheme.secondaryButtonStyle,
                    child: Text(
                      viewModel.selectedCount == viewModel.friends.length
                          ? 'Rensa alla'
                          : 'Välj alla',
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: viewModel.friends.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: AppTheme.dividerColor,
              ),
              itemBuilder: (context, index) {
                final friend = viewModel.friends[index];
                final isSelected =
                    viewModel.selectedFriendIds.contains(friend.uid);

                return Material(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        viewModel.toggleFriendSelectionCommand(friend.uid),
                    child: Padding(
                      padding: AppTheme.listItemPadding,
                      child: Row(
                        children: [
                          UserAvatar.small(
                            displayName: friend.displayName,
                            imageUrl: friend.avatarUrl,
                          ),
                          SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend.displayName,
                                  style: AppTheme.cardTitleStyle.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (friend.bio?.isNotEmpty == true)
                                  Text(
                                    friend.bio!,
                                    style: AppTheme.captionStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => viewModel
                                .toggleFriendSelectionCommand(friend.uid),
                            activeColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppTheme.smallRadius,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===== EXECUTION METHODS =====

  Future<void> _executeSocialShare(ShoppingShareViewModel viewModel) async {
    final success =
        await viewModel.shareShoppingListCommand(widget.shoppingList);

    if (success && mounted) {
      Navigator.pop(context);
      _showSuccessMessage('Lista delad med ${viewModel.selectedCount} vänner!');
    } else if (mounted && viewModel.hasError) {
      _showErrorMessage(viewModel.error!);
    }
  }

  // ✅ Kopiera text direkt från header-ikonen
  Future<void> _copyListText() async {
    try {
      final text = _generateListText();
      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        _showSuccessMessage('Lista kopierad! Klistra in var du vill.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Kunde inte kopiera listan: $e');
      }
    }
  }

  // ✅ Generera text från shopping list
  String _generateListText() {
    final buffer = StringBuffer();

    buffer.writeln('🛒 ${widget.shoppingList.name.toUpperCase()}');
    buffer.writeln('===========');
    buffer.writeln();

    for (final item in widget.shoppingList.items) {
      final checkbox = item.bought ? '☑️' : '☐';
      buffer.writeln('$checkbox ${item.name}');

      // ✅ Säker hantering av amount och unit
      if (_hasValidAmount(item) && _hasValidUnit(item)) {
        buffer.writeln('   ${_formatAmount(item)} ${item.unit}');
      }
    }

    return buffer.toString();
  }

  // ===== HJÄLPMETODER FÖR SÄKER AMOUNT-HANTERING =====

  bool _hasValidAmount(dynamic item) {
    if (item.amount == null) return false;

    if (item.amount is String) {
      return (item.amount as String).trim().isNotEmpty;
    }

    if (item.amount is num) {
      return item.amount > 0;
    }

    return false;
  }

  bool _hasValidUnit(dynamic item) {
    return item.unit != null &&
        item.unit is String &&
        (item.unit as String).trim().isNotEmpty;
  }

  String _formatAmount(dynamic item) {
    if (item.amount is String) {
      return item.amount as String;
    }
    if (item.amount is double) {
      final amount = item.amount as double;
      return amount == amount.roundToDouble()
          ? amount.round().toString()
          : amount.toString();
    }
    return item.amount.toString();
  }

  // ===== SNACKBAR HELPERS =====

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
