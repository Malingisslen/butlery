// lib/widgets/social_share_dialog.dart
// Komplett social delnings-dialog för recept

import 'package:flutter/material.dart';
import '../viewmodels/social_recipe_viewmodel.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_theme.dart';

/// ✨ KOMPLETT SOCIAL DELNINGS-DIALOG
///
/// Features:
/// - Elegant design med search
/// - Meddelande-fält med förslag
/// - Smart vän-selektion med visual feedback
/// - Loading states och error handling
/// - Success animation
class SocialShareDialog extends StatefulWidget {
  final String recipeTitle;
  final SocialRecipeViewModel socialViewModel;

  const SocialShareDialog({
    super.key,
    required this.recipeTitle,
    required this.socialViewModel,
  });

  @override
  State<SocialShareDialog> createState() => _SocialShareDialogState();
}

class _SocialShareDialogState extends State<SocialShareDialog>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();

  late AnimationController _successAnimController;
  late Animation<double> _successScaleAnimation;

  bool _showSuccess = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Success animation
    _successAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _successScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    ));

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socialViewModel = widget.socialViewModel;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppTheme.largeRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _showSuccess
            ? _buildSuccessContent(socialViewModel)
            : _buildShareContent(socialViewModel),
      ),
    );
  }

  Widget _buildShareContent(SocialRecipeViewModel socialViewModel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: AppTheme.cardPadding,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.share,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: AppTheme.iconSizeAction,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dela recept med vänner',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      widget.recipeTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),

        // Content
        Flexible(
          child: Padding(
            padding: AppTheme.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meddelande (med förslag)
                _buildMessageSection(),
                AppTheme.mediumGap,

                // Vän-sökning
                _buildFriendSearch(socialViewModel),
                AppTheme.mediumGap,

                // Vänlista
                Expanded(
                  child: _buildFriendsList(socialViewModel),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        _buildActionButtons(socialViewModel),
      ],
    );
  }

  Widget _buildSuccessContent(SocialRecipeViewModel socialViewModel) {
    return Container(
      padding: AppTheme.cardPadding * 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _successScaleAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          AppTheme.largeGap,
          Text(
            'Recept delat! 🎉',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          AppTheme.smallGap,
          Text(
            'Ditt recept har delats med ${socialViewModel.selectedFriendIds.length} vänner',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          AppTheme.largeGap,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stäng'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.message_outlined,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Meddelande (valfritt)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        AppTheme.smallGap,
        TextField(
          controller: _messageController,
          decoration: InputDecoration(
            hintText: 'Lägg till ett personligt meddelande...',
            border: OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            contentPadding: AppTheme.cardPadding,
          ),
          maxLines: 2,
          maxLength: 200,
        ),
        AppTheme.smallGap,
      ],
    );
  }

  Widget _buildFriendSearch(SocialRecipeViewModel socialViewModel) {
    if (socialViewModel.friends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.search,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Sök vänner',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const Spacer(),
            // Select all/none knappar
            TextButton.icon(
              onPressed: _hasSelectedAll(socialViewModel)
                  ? socialViewModel.clearFriendSelection
                  : socialViewModel.selectAllFriends,
              icon: Icon(
                _hasSelectedAll(socialViewModel)
                    ? Icons.deselect
                    : Icons.select_all,
                size: AppTheme.iconSizeInfo,
              ),
              label: Text(_hasSelectedAll(socialViewModel) ? 'Rensa' : 'Alla'),
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        AppTheme.smallGap,
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Sök bland ${socialViewModel.friends.length} vänner...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsList(SocialRecipeViewModel socialViewModel) {
    if (socialViewModel.friends.isEmpty) {
      return Container(
        padding: AppTheme.cardPadding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: AppTheme.mediumRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            AppTheme.smallGap,
            Text(
              'Inga vänner att dela med',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            AppTheme.smallGap,
            Text(
              'Lägg till vänner för att kunna dela recept!',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filteredFriends = _getFilteredFriends(socialViewModel);

    if (filteredFriends.isEmpty && _searchQuery.isNotEmpty) {
      return Container(
        padding: AppTheme.cardPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            AppTheme.smallGap,
            Text(
              'Inga vänner matchade "$_searchQuery"',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: AppTheme.mediumRadius,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filteredFriends.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        itemBuilder: (context, index) {
          final friend = filteredFriends[index];
          return _buildFriendItem(friend, socialViewModel);
        },
      ),
    );
  }

  Widget _buildFriendItem(
      UserProfile friend, SocialRecipeViewModel socialViewModel) {
    final isSelected = socialViewModel.selectedFriendIds.contains(friend.uid);

    return Material(
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: () => socialViewModel.toggleFriendSelection(friend.uid),
        borderRadius: AppTheme.mediumRadius,
        child: Padding(
          padding: AppTheme.cardPadding,
          child: Row(
            children: [
              UserAvatar.medium(
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                    ),
                    if (friend.bio?.isNotEmpty == true)
                      Text(
                        friend.bio!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Checkbox med animation
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.8,
                duration: const Duration(milliseconds: 150),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) =>
                      socialViewModel.toggleFriendSelection(friend.uid),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.smallRadius,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(SocialRecipeViewModel socialViewModel) {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainer
            .withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Selected count
          if (socialViewModel.hasSelectedFriends)
            Container(
              margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people,
                    size: AppTheme.iconSizeInfo,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppTheme.spacingXs),
                  Text(
                    '${socialViewModel.selectedFriendIds.length} vald(a)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Avbryt'),
                ),
              ),
              SizedBox(width: AppTheme.spacingMd),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: socialViewModel.hasSelectedFriends &&
                          !socialViewModel.isSharing
                      ? _shareRecipe
                      : null,
                  icon: socialViewModel.isSharing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    socialViewModel.isSharing ? 'Delar...' : 'Dela recept',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareRecipe() async {
    final socialViewModel = widget.socialViewModel;

    final success = await socialViewModel.shareRecipe(
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _showSuccess = true;
      });
      _successAnimController.forward();

      // Auto-close efter 2 sekunder
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  List<UserProfile> _getFilteredFriends(SocialRecipeViewModel socialViewModel) {
    if (_searchQuery.isEmpty) {
      return socialViewModel.friends;
    }

    return socialViewModel.friends.where((friend) {
      return friend.displayName.toLowerCase().contains(_searchQuery) ||
          (friend.bio?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  bool _hasSelectedAll(SocialRecipeViewModel socialViewModel) {
    final filteredFriends = _getFilteredFriends(socialViewModel);
    if (filteredFriends.isEmpty) return false;

    return filteredFriends.every(
        (friend) => socialViewModel.selectedFriendIds.contains(friend.uid));
  }
}
