import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/theme_constants.dart';

/// BUT-406: Square, cream-bg widget shown in the bottom sheet triggered by
/// long-pressing a cooking-mode step. Drives a [StepTimerService] that the
/// caller owns — the widget re-attaches cleanly if the user reopens the
/// sheet while a timer is still running.
///
/// Visual spec:
/// - `colorScheme.surface` background, `colorScheme.onPrimaryContainer` numerals.
/// - Square container (plain `Container`, no `BorderRadius`).
/// - On expiry: `butleryColors.starGold` pulse via `AnimationController` running
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

  /// BUT-1242: id of the timer this widget drives. Defaults to the legacy
  /// single-timer slot so existing callers keep working unchanged. Pass a
  /// stable per-step id (e.g. the step index) to run concurrent timers.
  final String timerId;

  /// Initial duration seeded from [parseSwedishDuration] on the step text.
  /// Ignored when the service is already running or paused (re-entry case).
  final Duration initialDuration;

  /// Optional source phrase (e.g. `"Låt koka i 10 min"`) displayed as a
  /// hint under the timer so users know where the prefill came from. When
  /// null, no hint is shown. Also used as the timer's label for the
  /// active-timers overview and the expiry notification body.
  final String? sourcePhrase;

  /// Fired once when a running timer reaches zero. The sheet uses this to
  /// trigger haptics + snackbar; the widget itself only handles the visual
  /// pulse.
  final VoidCallback? onExpired;

  const StepTimerWidget({
    super.key,
    required this.service,
    required this.initialDuration,
    this.timerId = StepTimerService.defaultTimerId,
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
      if (widget.service.isRunningFor(widget.timerId) ||
          widget.service.isPausedFor(widget.timerId)) {
        return;
      }
      widget.service.startTimer(
        id: widget.timerId,
        duration: widget.initialDuration,
        label: widget.sourcePhrase.orEmpty(),
      );
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
      stream: widget.service.remainingFor(widget.timerId),
      initialData:
          widget.service.currentRemainingFor(widget.timerId) == Duration.zero
          ? widget.initialDuration
          : widget.service.currentRemainingFor(widget.timerId),
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? widget.initialDuration;
        final isRunning = widget.service.isRunningFor(widget.timerId);
        final isPaused = widget.service.isPausedFor(widget.timerId);
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLg),
            _TimerControls(
              isRunning: isRunning,
              isPaused: isPaused,
              isExpired: isExpired,
              onPause: () => widget.service.pauseTimer(widget.timerId),
              onResume: () => widget.service.resumeTimer(widget.timerId),
              onReset: () {
                _pulseController.stop();
                _hasFiredExpired = false;
                widget.service.resetTimer(widget.timerId);
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
    final cs = Theme.of(context).colorScheme;
    final starGold = context.butleryColors.starGold;
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final pulseAlpha = isExpired ? pulseController.value : 0.0;
        return Container(
          // Square — no BorderRadius per design system.
          color: Color.lerp(cs.surface, starGold, pulseAlpha),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacingLg,
            horizontal: AppDimensions.spacingMd,
          ),
          alignment: Alignment.center,
          child: Text(
            _formatRemaining(remaining),
            style: AppTextStyles.titleLarge.copyWith(
              color: cs.onPrimaryContainer,
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
            context: context,
            icon: Icons.pause,
            label: context.l10n.pauseTimer,
            onPressed: onPause,
          )
        else if (isPaused)
          _controlButton(
            context: context,
            icon: Icons.play_arrow,
            label: context.l10n.resumeTimer,
            onPressed: onResume,
          )
        else
          _controlButton(
            context: context,
            icon: Icons.play_arrow,
            label: context.l10n.resumeTimer,
            onPressed: null,
          ),
        _controlButton(
          context: context,
          icon: Icons.refresh,
          label: context.l10n.resetTimer,
          onPressed: onReset,
        ),
      ],
    );
  }

  Widget _controlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    final base = Theme.of(context).colorScheme.onPrimaryContainer;
    final color = enabled ? base : base.withValues(alpha: 0.4);
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
