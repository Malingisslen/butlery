// lib/widgets/common/dialogs/draft_recovery_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';

/// Dialog for recovering auto-saved recipe drafts with Swedish localization
class DraftRecoveryDialog extends StatelessWidget {
  final List<DraftMetadata> availableDrafts;

  const DraftRecoveryDialog({
    super.key,
    required this.availableDrafts,
  });

  /// Show draft recovery dialog
  static Future<String?> show(
    BuildContext context,
    List<DraftMetadata> availableDrafts,
  ) async {
    if (availableDrafts.isEmpty) return null;

    return showDialog<String?>(
      context: context,
      barrierDismissible: false, // Force user to make choice
      builder: (context) =>
          DraftRecoveryDialog(availableDrafts: availableDrafts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.restore,
        color: Theme.of(context).colorScheme.primary,
        size: AppDimensions.iconSizeL,
      ),
      title: Text(
        context.l10n.draftRecovery,
        style: AppTextStyles.headlineSmall,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.draftRecoverySubtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),

          // Draft list
          Container(
            constraints: const BoxConstraints(
              maxHeight: 300, // Limit height for many drafts
              minWidth: 280,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: availableDrafts
                    .map((draft) => _buildDraftTile(context, draft))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Secondary action - Start fresh
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: Text(context.l10n.draftStartFresh),
        ),

        // Primary action - Restore most recent
        FilledButton.icon(
          onPressed: availableDrafts.isNotEmpty
              ? () => Navigator.of(context).pop(availableDrafts.first.draftId)
              : null,
          icon: const Icon(Icons.restore, size: AppDimensions.iconSizeS),
          label: Text(context.l10n.draftRestore),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  /// Build individual draft tile
  Widget _buildDraftTile(BuildContext context, DraftMetadata draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        onTap: () => Navigator.of(context).pop(draft.draftId),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            children: [
              // Recipe icon
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: AppDimensions.opacityVeryLight),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Icon(
                  Icons.article_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: AppDimensions.iconSizeM,
                ),
              ),

              const SizedBox(width: AppDimensions.spacingM),

              // Draft details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      draft.title.isEmpty
                          ? context.l10n.draftUnnamedRecipe
                          : draft.title,
                      style: AppTextStyles.contentTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: AppDimensions.spacingXxs),

                    // Metadata (time and field count)
                    Text(
                      '${draft.timeAgo} • ${context.l10n.draftFieldsFilledCount(draft.fieldCount)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              Icon(
                Icons.arrow_forward_ios,
                size: AppDimensions.iconSizeS,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension for easy dialog access
extension DraftRecoveryDialogExtension on BuildContext {
  /// Show draft recovery dialog
  Future<String?> showDraftRecovery(List<DraftMetadata> availableDrafts) {
    return DraftRecoveryDialog.show(this, availableDrafts);
  }
}
