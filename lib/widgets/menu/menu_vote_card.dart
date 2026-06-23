/// Vote card widget for menu slot voting — shows alternatives, tallies, and status.

// lib/widgets/menu/menu_vote_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Displays a menu slot vote with alternatives, progress bars, and actions.
class MenuVoteCard extends StatelessWidget {
  final MenuSlotVote vote;
  final String currentUserId;
  final ValueChanged<String>? onVote;
  final VoidCallback? onResolve;

  const MenuVoteCard({
    super.key,
    required this.vote,
    required this.currentUserId,
    this.onVote,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (vote.isResolved) {
      return _buildResolvedCard(context, cs);
    }

    if (vote.isExpired) {
      return _buildExpiredCard(context, cs);
    }

    return _buildActiveCard(context, cs);
  }

  Widget _buildActiveCard(BuildContext context, ColorScheme cs) {
    final hasVoted = vote.hasVoted(currentUserId);
    final tallies = vote.tallies;
    final total = vote.totalVotes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.how_to_vote,
                  size: AppDimensions.iconSizeM,
                  color: cs.primary,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Text(
                    context.l10n.menuVoteTitle,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ),
                Text(
                  context.l10n.menuVoteCount(total),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Vote options with progress bars
            ...vote.alternatives.map((option) {
              final count = tallies[option.id] ?? 0;
              final fraction = total > 0 ? count / total : 0.0;
              final isSelected =
                  hasVoted && vote.votes[currentUserId] == option.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
                child: Semantics(
                  label: isSelected
                      ? context.l10n.a11yMenuVoteOptionSelected(
                          option.recipeName,
                        )
                      : context.l10n.a11yMenuVoteOption(option.recipeName),
                  button: true,
                  selected: isSelected,
                  child: InkWell(
                    onTap: hasVoted || onVote == null
                        ? null
                        : () => onVote!(option.id),
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary.withValues(
                                alpha: AppDimensions.opacityLight,
                              )
                            : cs.surfaceContainer,
                        border: isSelected
                            ? Border.all(color: cs.primary)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.recipeName,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: isSelected ? cs.primary : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXs),
                          ClipRRect(
                            child: LinearProgressIndicator(
                              value: fraction,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                cs.primary,
                              ),
                              minHeight: AppDimensions.spacingXs,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            context.l10n.menuVoteCount(count),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Resolve button (for vote creator)
            if (onResolve != null && vote.totalVotes > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingS),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onResolve,
                    child: Text(context.l10n.menuVoteResolved),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolvedCard(BuildContext context, ColorScheme cs) {
    final winner = vote.winningOption;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: context.butleryColors.success,
              size: AppDimensions.iconSizeL,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.menuVoteResolved,
                    style: AppTextStyles.titleSmall,
                  ),
                  if (winner != null)
                    Text(
                      context.l10n.menuVoteWinner(winner.recipeName),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredCard(BuildContext context, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Row(
          children: [
            Icon(
              Icons.timer_off,
              color: cs.onSurfaceVariant,
              size: AppDimensions.iconSizeL,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.menuVoteExpired,
                    style: AppTextStyles.titleSmall,
                  ),
                  Text(
                    context.l10n.menuVoteCount(vote.totalVotes),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onResolve != null && vote.totalVotes > 0)
              FilledButton(
                onPressed: onResolve,
                child: Text(context.l10n.menuVoteResolved),
              ),
          ],
        ),
      ),
    );
  }
}
