// lib/views/social/friend_requests/friend_request_builders.dart

import 'package:flutter/material.dart';

// Theme
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';

// ViewModels
import 'package:butlery/viewmodels/friends_viewmodel.dart';

// Widgets
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/state_widget.dart';

// Local
import 'package:butlery/views/social/friend_requests/friend_request_card.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Builds the error line of the friend requests view
class FriendRequestsHeaderBuilder {
  static Widget buildErrorDisplay(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    if (!viewModel.hasError) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space12),
      margin: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintDanger,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(ButleryIcons.triangleAlert, color: cs.onErrorContainer),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              viewModel.error!,
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: viewModel.clearError,
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }
}

/// The one list of the page: the incoming requests, then the sent ones, each
/// under its own overline with a count.
class FriendRequestsListBuilder {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedIncoming,
    Set<String> selectedSent, {
    required bool selecting,
    required void Function(String id, bool selected) onIncomingChanged,
    required void Function(String id, bool selected) onSentChanged,
    required VoidCallback onRefreshed,
  }) {
    final incoming = viewModel.incomingRequests;
    final sent = viewModel.sentRequests;

    if (viewModel.isLoading && incoming.isEmpty && sent.isEmpty) {
      return StateWidget.loading(message: context.l10n.socialLoadingRequests);
    }

    if (incoming.isEmpty && sent.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.socialNoFriendRequests,
        subtitle: context.l10n.socialNoFriendRequestsDescription,
        icon: ButleryIcons.inbox,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refresh();
        onRefreshed();
      },
      child: ListView(
        padding: ButleryPageBody.margin(context, bottom: AppDimensions.space32),
        children: [
          if (incoming.isNotEmpty)
            ButleryListSection(
              title: context.l10n.socialRequestsIncomingSection(
                incoming.length,
              ),
              rows: [
                for (final request in incoming)
                  KeyedSubtree(
                    key: ValueKey(request.id),
                    child: FriendRequestCard.buildIncomingCard(
                      context,
                      request,
                      viewModel,
                      selectedIncoming.contains(request.id),
                      (selected) => onIncomingChanged(request.id, selected),
                      selecting: selecting,
                    ),
                  ),
              ],
            ),
          if (sent.isNotEmpty)
            ButleryListSection(
              title: context.l10n.socialRequestsSentSection(sent.length),
              rows: [
                for (final request in sent)
                  KeyedSubtree(
                    key: ValueKey(request.id),
                    child: FriendRequestCard.buildSentCard(
                      context,
                      request,
                      viewModel,
                      selectedSent.contains(request.id),
                      (selected) => onSentChanged(request.id, selected),
                      selecting: selecting,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
