// lib/widgets/recipe/draft_recovery_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Dialog for recovering unsaved recipe drafts.
/// Shows available drafts with metadata and allows user to:
/// - Recover a specific draft
/// - Discard all drafts and start fresh
/// - Cancel and continue without recovery
class DraftRecoveryDialog extends StatelessWidget {
  final List<DraftMetadata> drafts;
  final void Function(String draftId) onRecover;
  final VoidCallback onDiscardAll;
  final VoidCallback onCancel;

  const DraftRecoveryDialog({
    super.key,
    required this.drafts,
    required this.onRecover,
    required this.onDiscardAll,
    required this.onCancel,
  });

  /// Show the draft recovery dialog if drafts are available.
  /// Returns the selected draft ID to recover, or null if user chose to skip.
  static Future<String?> showIfDraftsAvailable(
    BuildContext context,
    List<DraftMetadata> drafts, {
    VoidCallback? onDiscardAll,
  }) async {
    if (drafts.isEmpty) return null;

    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DraftRecoveryDialog(
        drafts: drafts,
        onRecover: (draftId) => Navigator.of(context).pop(draftId),
        onDiscardAll: () {
          onDiscardAll?.call();
          Navigator.of(context).pop(null);
        },
        onCancel: () => Navigator.of(context).pop(null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.restore,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppDimensions.width12),
          Expanded(
            child: Text(context.l10n.draftUnsavedFound),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.draftContinueEditing,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: drafts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final draft = drafts[index];
                  return _DraftListTile(
                    draft: draft,
                    onTap: () => onRecover(draft.draftId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDiscardAll,
          child: Text(
            context.l10n.draftDiscardAll,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: onCancel,
          child: Text(context.l10n.draftStartFresh),
        ),
      ],
    );
  }
}

class _DraftListTile extends StatelessWidget {
  final DraftMetadata draft;
  final VoidCallback onTap;

  const _DraftListTile({
    required this.draft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draftTitle =
        draft.title.isNotEmpty ? draft.title : context.l10n.draftUnnamedRecipe;

    return Semantics(
      label: context.l10n.a11yDraftRecoverTile(draftTitle),
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppDimensions.paddingSymmetric4x12,
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: AppDimensions.iconSizeM,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.width12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draftTitle,
                      style: AppTextStyles.contentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      '${context.l10n.draftFieldsFilledCount(draft.fieldCount)} • ${draft.timeAgo}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mixin to add draft recovery capability to recipe form screens.
/// Use in StatefulWidget that manages recipe form initialization.
mixin DraftRecoveryMixin<T extends StatefulWidget> on State<T> {
  /// Check for available drafts and show recovery dialog if any exist.
  /// Call this in initState or after widget is built.
  Future<void> checkAndOfferDraftRecovery({
    required Future<List<DraftMetadata>> Function() getDrafts,
    required Future<void> Function(String draftId) onRecover,
    required Future<void> Function() onDiscardAll,
  }) async {
    // Wait for next frame to ensure context is available
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final drafts = await getDrafts();
    if (drafts.isEmpty || !mounted) return;

    final selectedDraftId = await DraftRecoveryDialog.showIfDraftsAvailable(
      context,
      drafts,
      onDiscardAll: () async {
        await onDiscardAll();
      },
    );

    if (selectedDraftId != null && mounted) {
      await onRecover(selectedDraftId);
    }
  }
}
