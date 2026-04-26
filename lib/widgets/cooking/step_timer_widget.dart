import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/theme_constants.dart';

/// BUT-406: Square, cream-bg widget shown in the bottom sheet triggered by
/// long-pressing a cooking-mode step. Drives a [StepTimerService] that the
/// caller owns — the widget re-attaches cleanly if the user reopens the
/// sheet while a timer is still running.
///
/// Visual spec:
/// - `AppColors.cream` background, `AppColors.forestGreenDark` numerals.
/// - Square container (plain `Container`, no `BorderRadius`).
/// - On expiry: `AppColors.starGold` pulse via `AnimationController` running
///   `ThemeConstants.durationMedium` in reverse-repeat until the user
///   dismisses the sheet.
///
/// The widget has three visible states:
/// - **running** — shows remaining `mm:ss`, "Pausa" + "Återställ" buttons.
/// - **paused** — shows frozen remaining, "Återuppta" + "Återställ" buttons.
/// - **expired** — shows `00:00`, pulses gold, only "Återställ" is enabled.
class StepTimerWidget extends StatefulWidget {
  /// Service driving this widget. Must outlive the widget — reusing the DI
  /// singleton is the expected pattern so a running timer survives sheet
  /// re-opens.
  final StepTimerService service;

  /// Initial duration seeded from [parseSwedishDuration] on the step text.
  /// Ignored when the service is already running or paused (re-entry case).
  final Duration initialDuration;

  /// Optional source phrase (e.g. `"Låt koka i 10 min"`) displayed as a
  /// hint under the timer so users know where the prefill came from. When
  /// null, no hint is shown.
  final String? sourcePhrase;

  /// Fired once when a running timer reaches zero. The sheet uses this to
  /// trigger haptics + snackbar; the widget itself only handles the visual
  /// pulse.
  final VoidCallback? onExpired;

  const StepTimerWidget({
    super.key,
    required this.service,
    required this.initialDuration,
    this.sourcePhrase,
    this.onExpired,
  });

  @override
  State<StepTimerWidget> createState() => _StepTimerWidgetState();
}

class _StepTimerWidgetState extends State<StepTimerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _hasFiredExpired = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: ThemeConstants.durationMedium,
    );
    // Auto-start once at mount — no need to re-check on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.service.isRunning || widget.service.isPaused) return;
      widget.service.start(widget.initialDuration);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleExpiry() {
    if (_hasFiredExpired) return;
    _hasFiredExpired = true;
    // BUT-527: when the OS "Reduce Motion" setting is on, snap to the
    // expired end-state instead of looping the attention-grabbing pulse.
    // The static gold tint still conveys the expired state — see
    // `_TimerDisplay.build` where `pulseController.value` drives the
    // background colour lerp.
    if (isReducedMotion(context)) {
      _pulseController.value = 1.0;
    } else {
      _pulseController.repeat(reverse: true);
    }
    widget.onExpired?.call();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.service.remaining,
      initialData: widget.service.currentRemaining == Duration.zero
          ? widget.initialDuration
          : widget.service.currentRemaining,
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? widget.initialDuration;
        final isRunning = widget.service.isRunning;
        final isPaused = widget.service.isPaused;
        final isExpired = !isRunning && !isPaused && remaining == Duration.zero;

        // Only schedule the expiry post-frame on the first expired frame —
        // `_handleExpiry` self-guards via `_hasFiredExpired` anyway, so
        // the extra check here just avoids the wasted scheduling.
        if (isExpired && !_hasFiredExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _handleExpiry();
          });
        }

        return _buildSheetContent(
          context: context,
          remaining: remaining,
          isRunning: isRunning,
          isPaused: isPaused,
          isExpired: isExpired,
        );
      },
    );
  }

  Widget _buildSheetContent({
    required BuildContext context,
    required Duration remaining,
    required bool isRunning,
    required bool isPaused,
    required bool isExpired,
  }) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimerDisplay(
              remaining: remaining,
              pulseController: _pulseController,
              isExpired: isExpired,
            ),
            if (widget.sourcePhrase != null) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                context.l10n.timerDurationHint(widget.sourcePhrase!),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.forestGreenDark.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLg),
            _TimerControls(
              isRunning: isRunning,
              isPaused: isPaused,
              isExpired: isExpired,
              onPause: widget.service.pause,
              onResume: widget.service.resume,
              onReset: () {
                _pulseController.stop();
                _hasFiredExpired = false;
                widget.service.reset();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  final Duration remaining;
  final AnimationController pulseController;
  final bool isExpired;

  const _TimerDisplay({
    required this.remaining,
    required this.pulseController,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final pulseAlpha = isExpired ? pulseController.value : 0.0;
        return Container(
          // Square — no BorderRadius per design system.
          color: Color.lerp(
            AppColors.cream,
            AppColors.starGold,
            pulseAlpha,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacingLg,
            horizontal: AppDimensions.spacingMd,
          ),
          alignment: Alignment.center,
          child: Text(
            _formatRemaining(remaining),
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.forestGreenDark,
              fontSize: 56,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }

  static String _formatRemaining(Duration d) {
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _TimerControls extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final bool isExpired;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onReset;

  const _TimerControls({
    required this.isRunning,
    required this.isPaused,
    required this.isExpired,
    required this.onPause,
    required this.onResume,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (isRunning)
          _controlButton(
            icon: Icons.pause,
            label: context.l10n.pauseTimer,
            onPressed: onPause,
          )
        else if (isPaused)
          _controlButton(
            icon: Icons.play_arrow,
            label: context.l10n.resumeTimer,
            onPressed: onResume,
          )
        else
          _controlButton(
            icon: Icons.play_arrow,
            label: context.l10n.resumeTimer,
            onPressed: null,
          ),
        _controlButton(
          icon: Icons.refresh,
          label: context.l10n.resetTimer,
          onPressed: onReset,
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    final color = enabled
        ? AppColors.forestGreenDark
        : AppColors.forestGreenDark.withValues(alpha: 0.4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 32,
          color: color,
          onPressed: onPressed,
          icon: Icon(icon),
          tooltip: label,
        ),
        Text(
          label,
          style: AppTextStyles.bodyLarge.copyWith(color: color),
        ),
      ],
    );
  }
}
