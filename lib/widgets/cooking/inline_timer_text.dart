/// BUT-604: instruction text with the parsed duration phrase rendered as an
/// inline tappable timer chip.
///
/// BUT-406 shipped the Swedish duration parsing but the only way to reach the
/// timer was long-pressing a step — invisible affordance. This widget makes
/// the duration phrase itself the affordance: "grädda i `25 min ⏲` mitt i
/// ugnen". Lines without a parsable duration render as plain [Text] with the
/// same style, so callers can use it unconditionally.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/utils/duration_parser.dart';
import 'package:butlery/utils/step_quantity_matcher.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class InlineTimerText extends StatelessWidget {
  /// The full instruction line.
  final String text;

  /// Base style for the surrounding (non-chip) text.
  final TextStyle? style;

  /// Called with the parsed duration when the chip is tapped.
  final ValueChanged<DurationMatch> onTimerTap;

  /// Chip foreground/border color; defaults to the surrounding text color.
  final Color? chipColor;

  /// BUT-1601: ingredient amounts to show after the words they belong to.
  /// [text] itself is never changed; a mark overlapping the timer phrase is
  /// dropped.
  final List<StepQuantityMark> quantityMarks;

  /// Chip fill; defaults to the theme's raised surface. Pass the on-ink raised
  /// surface when the line sits on the ink base.
  final Color? chipFill;

  const InlineTimerText({
    super.key,
    required this.text,
    required this.onTimerTap,
    this.style,
    this.chipColor,
    this.chipFill,
    this.quantityMarks = const [],
  });

  @override
  Widget build(BuildContext context) {
    final match = parseSwedishDurationMatch(text);
    final marks = [
      for (final m in quantityMarks)
        if (m.start >= 0 &&
            m.end <= text.length &&
            (match == null || m.end <= match.start || m.start >= match.end))
          m,
    ]..sort((a, b) => a.start.compareTo(b.start));
    if (match == null && marks.isEmpty) return Text(text, style: style);

    final children = <InlineSpan>[];
    var cursor = 0;
    void addPlain(int end) {
      for (final m in marks) {
        if (m.end <= cursor || m.end > end) continue;
        children
          ..add(TextSpan(text: text.substring(cursor, m.end)))
          ..add(_quantitySpan(m.label));
        cursor = m.end;
      }
      if (end > cursor) {
        children.add(TextSpan(text: text.substring(cursor, end)));
      }
      cursor = end;
    }

    if (match == null) {
      addPlain(text.length);
    } else {
      addPlain(match.start);
      children.add(_timerChip(context, match));
      cursor = match.end;
      addPlain(text.length);
    }
    return Text.rich(TextSpan(style: style, children: children));
  }

  // Semi-bold in parentheses, so the cook can tell what Butlery added.
  TextSpan _quantitySpan(String label) => TextSpan(
    text: ' ($label)',
    style: const TextStyle(fontWeight: FontWeight.w600),
  );

  WidgetSpan _timerChip(BuildContext context, DurationMatch match) {
    final cs = Theme.of(context).colorScheme;
    final accent = chipColor ?? style?.color ?? cs.onSurface;
    final phrase = text.substring(match.start, match.end);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Semantics(
        label: context.l10n.a11yStartTimerForPhrase,
        button: true,
        // GestureDetector, not InkWell: ink splashes inside a
        // WidgetSpan clip to the paragraph's paint layer, and opaque
        // hit-testing keeps the tap from also reaching the row-level
        // tap/long-press handlers in the calling views.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTimerTap(match),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXs,
              vertical: AppDimensions.space4,
            ),
            decoration: BoxDecoration(
              // Square design language — no border radius.
              border: Border.all(color: accent),
              color: chipFill ?? cs.surfaceContainerHighest,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ButleryIcon(
                  ButleryIcons.clock,
                  size: AppDimensions.iconSizeS,
                  color: accent,
                ),
                const SizedBox(width: AppDimensions.space4),
                Text(
                  phrase,
                  style: (style ?? const TextStyle()).copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
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
