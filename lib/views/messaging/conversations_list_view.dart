// lib/views/messaging/conversations_list_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/views/messaging/conversations_list/conversation_actions.dart';
import 'package:butlery/views/messaging/conversations_list/conversation_row.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/loading/loading_widgets.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';

/// Conversations list view showing all user's messaging conversations.
/// Delegates all state management to ConversationsViewModel.
class ConversationsListView extends StatefulWidget {
  const ConversationsListView({super.key});

  @override
  State<ConversationsListView> createState() => _ConversationsListViewState();
}

class _ConversationsListViewState extends State<ConversationsListView> {
  bool _archivedExpanded = false;

  void _navigateToChat(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatViewFacade(
          conversationId: conversation.id,
          conversation: conversation,
          backTo: context.l10n.messagingTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final margin = ButleryTopBar.sideMargin(context);

    return ButleryPage.undersida(
      title: l10n.messagingTitle,
      backTo: l10n.moreTitle,
      actions: [
        AppIconButton(
          onPressed: () => showNewMessageSheet(context),
          icon: ButleryIcons.pencil,
          semanticLabel: l10n.messagesNewMessage,
        ),
      ],
      body: FocusTraversalGroup(
        child: Column(
          children: [
            LayoutComponents.offlineIndicator(),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                margin,
                AppDimensions.space16,
                margin,
                AppDimensions.space4,
              ),
              child: ButlerySearchBox(
                hintText: l10n.messagesSearchHint,
                onChanged: (query) => context
                    .read<ConversationsViewModel>()
                    .updateSearchQuery(query),
              ),
            ),
            Expanded(child: _buildConversationsList(margin)),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(double margin) {
    final l10n = context.l10n;

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
            icon: ButleryIcons.triangleAlert,
            // The VM's error names what failed (errorCouldNotLoad), so it is
            // the title; no causeless errorGeneric (content-style-guide.md:95).
            title: vm.conversationsError!,
            customAction: ActionButtons.primaryButton(
              context,
              label: l10n.commonRetry,
              onPressed: vm.refresh,
            ),
          );
        }

        if (!vm.hasConversations) {
          // No button of its own: the pencil in the top bar is the one place
          // a new message starts.
          if (vm.searchQuery.isNotEmpty) {
            return EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noSearchResults,
              icon: ButleryIcons.searchOff,
              title: l10n.messagingNoConversationsFound,
              subtitle: l10n.messagingTryAnotherSearch,
            );
          }
          return EmptyStates.buildEmptyState(
            context,
            variant: EmptyStateVariant.generic,
            icon: ButleryIcons.messageSquare,
            title: l10n.messagingNoConversationsYet,
            subtitle: l10n.messagingStartFirstConversation,
          );
        }

        final pinned = vm.pinnedConversations;
        final regular = vm.regularConversations;
        final archived = vm.archivedConversations;

        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView(
            padding: EdgeInsetsDirectional.only(
              start: margin,
              end: margin,
              bottom: AppDimensions.space24,
            ),
            children: [
              if (pinned.isNotEmpty)
                ButleryListSection(
                  title: l10n.messagingPinned,
                  rows: [for (final c in pinned) _row(vm, c)],
                ),
              if (regular.isNotEmpty)
                ButleryListSection(
                  title: l10n.filterAll,
                  rows: [for (final c in regular) _row(vm, c)],
                ),
              if (archived.isNotEmpty) ...[
                ButleryListSection(
                  rows: [
                    ButleryListRow(
                      label: l10n.messagesArchivedRow,
                      value: '${archived.length}',
                      leading: ButleryIcons.archive,
                      onTap: () => setState(
                        () => _archivedExpanded = !_archivedExpanded,
                      ),
                    ),
                  ],
                ),
                if (_archivedExpanded)
                  ButleryListSection(
                    rows: [for (final c in archived) _row(vm, c)],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(ConversationsViewModel vm, Conversation conversation) {
    return ConversationRow(
      key: ValueKey(conversation.id),
      conversation: conversation,
      currentUserId: vm.currentUserId.orEmpty(),
      onOpen: () => _navigateToChat(conversation),
      onActions: () => showConversationActions(context, vm, conversation),
      onPin: () => vm.togglePin(conversation.id),
      onArchive: () => vm.toggleArchive(conversation.id),
    );
  }
}
