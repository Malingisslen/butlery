/// "Förra versionen · i går [Återställ]" under the pantry edit sheet's
/// heading (BUT-2140).
///
/// The item has no menu of its own (tap edits, swipe removes, long-press
/// selects), so the edit sheet is where Återställ lives, and nothing is added
/// to the item card. The row is there only while a previous version younger
/// than [PantryPreviousVersion.restoreWindow] exists.
///
/// Restoring swaps the two versions, so what it replaces is kept and can be
/// restored in turn: BUT-954 class 1 (.claude/rules/ui-conventions.md), no
/// dialog, then Ångra through the undo primitive.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/content_time_labels.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';

class PantryPreviousVersionRow extends StatefulWidget {
  const PantryPreviousVersionRow({super.key, required this.item});

  final PantryItem item;

  static const restoreButtonKey = ValueKey('pantry-restore-previous');

  @override
  State<PantryPreviousVersionRow> createState() =>
      _PantryPreviousVersionRowState();
}

class _PantryPreviousVersionRowState extends State<PantryPreviousVersionRow> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _restore() async {
    final l10n = context.l10n;
    final viewModel = context.read<PantryViewModel>();
    final navigator = Navigator.of(context);
    // Captured now: the snackbar shows after the sheet has closed.
    final undo = UndoSnackBar.capture(context);
    setState(() {
      _busy = true;
      _failed = false;
    });

    final restored = await viewModel.restorePrevious(widget.item);
    if (!mounted) return;
    if (restored == null) {
      setState(() {
        _busy = false;
        _failed = true;
      });
      return;
    }
    // The sheet's fields hold the version that was just replaced, so it
    // closes rather than offering to save it back over the restore.
    navigator.pop();
    undo.show(
      l10n.pantryPreviousRestored,
      onUndo: () => unawaited(viewModel.restorePrevious(restored)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.item.previous;
    final now = clock.now();
    if (previous == null || !previous.isRestorableAt(now)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.pantryPreviousVersion(
                    ContentTimeLabels.whenLabel(l10n, previous.at, now),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              KeyedSubtree(
                key: PantryPreviousVersionRow.restoreButtonKey,
                child: ActionButtons.textButton(
                  context,
                  label: l10n.pantryRestorePreviousAction,
                  isLoading: _busy,
                  onPressed: _restore,
                ),
              ),
            ],
          ),
          if (_failed)
            InlineError(
              what: l10n.pantryRestorePreviousFailed,
              actionLabel: l10n.commonRetry,
              onAction: _restore,
            ),
        ],
      ),
    );
  }
}
