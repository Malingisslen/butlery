import 'package:flutter/material.dart';
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
            content: Text(success
                ? context.l10n.reportSubmitted
                : context.l10n.reportSubmitFailed),
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
          final descriptionFilled =
              descriptionController.text.trim().isNotEmpty;
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
                        .map((reason) => RadioListTile<String>(
                              title: Text(reason),
                              value: reason,
                            ))
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
