// lib/widgets/messaging/new_conversation_dialog.dart

import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/messaging/create_group_conversation_view.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

/// Styled dialog for creating new conversations
class NewConversationDialog extends StatefulWidget {
  final Function(String conversationId) onConversationCreated;

  const NewConversationDialog({
    super.key,
    required this.onConversationCreated,
  });

  @override
  State<NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<NewConversationDialog> {
  final TextEditingController _searchController = TextEditingController();

  late final UnifiedFriendsService _friendsService;
  late final MessagingService _messagingService;

  List<UserProfile> _friends = [];
  List<UserProfile> _filteredFriends = [];
  final List<String> _selectedFriendIds = [];
  bool _isCreating = false;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _friendsService = ServiceLocator.get<UnifiedFriendsService>();
    _messagingService = ServiceLocator.get<MessagingService>();
    _loadFriends();
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFriends);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      // Get friends from the unified friends service
      final friends = _friendsService.friends;

      if (mounted) {
        setState(() {
          _friends = friends;
          _filteredFriends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredFriends = _friends;
        } else {
          _filteredFriends = _friends.where((friend) {
            return friend.displayName.toLowerCase().contains(query);
          }).toList();
        }
      });
    }
  }

  void _navigateToGroupCreation() {
    // Close current dialog
    Navigator.of(context).pop();

    // Navigate to group creation view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateGroupConversationView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ButleryDialog(
      title: context.l10n.conversationNew,
      scrollable: false,
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Column(
          children: [
            // Quick action button for group creation
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppDimensions.space12),
              child: ActionButtons.outlinedButton(
                context,
                label: context.l10n.conversationCreateGroup,
                icon: ButleryIcons.usersPlus,
                isExpanded: true,
                onPressed: _navigateToGroupCreation,
              ),
            ),

            const ButleryDivider(),
            const SizedBox(height: AppDimensions.space8),

            // Or select friend for direct chat
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.l10n.conversationSelectFriendForDM,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space12),

            _buildSearchField(),
            const SizedBox(height: AppDimensions.space12),

            Expanded(
              child: _buildFriendsList(),
            ),
          ],
        ),
      ),
      actions: [
        const DialogCancelButton(),
        ActionButtons.primaryButton(
          context,
          label: context.l10n.commonCreate,
          onPressed: _selectedFriendIds.isEmpty ? null : _createConversation,
          // Creating keeps the name and draws the plate line (Komponentark
          // v1:372); busy ignores presses rather than disabling.
          isLoading: _isCreating,
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return ButlerySearchBox(
      controller: _searchController,
      hintText: context.l10n.chatSearchFriends,
    );
  }

  /// Friends list with actual friends from the friends service
  /// ✅ FIXED: Integrated with existing friends system
  Widget _buildFriendsList() {
    final cs = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Center(
        child: PlateLineMessage(message: context.l10n.messagingLoadingFriends),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ButleryIcon(
              ButleryIcons.triangleAlert,
              size: AppDimensions.iconSizeXxl,
              color: cs.error,
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              context.l10n.errorGeneric,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space12),
            ButleryTextButton(
              label: context.l10n.commonRetry,
              icon: ButleryIcons.refreshCw,
              onPressed: () {
                setState(() => _hasError = false);
                _loadFriends();
              },
            ),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ButleryIcon(
              ButleryIcons.users,
              size: AppDimensions.iconSizeXxl,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              context.l10n.conversationNoFriendsYet,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Text(
              context.l10n.conversationAddFriendsFirst,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredFriends.isEmpty) {
      return Center(
        child: Text(
          context.l10n.conversationNoFriendsMatch,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = _filteredFriends[index];
        final isSelected = _selectedFriendIds.contains(friend.uid);

        return ButleryCheckboxTile(
          key: ValueKey(friend.uid),
          title: Text(friend.displayName),
          value: isSelected,
          onChanged: (bool selected) {
            if (mounted) {
              setState(() {
                if (selected) {
                  _selectedFriendIds.add(friend.uid);
                } else {
                  _selectedFriendIds.remove(friend.uid);
                }
              });
            }
          },
          secondary: AvatarCircle(
            imageUrl: friend.avatarUrl,
            displayName: friend.displayName,
          ),
        );
      },
    );
  }

  /// Create conversation with selected friends
  /// ✅ FIXED: Implemented actual conversation creation with friends system integration
  Future<void> _createConversation() async {
    if (_selectedFriendIds.isEmpty || _isCreating) return;

    if (mounted) {
      setState(() {
        _isCreating = true;
      });
    }

    try {
      String? conversationId;

      if (_selectedFriendIds.length == 1) {
        // Create direct conversation with single friend
        final friend = _friends.firstWhere(
          (f) => f.uid == _selectedFriendIds.first,
        );
        conversationId = await _messagingService.startDirectConversation(
          otherUserId: friend.uid,
          otherUserDisplayName: friend.displayName,
        );
      } else {
        // Create group conversation with multiple friends
        final selectedFriends = _friends
            .where((f) => _selectedFriendIds.contains(f.uid))
            .toList();
        final participantIds = _selectedFriendIds.toList();

        // Build participant maps for group conversation
        final participantDisplayNames = <String, String>{};
        final participantAvatarUrls = <String, String?>{};

        for (final friend in selectedFriends) {
          participantDisplayNames[friend.uid] = friend.displayName;
          participantAvatarUrls[friend.uid] = friend.avatarUrl;
        }

        conversationId = await _messagingService.createGroupConversation(
          participantIds: participantIds,
          participantDisplayNames: participantDisplayNames,
          participantAvatarUrls: participantAvatarUrls,
          title: context.l10n.conversationGroupChatWith(
            selectedFriends.map((f) => f.displayName).join(', '),
          ),
        );
      }

      if (conversationId.isNotEmpty) {
        widget.onConversationCreated(conversationId);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Never the exception's own text (content-style-guide.md:95).
      AppLogger.error('Could not create conversation', e);
      if (mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.errorCouldNotStartConversation,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}
