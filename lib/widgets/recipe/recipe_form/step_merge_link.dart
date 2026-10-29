import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The link between two steps that joins them into one, for a step an import
/// cut in two (BUT-2455). Both recipe forms draw it under every step but the
/// last.
class StepMergeLink extends StatelessWidget {
  const StepMergeLink({required this.index, required this.onMerge, super.key});

  /// Whether the link belongs under row [index]: not under the last row, and
  /// not above the empty line the form keeps at the end for the next step.
  static bool showsUnder(List<TextEditingController> controllers, int index) {
    final next = index + 1;
    if (next >= controllers.length) return false;
    return next < controllers.length - 1 ||
        controllers[next].text.trim().isNotEmpty;
  }

  /// The instruction validator's limit in `RecipeFormState`: a longer merged
  /// step would grey out Spara with no reason shown.
  static const maxStepLength = 500;

  /// Joins step [index] with the next and offers the undo every reversible
  /// removal gets (ui-conventions, BUT-954 class 1).
  static void mergeWithUndo(
    BuildContext context,
    RecipeFormViewModel viewModel,
    int index,
  ) {
    final before = viewModel.instructions;
    if (index + 1 < before.length &&
        before[index].trim().length + 1 + before[index + 1].trim().length >
            maxStepLength) {
      SnackBarUtils.showWarning(context, context.l10n.stepsTooLongToMerge);
      return;
    }
    final merged = viewModel.mergeInstructionWithNext(index);
    if (merged == null) return;
    SnackBarUtils.showSuccessWithAction(
      context,
      context.l10n.stepsMerged,
      actionLabel: context.l10n.commonUndo,
      duration: const Duration(seconds: 7),
      onAction: () => viewModel.undoInstructionMerge(
        index,
        merged,
        before[index],
        before[index + 1],
      ),
    );
  }

  /// The upper of the two steps, zero-based.
  final int index;
  final void Function(int index) onMerge;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ButleryTextButton(
        key: ValueKey('step-merge-$index'),
        icon: ButleryIcons.merge,
        label: context.l10n.mergeWithNextStep,
        semanticLabel: context.l10n.a11yMergeSteps(index + 1, index + 2),
        dense: true,
        onPressed: () => onMerge(index),
      ),
    );
  }
}
