/// BUT-1185: merge + bulk-delete dialogs for the multi-select flow on the
/// personal-tags screen.
///
/// Kept in a separate file from [PersonalTagDialogs] (already 800+ lines, an
/// accepted large file) to stay under the 500-line limit. The public API is
/// re-exposed via thin delegators on [PersonalTagDialogs].
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final targetTag = selectedTags.firstWhere((t) => t.id == targetId);
            return AlertDialog(
              title: Text(context.l10n.personalTagMergeTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.personalTagMergeMessage(
                      selectedTags.length, targetTag.name)),
                  const SizedBox(height: AppDimensions.spacingM),
                  Text(context.l10n.personalTagMergeKeepLabel),
                  const SizedBox(height: AppDimensions.spacingXs),
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
                            for (final tag in selectedTags)
                              RadioListTile<String>(
                                value: tag.id,
                                title: Text(tag.name),
                                contentPadding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
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
                              context.l10n.personalTagMergeSuccessCount(merged),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            if (!context.mounted) return;
                            SnackBarUtils.showUserFriendlyError(context, e);
                          }
                        },
                  child: isLoading
                      ? const LoadingIndicator(size: 16, strokeWidth: 2)
                      : Text(context.l10n.personalTagMergeConfirm),
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.personalTagBulkDeleteTitle(ids.length)),
            content: Text(
              context.l10n.personalTagBulkDeleteMessage(ids.length),
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);
                        try {
                          final deleted = await viewModel.bulkDeleteTags(ids);
                          await viewModel.loadTagStatistics();

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          selection.exitSelection();

                          if (!context.mounted) return;
                          SnackBarUtils.showSuccess(
                            context,
                            context.l10n.personalTagBulkDeleted(deleted),
                          );
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showUserFriendlyError(context, e);
                        }
                      },
                child: isLoading
                    ? const LoadingIndicator(size: 16, strokeWidth: 2)
                    : Text(context.l10n.commonDelete),
              ),
            ],
          ),
        );
      },
    );
  }
}
