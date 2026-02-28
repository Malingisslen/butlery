import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Reusable report dialog for any content type.
///
/// Usage:
/// ```dart
/// ReportContentDialog.show(
///   context: context,
///   contentType: 'recipe',
///   contentId: recipe.id,
///   contentOwnerId: recipe.userId,
/// );
/// ```
class ReportContentDialog {
  static Future<void> show({
    required BuildContext context,
    required String contentType,
    required String contentId,
    String? contentOwnerId,
  }) async {
    final reason = await _showReasonDialog(context);
    if (reason == null || !context.mounted) return;

    try {
      final reportService = ServiceLocator.get<ReportService>();
      final success = await reportService.submitReport(
        contentType: contentType,
        contentId: contentId,
        reason: reason,
        contentOwnerId: contentOwnerId,
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

  static Future<String?> _showReasonDialog(BuildContext context) async {
    String? selectedReason;

    final reasons = [
      context.l10n.reportReasonInappropriate,
      context.l10n.reportReasonSpam,
      context.l10n.reportReasonHarassment,
      context.l10n.reportReasonCopyright,
      context.l10n.reportReasonOther,
    ];

    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.reportDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((reason) => RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (value) =>
                          setState(() => selectedReason = value),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () => Navigator.pop(context, selectedReason)
                  : null,
              child: Text(context.l10n.reportSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
