// lib/widgets/universal_share_dialog.dart - FACADE PATTERN

import 'package:flutter/material.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';

// Import focused components
import 'package:butlery/widgets/common/share_dialog/share_dialog_header.dart';
import 'package:butlery/widgets/common/share_dialog/share_mode_selection.dart';
import 'package:butlery/widgets/common/share_dialog/share_message_input.dart';
import 'package:butlery/widgets/common/share_dialog/share_target_selection_enhanced.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/share_dialog/share_dialog_states.dart';
import 'package:butlery/widgets/common/share_dialog/share_dialog_actions.dart';
import 'package:butlery/widgets/common/share_dialog/share_dialog_helpers.dart';

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
  final List<FriendCategory>? availableGroups;
  final UniversalShareDialogViewModel viewModel;

  const UniversalShareDialog({
    super.key,
    required this.content,
    required this.contentType,
    required this.viewModel,
    this.initialMessage,
    this.availableFriends,
    this.availableGroups,
  });

  /// Factory constructors för type safety
  factory UniversalShareDialog.recipe({
    required Recipe recipe,
    required UniversalShareDialogViewModel viewModel,
    String? initialMessage,
    List<UserProfile>? availableFriends,
    List<FriendCategory>? availableGroups,
  }) {
    return UniversalShareDialog(
      content: recipe,
      contentType: ShareContentType.recipe,
      viewModel: viewModel,
      initialMessage: initialMessage,
      availableFriends: availableFriends,
      availableGroups: availableGroups,
    );
  }

  factory UniversalShareDialog.menu({
    required Map<String, List<Recipe>> menu,
    required UniversalShareDialogViewModel viewModel,
    String? initialMessage,
    List<UserProfile>? availableFriends,
    List<FriendCategory>? availableGroups,
  }) {
    return UniversalShareDialog(
      content: menu,
      contentType: ShareContentType.menu,
      viewModel: viewModel,
      initialMessage: initialMessage,
      availableFriends: availableFriends,
      availableGroups: availableGroups,
    );
  }

  factory UniversalShareDialog.shoppingList({
    required UnifiedShoppingList shoppingList,
    required UniversalShareDialogViewModel viewModel,
    String? initialMessage,
    List<UserProfile>? availableFriends,
    List<FriendCategory>? availableGroups,
  }) {
    return UniversalShareDialog(
      content: shoppingList,
      contentType: ShareContentType.shoppingList,
      viewModel: viewModel,
      initialMessage: initialMessage,
      availableFriends: availableFriends,
      availableGroups: availableGroups,
    );
  }

  @override
  State<UniversalShareDialog> createState() => _UniversalShareDialogState();
}

class _UniversalShareDialogState extends State<UniversalShareDialog> {
  // Controllers och state
  late final TextEditingController _messageController;
  late final bool _supportsRealtimeSharing;
  late final bool _hasFriends;
  
  // Delningsstate
  ShareMode _selectedMode = ShareMode.staticCopy;
  ShareTargetType _selectedTab = ShareTargetType.friends;
  final Set<String> _selectedFriendIds = {};
  final Set<String> _selectedGroupIds = {};
  String _searchQuery = '';
  bool allowCollaboration = false;

