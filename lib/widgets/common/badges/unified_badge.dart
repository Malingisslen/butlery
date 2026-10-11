// lib/widgets/common/badges/unified_badge.dart
//
// The app's one badge (BUT-2373). Komponentark v1 draws two kinds and no
// others: the status pill (§08) and the counter (v1:34, v1:741). Every view
// that marks a state or a count uses this widget instead of drawing its own
// box, so a change in the component sheet lands everywhere at once.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/utils/accessibility_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

/// What a status pill says about its subject. The tone colours the word and
/// the glyph only: "Aldrig fylld yta i statusfärg — success och danger är
/// text- och ikonfärger" (Komponentark §08).
enum BadgeTone { neutral, success, warning, danger }

/// Whether a counter asks for action. Ink is the norm; saffron only for
/// something that needs the user, or it competes with the view's hero
/// (Komponentark v1:741).
enum CountEmphasis { ink, action }

class UnifiedBadge extends StatelessWidget {
  /// A status pill: an outline pill in border-subtle with the word, and an
  /// optional glyph, in the tone's text colour. 10,5/700 uppercase, 3 × 9,
  /// an 11 px glyph 5 px from the word (Komponentark §08,
  /// tokens.json controls.statusPill).
  const UnifiedBadge.status({
    required String this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    super.key,
  }) : count = null,
       emphasis = CountEmphasis.ink;

  /// A counter: a filled pill, 2 × 7 (tokens.json controls.badge). Above 99
  /// it reads "99+" (Komponentark v1:741).
  const UnifiedBadge.count({
    required int this.count,
    this.emphasis = CountEmphasis.ink,
    super.key,
  }) : label = null,
       tone = BadgeTone.neutral,
       icon = null;

  final String? label;
  final BadgeTone tone;
  final IconData? icon;
  final int? count;
  final CountEmphasis emphasis;

  static const double _statusIconSize = 11;
  static const double _statusIconGap = 5;

  /// The text colour a status pill takes for [tone].
  static Color toneColor(BuildContext context, BadgeTone tone) {
    final cs = Theme.of(context).colorScheme;
    return switch (tone) {
      BadgeTone.neutral => cs.onSurfaceVariant,
      BadgeTone.success => context.modeColors.success,
      BadgeTone.warning => AppModeColors.textWarning(cs.brightness),
      BadgeTone.danger => cs.error,
    };
  }

  @override
  Widget build(BuildContext context) =>
      count != null ? _count(context) : _status(context);

  Widget _status(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = toneColor(context, tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Padding(
        padding: AppDimensions.statusPillPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: ButleryIcon(icon, size: _statusIconSize, color: color),
              ),
              const SizedBox(width: _statusIconGap),
            ],
            // Drawn in capitals, announced as written.
            Flexible(
              child: Semantics(
                label: label,
                excludeSemantics: true,
                child: Text(
                  label!.toUpperCase(),
                  style: AppTextStyles.overline.copyWith(
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _count(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final action = emphasis == CountEmphasis.action;
    final n = count!;
    // A counter sits on an icon or at a row's end, where a growing pill
    // would cover its neighbour; its digits scale only so far.
    return AccessibilityUtils.clampTextScaling(
      context: context,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: action ? cs.secondary : cs.primary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Padding(
          padding: AppDimensions.badgePadding,
          child: Text(
            n > 99 ? '99+' : '$n',
            style: AppTextStyles.overline.copyWith(
              color: action ? cs.onSecondary : cs.onPrimary,
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
