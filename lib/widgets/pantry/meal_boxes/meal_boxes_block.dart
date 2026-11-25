/// The "MATLÅDOR · N" block at the top of "Skafferiet" (BUT-2486, part 5).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/keyboard/app_actions.dart'
    show mainTabSwitchRequest;
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/pantry/meal_boxes_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_actions_sheet.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_edit_sheet.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_stepper.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_ui.dart';

/// Draws loading (compact), error (one row), empty (nothing) or the cards.
class MealBoxesBlock extends StatelessWidget {
  const MealBoxesBlock({required this.viewModel, super.key});

  final MealBoxesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final l10n = context.l10n;
        final cs = Theme.of(context).colorScheme;
        final margin = AppDimensions.layoutMarginOf(context);
        Widget padded(Widget child) => Padding(
          padding: EdgeInsets.fromLTRB(
            margin,
            0,
            margin,
            AppDimensions.space16,
          ),
          child: child,
        );

        if (viewModel.hasError && !viewModel.loaded) {
          return padded(
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.mealBoxesLoadFailed,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                ButleryTextButton(
                  key: const ValueKey('meal-boxes-retry'),
                  label: l10n.commonRetry,
                  onPressed: () {
                    viewModel.clearError();
                    viewModel.load();
                  },
                ),
              ],
            ),
          );
        }
        if (viewModel.isLoading && !viewModel.loaded) {
          return padded(
            Text(
              l10n.mealBoxesLoading,
              key: const ValueKey('meal-boxes-loading'),
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          );
        }
        final boxes = viewModel.boxes;
        if (boxes.isEmpty) return const SizedBox.shrink();

        return padded(
          Column(
            key: const ValueKey('meal-boxes-block'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                child: SectionHeading(
                  l10n.mealBoxesHeading(viewModel.totalRemaining),
                  tone: SectionHeadingTone.emphasis,
                ),
              ),
              ButleryOutlinedBox(
                color: cs.surfaceContainerHighest,
                borderColor: cs.outlineVariant,
                paintOnly: true,
                child: Column(
                  children: [
                    for (final (i, box) in boxes.indexed) ...[
                      if (i > 0) const ButleryDivider(spacing: 1),
                      _MealBoxCard(
                        key: ValueKey('meal-box-${box.id}'),
                        box: box,
                        viewModel: viewModel,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MealBoxCard extends StatelessWidget {
  const _MealBoxCard({required this.box, required this.viewModel, super.key});

  final MealBox box;
  final MealBoxesViewModel viewModel;

  Future<void> _change(BuildContext context, int remaining) async {
    // Taken before the await: the row may be gone when the write answers.
    final undo = UndoSnackBar.capture(context);
    final snackBars = CapturedSnackBars.capture(context);
    final l10n = context.l10n;
    final previous = box.remaining;
    final ok = await viewModel.setRemaining(box, remaining);
    if (!ok) {
      snackBars.showFailure(what: l10n.mealBoxChangeFailed);
      return;
    }
    if (remaining == 0) {
      undo.show(
        l10n.mealBoxEmptiedUndo(box.recipeTitle),
        onUndo: () => viewModel.setRemaining(box, previous),
      );
    }
  }

  Future<void> _openActions(BuildContext context) async {
    // Taken before the awaits: the card can be gone when an action ends.
    final undo = UndoSnackBar.capture(context);
    final snackBars = CapturedSnackBars.capture(context);
    final l10n = context.l10n;
    final action = await showMealBoxActionsSheet(context, box);
    if (action == null || !context.mounted) return;
    switch (action) {
      case MealBoxAction.plan:
        mainTabSwitchRequest.value = LayoutScaffolds.menuTab;
      case MealBoxAction.edit:
        await showMealBoxEditSheet(context, box, viewModel);
      case MealBoxAction.move:
        final to = box.location == MealBoxLocation.fridge
            ? MealBoxLocation.freezer
            : MealBoxLocation.fridge;
        final id = await viewModel.move(box, to);
        if (id == null) {
          snackBars.showFailure(what: l10n.mealBoxMoveFailed);
          return;
        }
        undo.show(
          to == MealBoxLocation.freezer
              ? l10n.mealBoxMovedFreezer(box.recipeTitle)
              : l10n.mealBoxMovedFridge(box.recipeTitle),
          onUndo: () async {
            if (!await viewModel.undoMove(box, id)) {
              snackBars.showFailure(what: l10n.mealBoxMoveUndoFailed);
            }
          },
        );
      case MealBoxAction.remove:
        if (!await viewModel.remove(box)) {
          snackBars.showFailure(what: l10n.mealBoxRemoveFailed);
          return;
        }
        undo.show(
          l10n.mealBoxRemovedUndo(box.recipeTitle),
          onUndo: () async {
            if (!await viewModel.restore(box)) {
              snackBars.showFailure(what: l10n.mealBoxRestoreFailed);
            }
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ButleryItemRow(
      onTap: () => _openActions(context),
      leadingIcon: mealBoxIcon(box.location),
      title: box.recipeTitle,
      titleMaxLines: 1,
      emphasised: true,
      subtitleWidget: Text(
        mealBoxSubtitle(l10n, Localizations.localeOf(context).toString(), box),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.captionBase.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: MealBoxStepper(
        value: box.remaining,
        max: MealBox.maxCount - box.taken,
        fewerLabel: l10n.a11yMealBoxFewer(box.recipeTitle),
        moreLabel: l10n.a11yMealBoxMore(box.recipeTitle),
        onChanged: (next) => _change(context, next),
      ),
    );
  }
}
