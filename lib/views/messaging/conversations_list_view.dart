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
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/models/user_profile.dart';

/// Conversations list view showing all user's messaging conversations
///
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
    await Future.delayed(const Duration(milliseconds: 500));
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
    return LayoutComponents.simpleLayout(
      title: 'Meddelanden',
      actions: [
        IconButton(
          onPressed: _showNewConversationDialog,
          icon: const Icon(Icons.add),
          tooltip: 'Ny konversation',
        ),
      ],
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
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
    return SearchBarContainer(
      child: SearchInputWidget(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: 'Sök konversationer...',
        onClear: () {
          _searchController.clear();
        },
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_isLoading) {
      return LoadingWidgets.loadingOverlay(
        isLoading: true,
        loadingMessage: 'Laddar konversationer...',
      );
    }

    if (_filteredConversations.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return EmptyStates.buildEmptyState(
          context,
          variant: EmptyStateVariant.noSearchResults,
          icon: Icons.search_off,
          title: 'Inga konversationer hittades',
          subtitle: 'Försök med ett annat sökord',
        );
      } else {
        return EmptyStates.buildEmptyState(
          context,
          variant: EmptyStateVariant.generic,
          icon: Icons.chat_bubble_outline,
          title: 'Inga konversationer än',
          subtitle:
              'Starta din första konversation genom att trycka på meddelande-knappen',
          customAction: StyledButton.primary(
            text: 'Ny konversation',
            onPressed: _showNewConversationDialog,
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: _refreshConversations,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        itemCount: _filteredConversations.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Theme.of(context).dividerColor,
          indent: AppDimensions.spacingHuge, // Account for avatar width
        ),
        itemBuilder: (context, index) {
          final conversation = _filteredConversations[index];

          return ConversationListItem(
            key: ValueKey(conversation.id),
            conversation: conversation,
            currentUserId: _currentUserId ?? '',
            onTap: () => _navigateToChat(conversation),
            onLongPress: () => _showConversationActions(conversation),
          );
        },
      ),
    );
  }

  void _showConversationActions(Conversation conversation) {
    StyledModalBottomSheet.show(
      context: context,
      child: ModalContentContainer(
        children: [
          ModalHeaderText(conversation.getDisplayTitle(_currentUserId ?? '')),
          ListTile(
            leading: const Icon(Icons.mark_chat_read),
            title: const Text('Markera som läst'),
            onTap: () {
              Navigator.pop(context);
              _markAsRead(conversation);
            },
          ),
          if (conversation.isGroup) ...[
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Grupinformation'),
              onTap: () {
                Navigator.pop(context);
                _navigateToGroupInfo(context, conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Lämna grupp'),
              onTap: () {
                Navigator.pop(context);
                _leaveGroup(conversation);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Visa profil'),
              onTap: () {
                Navigator.pop(context);
                _navigateToUserProfile(context, conversation);
              },
            ),
          ],
          ErrorListTile(
            icon: Icons.delete_outline,
            title: 'Radera konversation',
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lämna grupp'),
        content:
            Text('Är du säker på att du vill lämna "${conversation.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _messagingService.removeParticipantFromGroup(
                  conversationId: conversation.id,
                  participantId: _currentUserId!,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Du har lämnat gruppen')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Kunde inte lämna gruppen: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const ErrorText('Lämna'),
          ),
        ],
      ),
    );
  }

  void _deleteConversation(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radera konversation'),
        content: const Text(
            'Är du säker på att du vill radera denna konversation? Alla meddelanden kommer att försvinna.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performConversationDeletion(conversation);
            },
            child: const ErrorText('Radera'),
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
            content: Text('Kunde inte visa profil: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _performConversationDeletion(Conversation conversation) async {
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
            content: Text('Konversation "${conversation.title}" raderad'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Kunde inte radera konversation: $e'),
            backgroundColor: AppColors.error,
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
