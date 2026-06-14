import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// BUT-1242: horizontally-scrolling strip of all running/paused step timers,
/// shown above the instruction list in cooking mode so the cook can glance at
/// every active countdown at once. Tapping a chip reopens that step's timer
/// sheet via [onTapTimer]. Renders nothing when no timers are active —
/// idle/expired entries are filtered out so the strip only ever shows live
/// countdowns.
///
/// Extracted from `cooking_mode_view.dart` (BUT-1283) into a public widget so
/// the strip's behaviour can be pinned by a focused widget test driving a real
/// [StepTimerService], rather than reaching into private view state.
class ActiveTimersStrip extends StatelessWidget {
  final StepTimerService service;
  final ValueChanged<int> onTapTimer;

  const ActiveTimersStrip({
    super.key,
    required this.service,
    required this.onTapTimer,
  });

  /// Maps a `step-<n>` timer id back to its step index, or null for ids that
  /// don't follow the convention (e.g. the legacy default timer).
  static int? stepIndexOf(String timerId) {
    const prefix = 'step-';
    if (!timerId.startsWith(prefix)) return null;
    return int.tryParse(timerId.substring(prefix.length));
  }

  static String _format(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<StepTimerEntry>>(
      stream: service.timers,
      initialData: service.currentTimers,
      builder: (context, snapshot) {
        final active = (snapshot.data ?? const <StepTimerEntry>[])
            .where((e) => e.isRunning || e.isPaused)
            .toList();
        if (active.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: cs.surface.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.spacingSm),
                child: Text(
                  context.l10n.cookingActiveTimersTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in active)
                        _TimerChip(
                          entry: entry,
                          time: _format(entry.remaining),
                          onTap: () {
                            final index = stepIndexOf(entry.id);
                            if (index != null) onTapTimer(index);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimerChip extends StatelessWidget {
  final StepTimerEntry entry;
  final String time;
  final VoidCallback onTap;

  const _TimerChip({
    required this.entry,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = entry.label.isEmpty ? time : entry.label;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppDimensions.spacingSm),
      child: Semantics(
        label: context.l10n.a11yActiveTimer(label, time),
        button: true,
        // Square design language — no border radius.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: cs.onPrimary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  entry.isPaused ? Icons.pause : Icons.timer_outlined,
                  size: AppDimensions.iconSizeS,
                  color: cs.primary,
                ),
                const SizedBox(width: AppDimensions.spacingXxs),
                Text(
                  time,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
