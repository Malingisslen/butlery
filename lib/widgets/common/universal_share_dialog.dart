// lib/widgets/universal_share_dialog.dart - FACADE PATTERN

import 'package:flutter/material.dart';

import 'package:butlery/core/utils/logger.dart';
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
  // För bulk sharing: List<dynamic> med flera items
  final dynamic content;
  final ShareContentType contentType;
  final String? initialMessage;
  final List<UserProfile>? availableFriends;
  final List<FriendCategory>? availableGroups;
  final UniversalShareDialogViewModel viewModel;
  final bool isBulkSharing; // Indikerar om detta är bulk sharing
  final String? menuName; // Optional menu name for menu sharing

  const UniversalShareDialog({
    super.key,
    required this.content,
    required this.contentType,
    required this.viewModel,
    this.initialMessage,
    this.availableFriends,
    this.availableGroups,
    this.isBulkSharing = false,
    this.menuName,
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
    String? menuName,
    String? initialMessage,
    List<UserProfile>? availableFriends,
    List<FriendCategory>? availableGroups,
  }) {
    return UniversalShareDialog(
      content: menu,
      contentType: ShareContentType.menu,
      viewModel: viewModel,
      menuName: menuName,
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

  /// Factory constructor för bulk sharing av flera items
  factory UniversalShareDialog.bulkShare({
    required List<dynamic> contentItems,
    required ShareContentType
        primaryContentType, // Typ för majoriteten av items
    required UniversalShareDialogViewModel viewModel,
    String? initialMessage,
    List<UserProfile>? availableFriends,
    List<FriendCategory>? availableGroups,
  }) {
    return UniversalShareDialog(
      content: contentItems,
      contentType: primaryContentType,
      viewModel: viewModel,
      initialMessage: initialMessage,
      availableFriends: availableFriends,
      availableGroups: availableGroups,
      isBulkSharing: true,
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
  late ShareMode _selectedMode;
  ShareTargetType _selectedTab = ShareTargetType.friends;
  final Set<String> _selectedFriendIds = {};
  final Set<String> _selectedGroupIds = {};
  String _searchQuery = '';
  bool allowCollaboration = false;

  @override
  void initState() {
    super.initState();

    // Initiera controllers
    _messageController =
        TextEditingController(text: widget.initialMessage ?? '');

    // Bestäm om realtidsdelning stöds
    _supportsRealtimeSharing =
        ShareDialogHelpers.supportsRealtimeSharing(widget.contentType);

    // Set default share mode - collaborative for shopping lists, static copy for others
    _selectedMode = (widget.contentType == ShareContentType.shoppingList &&
            _supportsRealtimeSharing)
        ? ShareMode.realtime
        : ShareMode.staticCopy;

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
                color: AppColors.textDark.withValues(alpha: AppDimensions.opacityVeryLight),
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
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
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
          if (_supportsRealtimeSharing) _buildShareModeSelection(),

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
    // PHASE 2: Get existing collaborators if this is a shopping list
    Set<String>? existingCollaborators;
    if (widget.contentType == ShareContentType.shoppingList &&
        widget.content is UnifiedShoppingList) {
      final shoppingList = widget.content as UnifiedShoppingList;
      existingCollaborators =
          shoppingList.collaborators.toSet(); // Get current collaborators
    }

    return ShareTargetSelectionEnhanced.build(
      context,
      _selectedTab,
      widget.availableFriends ?? [],
      widget.availableGroups ?? [],
      _selectedFriendIds,
      _selectedGroupIds,
      _searchQuery,
      (tab) {
        if (mounted) {
          setState(() {
            _selectedTab = tab;
            _searchQuery = ''; // Clear search when switching tabs
          });
        }
      },
      (query) => setState(() => _searchQuery = query),
      (friendId) {
        if (mounted) {
          setState(() {
            if (_selectedFriendIds.contains(friendId)) {
              _selectedFriendIds.remove(friendId);
            } else {
              _selectedFriendIds.add(friendId);
            }
          });
        }
      },
      (groupId) {
        if (mounted) {
          setState(() {
            if (_selectedGroupIds.contains(groupId)) {
              _selectedGroupIds.remove(groupId);
            } else {
              _selectedGroupIds.add(groupId);
            }
          });
        }
      },
      existingCollaborators:
          existingCollaborators, // PHASE 2: Pass existing collaborators info
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
    AppLogger.info('🔍🔍🔍 DEBUG DIALOG: _handleShare() CALLED');
    AppLogger.info('🔍 DEBUG: _selectedFriendIds = $_selectedFriendIds');
    AppLogger.info('🔍 DEBUG: _selectedGroupIds = $_selectedGroupIds');

    if (_selectedFriendIds.isEmpty && _selectedGroupIds.isEmpty) {
      AppLogger.warning('🔍 DEBUG: Early return - no selections!');
      return;
    }

    try {
      AppLogger.info('🔍 DEBUG: Proceeding with share...');
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
            menuName: widget.menuName, // Pass user-provided menu name
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
            shareMode: _selectedMode,
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
      } else if (widget.viewModel.hasError && mounted) {
        // PHASE 2: Show specific validation error from ViewModel
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.viewModel.errorMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(
                seconds: 4), // Longer duration for validation messages
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
