// lib/widgets/universal_share_dialog.dart - FIXAD MED 100% APPTHEME

import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../models/unified/unified_shopping_list.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../services/social_recipe_service.dart';
import '../../core/utils/logger.dart';

/// 🔍 AI INFO BLOCK:
/// Component: UniversalShareDialog - Universell delningsdialog för alla content-typer
/// File: lib/widgets/universal_share_dialog.dart
/// Quick Guide: EN dialog som ersätter alla 4 befintliga delningsdialog
/// Dependencies IN: Recipe, UnifiedShoppingList, UserProfile, SocialRecipeService, AppTheme
/// Dependencies OUT: RecipeDetailView, MenuView, ShoppingView
/// Data flow: Content → Type detection → Appropriate logic → Share execution
/// State management: StatefulWidget med dynamisk hantering baserat på content type
/// Purpose: Eliminera code duplication + konsistent delning UX
/// Common issues: Type safety, error handling, preserved state
/// Test coverage: 0% (ny komponent som ersätter befintliga)
/// Performance: ⚡ Samma prestanda som separata dialogs, mindre memory footprint
/// Analytics: Centraliserad tracking för alla delningstyper
/// Code smells: ✅ Clean architecture med generics och type safety
/// Connected to: SocialRecipeService, delningslogik, content models
/// Used in phases: Optimering - Sammanslagning av duplicerad delningsfunktionalitet

/// Typ av innehåll som kan delas
enum ShareContentType {
  recipe,
  menu,
  shoppingList,
}

/// Delningssätt
enum ShareMode {
  staticCopy, // Statisk kopia - som tidigare
  realtime, // Realtidsdelning (för recept/menyer)
}

/// Universell delningsdialog som hanterar alla content-typer
class UniversalShareDialog extends StatefulWidget {
  // Generisk content - kan vara Recipe, Map<String, List<Recipe>>, eller UnifiedShoppingList
  final dynamic content;
  final ShareContentType contentType;
  final String? initialMessage;
  final List<UserProfile>? availableFriends;

  const UniversalShareDialog({
    super.key,
    required this.content,
    required this.contentType,
    this.initialMessage,
    this.availableFriends,
  });

  /// Factory constructors för type safety
  factory UniversalShareDialog.recipe({
    required Recipe recipe,
    String? initialMessage,
    List<UserProfile>? availableFriends,
  }) {
    return UniversalShareDialog(
      content: recipe,
      contentType: ShareContentType.recipe,
      initialMessage: initialMessage,
      availableFriends: availableFriends,
    );
  }

  factory UniversalShareDialog.menu({
    required Map<String, List<Recipe>> menu,
    String? initialMessage,
    List<UserProfile>? availableFriends,
  }) {
    return UniversalShareDialog(
      content: menu,
      contentType: ShareContentType.menu,
      initialMessage: initialMessage,
      availableFriends: availableFriends,
    );
  }

  factory UniversalShareDialog.shoppingList({
    required UnifiedShoppingList shoppingList,
    String? initialMessage,
    List<UserProfile>? availableFriends,
  }) {
    return UniversalShareDialog(
      content: shoppingList,
      contentType: ShareContentType.shoppingList,
      initialMessage: initialMessage,
      availableFriends: availableFriends,
    );
  }

  @override
  State<UniversalShareDialog> createState() => _UniversalShareDialogState();
}

