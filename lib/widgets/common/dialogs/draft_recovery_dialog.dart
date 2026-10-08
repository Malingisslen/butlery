// lib/widgets/common/dialogs/draft_recovery_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Dialog for recovering auto-saved recipe drafts with Swedish localization
class DraftRecoveryDialog extends StatelessWidget {
  final List<DraftMetadata> availableDrafts;

  /// Shows "Släng" (one draft) or "Släng alla", the only choice that deletes
  /// (produktregler.md:171-172). The dialog then pops with null, as
  /// "Börja om" does, which keeps the drafts.
  final VoidCallback? onDiscardAll;

  const DraftRecoveryDialog({
    super.key,
    required this.availableDrafts,
    this.onDiscardAll,
  });

  /// Show draft recovery dialog
  static Future<String?> show(
    BuildContext context,
    List<DraftMetadata> availableDrafts, {
    VoidCallback? onDiscardAll,
  }) async {
    if (availableDrafts.isEmpty) return null;

    return showDialog<String?>(
      context: context,
      barrierDismissible: false, // Force user to make choice
      builder: (context) => DraftRecoveryDialog(
        availableDrafts: availableDrafts,
        onDiscardAll: onDiscardAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: ButleryIcon(
        ButleryIcons.history,
        color: Theme.of(context).colorScheme.onSurface,
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
        if (onDiscardAll != null)
          TextButton(
            onPressed: () {
              onDiscardAll!();
              Navigator.of(context).pop(null);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              availableDrafts.length == 1
                  ? context.l10n.draftDiscard
                  : context.l10n.draftDiscardAll,
            ),
          ),

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
          icon: const ButleryIcon(
            ButleryIcons.history,
            size: AppDimensions.iconSizeS,
          ),
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
    final draftTitle = draft.title.isEmpty
        ? context.l10n.draftUnnamedRecipe
        : draft.title;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.space4),
      child: Semantics(
        label: context.l10n.a11yDraftRecoverTile(draftTitle),
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          onTap: () => Navigator.of(context).pop(draft.draftId),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingS),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
                  ),
                  child: ButleryIcon(
                    Icons.article_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draftTitle,
                        style: AppTextStyles.contentTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      Text(
                        // How long the draft is kept, not only when it
                        // was written (Skarmar v12 etapp 4 #editorutkastval;
                        // 30 days, ux-beslut.json D-01).
                        '${draft.timeAgo} · ${context.l10n.draftFieldsFilledCount(draft.fieldCount)} · ${draftTimeLeftLabel(context, draft.timeLeft)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ButleryIcon(
                  ButleryIcons.chevronRight,
                  size: AppDimensions.iconSizeS,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension for easy dialog access
extension DraftRecoveryDialogExtension on BuildContext {
  /// Show draft recovery dialog
  Future<String?> showDraftRecovery(
    List<DraftMetadata> availableDrafts, {
    VoidCallback? onDiscardAll,
  }) {
    return DraftRecoveryDialog.show(
      this,
      availableDrafts,
      onDiscardAll: onDiscardAll,
    );
  }
}

/// "finns kvar i 23 dagar", or hours on the last day: the row says how long
/// the draft is still kept (Skarmar v12 etapp 4 #editorutkastval).
String draftTimeLeftLabel(BuildContext context, Duration left) {
  if (left.inDays >= 1) return context.l10n.draftTimeLeftDays(left.inDays);
  final hours = left.inHours < 1 ? 1 : left.inHours;
  return context.l10n.draftTimeLeftHours(hours);
}