  @override
  void initState() {
    super.initState();
    
    // Initiera controllers
    _messageController = TextEditingController(text: widget.initialMessage ?? '');
    
    // Bestäm om realtidsdelning stöds
    _supportsRealtimeSharing = ShareDialogHelpers.supportsRealtimeSharing(widget.contentType);
    
    // Kontrollera om vi har vänner eller grupper
    _hasFriends = (widget.availableFriends?.isNotEmpty ?? false) || 
                  (widget.availableGroups?.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.buttonWidthXLarge + 170,
          maxHeight: 650,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: AppDimensions.elevationHigh * 2.5,
                offset: const Offset(0, AppDimensions.elevationMedium + 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildContentArea(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ShareDialogHeader.build(
      context,
      widget.contentType,
      widget.content,
    );
  }

  Widget _buildContentArea() {
    if (!_hasFriends) {
      return ShareDialogStates.buildNoFriendsState(context, widget.contentType);
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Share mode selection
          if (_supportsRealtimeSharing &&
              widget.contentType != ShareContentType.shoppingList)
            _buildShareModeSelection(),

          // Message input
          _buildMessageInput(),

          // Target selection
          _buildTargetSelection(),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildShareModeSelection() {
    return ShareModeSelection.build(
      context,
      _selectedMode,
      widget.contentType,
      _supportsRealtimeSharing,
      (mode) => setState(() => _selectedMode = mode),
    );
  }

  Widget _buildMessageInput() {
    return ShareMessageInput.build(
      context,
      _messageController,
      widget.initialMessage,
    );
  }

  Widget _buildTargetSelection() {
    return ShareTargetSelectionEnhanced.build(
      context,
      _selectedTab,
      widget.availableFriends ?? [],
      widget.availableGroups ?? [],
      _selectedFriendIds,
      _selectedGroupIds,
      _searchQuery,
      (tab) => setState(() {
        _selectedTab = tab;
        _searchQuery = ''; // Clear search when switching tabs
      }),
      (query) => setState(() => _searchQuery = query),
      (friendId) => setState(() {
        if (_selectedFriendIds.contains(friendId)) {
          _selectedFriendIds.remove(friendId);
        } else {
          _selectedFriendIds.add(friendId);
        }
      }),
      (groupId) => setState(() {
        if (_selectedGroupIds.contains(groupId)) {
          _selectedGroupIds.remove(groupId);
        } else {
          _selectedGroupIds.add(groupId);
        }
      }),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ShareDialogActions.buildSelectionSummary(
          context,
          _selectedFriendIds.length + _selectedGroupIds.length,
          ShareDialogHelpers.getContentTypeName(widget.contentType),
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        ShareDialogActions.buildActionButtons(
          context,
          widget.contentType,
          _selectedMode,
          _supportsRealtimeSharing,
          _selectedFriendIds.isNotEmpty || _selectedGroupIds.isNotEmpty,
          widget.viewModel.isSharing,
          () => Navigator.pop(context),
          _handleShare,
        ),
      ],
    );
  }

  // Share action
  Future<void> _handleShare() async {
    if (_selectedFriendIds.isEmpty && _selectedGroupIds.isEmpty) return;

    try {
      bool shareResult = false;
      final message = _messageController.text.trim();
      final friendIds = _selectedFriendIds.toList();
      final groupIds = _selectedGroupIds.toList();
      final allowCollaboration = _selectedMode == ShareMode.realtime;

      switch (widget.contentType) {
        case ShareContentType.recipe:
          shareResult = await widget.viewModel.shareRecipe(
            recipe: widget.content as Recipe,
            friendUserIds: friendIds,
            groupIds: groupIds,
            message: message.isNotEmpty ? message : null,
            allowCollaboration: allowCollaboration,
          );
          break;
        case ShareContentType.menu:
          shareResult = await widget.viewModel.shareMenu(
            menu: widget.content as Map<String, List<Recipe>>,
            friendUserIds: friendIds,
            groupIds: groupIds,
            message: message.isNotEmpty ? message : null,
            allowCollaboration: allowCollaboration,
          );
          break;
        case ShareContentType.shoppingList:
          shareResult = await widget.viewModel.shareShoppingList(
            shoppingList: widget.content as UnifiedShoppingList,
            friendUserIds: friendIds,
            groupIds: groupIds,
            message: message.isNotEmpty ? message : null,
          );
          break;
      }

      if (shareResult && mounted) {
        final successMessage = ShareDialogHelpers.getSuccessMessage(
          widget.contentType,
          _selectedFriendIds.length + _selectedGroupIds.length,
          _selectedMode,
        );

        // Show success and close dialog
        Navigator.pop(context, true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delning misslyckades: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}