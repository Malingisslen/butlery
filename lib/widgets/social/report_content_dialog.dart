import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Reusable report dialog for any content type.
///
/// Usage:
/// ```dart
/// ReportContentDialog.show(
///   context: context,
///   contentType: ContentType.recipe,
///   contentId: recipe.id,
///   contentOwnerId: recipe.userId,
/// );
/// ```
class ReportContentDialog {
  static Future<void> show({
    required BuildContext context,
    required ContentType contentType,
    required String contentId,
    String? contentOwnerId,
  }) async {
    final outcome = await _showReasonDialog(context);
    if (outcome == null || !context.mounted) return;

    try {
      final reportService = ServiceLocator.get<ReportService>();
      final success = await reportService.submitReport(
        contentType: contentType,
        contentId: contentId,
        reason: outcome.reason,
        contentOwnerId: contentOwnerId,
        description: outcome.description,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? context.l10n.reportSubmitted
                  : context.l10n.reportSubmitFailed,
            ),
            backgroundColor: success
                ? context.butleryColors.success
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.reportSubmitFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  static Future<_ReportOutcome?> _showReasonDialog(BuildContext context) async {
    String? selectedReason;
    final descriptionController = TextEditingController();

    final l10n = context.l10n;
    final reasons = [
      l10n.reportReasonInappropriate,
      l10n.reportReasonSpam,
      l10n.reportReasonHarassment,
      l10n.reportReasonCopyright,
      l10n.reportReasonOther,
    ];
    final otherLabel = l10n.reportReasonOther;

    final result = await showDialog<_ReportOutcome>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // BUT-531: when "Other" is selected, surface a TextField so the
          // reporter can describe the issue. Required when "Other" is chosen
          // (Google Play appeal policy expects a reporter description); the
          // submit button stays disabled until non-empty.
          final isOther = selectedReason == otherLabel;
          final descriptionFilled = descriptionController.text
              .trim()
              .isNotEmpty;
          final canSubmit =
              selectedReason != null && (!isOther || descriptionFilled);

          return AlertDialog(
            title: Text(l10n.reportDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (value) => setState(() => selectedReason = value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: reasons
                        .map(
                          (reason) => RadioListTile<String>(
                            title: Text(reason),
                            value: reason,
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (isOther) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    autofocus: true,
                    maxLength: 500,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.reportDescriptionHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _GuidelinesNote(
                  prefix: l10n.reportDialogGuidelinesNotePrefix,
                  linkText: l10n.reportDialogGuidelinesLink,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: canSubmit
                    ? () => Navigator.pop(
                        context,
                        _ReportOutcome(
                          reason: selectedReason!,
                          description: isOther
                              ? descriptionController.text.trim()
                              : null,
                        ),
                      )
                    : null,
                child: Text(l10n.reportSubmit),
              ),
            ],
          );
        },
      ),
    );

    descriptionController.dispose();
    return result;
  }
}

class _ReportOutcome {
  const _ReportOutcome({required this.reason, this.description});

  final String reason;
  final String? description;
}

/// Inline note linking to community guidelines from the report dialog.
/// Tap on the linked phrase opens the guidelines view; the visible
/// version is implicitly the version stamped on the resulting report record.
class _GuidelinesNote extends StatelessWidget {
  const _GuidelinesNote({required this.prefix, required this.linkText});

  final String prefix;
  final String linkText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    return Text.rich(
      TextSpan(
        style: base.copyWith(color: base.color?.withValues(alpha: 0.75)),
        children: [
          TextSpan(text: '$prefix '),
          // BUT-1446: WidgetSpan + Semantics(link:) so the guidelines link is
          // announced as a link with a name (was an inline TapGestureRecognizer
          // — no link role, invisible to the a11y audit scanner). Dropping the
          // recognizer also lets this be a StatelessWidget.
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Semantics(
              link: true,
              label: linkText,
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context).pushNamed(Routes.communityGuidelines),
                child: Text(
                  linkText,
                  style: base.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
