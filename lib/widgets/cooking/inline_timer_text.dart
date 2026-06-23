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

class InlineTimerText extends StatelessWidget {
  /// The full instruction line.
  final String text;

  /// Base style for the surrounding (non-chip) text.
  final TextStyle? style;

  /// Called with the parsed duration when the chip is tapped.
  final ValueChanged<DurationMatch> onTimerTap;

  /// Chip foreground/border color; defaults to the surrounding text color.
  final Color? chipColor;

  const InlineTimerText({
    super.key,
    required this.text,
    required this.onTimerTap,
    this.style,
    this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    final match = parseSwedishDurationMatch(text);
    if (match == null) return Text(text, style: style);

    final cs = Theme.of(context).colorScheme;
    final accent = chipColor ?? style?.color ?? cs.onSurface;
    final phrase = text.substring(match.start, match.end);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (match.start > 0) TextSpan(text: text.substring(0, match.start)),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Semantics(
              label: context.l10n.a11yStartTimerForPhrase(phrase),
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
                    vertical: AppDimensions.spacingXxs,
                  ),
                  decoration: BoxDecoration(
                    // Square design language — no border radius.
                    border: Border.all(color: accent),
                    color: accent.withValues(
                      alpha: AppDimensions.opacityExtraVeryLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: AppDimensions.iconSizeS,
                        color: accent,
                      ),
                      const SizedBox(width: AppDimensions.spacingXxs),
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
          ),
          if (match.end < text.length)
            TextSpan(text: text.substring(match.end)),
        ],
      ),
    );
  }
}
