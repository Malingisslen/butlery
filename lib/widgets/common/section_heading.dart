// lib/widgets/common/section_heading.dart
//
// The one heading for a section inside a page (BUT-2369): the overline in
// capitals, as the drawn screens set it. A view names the section and, where
// it must, a tone; it never sets its own size, weight or colour.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

/// What the heading's colour says about the section under it.
enum SectionHeadingTone {
  /// text.secondary, as most drawn screens set it.
  standard,

  /// text.primary: the user's own section beside other people's, as "Min
  /// del" in a shared shopping list.
  strong,

  /// text.success, the green overline of the Mer pages (B-52).
  emphasis,

  /// text.danger: the cards under it need the user, as "Väntar på dig".
  attention,

  /// text.warning: the section is about to run out, as "Utgår snart" in the
  /// pantry.
  warning,
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.text, {
    this.tone = SectionHeadingTone.standard,
    super.key,
  });

  /// Written in the case the l10n string has; drawn in capitals.
  final String text;

  final SectionHeadingTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (tone) {
      SectionHeadingTone.standard => cs.onSurfaceVariant,
      SectionHeadingTone.strong => cs.onSurface,
      SectionHeadingTone.emphasis => cs.tertiary,
      SectionHeadingTone.attention => cs.error,
      SectionHeadingTone.warning => AppModeColors.textWarning(cs.brightness),
    };
    return Semantics(
      // Its own node, so the heading names the section and does not swallow
      // the content under it.
      container: true,
      header: true,
      child: WholeWordText(
        text.toUpperCase(),
        style: AppTextStyles.sectionHeading.copyWith(color: color),
      ),
    );
  }
}
