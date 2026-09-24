// lib/widgets/common/dialogs/session_timeout_warning_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';

/// Warning dialog shown before session timeout
/// Provides user with option to extend session or logout immediately
///
/// Two modes (produktregler.md:832, § 16.2). With an empty queue it is the
/// plain question and "Logga ut nu" signs out at once. With changes waiting,
/// Fortsätt is primary, the waiting changes are named, and "Logga ut nu"
/// leads to the same confirmation as the manual sign-out (#utloggningko).
/// Only its destructive choice throws the queue away; "Vänta på synk" keeps
/// the session going.
class SessionTimeoutWarningDialog extends StatefulWidget {
  /// Remaining seconds until automatic logout
  final int remainingSeconds;

  /// Callback when user chooses to extend session
  final VoidCallback onExtendSession;

  /// Callback when user chooses to logout immediately (empty queue)
  final VoidCallback onLogoutNow;

  /// The signed-in user's unsaved changes when the warning opened.
  final PendingChanges pendingChanges;

  /// Callback when the user chose "Logga ut och släng ändringarna" in the
  /// queue confirmation. Required for the queue mode to offer a sign-out.
  final Future<void> Function()? onDiscardAndLogout;

  const SessionTimeoutWarningDialog({
    super.key,
    required this.remainingSeconds,
    required this.onExtendSession,
    required this.onLogoutNow,
    this.pendingChanges = PendingChanges.none,
    this.onDiscardAndLogout,
  });

  /// Show the session timeout warning dialog
  static Future<bool?> show({
    required BuildContext context,
    required int remainingSeconds,
    required VoidCallback onExtendSession,
    required VoidCallback onLogoutNow,
    PendingChanges pendingChanges = PendingChanges.none,
    Future<void> Function()? onDiscardAndLogout,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => SessionTimeoutWarningDialog(
        remainingSeconds: remainingSeconds,
        onExtendSession: onExtendSession,
        onLogoutNow: onLogoutNow,
        pendingChanges: pendingChanges,
        onDiscardAndLogout: onDiscardAndLogout,
      ),
    );
  }

  @override
  State<SessionTimeoutWarningDialog> createState() =>
      _SessionTimeoutWarningDialogState();
}

class _SessionTimeoutWarningDialogState
    extends State<SessionTimeoutWarningDialog> {
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.remainingSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds <= 0) {
          timer.cancel();
          if (mounted) {
            Navigator.of(context).pop(false); // Timeout expired
          }
        }
      },
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _handleExtendSession() {
    _countdownTimer?.cancel();
    widget.onExtendSession();
    Navigator.of(context).pop(true); // Extended
  }

  bool get _queueMode => !widget.pendingChanges.isEmpty;

  Future<void> _handleLogoutNow() async {
    if (!_queueMode) {
      _countdownTimer?.cancel();
      widget.onLogoutNow();
      Navigator.of(context).pop(false); // Logging out
      return;
    }

    // Queue mode: the same confirmation as the manual sign-out. The
    // countdown keeps running underneath; if it runs out, the automatic
    // sign-out still never clears the queue (produktregler.md:833).
    final choice = await ProfileDialogs.showPendingChangesDialog(
      context,
      widget.pendingChanges,
    );
    if (!mounted) return;
    if (choice == PendingChangesChoice.discardAndSignOut &&
        widget.onDiscardAndLogout != null) {
      _countdownTimer?.cancel();
      Navigator.of(context).pop(false); // Logging out
      await widget.onDiscardAndLogout!();
      return;
    }
    // "Vänta på synk": staying signed in is what waiting means here.
    _handleExtendSession();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warningColor = context.butleryColors.warning;
    return AlertDialog(
      icon: Icon(
        Icons.timer_outlined,
        color: warningColor,
        size: AppDimensions.iconSizeXxl,
      ),
      title: Text(context.l10n.sessionExpiringTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.sessionExpiringMessage,
            style: AppTextStyles.bodyLarge,
          ),
          if (_queueMode) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              context.l10n.sessionPendingChangesIntro(
                widget.pendingChanges.total,
              ),
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            ...ProfileDialogs.pendingChangeLines(
              context,
              widget.pendingChanges,
            ),
          ],
          const SizedBox(height: AppDimensions.spacingM),
          // Only the number updates, announced politely
          // (produktregler.md:830).
          Center(
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingL,
                  vertical: AppDimensions.spacingM,
                ),
                decoration: BoxDecoration(
                  color: warningColor.withValues(
                    alpha: AppDimensions.opacityVeryLight,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusM,
                  ),
                  border: Border.all(
                    color: warningColor.withValues(
                      alpha: AppDimensions.opacityMediumLight,
                    ),
                    width: 2,
                  ),
                ),
                child: Text(
                  _formatDuration(_remainingSeconds),
                  style: AppTextStyles.headlineBold.copyWith(
                    color: warningColor,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            context.l10n.sessionContinueOrLogout,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('sessionTimeout.logoutNow'),
          onPressed: _handleLogoutNow,
          child: Text(
            context.l10n.commonLogoutNow,
            style: AppTextStyles.labelLarge.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          key: const ValueKey('sessionTimeout.continue'),
          onPressed: _handleExtendSession,
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
          ),
          child: Text(
            context.l10n.sessionContinue,
            style: AppTextStyles.labelLarge.copyWith(
              color: cs.surfaceContainerHighest,
            ),
          ),
        ),
      ],
    );
  }
}
