/// BUT-1185: merge + bulk-delete dialogs for the multi-select flow on the
/// personal-tags screen.
///
/// Kept in a separate file from [PersonalTagDialogs] (already 800+ lines, an
/// accepted large file) to stay under the 500-line limit. The public API is
/// re-exposed via thin delegators on [PersonalTagDialogs].
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/list/butlery_radio_row.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/models/tagging/personal_tag_bulk_delete_result.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';

/// Static helpers for the bulk merge / delete dialogs.
abstract final class PersonalTagBulkDialogs {
  /// Merge dialog: the user picks ONE selected tag as the "keep" target; every
  /// other selected tag is merged into it (recipes retagged, source deleted).
  static Future<void> showMergeDialog(
    BuildContext context,
    List<PersonalTag> selectedTags,
  ) async {
    if (selectedTags.length < 2) return;

    final viewModel = context.read<PersonalTagViewModel>();
    final selection = context.read<PersonalTagSelectionManager>();
    // Default the keep-target to the first selected tag.
    String targetId = selectedTags.first.id;

    await showButleryDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final targetTag = selectedTags.firstWhere((t) => t.id == targetId);
            return ButleryDialog(
              title: context.l10n.personalTagMergeTitle,
              scrollable: false,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.personalTagMergeMessage(
                      selectedTags.length,
                      targetTag.name,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  Text(context.l10n.personalTagMergeKeepLabel),
                  const SizedBox(height: AppDimensions.space4),
                  Flexible(
                    child: SingleChildScrollView(
                      child: RadioGroup<String>(
                        groupValue: targetId,
                        onChanged: (v) {
                          if (isLoading) return;
                          setState(() => targetId = v ?? targetId);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // The tag is chosen by id.
                            for (final tag in selectedTags)
                              ButleryRadioRow<String>(
                                key: ValueKey('merge-keep-${tag.id}'),
                                value: tag.id,
                                title: tag.name,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                DialogCancelButton(enabled: !isLoading),
                ButleryDialogPrimary(
                  label: context.l10n.personalTagMergeConfirm,
                  busy: isLoading,
                  onPressed: () async {
                    setState(() => isLoading = true);
                    // BUT-1188: the N-into-1 merge loop lives in the VM
                    // (mergeTagsInto) so it's unit-testable; the success
                    // metric is tags-merged, not a recipe count (the old
                    // per-merge sum over-reported recipes carrying two
                    // merged tags).
                    final sources = selectedTags
                        .where((t) => t.id != targetId)
                        .map((t) => t.id)
                        .toList();
                    try {
                      final merged = await viewModel.mergeTagsInto(
                        targetId,
                        sources,
                      );
                      await viewModel.loadTagStatistics();

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      selection.exitSelection();

                      if (!context.mounted) return;
                      SnackBarUtils.showSuccess(
                        context,
                        context.l10n.personalTagMergeSuccessCount(
                          merged,
                        ),
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);

                      if (!context.mounted) return;
                      SnackBarUtils.showUserFriendlyError(context, e);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Bulk-delete confirmation for the selected tags.
  static Future<void> showBulkDeleteDialog(
    BuildContext context,
    List<PersonalTag> selectedTags,
  ) async {
    if (selectedTags.isEmpty) return;

    final viewModel = context.read<PersonalTagViewModel>();
    final selection = context.read<PersonalTagSelectionManager>();
    final ids = selectedTags.map((t) => t.id).toList();
    PersonalTagBulkDeleteResult? result;
    final confirmed = await DestructiveConfirmationDialog.show(
      context,
      title: context.l10n.personalTagBulkDeleteTitle(ids.length),
      message: context.l10n.personalTagBulkDeleteMessage(ids.length),
      warning: selectedTags.any((t) => t.isCookbook)
          ? context.l10n.cookbookDeleteTagWarning
          : null,
      primaryActionText: context.l10n.personalTagBulkDeleteAction(ids.length),
      onConfirm: () async {
        selection.clearPartialDelete();
        result = await viewModel.bulkDeleteTags(ids);
        await viewModel.loadTagStatistics();
      },
    );
    final outcome = result;
    if (confirmed != true || outcome == null || !context.mounted) return;

    // P5-U33: all went is a success; some went is
    // the third outcome, shown by the list with the rest still selected; none
    // went is a failure that keeps the selection.
    if (outcome.isComplete) {
      selection.exitSelection();
      SnackBarUtils.showSuccess(
        context,
        context.l10n.personalTagBulkDeleted(outcome.deletedIds.length),
      );
    } else if (outcome.isPartial) {
      final deleted = outcome.deletedIds.toSet();
      selection.showPartialDelete(
        outcome,
        deletedNames: [
          for (final t in selectedTags)
            if (deleted.contains(t.id)) t.name,
        ],
      );
    } else {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.personalTagBulkDeleteNone,
        preserved: context.l10n.selectionFailedKept,
      );
    }
  }
}
