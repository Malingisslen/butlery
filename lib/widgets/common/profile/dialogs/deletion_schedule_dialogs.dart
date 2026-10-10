// lib/widgets/common/profile/dialogs/deletion_schedule_dialogs.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// Dialogs for scheduling an account deletion (BUT-950). Kept apart from
/// `ProfileDialogs`, which is already past the file-size limit.
class DeletionScheduleDialogs {
  /// The date as the user reads it, in the app's language.
  static String formatDate(BuildContext context, DateTime date) =>
      DateFormat.yMMMMd(Localizations.localeOf(context).languageCode).format(
        date,
      );

  /// Cannot be closed while the request is in flight. Unlike the immediate
  /// deletion's wait there is no nine-minute notice: scheduling is one call.
  static void showSchedulingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          key: const ValueKey('accountDeletion.scheduling'),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: PlateLineMessage(
              message: dialogContext.l10n.accountDeletionScheduling,
            ),
          ),
        ),
      ),
    );
  }

  /// Tells the user when the account goes and that signing in before then
  /// undoes it. [scheduledFor] is null only when the server sent no date.
  static Future<void> showScheduledDialog(
    BuildContext context, {
    required DateTime? scheduledFor,
  }) {
    final l10n = context.l10n;
    final body = scheduledFor == null
        ? l10n.accountDeletionScheduledBodyNoDate
        : l10n.accountDeletionScheduledBody(formatDate(context, scheduledFor));
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('accountDeletion.scheduled'),
        title: Text(l10n.accountDeletionScheduledTitle),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
