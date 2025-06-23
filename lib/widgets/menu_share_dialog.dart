// lib/widgets/menu_share_dialog.dart
// Komplett social delnings-dialog för veckomeny

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_theme.dart';
import '../services/social_recipe_service.dart';
import '../core/injection.dart';

/// ✨ KOMPLETT MENY DELNINGS-DIALOG
///
/// Features:
/// - Elegant design med meny-översikt
/// - Anpassningsbar titel för menyn
/// - Smart vän-selektion med search
/// - Loading states och error handling
/// - Success animation med meny-statistik
class MenuShareDialog extends StatefulWidget {
  final Map<String, List<Recipe>> menu;
  final List<UserProfile> friends;

  const MenuShareDialog({
    super.key,
    required this.menu,
    required this.friends,
  });

  @override
  State<MenuShareDialog> createState() => _MenuShareDialogState();
}

class _MenuShareDialogState extends State<MenuShareDialog>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();

  late AnimationController _successAnimController;
  late Animation<double> _successScaleAnimation;

  final SocialRecipeService _socialRecipeService = sl<SocialRecipeService>();
  final Set<String> _selectedFriendIds = {};

  bool _showSuccess = false;
  bool _isSharing = false;
  String _searchQuery = '';
  String? _sharingError;

  @override
  void initState() {
    super.initState();

    // Default meny-titel
    _titleController.text = 'Min veckomeny';

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
    _titleController.dispose();
    _searchController.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 450,
          maxHeight: 650, // Minska maxhöjd för bättre mobilanpassning
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
        child: _showSuccess ? _buildSuccessContent() : _buildShareContent(),
      ),
    );
  }

  Widget _buildShareContent() {
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
                Icons.restaurant_menu,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: AppTheme.iconSizeAction,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dela veckomeny med vänner',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${_getTotalRecipeCount()} recept i ${widget.menu.length} kategorier',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
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
        Expanded(
          child: SingleChildScrollView(
            padding: AppTheme.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meny-titel
                _buildMenuTitleSection(),
                AppTheme.mediumGap,

                // Meny-översikt
                _buildMenuOverview(),
                AppTheme.mediumGap,

                // Meddelande
                _buildMessageSection(),
                AppTheme.mediumGap,

                // Vän-sökning
                _buildFriendSearch(),
                AppTheme.mediumGap,

                // Vänlista (med egen scrolling)
                SizedBox(
                  height: 300, // Fast höjd för vänlistan
                  child: _buildFriendsList(),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildSuccessContent() {
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
                Icons.restaurant_menu,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          AppTheme.largeGap,
          Text(
            'Meny delad! 🎉',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          AppTheme.smallGap,
          Text(
            'Din veckomeny "${_titleController.text}" har delats med ${_selectedFriendIds.length} vänner',
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

  Widget _buildMenuTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Meny-titel',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        AppTheme.smallGap,
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Ge din meny ett namn...',
            border: OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            contentPadding: AppTheme.cardPadding,
          ),
          maxLength: 50,
        ),
      ],
    );
  }

  Widget _buildMenuOverview() {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainer
            .withValues(alpha: 0.5),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview,
                size: AppTheme.iconSizeInfo,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: AppTheme.spacingXs),
              Text(
                'Meny-översikt',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          AppTheme.smallGap,
          ...widget.menu.entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacingXs),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingSm),
                    Text(
                      '${entry.key}: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Expanded(
                      child: Text(
                        '${entry.value.length} recept',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )),
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
      ],
    );
  }

  Widget _buildFriendSearch() {
    if (widget.friends.isEmpty) {
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
              onPressed:
                  _hasSelectedAll() ? _clearFriendSelection : _selectAllFriends,
              icon: Icon(
                _hasSelectedAll() ? Icons.deselect : Icons.select_all,
                size: AppTheme.iconSizeInfo,
              ),
              label: Text(_hasSelectedAll() ? 'Rensa' : 'Alla'),
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
            hintText: 'Sök bland ${widget.friends.length} vänner...',
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

  Widget _buildFriendsList() {
    if (widget.friends.isEmpty) {
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
              'Lägg till vänner för att kunna dela menyer!',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filteredFriends = _getFilteredFriends();

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
      height: 300, // Fast höjd med egen scrolling
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: AppTheme.mediumRadius,
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: filteredFriends.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        itemBuilder: (context, index) {
          final friend = filteredFriends[index];
          return _buildFriendItem(friend);
        },
      ),
    );
  }

  Widget _buildFriendItem(UserProfile friend) {
    final isSelected = _selectedFriendIds.contains(friend.uid);

    return Material(
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _toggleFriendSelection(friend.uid),
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
                  onChanged: (_) => _toggleFriendSelection(friend.uid),
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

  Widget _buildActionButtons() {
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
          if (_selectedFriendIds.isNotEmpty)
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
                    '${_selectedFriendIds.length} vald(a)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Error display
          if (_sharingError != null)
            Container(
              margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
              padding: EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.errorColor),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      _sharingError!,
                      style: TextStyle(color: AppTheme.errorColor),
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
                  onPressed: _selectedFriendIds.isNotEmpty && !_isSharing
                      ? _shareMenu
                      : null,
                  icon: _isSharing
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
                    _isSharing ? 'Delar...' : 'Dela meny',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  int _getTotalRecipeCount() {
    return widget.menu.values.fold(0, (sum, recipes) => sum + recipes.length);
  }

  List<UserProfile> _getFilteredFriends() {
    if (_searchQuery.isEmpty) {
      return widget.friends;
    }

    return widget.friends.where((friend) {
      return friend.displayName.toLowerCase().contains(_searchQuery) ||
          (friend.bio?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  bool _hasSelectedAll() {
    final filteredFriends = _getFilteredFriends();
    if (filteredFriends.isEmpty) return false;

    return filteredFriends
        .every((friend) => _selectedFriendIds.contains(friend.uid));
  }

  void _toggleFriendSelection(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  void _selectAllFriends() {
    setState(() {
      _selectedFriendIds.clear();
      _selectedFriendIds.addAll(_getFilteredFriends().map((f) => f.uid));
    });
  }

  void _clearFriendSelection() {
    setState(() {
      _selectedFriendIds.clear();
    });
  }

  Future<void> _shareMenu() async {
    if (_selectedFriendIds.isEmpty) {
      setState(() {
        _sharingError = 'Välj minst en vän att dela med';
      });
      return;
    }

    try {
      setState(() {
        _isSharing = true;
        _sharingError = null;
      });

      final success = await _socialRecipeService.shareMenuToFriends(
        menu: widget.menu,
        friendUserIds: _selectedFriendIds.toList(),
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        customTitle: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
      );

      if (success && mounted) {
        setState(() {
          _showSuccess = true;
        });
        _successAnimController.forward();

        // Auto-close efter 3 sekunder
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        setState(() {
          _sharingError = _socialRecipeService.error ?? 'Kunde inte dela meny';
        });
      }
    } catch (e) {
      setState(() {
        _sharingError = 'Kunde inte dela meny: $e';
      });
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }
}
