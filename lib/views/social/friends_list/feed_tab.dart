/// Feed tab — shows social activity from friends (CookSnaps, shares).
// lib/views/social/friends_list/feed_tab.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/widgets/recipe/cook_snap_photo_carousel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';

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
    return LoadingStateBuilder<List<ActivityEvent>>(
      isLoading: viewModel.isLoading,
      error: viewModel.error,
      data: viewModel.filteredEvents.isEmpty && viewModel.events.isEmpty
          ? null
          : viewModel.filteredEvents,
      loadingMessage: context.l10n.socialFeed,
      emptyTitle: hasFriends
          ? context.l10n.feedEmpty
          : context.l10n.feedEmptyNoFriendsTitle,
      emptySubtitle: hasFriends
          ? context.l10n.feedEmptyDescription
          : context.l10n.feedEmptyNoFriendsSubtitle,
      emptyActionLabel: hasFriends ? null : context.l10n.feedEmptyNoFriendsCta,
      onEmptyAction: hasFriends ? null : onAddFriendsCta,
      emptyIcon: Icons.groups_outlined,
      builder: (context, events) => Column(
        children: [
          _buildFilterChips(context, viewModel),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => viewModel.refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppDimensions.spacingSm),
                itemCount: events.length + (viewModel.hasMore ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppDimensions.spacingXs),
                itemBuilder: (context, index) {
                  if (index >= events.length) {
                    if (!viewModel.isLoading) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) viewModel.loadMore();
                      });
                    }
                    return const Padding(
                      padding: EdgeInsets.all(AppDimensions.spacingMd),
                      child: Center(
                        child: LoadingIndicator(size: 24, strokeWidth: 2),
                      ),
                    );
                  }

                  final event = events[index];
                  final showDateHeader = index == 0 ||
                      !_isSameDay(events[index - 1].createdAt, event.createdAt);

                  return AnimatedListItem(
                    key: ValueKey(event.id),
                    index: index,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDateHeader)
                          _buildDateHeader(context, event.createdAt),
                        _buildActivityCard(context, event),
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

  static Widget _buildFilterChips(
    BuildContext context,
    ActivityFeedViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Row(
        children: [
          _filterChip(
            context,
            context.l10n.feedFilterAll,
            viewModel.filter == null,
            () => viewModel.setFilter(null),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          _filterChip(
            context,
            context.l10n.feedFilterCooked,
            viewModel.filter == ActivityEventType.cooked,
            () => viewModel.setFilter(ActivityEventType.cooked),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
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
      label: context.l10n.a11yFeedFilter(label),
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
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
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
              fontWeight: FontWeight.w600,
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
        vertical: AppDimensions.spacingSm,
        horizontal: AppDimensions.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: Theme.of(context).dividerColor)),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.spacingSm),
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

  static Widget _buildActivityCard(BuildContext context, ActivityEvent event) {
    final cs = Theme.of(context).colorScheme;
    final borderColor =
        event.type == ActivityEventType.cooked ? cs.primary : cs.secondary;

    final actionText = event.type == ActivityEventType.cooked
        ? context.l10n.feedActionCooked
        : context.l10n.feedActionShared;

    final initials = _initialsFrom(event.actorDisplayName);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          bottom: BorderSide(
            // Decorative thin rust accent — kept on rustLight per BUT-572
            // legitimate-keep set (no clean theme-token equivalent).
            color: AppColors.rustLight.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            color: borderColor,
            alignment: Alignment.center,
            child: Text(
              initials,
              style: AppTextStyles.labelSmall.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(
              width: AppDimensions.spacingSm + AppDimensions.spacingXs),
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                const SizedBox(height: AppDimensions.spacingSm),
                // Recipe preview
                _buildRecipePreview(context, event),
                // CookSnap album — swipeable carousel for multi-photo snaps,
                // a single image for legacy/single-photo events (BUT-949).
                if (event.photoUrls.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: AppDimensions.spacingSm),
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
      label: context.l10n.a11yFeedRecipePreview(event.recipeTitle),
      button: true,
      child: GestureDetector(
        onTap: () => _navigateToRecipe(context, event),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacingSm),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                color: Theme.of(context).dividerColor,
                alignment: Alignment.center,
                // greenMuted retained per BUT-572 legitimate-keep set —
                // muted icon tone with no clean theme-token equivalent.
                child: const Icon(
                  Icons.restaurant_outlined,
                  color: AppColors.greenMuted,
                  size: AppDimensions.iconSizeM,
                ),
              ),
              const SizedBox(
                  width: AppDimensions.spacingSm + AppDimensions.spacingXs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.recipeTitle.toLowerCase(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: AppDimensions.iconSizeS,
                color: cs.onSurfaceVariant,
              ),
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.feedRequestRecipeTitle),
          content: Text(
            ctx.l10n.feedRequestRecipeBody(event.actorDisplayName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.feedRequestRecipeConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final ok =
          await ServiceLocator.get<SocialRecipeService>().requestRecipeShare(
        ownerId: event.actorId,
        recipeId: event.recipeId,
        recipeTitle: event.recipeTitle,
      );
      if (!context.mounted) return;
      if (ok) {
        SnackBarUtils.showSuccess(context, context.l10n.feedRecipeRequestSent);
      } else {
        SnackBarUtils.showError(context, context.l10n.commonErrorOccurred);
      }
    }
  }

  // ---- Helpers ----

  static String _initialsFrom(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
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
