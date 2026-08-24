// lib/widgets/messaging/poll_message_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';

/// Displays an interactive poll within a chat message.
/// Shows question, votable options with progress bars, and close button for creator.
class PollMessageWidget extends StatelessWidget {
  final Poll poll;
  final String currentUserId;
  final bool isFromCurrentUser;
  final void Function(String optionId)? onVote;
  final VoidCallback? onClose;

  /// Whether the vote counts below were actually read (BUT-1908).
  ///
  /// REQUIRED, not defaulted. There is one production call site and it passes
  /// the real value; a default of `ok` on a one-way-door gate would only ever
  /// serve a future second call site that forgot, by drawing the close button
  /// over votes nobody read.
  final PollVoteHydration voteHydration;

  /// Called when a recipe-backed option is tapped (vs voted on). When null,
  /// recipe options behave like plain-text options (tap = vote).
  final void Function(String recipeId)? onRecipeTap;

  const PollMessageWidget({
    super.key,
    required this.poll,
    required this.currentUserId,
    required this.isFromCurrentUser,
    this.onVote,
    this.onClose,
    this.onRecipeTap,
    required this.voteHydration,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalVotes = poll.totalVotes;
    final textColor = isFromCurrentUser ? cs.onPrimary : cs.onSurface;
    final subtleColor = isFromCurrentUser
        ? cs.onPrimary.withValues(alpha: AppDimensions.opacityDark)
        : cs.onSurfaceVariant;
    final votesUnread = voteHydration.isUnread;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll icon + question
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 16)),
              const SizedBox(width: AppDimensions.spacingXs),
              Expanded(
                child: Text(
                  poll.question,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),

          // Options
          ...poll.options.map(
            (option) => _buildOption(
              context: context,
              option: option,
              totalVotes: totalVotes,
              textColor: textColor,
              subtleColor: subtleColor,
            ),
          ),

          // Vote count + status
          const SizedBox(height: AppDimensions.spacingXs),
          Row(
            children: [
              // BUT-1908: "0 röster" is a claim about the votes, and it must
              // not be made about votes nobody read. The two unread states get
              // DIFFERENT text because they mean different things to the user —
              // one is repaired by reopening the chat, the other may not be.
              if (votesUnread)
                Expanded(
                  child: Text(
                    voteHydration == PollVoteHydration.capped
                        ? context.l10n.pollVotesNotLoadedShort
                        : context.l10n.pollVotesFailedShort,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: subtleColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Text(
                  '$totalVotes ${totalVotes == 1 ? context.l10n.pollVoteSingular : context.l10n.pollVotePlural}',
                  style: AppTextStyles.labelSmall.copyWith(color: subtleColor),
                ),
              if (!poll.isActive) ...[
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  context.l10n.pollClosed,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: subtleColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),

          if (votesUnread) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              voteHydration == PollVoteHydration.capped
                  ? context.l10n.pollVotesNotLoadedHint
                  : context.l10n.pollVotesFailedHint,
              style: AppTextStyles.labelSmall.copyWith(color: subtleColor),
            ),
          ],

          // Close button for creator.
          //
          // BUT-1908: gated on `!votesUnread` as well. Closing is a one-way
          // door that writes the winning recipe into the household's week, and
          // the harm this ticket exists for is precisely that the button was
          // drawn on a poll showing "0 röster" while the close path re-read the
          // real votes on its own route.
          if (poll.isActive &&
              poll.creatorId == currentUserId &&
              !votesUnread &&
              onClose != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onClose,
                child: Text(
                  context.l10n.pollCloseAction,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isFromCurrentUser ? cs.onPrimary : cs.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required PollOption option,
    required int totalVotes,
    required Color textColor,
    required Color subtleColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasVoted = option.hasVoted(currentUserId);
    final percentage = totalVotes > 0 ? option.voteCount / totalVotes : 0.0;
    final isRecipeOption = option.hasRecipe;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Semantics(
        label: context.l10n.a11yPollVoteOption(option.text),
        button: true,
        selected: hasVoted,
        enabled: poll.isActive,
        child: GestureDetector(
          onTap: poll.isActive ? () => onVote?.call(option.id) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingS,
              vertical: AppDimensions.spacingXs + 2,
            ),
            decoration: BoxDecoration(
              color: hasVoted
                  ? (isFromCurrentUser
                        ? cs.onPrimary.withValues(
                            alpha: AppDimensions.opacityLight,
                          )
                        : cs.primary.withValues(
                            alpha: AppDimensions.opacityVeryLight,
                          ))
                  : (isFromCurrentUser
                        ? cs.onPrimary.withValues(
                            alpha: AppDimensions.opacityVeryLight,
                          )
                        : cs.surface.withValues(
                            alpha: AppDimensions.opacityHalf,
                          )),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              border: Border.all(
                color: hasVoted
                    ? (isFromCurrentUser
                          ? cs.onPrimary.withValues(
                              alpha: AppDimensions.opacityMediumLight,
                            )
                          : cs.primary.withValues(
                              alpha: AppDimensions.opacityMediumLight,
                            ))
                    : Colors.transparent,
              ),
            ),
            child: isRecipeOption
                ? _buildRecipeOptionContent(
                    context: context,
                    option: option,
                    totalVotes: totalVotes,
                    textColor: textColor,
                    subtleColor: subtleColor,
                    hasVoted: hasVoted,
                    percentage: percentage,
                  )
                : _buildTextOptionContent(
                    context: context,
                    option: option,
                    totalVotes: totalVotes,
                    textColor: textColor,
                    subtleColor: subtleColor,
                    hasVoted: hasVoted,
                    percentage: percentage,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextOptionContent({
    required BuildContext context,
    required PollOption option,
    required int totalVotes,
    required Color textColor,
    required Color subtleColor,
    required bool hasVoted,
    required double percentage,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // Progress bar background
        if (totalVotes > 0)
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: hasVoted
                      ? (isFromCurrentUser
                            ? cs.onPrimary.withValues(
                                alpha: AppDimensions.opacityVeryLight,
                              )
                            : cs.primary.withValues(
                                alpha: AppDimensions.opacityExtraVeryLight,
                              ))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusS,
                  ),
                ),
              ),
            ),
          ),
        // Option text and vote count
        Row(
          children: [
            if (hasVoted)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppDimensions.spacingXs,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: isFromCurrentUser ? cs.onPrimary : cs.primary,
                ),
              ),
            Expanded(
              child: Text(
                option.text,
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor,
                  fontWeight: hasVoted ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (totalVotes > 0)
              Text(
                '${(percentage * 100).round()}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: subtleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Recipe-aware layout: thumbnail + title + metadata row above the
  /// percentage bar. Tapping the thumbnail navigates to recipe detail via
  /// [onRecipeTap]; tapping elsewhere still casts a vote.
  Widget _buildRecipeOptionContent({
    required BuildContext context,
    required PollOption option,
    required int totalVotes,
    required Color textColor,
    required Color subtleColor,
    required bool hasVoted,
    required double percentage,
  }) {
    final cs = Theme.of(context).colorScheme;
    final portions = option.recipePortions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              label: context.l10n.a11yPollRecipeThumbnail(option.text),
              button: true,
              enabled: option.recipeId != null && onRecipeTap != null,
              child: GestureDetector(
                onTap: option.recipeId != null && onRecipeTap != null
                    ? () => onRecipeTap!(option.recipeId!)
                    : null,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: option.recipeImageUrl != null
                      ? SimpleImageWidget.thumbnail(
                          imageUrl: option.recipeImageUrl!,
                        )
                      : _RecipeFallbackThumbnail(
                          isFromCurrent: isFromCurrentUser,
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (hasVoted)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: AppDimensions.spacingXs,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: isFromCurrentUser
                                ? cs.onPrimary
                                : cs.primary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          option.text,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: textColor,
                            fontWeight: hasVoted
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (portions != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppDimensions.spacingXs,
                      ),
                      child: Text(
                        '$portions ${context.l10n.portionsUnit}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: subtleColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        // Progress bar + percentage row
        SizedBox(
          height: 12,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(
                      alpha: AppDimensions.opacityVeryLight,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusS,
                    ),
                  ),
                ),
              ),
              if (totalVotes > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: percentage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasVoted
                            ? (isFromCurrentUser
                                  ? cs.onPrimary.withValues(
                                      alpha: AppDimensions.opacityMediumLight,
                                    )
                                  : cs.primary.withValues(
                                      alpha: AppDimensions.opacityVeryLight,
                                    ))
                            : cs.primary.withValues(
                                alpha: AppDimensions.opacityExtraVeryLight,
                              ),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusS,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (totalVotes > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              '${(percentage * 100).round()}%',
              style: AppTextStyles.labelSmall.copyWith(
                color: subtleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Fallback thumbnail when a recipe option has no image URL. Theme-tinted
/// square (no border radius — square design language).
class _RecipeFallbackThumbnail extends StatelessWidget {
  final bool isFromCurrent;
  const _RecipeFallbackThumbnail({required this.isFromCurrent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isFromCurrent
            ? cs.onPrimary.withValues(alpha: AppDimensions.opacityVeryLight)
            : cs.surfaceContainerHighest,
      ),
      child: Icon(
        Icons.restaurant_menu,
        size: 20,
        color: isFromCurrent
            ? cs.onPrimary.withValues(alpha: AppDimensions.opacityMedium)
            : cs.onSurfaceVariant,
      ),
    );
  }
}
