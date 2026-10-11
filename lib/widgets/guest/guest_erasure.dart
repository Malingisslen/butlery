import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// A guest cannot sign back in, so leaving the guest account erases it at
/// once, with everything in it (BUT-920). Both ways out, signing out and
/// "Logga in i stället", come through here.
class GuestErasure {
  const GuestErasure._();

  static const Key progressKey = ValueKey('guestErasure.progress');

  /// The erasure itself; replaced in tests. The server erases immediately,
  /// and the service signs out once the server has answered.
  @visibleForTesting
  static Future<Map<String, dynamic>> Function(String reason) erase =
      (reason) => ServiceLocator.get<AccountDeletionService>()
          .deleteUserAccount(reason: reason);

  /// Asks before erasing. [body] says what is lost; the dialog adds that it
  /// cannot be undone.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final confirmed = await DestructiveConfirmationDialog.show(
      context,
      title: title,
      message: body,
      irreversible: true,
      primaryActionText: confirmLabel,
    );
    return confirmed ?? false;
  }

  /// Erases the guest and signs out. Returns whether the server erased it;
  /// when it did not, the guest is still signed in and has been told.
  static Future<bool> eraseAndSignOut(
    BuildContext context, {
    required String reason,
  }) async {
    final l10n = context.l10n;
    // showDialog uses the root navigator; the account page can sit in a
    // nested one (the Mer detail pane), which would pop the wrong route.
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          key: progressKey,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: PlateLineMessage(message: l10n.guestErasing),
          ),
        ),
      ),
    );

    var erased = false;
    try {
      final result = await erase(reason);
      // Once the server has answered the account is gone, or as gone as an
      // erasure gets, and the service has signed out.
      erased = result['cfCompleted'] == true;
    } catch (e) {
      AppLogger.error('Guest erasure failed', e);
    }
    navigator.pop();
    if (!erased && context.mounted) {
      SnackBarUtils.showFailure(context, what: l10n.guestEraseFailed);
    }
    return erased;
  }
}
