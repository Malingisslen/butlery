// lib/widgets/messaging/poll_message_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Displays an interactive poll within a chat message.
/// Shows question, votable options with progress bars, and close button for creator.
class PollMessageWidget extends StatelessWidget {
  final Poll poll;
  final String currentUserId;
  final bool isFromCurrentUser;
  final void Function(String optionId)? onVote;
  final VoidCallback? onClose;

  const PollMessageWidget({
    super.key,
    required this.poll,
    required this.currentUserId,
    required this.isFromCurrentUser,
    this.onVote,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalVotes = poll.totalVotes;
    final textColor = isFromCurrentUser ? cs.onPrimary : cs.onSurface;
    final subtleColor = isFromCurrentUser
        ? cs.onPrimary.withValues(alpha: AppDimensions.opacityDark)
        : cs.onSurfaceVariant;

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
          ...poll.options.map((option) => _buildOption(
                context: context,
                option: option,
                totalVotes: totalVotes,
                textColor: textColor,
                subtleColor: subtleColor,
              )),

          // Vote count + status
          const SizedBox(height: AppDimensions.spacingXs),
          Row(
            children: [
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

          // Close button for creator
          if (poll.isActive &&
              poll.creatorId == currentUserId &&
              onClose != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            GestureDetector(
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
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
                    ? cs.onPrimary.withValues(alpha: AppDimensions.opacityLight)
                    : cs.primary
                        .withValues(alpha: AppDimensions.opacityVeryLight))
                : (isFromCurrentUser
                    ? cs.onPrimary
                        .withValues(alpha: AppDimensions.opacityVeryLight)
                    : cs.surface.withValues(alpha: AppDimensions.opacityHalf)),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            border: Border.all(
              color: hasVoted
                  ? (isFromCurrentUser
                      ? cs.onPrimary
                          .withValues(alpha: AppDimensions.opacityMediumLight)
                      : cs.primary
                          .withValues(alpha: AppDimensions.opacityMediumLight))
                  : Colors.transparent,
            ),
          ),
          child: Stack(
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
                                    alpha: AppDimensions.opacityVeryLight)
                                : cs.primary.withValues(
                                    alpha: AppDimensions.opacityExtraVeryLight))
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadiusS),
                      ),
                    ),
                  ),
                ),
              // Option text and vote count
              Row(
                children: [
                  if (hasVoted)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(end: AppDimensions.spacingXs),
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
                        fontWeight:
                            hasVoted ? FontWeight.w600 : FontWeight.normal,
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
          ),
        ),
      ),
    );
  }
}
