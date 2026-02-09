// lib/widgets/common/dialogs/session_timeout_warning_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Warning dialog shown before session timeout
/// Provides user with option to extend session or logout immediately
class SessionTimeoutWarningDialog extends StatefulWidget {
  /// Remaining seconds until automatic logout
  final int remainingSeconds;

  /// Callback when user chooses to extend session
  final VoidCallback onExtendSession;

  /// Callback when user chooses to logout immediately
  final VoidCallback onLogoutNow;

  const SessionTimeoutWarningDialog({
    super.key,
    required this.remainingSeconds,
    required this.onExtendSession,
    required this.onLogoutNow,
  });

  /// Show the session timeout warning dialog
  static Future<bool?> show({
    required BuildContext context,
    required int remainingSeconds,
    required VoidCallback onExtendSession,
    required VoidCallback onLogoutNow,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => SessionTimeoutWarningDialog(
        remainingSeconds: remainingSeconds,
        onExtendSession: onExtendSession,
        onLogoutNow: onLogoutNow,
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

  void _handleLogoutNow() {
    _countdownTimer?.cancel();
    widget.onLogoutNow();
    Navigator.of(context).pop(false); // Logging out
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.timer_outlined,
        color: AppColors.warning,
        size: AppDimensions.iconSizeXxl,
      ),
      title: const Text('Session utgår snart'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Din session kommer att avslutas om:',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingL,
                vertical: AppDimensions.spacingM,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning
                    .withValues(alpha: AppDimensions.opacityVeryLight),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusM),
                border: Border.all(
                  color: AppColors.warning
                      .withValues(alpha: AppDimensions.opacityMediumLight),
                  width: 2,
                ),
              ),
              child: Text(
                _formatDuration(_remainingSeconds),
                style: AppTextStyles.headlineBold.copyWith(
                  color: AppColors.warning,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            'Vill du fortsätta din session eller logga ut nu?',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _handleLogoutNow,
          child: Text(
            'Logga ut nu',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        FilledButton(
          onPressed: _handleExtendSession,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forestGreen,
          ),
          child: Text(
            'Fortsätt session',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.cardWhite,
            ),
          ),
        ),
      ],
    );
  }
}
