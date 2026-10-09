/// Vote card widget for menu slot voting — shows alternatives, tallies, and status.

// lib/widgets/menu/menu_vote_card.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// One slot's vote, drawn per Skärmar v12 etapp 2 (#veckorostning,
/// #veckorostlagg, #veckorostavgor, #veckorostutgang). Counts only, never who
/// voted for what (produktregler 4.8). A callback left null hides its action.
class MenuVoteCard extends StatelessWidget {
  final MenuSlotVote vote;
  final String currentUserId;
  final ValueChanged<String>? onVote;

  /// The starter puts an option on the slot: the clear winner, or one of the
  /// tied leaders.
  final ValueChanged<String>? onDecide;
  final VoidCallback? onReopen;
  final VoidCallback? onRelease;

  /// Adds another dish to an open vote. Null when the user may not, or
  /// already has.
  final VoidCallback? onPropose;

  const MenuVoteCard({
    super.key,
    required this.vote,
    required this.currentUserId,
    this.onVote,
    this.onDecide,
    this.onReopen,
    this.onRelease,
    this.onPropose,
  });

  bool get _isStarter => vote.isStarter(currentUserId);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (vote.state) {
      SlotVoteState.decided => _buildDecided(context, cs),
      SlotVoteState.released => const SizedBox.shrink(),
      SlotVoteState.open => _buildOpen(context, cs),
      SlotVoteState.expiredWithVotes => _buildExpired(context, cs),
      SlotVoteState.expiredEmpty => _buildNobodyVoted(context, cs),
    };
  }

  Widget _buildOpen(BuildContext context, ColorScheme cs) {
    final total = vote.totalVotes;
    final tied = vote.isTie;
    return _CardFrame(
      children: [
        _Header(
          title: context.l10n.menuVoteQuestion,
          trailing: context.l10n.menuVoteCount(total),
        ),
        Text(
          _closesIn(context),
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        for (final option in vote.alternatives)
          _OptionRow(
            option: option,
            count: vote.tallies[option.id] ?? 0,
            total: total,
            isSelected: vote.votes[currentUserId] == option.id,
            onTap: onVote == null || vote.votes[currentUserId] == option.id
                ? null
                : () => onVote!(option.id),
          ),
        if (onPropose != null)
          _ActionRow(
            children: [
              OutlinedButton(
                onPressed: onPropose,
                child: Text(context.l10n.menuVoteProposeOther),
              ),
            ],
          ),
        if (_isStarter && total > 0 && !tied && onDecide != null)
          _ActionRow(
            children: [
              FilledButton(
                onPressed: () => onDecide!(vote.clearWinner!.id),
                child: Text(context.l10n.menuVoteDecide),
              ),
            ],
          ),
        if (tied) ..._tieSection(context, cs),
      ],
    );
  }

  /// A tie is drawn as a tie: the starter picks among the leaders or gives it
  /// a day; everyone else sees that it waits on the starter.
  List<Widget> _tieSection(BuildContext context, ColorScheme cs) => [
    const SizedBox(height: AppDimensions.space4),
    Text(context.l10n.menuVoteTieTitle, style: AppTextStyles.titleSmall),
    Text(
      _isStarter
          ? context.l10n.menuVoteTieStarterBody
          : context.l10n.menuVoteWaitingOnStarter,
      style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
    ),
    if (_isStarter)
      _ActionRow(
        children: [
          if (onDecide != null)
            for (final leader in vote.leaders)
              FilledButton(
                onPressed: () => onDecide!(leader.id),
                child: Text(context.l10n.menuVoteDecideFor(leader.recipeName)),
              ),
          if (onReopen != null && vote.isExpired)
            OutlinedButton(
              onPressed: onReopen,
              child: Text(context.l10n.menuVoteGiveADay),
            ),
          if (onRelease != null && vote.isExpired)
            TextButton(
              onPressed: onRelease,
              child: Text(context.l10n.menuVoteRelease),
            ),
        ],
      ),
  ];

  Widget _buildExpired(BuildContext context, ColorScheme cs) {
    final leader = vote.clearWinner;
    return _CardFrame(
      children: [
        _Header(
          title: context.l10n.menuVoteExpired,
          trailing: context.l10n.menuVoteCount(vote.totalVotes),
          icon: ButleryIcons.clock,
        ),
        for (final option in vote.alternatives)
          _OptionRow(
            option: option,
            count: vote.tallies[option.id] ?? 0,
            total: vote.totalVotes,
            isSelected: vote.votes[currentUserId] == option.id,
            onTap: null,
          ),
        if (!_isStarter)
          Text(
            context.l10n.menuVoteWaitingOnStarter,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          )
        else if (vote.isTie)
          ..._tieSection(context, cs)
        else
          _ActionRow(
            children: [
              if (onDecide != null && leader != null)
                FilledButton(
                  onPressed: () => onDecide!(leader.id),
                  child: Text(context.l10n.menuVoteDecideAnyway),
                ),
              if (onReopen != null)
                OutlinedButton(
                  onPressed: onReopen,
                  child: Text(context.l10n.menuVoteReopen),
                ),
              if (onRelease != null)
                TextButton(
                  onPressed: onRelease,
                  child: Text(context.l10n.menuVoteRelease),
                ),
            ],
          ),
      ],
    );
  }

  /// Expired with no votes is not a tie: nobody took the suggestion up, and
  /// it gives no claim on the slot.
  Widget _buildNobodyVoted(BuildContext context, ColorScheme cs) {
    return _CardFrame(
      children: [
        _Header(
          title: context.l10n.menuVoteNobodyVoted,
          icon: ButleryIcons.clock,
        ),
        Text(
          context.l10n.menuVoteNobodyVotedBody,
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        if (_isStarter && onRelease != null)
          _ActionRow(
            children: [
              TextButton(
                onPressed: onRelease,
                child: Text(context.l10n.menuVoteRelease),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDecided(BuildContext context, ColorScheme cs) {
    final winner = vote.winningOption;
    return _CardFrame(
      children: [
        Row(
          children: [
            ButleryIcon(
              ButleryIcons.circleCheck,
              color: context.modeColors.success,
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
                  Text(
                    context.l10n.menuVoteCount(vote.totalVotes),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _closesIn(BuildContext context) {
    final left = vote.deadline.difference(clock.now());
    final hours = left.inHours;
    return hours >= 1
        ? context.l10n.menuVoteClosesInHours(hours)
        : context.l10n.menuVoteClosesSoon;
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.trailing, this.icon});

  final String title;
  final String? trailing;
  final ButleryGlyph? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // text.primary, not cs.primary: primary is ink in both modes and
        // would vanish on the dark card.
        ButleryIcon(
          icon ?? ButleryIcons.vote,
          size: AppDimensions.iconSizeM,
          color: cs.onSurface,
        ),
        const SizedBox(width: AppDimensions.space4),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppDimensions.space4),
    child: Wrap(
      spacing: AppDimensions.space4,
      runSpacing: AppDimensions.space4,
      children: children,
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.count,
    required this.total,
    required this.isSelected,
    required this.onTap,
  });

  final VoteOption option;
  final int count;
  final int total;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space4),
      child: Semantics(
        label: isSelected
            ? context.l10n.a11yMenuVoteOptionSelected
            : context.l10n.a11yMenuVoteOption,
        button: true,
        enabled: onTap != null,
        selected: isSelected,
        child: Material(
          type: MaterialType.transparency,
          child: PressFill(
            surface: isSelected ? PressSurface.raised : PressSurface.base,
            child: InkWell(
              onTap: onTap,
              // The chosen option is surface.selected with a real 1.5 px
              // text.primary border, never a tint. primaryContainer is
              // surface.selected (#E6EAD9 / #2F4437) and onSurface
              // text.primary (ink / paper) in both schemes.
              child: Ink(
                decoration: BoxDecoration(
                  color: isSelected ? cs.primaryContainer : cs.surface,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? cs.onSurface : cs.outlineVariant,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.recipeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      if (option.votersBefore > 0)
                        Text(
                          context.l10n.menuVoteLateOption(
                            option.votersBefore,
                          ),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      // The share of the votes as the determinate plate
                      // line. The count below says the number, so the line
                      // is not read out on its own.
                      ExcludeSemantics(child: PlateLine(value: fraction)),
                      const SizedBox(height: AppDimensions.space4),
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
          ),
        ),
      ),
    );
  }
}
