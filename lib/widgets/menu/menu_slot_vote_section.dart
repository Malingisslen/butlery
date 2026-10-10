// lib/widgets/menu/menu_slot_vote_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/menu_voting_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/menu/menu_vote_card.dart';
import 'package:butlery/widgets/menu/suggest_alternative_sheet.dart';

/// Lets the user pick a dish for a vote, leaving out the ones already on it.
Future<Recipe?> _pickDish(
  BuildContext context,
  MenuViewModel menu,
  List<String> exclude,
) async {
  final pool = await menu.getAvailableRecipesAsync();
  if (!context.mounted) return null;
  return SuggestAlternativeSheet.show(
    context,
    availableRecipes: pool,
    excludeRecipeIds: exclude,
  );
}

void _reportFailure(BuildContext context, MenuVotingViewModel voting) {
  if (!context.mounted) return;
  final what = voting.error ?? context.l10n.menuVoteSaveFailed;
  voting.clearError();
  SnackBarUtils.showFailure(context, what: what);
}

/// The vote card under one dish of a live menu (BUT-2118). Starting, adding
/// to and settling a vote change the menu's agenda, so they need an edit
/// role, as the rules do; voting is open to everyone on the menu.
class MenuSlotVoteSection extends StatelessWidget {
  const MenuSlotVoteSection({
    super.key,
    required this.voting,
    required this.menu,
    required this.category,
    required this.slotIndex,
  });

  final MenuVotingViewModel voting;
  final MenuViewModel menu;
  final String category;
  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voting,
      builder: (context, _) {
        final vote = voting.voteForSlot(category, slotIndex);
        if (vote == null) return const SizedBox.shrink();
        final canEdit = menu.canEditMenu;
        final open = vote.state == SlotVoteState.open;

        Future<void> run(Future<bool> Function() action) async {
          if (!await action()) {
            if (context.mounted) _reportFailure(context, voting);
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.space4),
          child: MenuVoteCard(
            vote: vote,
            currentUserId: voting.currentUserId,
            onVote: open
                ? (optionId) => run(() => voting.castVote(vote, optionId))
                : null,
            onDecide: canEdit
                ? (optionId) => run(() => voting.settle(vote, optionId))
                : null,
            onReopen: canEdit ? () => run(() => voting.reopen(vote)) : null,
            onRelease: canEdit ? () => run(() => voting.release(vote)) : null,
            onPropose: canEdit && open && !voting.hasProposed(vote)
                ? () async {
                    final dish = await _pickDish(context, menu, [
                      for (final o in vote.alternatives) o.recipeId,
                    ]);
                    if (dish == null) return;
                    await run(() => voting.propose(vote, dish));
                  }
                : null,
          ),
        );
      },
    );
  }
}

/// The button on a dish that puts it to a vote against another dish.
class MenuStartVoteButton extends StatelessWidget {
  const MenuStartVoteButton({
    super.key,
    required this.voting,
    required this.menu,
    required this.recipe,
    required this.category,
    required this.slotIndex,
  });

  final MenuVotingViewModel voting;
  final MenuViewModel menu;
  final Recipe recipe;
  final String category;
  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: voting,
      builder: (context, _) {
        final enabled =
            menu.canEditMenu && voting.canStartVote(category, slotIndex);
        return Material(
          color: cs.surface,
          borderRadius: BorderRadius.zero,
          child: Semantics(
            label: context.l10n.a11yMenuSuggestAlternative(recipe.title),
            button: true,
            enabled: enabled,
            child: PressFill(
              surface: PressSurface.base,
              child: InkWell(
                onTap: enabled
                    ? () async {
                        final dish = await _pickDish(context, menu, [
                          recipe.id,
                        ]);
                        if (dish == null) return;
                        final ok = await voting.startVote(
                          category: category,
                          slotIndex: slotIndex,
                          current: recipe,
                          proposal: dish,
                        );
                        if (!ok && context.mounted) {
                          _reportFailure(context, voting);
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingXs),
                  child: ButleryIcon(
                    ButleryIcons.vote,
                    size: AppDimensions.iconSizeS,
                    color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