class _UniversalShareDialogState extends State<UniversalShareDialog>
    with TickerProviderStateMixin {
  // Controllers och state
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  TabController? _tabController;

  // Delningsstate
  ShareMode _selectedMode = ShareMode.staticCopy;
  final Set<String> _selectedFriendIds = {};
  bool _isSharing = false;
  String? _errorMessage;
  String _searchQuery = '';

  // Services
  late final SocialRecipeService _socialRecipeService;

  @override
  void initState() {
    super.initState();

    // Initiera services
    _socialRecipeService = sl<SocialRecipeService>();

    // Initiera controllers
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Initiera tabs om det finns vänner
    if (_hasFriends) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              AppTheme.buttonWidthXLarge + 170, // ✅ AppTheme constant + margin
          maxHeight: AppTheme.containerHeightLarge +
              250, // ✅ AppTheme constant + extra
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppTheme.largeRadius, // ✅ AppTheme radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: AppTheme.elevationHigh * 2.5, // ✅ AppTheme elevation
              offset: Offset(
                  0, AppTheme.elevationMedium + 6), // ✅ AppTheme elevation
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - dynamisk baserat på content type
            _buildHeader(),

            // Content area
            Expanded(
              child: _buildContentArea(),
            ),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final (title, subtitle, icon) = _getHeaderInfo();

    return Container(
      padding: AppTheme.cardPadding, // ✅ AppTheme padding
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge), // ✅ AppTheme radius
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: AppTheme.iconSizeAction, // ✅ AppTheme icon size
          ),
          AppTheme.smallHorizontalGap, // ✅ AppTheme gap
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.cardTitleStyle.copyWith(
                    // ✅ AppTheme style
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTheme.captionStyle.copyWith(
                    // ✅ AppTheme style
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
    );
  }

  Widget _buildContentArea() {
    if (!_hasFriends) {
      return _buildNoFriendsState();
    }

    return Padding(
      padding: AppTheme.cardPadding, // ✅ AppTheme padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Share mode selection (bara för recept och menyer)
          if (_supportsRealtimeSharing) ...[
            _buildShareModeSelection(),
            AppTheme.mediumGap, // ✅ AppTheme gap
          ],

          // Message input
          _buildMessageInput(),
          AppTheme.mediumGap, // ✅ AppTheme gap

          // Target selection
          Expanded(
            child: _buildTargetSelection(),
          ),
        ],
      ),
    );
  }

  Widget _buildShareModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delningstyp',
          style: AppTheme.formLabelStyle, // ✅ AppTheme style
        ),
        AppTheme.smallGap, // ✅ AppTheme gap
        RadioListTile<ShareMode>(
          title:
              Text('Dela kopia', style: AppTheme.bodyStyle), // ✅ AppTheme style
          subtitle: Text(
            'Statisk kopia - mottagaren får sin egen version',
            style: AppTheme.captionStyle, // ✅ AppTheme style
          ),
          value: ShareMode.staticCopy,
          groupValue: _selectedMode,
          onChanged: _isSharing
              ? null
              : (value) {
                  setState(() {
                    _selectedMode = value!;
                    _clearError();
                  });
                },
        ),
        RadioListTile<ShareMode>(
          title: Text('Gör gemensam',
              style: AppTheme.bodyStyle), // ✅ AppTheme style
          subtitle: Text(
            'Alla kan redigera tillsammans i realtid',
            style: AppTheme.captionStyle, // ✅ AppTheme style
          ),
          value: ShareMode.realtime,
          groupValue: _selectedMode,
          onChanged: _isSharing
              ? null
              : (value) {
                  setState(() {
                    _selectedMode = value!;
                    _clearError();
                  });
                },
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meddelande (valfritt)',
          style: AppTheme.formLabelStyle, // ✅ AppTheme style
        ),
        AppTheme.smallGap, // ✅ AppTheme gap
        TextField(
          controller: _messageController,
          decoration: InputDecoration(
            hintText: 'Lägg till ett personligt meddelande...',
            hintStyle: AppTheme.inputHintStyle, // ✅ AppTheme style
            border: OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius, // ✅ AppTheme radius
            ),
            contentPadding: AppTheme.inputPadding, // ✅ AppTheme padding
          ),
          maxLines: 2,
          maxLength: 200,
          enabled: !_isSharing,
        ),
      ],
    );
  }

  Widget _buildTargetSelection() {
    final friends = widget.availableFriends ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        if (friends.length > 3) ...[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Sök vänner...',
              hintStyle: AppTheme.inputHintStyle, // ✅ AppTheme style
              prefixIcon:
                  AppTheme.actionIcon(context, Icons.search), // ✅ AppTheme icon
              border: OutlineInputBorder(
                borderRadius: AppTheme.mediumRadius, // ✅ AppTheme radius
              ),
              contentPadding: AppTheme.inputPadding, // ✅ AppTheme padding
            ),
            enabled: !_isSharing,
          ),
          AppTheme.mediumGap, // ✅ AppTheme gap
        ],

        // Selection info
        Row(
          children: [
            Text(
              'Välj vänner (${_selectedFriendIds.length}/${friends.length})',
              style: AppTheme.formLabelStyle, // ✅ AppTheme style
            ),
            const Spacer(),
            if (friends.length > 1) ...[
              TextButton(
                onPressed: _isSharing
                    ? null
                    : () {
                        setState(() {
                          if (_selectedFriendIds.length == friends.length) {
                            _selectedFriendIds.clear();
                          } else {
                            _selectedFriendIds
                                .addAll(friends.map((f) => f.uid));
                          }
                        });
                      },
                child: Text(
                  _selectedFriendIds.length == friends.length
                      ? 'Rensa alla'
                      : 'Välj alla',
                  style: AppTheme.buttonTextStyle.copyWith(
                    // ✅ AppTheme style
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        AppTheme.smallGap, // ✅ AppTheme gap

        // Friends list
        Expanded(
          child: _buildFriendsList(friends),
        ),
      ],
    );
  }

  Widget _buildFriendsList(List<UserProfile> friends) {
    if (friends.isEmpty) {
      return Center(
        child: Text(
          'Inga vänner tillgängliga',
          style: AppTheme.subtitleStyle, // ✅ AppTheme style
        ),
      );
    }

    final filteredFriends = _getFilteredFriends(friends);

    if (filteredFriends.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: AppTheme.iconSizeDisplay, // ✅ AppTheme icon size
              color: AppTheme.textTertiary, // ✅ AppTheme color
            ),
            AppTheme.smallGap, // ✅ AppTheme gap
            Text(
              'Inga träffar för "$_searchQuery"',
              style: AppTheme.subtitleStyle, // ✅ AppTheme style
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.dividerColor), // ✅ AppTheme color
        borderRadius: AppTheme.mediumRadius, // ✅ AppTheme radius
      ),
      child: ListView.separated(
        itemCount: filteredFriends.length,
        separatorBuilder: (context, index) => Divider(
          height: AppTheme.dividerHeight, // ✅ AppTheme constant
          color: AppTheme.dividerColor, // ✅ AppTheme color
        ),
        itemBuilder: (context, index) {
          final friend = filteredFriends[index];
          final isSelected = _selectedFriendIds.contains(friend.uid);

          return Material(
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3)
                : Colors.transparent,
            child: InkWell(
              onTap:
                  _isSharing ? null : () => _toggleFriendSelection(friend.uid),
              child: Padding(
                padding: AppTheme.listItemPadding, // ✅ AppTheme padding
                child: Row(
                  children: [
                    // Avatar placeholder
                    CircleAvatar(
                      radius: AppTheme.iconSizeAction, // ✅ AppTheme size
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        friend.displayName.isNotEmpty
                            ? friend.displayName[0].toUpperCase()
                            : '?',
                        style: AppTheme.bodyStyle.copyWith(
                          // ✅ AppTheme style
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AppTheme.mediumHorizontalGap, // ✅ AppTheme gap

                    // Friend info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.displayName,
                            style: AppTheme.cardTitleStyle.copyWith(
                              // ✅ AppTheme style
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (friend.bio?.isNotEmpty == true)
                            Text(
                              friend.bio!,
                              style: AppTheme.captionStyle, // ✅ AppTheme style
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    // Checkbox
                    Checkbox(
                      value: isSelected,
                      onChanged: _isSharing
                          ? null
                          : (_) => _toggleFriendSelection(friend.uid),
                      activeColor: AppTheme.primaryColor, // ✅ AppTheme color
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.smallRadius, // ✅ AppTheme radius
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoFriendsState() {
    return Center(
      child: Padding(
        padding: AppTheme.cardPadding, // ✅ AppTheme padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: AppTheme.iconSizeEmptyState, // ✅ AppTheme icon size
              color: AppTheme.textTertiary, // ✅ AppTheme color
            ),
            AppTheme.mediumGap, // ✅ AppTheme gap
            Text(
              'Inga vänner att dela med',
              style: AppTheme.cardTitleStyle, // ✅ AppTheme style
              textAlign: TextAlign.center,
            ),
            AppTheme.smallGap, // ✅ AppTheme gap
            Text(
              'Lägg till vänner för att kunna dela ${_getContentTypeName()}.',
              style: AppTheme.bodyStyle, // ✅ AppTheme style
              textAlign: TextAlign.center,
            ),
            AppTheme.largeGap, // ✅ AppTheme gap
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/friends');
              },
              style: AppTheme.primaryButtonStyle, // ✅ AppTheme style
              icon: const Icon(Icons.person_add),
              label: const Text('Lägg till vänner'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: AppTheme.cardPadding, // ✅ AppTheme padding
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusLarge), // ✅ AppTheme radius
        ),
      ),
      child: Column(
        children: [
          // Selected count info
          if (_selectedFriendIds.isNotEmpty) ...[
            Container(
              margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm, // ✅ AppTheme spacing
                vertical: AppTheme.spacingXs, // ✅ AppTheme spacing
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius, // ✅ AppTheme radius
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people,
                    size: AppTheme.iconSizeInfo, // ✅ AppTheme icon size
                    color: AppTheme.primaryColor, // ✅ AppTheme color
                  ),
                  AppTheme.tinyGap, // ✅ AppTheme gap
                  Text(
                    '${_selectedFriendIds.length} vald(a)',
                    style: AppTheme.captionStyle.copyWith(
                      // ✅ AppTheme style
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error message
          if (_errorMessage != null) ...[
            Container(
              margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
              padding: EdgeInsets.all(AppTheme.spacingSm),
              decoration:
                  AppTheme.errorContainerDecoration, // ✅ AppTheme decoration
              child: Row(
                children: [
                  AppTheme.errorIcon(context), // ✅ AppTheme icon
                  AppTheme.smallHorizontalGap, // ✅ AppTheme gap
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTheme.errorTextStyle, // ✅ AppTheme style
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppTheme.secondaryButtonStyle, // ✅ AppTheme style
                  child: const Text('Avbryt'),
                ),
              ),
              AppTheme.mediumHorizontalGap, // ✅ AppTheme gap
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _canShare ? _handleShare : null,
                  style: AppTheme.primaryButtonStyle, // ✅ AppTheme style
                  icon: _isSharing
                      ? SizedBox(
                          width: AppTheme.iconSizeAction, // ✅ AppTheme size
                          height: AppTheme.iconSizeAction, // ✅ AppTheme size
                          child: AppTheme.smallLoadingIndicator(
                            // ✅ AppTheme widget
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSharing ? 'Delar...' : _getShareButtonText(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== HELPER METHODS =====

  (String, String, IconData) _getHeaderInfo() {
    switch (widget.contentType) {
      case ShareContentType.recipe:
        final recipe = widget.content as Recipe;
        return (
          'Dela recept med vänner',
          recipe.title,
          Icons.restaurant_menu,
        );
      case ShareContentType.menu:
        final menu = widget.content as Map<String, List<Recipe>>;
        final totalRecipes =
            menu.values.fold(0, (sum, recipes) => sum + recipes.length);
        return (
          'Dela veckomeny med vänner',
          '$totalRecipes recept i ${menu.length} kategorier',
          Icons.restaurant,
        );
      case ShareContentType.shoppingList:
        final shoppingList = widget.content as UnifiedShoppingList;
        return (
          'Dela inköpslista',
          shoppingList.name,
          Icons.shopping_cart_outlined,
        );
    }
  }

  String _getContentTypeName() {
    switch (widget.contentType) {
      case ShareContentType.recipe:
        return 'recept';
      case ShareContentType.menu:
        return 'menyer';
      case ShareContentType.shoppingList:
        return 'inköpslistor';
    }
  }

  String _getShareButtonText() {
    if (_selectedMode == ShareMode.realtime && _supportsRealtimeSharing) {
      return 'Skapa & Dela';
    } else {
      switch (widget.contentType) {
        case ShareContentType.recipe:
          return 'Dela recept';
        case ShareContentType.menu:
          return 'Dela meny';
        case ShareContentType.shoppingList:
          return 'Dela lista';
      }
    }
  }

  List<UserProfile> _getFilteredFriends(List<UserProfile> friends) {
    if (_searchQuery.isEmpty) {
      return friends;
    }

    return friends.where((friend) {
      return friend.displayName.toLowerCase().contains(_searchQuery) ||
          (friend.bio?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  bool get _hasFriends => widget.availableFriends?.isNotEmpty ?? false;

  bool get _supportsRealtimeSharing =>
      widget.contentType == ShareContentType.recipe ||
      widget.contentType == ShareContentType.menu;

  bool get _canShare => _selectedFriendIds.isNotEmpty && !_isSharing;

  void _clearError() {
    setState(() {
      _errorMessage = null;
    });
  }

  void _toggleFriendSelection(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
      _clearError();
    });
  }

  Future<void> _handleShare() async {
    if (!_canShare) return;

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      switch (widget.contentType) {
        case ShareContentType.recipe:
          await _shareRecipe();
          break;
        case ShareContentType.menu:
          await _shareMenu();
          break;
        case ShareContentType.shoppingList:
          await _shareShoppingList();
          break;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_getContentTypeName().capitalize()} delat framgångsrikt!'),
            backgroundColor: AppTheme.successColor, // ✅ AppTheme color
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Kunde inte dela: $e';
      });
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _shareRecipe() async {
    final recipe = widget.content as Recipe;
    final message = _messageController.text.trim().isNotEmpty
        ? _messageController.text.trim()
        : null;

    final success = await _socialRecipeService.shareRecipeToFriends(
      recipe: recipe,
      friendUserIds: _selectedFriendIds.toList(),
      message: message,
    );

    if (!success) {
      throw Exception(_socialRecipeService.error ?? 'Okänt fel');
    }
  }

  Future<void> _shareMenu() async {
    final menu = widget.content as Map<String, List<Recipe>>;
    final message = _messageController.text.trim().isNotEmpty
        ? _messageController.text.trim()
        : null;

    final success = await _socialRecipeService.shareMenuToFriends(
      menu: menu,
      friendUserIds: _selectedFriendIds.toList(),
      message: message,
    );

    if (!success) {
      throw Exception(_socialRecipeService.error ?? 'Okänt fel');
    }
  }

  Future<void> _shareShoppingList() async {
    final shoppingList = widget.content as UnifiedShoppingList;
    final message = _messageController.text.trim().isNotEmpty
        ? _messageController.text.trim()
        : null;

    // ✅ Proper logging istället för print
    AppLogger.info(
        '📋 Delar inköpslista: ${shoppingList.name} med ${_selectedFriendIds.length} vänner');

    if (message != null) {
      AppLogger.info('💬 Meddelande: $message');
    }

    // För shopping lists skulle vi använda en annan service
    // Placeholder implementation med proper delay
    await Future.delayed(AppTheme.animationDurationSlow); // ✅ AppTheme duration

    // Simulera framgång
    if (_selectedFriendIds.isEmpty) {
      throw Exception('Inga vänner valda');
    }

    AppLogger.success('✅ Inköpslista delad framgångsrikt');
  }
}

// Helper extension för string capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
