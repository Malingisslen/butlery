// lib/views/messaging/conversations_list_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/widgets/messaging/conversation_list_item.dart';
import 'package:butlery/widgets/messaging/new_conversation_dialog.dart';
import 'package:butlery/widgets/messaging/messaging_ui_components.dart';
import 'package:butlery/widgets/common/loading/loading_widgets.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/search_filter/search_input_widget.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/models/user_profile.dart';

/// Conversations list view showing all user's messaging conversations
/// Provides comprehensive conversation management including:
/// - Real-time conversation list with previews
/// - Search functionality for conversations
/// - Unread message indicators
/// - Pull-to-refresh functionality
/// - New conversation creation
/// - Swipe actions for archive/delete
/// - Integration with existing social features
class ConversationsListView extends StatefulWidget {
  const ConversationsListView({super.key});

  @override
  State<ConversationsListView> createState() => _ConversationsListViewState();
}

class _ConversationsListViewState extends State<ConversationsListView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final MessagingService _messagingService;
  late final AuthService _authService;

  String? _currentUserId;
  List<Conversation> _allConversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _archivedExpanded = false;

  @override
  void initState() {
    super.initState();
    _messagingService = ServiceLocator.get<MessagingService>();
    _authService = ServiceLocator.get<AuthService>();
    _currentUserId = _authService.currentUserId;

    _setupListeners();
    _loadConversations();
  }

  void _setupListeners() {
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _filterConversations();
      });
    }
  }

  void _loadConversations() {
    if (_currentUserId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    _messagingService.getMyConversations().listen((conversations) {
      if (mounted) {
        setState(() {
          _allConversations = conversations;
          _filterConversations();
          _isLoading = false;
        });
      }
    });
  }

  void _filterConversations() {
    if (_searchQuery.isEmpty) {
      _filteredConversations = List.from(_allConversations);
    } else {
      _filteredConversations = _allConversations.where((conversation) {
        final title =
            conversation.getDisplayTitle(_currentUserId ?? '').toLowerCase();
        final lastMessageContent =
            conversation.lastMessage?.content.toLowerCase() ?? '';

        return title.contains(_searchQuery) ||
            lastMessageContent.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _refreshConversations() async {
    // The stream listener will automatically update the UI
    // This is just for the RefreshIndicator feedback
    await Future.delayed(AppDimensions.animationDurationLong);
  }

  void _navigateToChat(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatViewFacade(
          conversationId: conversation.id,
          conversation: conversation,
        ),
      ),
    );
  }

  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => NewConversationDialog(
        onConversationCreated: (conversationId) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ChatViewFacade(conversationId: conversationId),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutComponents.simpleLayout(
      title: l10n.messagingTitle,
      actions: [
        IconButton(
          onPressed: _showNewConversationDialog,
          icon: const Icon(Icons.add),
          tooltip: l10n.messagingNewConversation,
        ),
      ],
      body: SafeArea(
        // Responsive: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: Column(
              children: [
                // Search bar
                _buildSearchBar(),

                // Conversations list
                Expanded(
                  child: _buildConversationsList(),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButtonWidget.message(
        onPressed: _showNewConversationDialog,
      ),
    );
  }

  Widget _buildSearchBar() {
    final l10n = context.l10n;

    return SearchBarContainer(
      child: SearchInputWidget(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: l10n.messagingSearchConversations,
        onClear: () {
          _searchController.clear();
        },
      ),
    );
  }

  Widget _buildConversationsList() {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return LoadingWidgets.loadingOverlay(
        isLoading: true,
        loadingMessage: l10n.messagingLoadingConversations,
      );
    }

    if (_filteredConversations.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return EmptyStates.buildEmptyState(
          context,
          variant: EmptyStateVariant.noSearchResults,
          icon: Icons.search_off,
          title: l10n.messagingNoConversationsFound,
          subtitle: l10n.messagingTryAnotherSearch,
        );
      } else {
        return EmptyStates.buildEmptyState(
          context,
          variant: EmptyStateVariant.generic,
          icon: Icons.chat_bubble_outline,
          title: l10n.messagingNoConversationsYet,
          subtitle: l10n.messagingStartFirstConversation,
          customAction: StyledButton.primary(
            text: l10n.messagingNewConversation,
            onPressed: _showNewConversationDialog,
          ),
        );
      }
    }

    // Split into pinned, regular, and archived sections
    final pinned = _filteredConversations
        .where((c) => c.isPinned && !c.isArchived)
        .toList();
    final regular = _filteredConversations
        .where((c) => !c.isPinned && !c.isArchived)
        .toList();
    final archived = _filteredConversations.where((c) => c.isArchived).toList();

    // Build a flat list of widgets for indexed access by ListView.builder
    final items = <Widget>[
      if (pinned.isNotEmpty) ...[
        _buildSectionHeader(
          icon: Icons.push_pin,
          label: context.l10n.messagingPinned,
        ),
        ...pinned.map((c) => _buildConversationItem(c)),
        Divider(height: 1, color: cs.outlineVariant),
      ],
      ...regular.map((c) => _buildConversationItem(c)),
      if (archived.isNotEmpty) _buildArchivedSection(archived),
    ];

    return RefreshIndicator(
      onRefresh: _refreshConversations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSize14,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedSection(List<Conversation> archived) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Divider(height: 1, color: cs.outlineVariant),
        InkWell(
          onTap: () => setState(() => _archivedExpanded = !_archivedExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
              vertical: AppDimensions.paddingM,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.archive,
                  size: AppDimensions.iconSizeM,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Text(
                    context.l10n.messagingArchivedCount(archived.length),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _archivedExpanded ? Icons.expand_less : Icons.expand_more,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_archivedExpanded)
          ...archived.map((c) => _buildConversationItem(c)),
      ],
    );
  }

  Widget _buildConversationItem(Conversation conversation) {
    return Column(
      children: [
        ConversationListItem(
          key: ValueKey(conversation.id),
          conversation: conversation,
          currentUserId: _currentUserId ?? '',
          onTap: () => _navigateToChat(conversation),
          onLongPress: () => _showConversationActions(conversation),
          onPin: () => _togglePin(conversation),
          onArchive: () => _toggleArchive(conversation),
        ),
        Divider(
          height: 1,
          color: Theme.of(context).dividerColor,
          indent: AppDimensions.spacingHuge,
        ),
      ],
    );
  }

  Future<void> _togglePin(Conversation conversation) async {
    if (conversation.isPinned) {
      await _messagingService.unpinConversation(conversation.id);
    } else {
      await _messagingService.pinConversation(conversation.id);
    }
  }

  Future<void> _toggleArchive(Conversation conversation) async {
    if (conversation.isArchived) {
      await _messagingService.unarchiveConversation(conversation.id);
    } else {
      await _messagingService.archiveConversation(conversation.id);
    }
  }

  void _showConversationActions(Conversation conversation) {
    final l10n = context.l10n;

    StyledModalBottomSheet.show(
      context: context,
      child: ModalContentContainer(
        children: [
          ModalHeaderText(conversation.getDisplayTitle(_currentUserId ?? '')),
          ListTile(
            leading: Icon(
              conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            ),
            title: Text(conversation.isPinned
                ? context.l10n.messagingUnpin
                : context.l10n.messagingPin),
            onTap: () {
              Navigator.pop(context);
              _togglePin(conversation);
            },
          ),
          ListTile(
            leading: Icon(
              conversation.isArchived ? Icons.unarchive : Icons.archive,
            ),
            title: Text(
              conversation.isArchived
                  ? context.l10n.messagingUnarchive
                  : context.l10n.messagingArchive,
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleArchive(conversation);
            },
          ),
          ListTile(
            leading: const Icon(Icons.mark_chat_read),
            title: Text(l10n.messagingMarkAsRead),
            onTap: () {
              Navigator.pop(context);
              _markAsRead(conversation);
            },
          ),
          if (conversation.isGroup) ...[
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.messagingGroupInfo),
              onTap: () {
                Navigator.pop(context);
                _navigateToGroupInfo(context, conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: Text(l10n.messagingLeaveGroup),
              onTap: () {
                Navigator.pop(context);
                _leaveGroup(conversation);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(l10n.messagingViewProfile),
              onTap: () {
                Navigator.pop(context);
                _navigateToUserProfile(context, conversation);
              },
            ),
          ],
          ErrorListTile(
            icon: Icons.delete_outline,
            title: l10n.messagingDeleteConversation,
            onTap: () {
              Navigator.pop(context);
              _deleteConversation(conversation);
            },
          ),
        ],
      ),
    );
  }

  void _markAsRead(Conversation conversation) {
    _messagingService.markConversationAsRead(conversation.id);
  }

  void _leaveGroup(Conversation conversation) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.messagingLeaveGroup),
        content:
            Text(l10n.messagingConfirmLeaveGroup(conversation.title ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _messagingService.removeParticipantFromGroup(
                  conversationId: conversation.id,
                  participantId: _currentUserId!,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.messagingLeftGroup)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content:
                          Text(l10n.messagingCouldNotLeaveGroup(e.toString())),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: ErrorText(l10n.messagingLeave),
          ),
        ],
      ),
    );
  }

  void _deleteConversation(Conversation conversation) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.messagingDeleteConversation),
        content: Text(l10n.messagingDeleteConversationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _performConversationDeletion(conversation);
            },
            child: ErrorText(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _navigateToGroupInfo(BuildContext context, Conversation conversation) {
    // Navigate to group detail using existing routes
    Navigator.pushNamed(
      context,
      '/group-detail',
      arguments: {'groupId': conversation.id},
    );
  }

  Future<void> _navigateToUserProfile(
      BuildContext context, Conversation conversation) async {
    final l10n = context.l10n;

    // For direct conversations, get the other participant's profile
    try {
      // Get the other participant's ID (not the current user)
      final otherParticipantId = conversation.participantIds.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => conversation.participantIds.first);

      // Try to get the UserProfile from friends service
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      final friends = friendsService.friends;

      // Find the friend profile
      final UserProfile friendProfile = friends.firstWhere(
        (friend) => friend.uid == otherParticipantId,
        orElse: () => throw Exception('Friend not found'),
      );

      // Navigate to friend profile with UserProfile object
      Navigator.pushNamed(
        context,
        Routes.friendProfile,
        arguments: friendProfile,
      );
    } catch (e) {
      // If friend not found or error occurred, show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.messagingCouldNotShowProfile(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _performConversationDeletion(Conversation conversation) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Get messaging service from DI for conversation deletion
      final messagingService = ServiceLocator.get<MessagingService>();

      // Attempt to delete the conversation
      await messagingService.deleteConversation(conversation.id);

      // Refresh the conversations list after successful deletion
      await _refreshConversations();

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                l10n.messagingConversationDeleted(conversation.title ?? '')),
            backgroundColor: context.butleryColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content:
                Text(l10n.messagingCouldNotDeleteConversation(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
