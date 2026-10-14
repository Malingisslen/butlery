/// Feed tab — shows social activity from friends (CookSnaps, shares).
// lib/views/social/friends_list/feed_tab.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/widgets/recipe/cook_snap_photo_carousel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// Activity feed tab in the friends view.
class FeedTab {
  /// BUT-981: [hasFriends] differentiates the two empty-state cases. When the
  /// user has no friends yet, we show a "find friends" CTA that invokes
  /// [onAddFriendsCta] (typically a tab-controller switch to the friends tab).
  /// When the user has friends but no activity yet, we keep the generic "quiet
  /// so far" copy with no CTA.
  static Widget build(
    BuildContext context,
    ActivityFeedViewModel viewModel, {
    bool hasFriends = true,
    VoidCallback? onAddFriendsCta,
  }) {
    final initialsByActor = _initialsByActor(viewModel.events);
    return LoadingStateBuilder<List<ActivityEvent>>(
      isLoading: viewModel.isLoading,
      // A failed refresh keeps the list; it is shown above the filters.
      error: viewModel.events.isEmpty ? viewModel.error : null,
      data: viewModel.events.isEmpty ? null : viewModel.filteredEvents,
      // A filter that matches nothing is not an empty feed: the chips stay.
      isDataEmpty: (_) => false,
      loadingMessage: context.l10n.loadingFeed,
      emptyTitle: hasFriends
          ? context.l10n.feedEmpty
          : context.l10n.feedEmptyNoFriendsTitle,
      emptySubtitle: hasFriends
          ? context.l10n.feedEmptyDescription
          : context.l10n.feedEmptyNoFriendsSubtitle,
      emptyActionLabel: hasFriends ? null : context.l10n.feedEmptyNoFriendsCta,
      onEmptyAction: hasFriends ? null : onAddFriendsCta,
      emptyIcon: ButleryIcons.users,
      builder: (context, events) => Column(
        children: [
          if (viewModel.error != null)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.space16),
              child: InlineError(
                what: viewModel.error!,
                actionLabel: context.l10n.commonRetry,
                onAction: viewModel.refresh,
              ),
            ),
          _buildFilterChips(context, viewModel),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.feedFilterNoMatch,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: viewModel.refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppDimensions.space8),
                      itemCount: events.length + (viewModel.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.space4),
                      itemBuilder: (context, index) {
                        if (index >= events.length) {
                          return _buildTail(context, viewModel);
                        }

                        final event = events[index];
                        final showDateHeader =
                            index == 0 ||
                            !_isSameDay(
                              events[index - 1].createdAt,
                              event.createdAt,
                            );

                        return AnimatedListItem(
                          key: ValueKey(event.id),
                          index: index,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDateHeader)
                                _buildDateHeader(context, event.createdAt),
                              _buildActivityCard(
                                context,
                                event,
                                initialsByActor,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// The row after the last event: the next page loading, a retry when it
  /// failed, or the trigger that starts it.
  static Widget _buildTail(
    BuildContext context,
    ActivityFeedViewModel viewModel,
  ) {
    if (viewModel.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          children: [
            Text(
              viewModel.loadMoreError!,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: viewModel.loadMore,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (!viewModel.isLoadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) viewModel.loadMore();
      });
    }
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Center(
        child: PlateLineMessage(message: context.l10n.loadingMoreActivity),
      ),
    );
  }

  static Widget _buildFilterChips(
    BuildContext context,
    ActivityFeedViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      child: Row(
        children: [
          _filterChip(
            context,
            context.l10n.feedFilterAll,
            viewModel.filter == null,
            () => viewModel.setFilter(null),
          ),
          const SizedBox(width: AppDimensions.space8),
          _filterChip(
            context,
            context.l10n.feedFilterCooked,
            viewModel.filter == ActivityEventType.cooked,
            () => viewModel.setFilter(ActivityEventType.cooked),
          ),
          const SizedBox(width: AppDimensions.space8),
          _filterChip(
            context,
            context.l10n.feedFilterShared,
            viewModel.filter == ActivityEventType.shared,
            () => viewModel.setFilter(ActivityEventType.shared),
          ),
        ],
      ),
    );
  }

  static Widget _filterChip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      hint: context.l10n.a11yFeedFilter,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppDimensions.minTouchTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space8,
          ),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            border: Border.all(
              color: selected ? cs.primary : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: selected ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildDateHeader(BuildContext context, DateTime date) {
    final cs = Theme.of(context).colorScheme;
    final label = _dateLabel(context, date);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.space8,
        horizontal: AppDimensions.space8,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: Theme.of(context).dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space8,
            ),
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                letterSpacing: 2,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Divider(color: Theme.of(context).dividerColor)),
        ],
      ),
    );
  }

  static Widget _buildActivityCard(
    BuildContext context,
    ActivityEvent event,
    Map<String, String> initialsByActor,
  ) {
    final cs = Theme.of(context).colorScheme;
    final actionText = event.type == ActivityEventType.cooked
        ? context.l10n.feedActionCooked
        : context.l10n.feedActionShared;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The initials are told apart across every loaded actor, so a
          // person's circle does not change when a filter is toggled.
          AvatarCircle(
            glyph:
                initialsByActor[event.actorDisplayName] ??
                initialsFor(event.actorDisplayName),
          ),
          const SizedBox(
            width: AppDimensions.space8 + AppDimensions.space4,
          ),
          // Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Actor + action
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyMedium,
                    children: [
                      TextSpan(
                        text: event.actorDisplayName,
                        style: AppTextStyles.bodyBold,
                      ),
                      TextSpan(
                        text: ' $actionText',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                // Time
                Text(
                  _relativeTime(context, event.createdAt),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.space8),
                // Recipe preview
                _buildRecipePreview(context, event),
                // CookSnap album — swipeable carousel for multi-photo snaps,
                // a single image for legacy/single-photo events (BUT-949).
                if (event.photoUrls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.space8,
                    ),
                    child: CookSnapPhotoCarousel(
                      photoUrls: event.photoUrls,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildRecipePreview(BuildContext context, ActivityEvent event) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.a11yFeedRecipePreview,
      button: true,
      child: GestureDetector(
        onTap: () => _navigateToRecipe(context, event),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.space8),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                color: Theme.of(context).dividerColor,
                alignment: Alignment.center,
                // text.secondary (onSurfaceVariant), #5B6959 light, #A9B2A0
                // dark (tokens.json:61-64): greenMuted's values, mode-aware.
                child: ButleryIcon(
                  ButleryIcons.utensils,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: AppDimensions.iconSizeM,
                ),
              ),
              const SizedBox(
                width: AppDimensions.space8 + AppDimensions.space4,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.recipeTitle,
                      style: AppTextStyles.bodyBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const ButleryChevron(),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _navigateToRecipe(
    BuildContext context,
    ActivityEvent event,
  ) async {
    final recipe = await ServiceLocator.get<UnifiedRecipeService>()
        .fetchFriendRecipe(ownerId: event.actorId, recipeId: event.recipeId);
    if (!context.mounted) return;
    if (recipe != null) {
      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      final readOnly = event.actorId != currentUserId;
      Navigator.of(context).pushNamed(
        Routes.recipeDetail,
        arguments: {'recipe': recipe, 'readOnly': readOnly},
      );
    } else {
      // Recipe not shared — offer to request it from the owner.
      final confirmed = await CommonDialogActions.showActionConfirmation(
        context: context,
        title: context.l10n.feedRequestRecipeTitle,
        message: context.l10n.feedRequestRecipeBody(event.actorDisplayName),
        confirmText: context.l10n.feedRequestRecipeConfirm,
      );
      if (confirmed != true || !context.mounted) return;
      final ok = await ServiceLocator.get<SocialRecipeService>()
          .requestRecipeShare(
            ownerId: event.actorId,
            recipeId: event.recipeId,
            recipeTitle: event.recipeTitle,
          );
      if (!context.mounted) return;
      if (ok) {
        SnackBarUtils.showSuccess(context, context.l10n.feedRecipeRequestSent);
      } else {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.feedRecipeRequestFailed,
        );
      }
    }
  }

  // ---- Helpers ----

  static Map<String, String> _initialsByActor(List<ActivityEvent> events) {
    final names = {for (final e in events) e.actorDisplayName}.toList();
    final initials = distinctInitials(names);
    return {for (var i = 0; i < names.length; i++) names[i]: initials[i]};
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dateLabel(BuildContext context, DateTime date) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(eventDay).inDays;

    if (diff == 0) return context.l10n.feedTimeToday;
    if (diff == 1) return context.l10n.feedTimeYesterday;
    return context.l10n.feedTimeDaysAgo(diff);
  }

  static String _relativeTime(BuildContext context, DateTime date) {
    final diff = clock.now().difference(date);
    if (diff.inMinutes < 1) return context.l10n.feedTimeJustNow;
    if (diff.inMinutes < 60) {
      return context.l10n.feedTimeMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) return context.l10n.feedTimeHoursAgo(diff.inHours);
    return _dateLabel(context, date);
  }
}
