import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';

const String appealMailAddress = 'overklagande@butlery.se';

/// The prefilled body for appealing one report. Takes only the four values the
/// mail may carry, so a report's free text, content id and owner id cannot
/// reach it.
String buildReportAppealBody(
  AppLocalizations l10n, {
  required String reportId,
  required String date,
  required String reason,
  required String outcome,
}) => l10n.myReportsAppealBody(reportId, date, reason, outcome);

Uri buildAppealMailUri({required String subject, required String body}) => Uri(
  scheme: 'mailto',
  path: appealMailAddress,
  queryParameters: {'subject': subject, 'body': body},
);

/// Opens the mail app on [uri]; a snackbar tells the user if that fails.
Future<void> launchAppealMail(BuildContext context, Uri uri) async {
  try {
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.appealEmailLaunchFailed,
      );
    }
  } catch (e) {
    AppLogger.error('[AppealMail] Failed to launch appeal mailto', e);
    if (context.mounted) {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.appealEmailLaunchFailed,
      );
    }
  }
}
