// lib/views/recipe_detail/recipe_source_artefact_sheet.dart

import 'package:flutter/material.dart';
import 'package:clock/clock.dart';

import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// BUT-1079 + BUT-1205: bottom sheet showing the persisted source artefact (the
/// raw text/URL the recipe was extracted from), with a stale-source banner
/// (>30 days) and a "re-extract" action.
///
/// Extracted from recipe_detail_view.dart (BUT-1205 size cleanup). The sheet is
/// purely presentational: the re-extract business flow (confirm dialog →
/// ViewModel.reextractFromSource → snackbar feedback) lives in the View and is
/// passed in via [onReextract], which fires after the sheet closes.
void showSourceArtefactSheet({
  required BuildContext context,
  required SourceArtefact artefact,
  required Future<void> Function() onReextract,
}) {
  final cs = Theme.of(context).colorScheme;
  // BUT-1205: a captured source older than 30 days may no longer match what a
  // fresh extraction would produce (site changed, transcript revised) — warn
  // before the user re-extracts.
  final isStale =
      clock.now().difference(artefact.fetchedAt) > const Duration(days: 30);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.recipeSourceSheetTitle,
                style: AppTextStyles.titleBold),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${_sourceTypeLabel(ctx, artefact.type)} · '
              '${ctx.l10n.recipeSourceCapturedAt(ContextualTimeFormatter.standard(artefact.fetchedAt))}',
              style: AppTextStyles.metadataEmphasized
                  .copyWith(color: cs.onSurfaceVariant),
            ),
            if (isStale) ...[
              const SizedBox(height: AppDimensions.spacingM),
              _StaleSourceBanner(message: ctx.l10n.recipeSourceStaleBanner),
            ],
            const Divider(height: AppDimensions.spacingLg),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: SelectableText(
                  artefact.payload,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh_outlined,
                    size: AppDimensions.iconSizeM),
                label: Text(ctx.l10n.recipeSourceReextract),
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await onReextract();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _sourceTypeLabel(BuildContext context, SourceArtefactType type) {
  return switch (type) {
    SourceArtefactType.url => context.l10n.recipeSourceTypeUrl,
    SourceArtefactType.youtubeTranscript =>
      context.l10n.recipeSourceTypeYoutube,
    SourceArtefactType.tiktokCaption => context.l10n.recipeSourceTypeTiktok,
    SourceArtefactType.instagramCaption =>
      context.l10n.recipeSourceTypeInstagram,
    SourceArtefactType.textPaste => context.l10n.recipeSourceTypeTextPaste,
    SourceArtefactType.photoOcr => context.l10n.recipeSourceTypePhotoOcr,
  };
}

/// BUT-1205: advisory banner shown in the source sheet when the captured
/// source is older than 30 days — a fresh re-extraction may diverge.
class _StaleSourceBanner extends StatelessWidget {
  const _StaleSourceBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final warning = context.butleryColors.warning;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: warning, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_outlined,
              size: AppDimensions.iconSizeM, color: warning),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(message, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}
