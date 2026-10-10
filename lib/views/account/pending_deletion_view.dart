// lib/views/account/pending_deletion_view.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/account/pending_deletion_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/profile/dialogs/deletion_schedule_dialogs.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

/// Shown instead of the app when a signed-in user's account is scheduled for
/// deletion (BUT-950): when it happens, and the way out.
class PendingDeletionView extends StatefulWidget {
  const PendingDeletionView({
    super.key,
    required this.scheduledFor,
    required this.onUndone,
  });

  final DateTime scheduledFor;

  /// Called once the deletion is cancelled, so the caller can open the app.
  final VoidCallback onUndone;

  @override
  State<PendingDeletionView> createState() => _PendingDeletionViewState();
}

class _PendingDeletionViewState extends State<PendingDeletionView> {
  late final PendingDeletionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<PendingDeletionViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _undo() async {
    final status = await _viewModel.undo();
    if (!mounted) return;
    final l10n = context.l10n;
    switch (status) {
      case DeletionScheduleStatus.ok:
        widget.onUndone();
      case DeletionScheduleStatus.deletionInProgress:
        SnackBarUtils.showFailure(
          context,
          what: l10n.pendingDeletionAlreadyStarted,
        );
      case DeletionScheduleStatus.network:
        SnackBarUtils.showFailure(
          context,
          what: l10n.pendingDeletionUndoFailed,
          preserved: l10n.errorNetwork,
        );
      case DeletionScheduleStatus.requiresReauth:
      case DeletionScheduleStatus.failed:
        SnackBarUtils.showFailure(
          context,
          what: l10n.pendingDeletionUndoFailed,
        );
    }
  }

  Future<void> _deleteNow() async {
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: context.l10n.pendingDeletionDeleteNowConfirmTitle,
          message: context.l10n.pendingDeletionDeleteNowConfirmBody,
          confirmText: context.l10n.pendingDeletionDeleteNow,
          cancelText: context.l10n.commonCancel,
        );
    if (!confirmed || !mounted) return;

    var outcome = await _viewModel.deleteNow();
    if (outcome != null && outcome.requiresReauth && mounted) {
      // A step, not an error: sign in again and the request is made again.
      final again = await ProfileDialogs.showDeletionReauthStep(context);
      if (!again || !mounted) return;
      String? reauthError;
      final reauthed = await AuthActionHandler.reauthenticate(
        context,
        onError: (msg) => reauthError = msg,
      );
      if (!reauthed || !mounted) {
        if (reauthError != null && mounted) _showDeleteFailed(reauthError);
        return;
      }
      outcome = await _viewModel.deleteNow();
    }
    // A finished deletion signs out inside the service, which replaces this
    // screen with the sign-in screen; there is nothing left to do here.
    if (!mounted) return;
    if (outcome == null || (!outcome.isComplete && !outcome.isPartial)) {
      _showDeleteFailed(null);
    } else if (outcome.isPartial) {
      await ProfileDialogs.showPartialDeletionDialog(
        context,
        failedCount: outcome.genuinelyFailed.length,
        auditLogId: outcome.auditLogId,
        onContactSupport: (id) =>
            AuthActionHandler.contactSupportAboutDeletion(context, id),
      );
    }
  }

  void _showDeleteFailed(String? cause) {
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.profileAccountDeleteFailed,
      preserved: cause,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final date = DeletionScheduleDialogs.formatDate(
      context,
      widget.scheduledFor,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  final busy = _viewModel.isLoading;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ButleryIcon(
                          ButleryIcons.triangleAlert,
                          size: AppDimensions.iconSizeXxl,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      Text(
                        l10n.pendingDeletionTitle,
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: cs.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spacingM),
                      Text(
                        l10n.pendingDeletionBody(date),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      if (busy)
                        Center(
                          child: PlateLineMessage(
                            message: l10n.accountDeletingProgress,
                          ),
                        )
                      else ...[
                        ActionButtons.primaryButton(
                          context,
                          label: l10n.pendingDeletionUndo,
                          onPressed: _undo,
                          isExpanded: true,
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        ActionButtons.outlinedButton(
                          context,
                          label: l10n.pendingDeletionDeleteNow,
                          onPressed: _deleteNow,
                          isExpanded: true,
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        ActionButtons.textButton(
                          context,
                          label: l10n.profileLogout,
                          onPressed: () =>
                              AuthActionHandler.handleLogout(context),
                          isExpanded: true,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
