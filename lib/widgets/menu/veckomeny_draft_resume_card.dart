import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/content_time_labels.dart';
import 'package:butlery/models/menu/weekly_menu_draft.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/draft_recovery_dialog.dart'
    show draftTimeLeftLabel;

/// BUT-2157: the kept week draft, offered at the top of Lista and Kalender
/// while the week is empty (Malin's sketch C "Veckan", 2026-10-09).
///
/// The draft is a suggestion that was never placed, so it has no days. The
/// row lays the longest meal type's dishes over Mån–Sön in draft order, the
/// order auto-placement takes them in.
class VeckomenyDraftResumeCard extends StatelessWidget {
  const VeckomenyDraftResumeCard({
    super.key,
    required this.draft,
    required this.now,
    required this.onRestore,
    required this.onDiscard,
    this.restoring = false,
  });

  final WeeklyMenuDraft draft;
  final DateTime now;
  final VoidCallback onRestore;
  final VoidCallback onDiscard;
  final bool restoring;

  static const int _days = 7;

  /// The dish name per day, null for a day the draft has nothing for.
  static List<String?> dayNames(WeeklyMenuDraft draft) {
    var row = const <String>[];
    for (final ids in draft.recipeIdsByMealType.values) {
      if (ids.length > row.length) row = ids;
    }
    return [
      for (var day = 0; day < _days; day++)
        day < row.length ? draft.recipeNames[row[day]].orEmpty() : null,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final onInk = Theme.of(context).colorScheme.onPrimary;
    final days = dayNames(draft);
    final done = days.where((name) => name != null).length;
    final meta =
        '${l.weekMenuDraftDaysDone(done)} · '
        '${draftTimeLeftLabel(context, draft.timeLeft)}';

    return Container(
      key: const ValueKey('veckomeny-draft-resume-card'),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(
                l.weekMenuDraftResumeTitle(
                  ContentTimeLabels.whenLabel(l, draft.lastModifiedAt, now),
                ),
                style: AppTextStyles.titleMedium.copyWith(color: onInk),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var day = 0; day < _days; day++) ...[
                    if (day > 0) const SizedBox(width: AppDimensions.spacingXs),
                    Expanded(
                      child: _DayCell(day: day, name: days[day]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              meta,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppModeColors.textSecondaryOnInk(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                KeyedSubtree(
                  key: const ValueKey('veckomeny-draft-restore'),
                  child: ActionButtons.actionButton(
                    context,
                    label: l.draftRestore,
                    isLoading: restoring,
                    onPressed: onRestore,
                  ),
                ),
                TextButton(
                  key: const ValueKey('veckomeny-draft-discard'),
                  onPressed: restoring ? null : onDiscard,
                  style: TextButton.styleFrom(
                    foregroundColor: onInk,
                    minimumSize: const Size(
                      AppDimensions.minTouchTarget,
                      AppDimensions.minTouchTarget,
                    ),
                  ),
                  child: Text(l.draftDiscard),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.name});

  final int day;

  /// Null for a day the draft has nothing for.
  final String? name;

  /// "Mån" … "Sön" from the locale; 2024-01-01 is a Monday.
  static String _weekday(BuildContext context, int day) {
    final label = DateFormat.E(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(DateTime(2024, 1, 1 + day));
    final trimmed = label.endsWith('.')
        ? label.substring(0, label.length - 1)
        : label;
    return trimmed.isEmpty
        ? trimmed
        : trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final onInk = Theme.of(context).colorScheme.onPrimary;
    final empty = name == null;
    final weekday = _weekday(context, day);
    final style = AppTextStyles.labelSmall.copyWith(
      color: AppModeColors.textSecondaryOnInk(),
    );
    final cell = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacingSm - 2,
        horizontal: 2,
      ),
      child: Column(
        children: [
          Text(
            weekday,
            textAlign: TextAlign.center,
            style: style.copyWith(color: onInk, fontWeight: FontWeight.w700),
          ),
          Text(
            empty ? '–' : name!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: empty
          ? '$weekday ${context.l10n.weekMenuDraftDayEmpty}'
          : '$weekday $name',
      excludeSemantics: true,
      child: empty
          ? CustomPaint(
              painter: _DashedBorderPainter(color: AppModeColors.borderOnInk()),
              child: cell,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: AppModeColors.surfaceRaisedOnInk(),
                borderRadius: BorderRadius.circular(AppDimensions.radiusKnob),
              ),
              child: cell,
            ),
    );
  }
}

/// The sketch's dashed outline for a day without a dish.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 3.0;
    const gap = 2.0;
    void line(Offset from, Offset to) {
      final length = (to - from).distance;
      final direction = (to - from) / length;
      for (var d = 0.0; d < length; d += dash + gap) {
        final end = d + dash < length ? d + dash : length;
        canvas.drawLine(from + direction * d, from + direction * end, paint);
      }
    }

    final r = Offset.zero & size;
    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
