// lib/views/messaging/conversations_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
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
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:collection/collection.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Conversations list view showing all user's messaging conversations.
/// Delegates all state management to ConversationsViewModel.
class ConversationsListView extends StatefulWidget {
  const ConversationsListView({super.key});

  @override
  State<ConversationsListView> createState() => _ConversationsListViewState();
}

class _ConversationsListViewState extends State<ConversationsListView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _archivedExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final vm = context.read<ConversationsViewModel>();
    vm.updateSearchQuery(_searchController.text);
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
            child: FocusTraversalGroup(
              child: Column(
                children: [
                  LayoutComponents.offlineIndicator(),
                  _buildSearchBar(),
                  Expanded(
                    child: _buildConversationsList(),
                  ),
                ],
              ),
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

    return Consumer<ConversationsViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoadingConversations) {
          return LoadingWidgets.loadingOverlay(
            isLoading: true,
            loadingMessage: l10n.messagingLoadingConversations,
          );
        }

        if (vm.conversationsError != null) {
          return EmptyStates.buildEmptyState(
            context,
            variant: EmptyStateVariant.generic,
            icon: Icons.error_outline,
            title: l10n.errorGeneric,
            subtitle: vm.conversationsError!,
            customAction: StyledButton.primary(
              text: l10n.commonRetry,
              onPressed: vm.refresh,
            ),
          );
        }

        if (!vm.hasConversations) {
          if (vm.searchQuery.isNotEmpty) {
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

        final pinned = vm.pinnedConversations;
        final regular = vm.regularConversations;
        final archived = vm.archivedConversations;

        final items = <Widget>[
          if (pinned.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.push_pin,
              label: context.l10n.messagingPinned,
            ),
            ...pinned.map((c) => _buildConversationItem(vm, c)),
            Divider(height: 1, color: cs.outlineVariant),
          ],
          ...regular.map((c) => _buildConversationItem(vm, c)),
          if (archived.isNotEmpty) _buildArchivedSection(vm, archived),
        ];

        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
            itemCount: items.length,
            itemBuilder: (context, index) => items[index],
          ),
        );
      },
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
      child: Semantics(
        header: true,
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
      ),
    );
  }

  Widget _buildArchivedSection(
      ConversationsViewModel vm, List<Conversation> archived) {
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
          ...archived.map((c) => _buildConversationItem(vm, c)),
      ],
    );
  }

  Widget _buildConversationItem(
      ConversationsViewModel vm, Conversation conversation) {
    return Column(
      children: [
        ConversationListItem(
          key: ValueKey(conversation.id),
          conversation: conversation,
          currentUserId: vm.currentUserId ?? '',
          onTap: () => _navigateToChat(conversation),
          onLongPress: () => _showConversationActions(vm, conversation),
          onPin: () => vm.togglePin(conversation.id),
          onArchive: () => vm.toggleArchive(conversation.id),
        ),
        Divider(
          height: 1,
          color: Theme.of(context).dividerColor,
          indent: AppDimensions.spacingHuge,
        ),
      ],
    );
  }

  void _showConversationActions(
      ConversationsViewModel vm, Conversation conversation) {
    final l10n = context.l10n;

    StyledModalBottomSheet.show(
      context: context,
      child: ModalContentContainer(
        children: [
          ModalHeaderText(conversation.getDisplayTitle(vm.currentUserId ?? '')),
          ListTile(
            leading: Icon(
              conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            ),
            title: Text(conversation.isPinned
                ? context.l10n.messagingUnpin
                : context.l10n.messagingPin),
            onTap: () {
              Navigator.pop(context);
              vm.togglePin(conversation.id);
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
              vm.toggleArchive(conversation.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.mark_chat_read),
            title: Text(l10n.messagingMarkAsRead),
            onTap: () {
              Navigator.pop(context);
              vm.markConversationAsRead(conversation.id);
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
                _leaveGroup(vm, conversation);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(l10n.messagingViewProfile),
              onTap: () {
                Navigator.pop(context);
                _navigateToUserProfile(context, vm, conversation);
              },
            ),
          ],
          ErrorListTile(
            icon: Icons.delete_outline,
            title: l10n.messagingDeleteConversation,
            onTap: () {
              Navigator.pop(context);
              _deleteConversation(vm, conversation);
            },
          ),
        ],
      ),
    );
  }

  void _leaveGroup(ConversationsViewModel vm, Conversation conversation) {
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
              final success = await vm.leaveGroup(conversation.id);
              if (mounted) {
                if (success) {
                  SnackBarUtils.showSuccess(context, l10n.messagingLeftGroup);
                } else {
                  SnackBarUtils.showError(
                      context, l10n.messagingCouldNotLeaveGroup(''));
                }
              }
            },
            child: ErrorText(l10n.messagingLeave),
          ),
        ],
      ),
    );
  }

  void _deleteConversation(
      ConversationsViewModel vm, Conversation conversation) {
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
              final success = await vm.deleteConversation(conversation.id);
              if (mounted) {
                if (success) {
                  SnackBarUtils.showSuccess(
                      context,
                      l10n.messagingConversationDeleted(
                          conversation.title ?? ''));
                } else {
                  SnackBarUtils.showError(
                      context, l10n.messagingCouldNotDeleteConversation(''));
                }
              }
            },
            child: ErrorText(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _navigateToGroupInfo(BuildContext context, Conversation conversation) {
    Navigator.pushNamed(
      context,
      '/group-detail',
      arguments: {'groupId': conversation.id},
    );
  }

  Future<void> _navigateToUserProfile(BuildContext context,
      ConversationsViewModel vm, Conversation conversation) async {
    final l10n = context.l10n;

    try {
      final otherParticipantId = conversation.participantIds.firstWhere(
          (id) => id != vm.currentUserId,
          orElse: () => conversation.participantIds.firstOrNull ?? '');

      final friendsService = ServiceLocator.get<UnifiedFriendsService>();

      // Try friends list first, fall back to UserService for non-friend DM partners
      final profile = friendsService.friends.firstWhereOrNull(
            (f) => f.uid == otherParticipantId,
          ) ??
          await ServiceLocator.get<UserService>()
              .getUserProfile(otherParticipantId);

      if (profile == null) throw Exception('Profile not found');

      if (!context.mounted) return;

      Navigator.pushNamed(
        context,
        Routes.friendProfile,
        arguments: profile,
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(
            context,
            l10n.messagingCouldNotShowProfile(
              SnackBarUtils.userFriendlyMessage(context, e),
            ));
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
