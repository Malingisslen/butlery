// lib/widgets/common/bold_in_text.dart
//
// A sentence from l10n with the names inside it set in the stronger style, as
// the drawn conflict and suggestion screens do ("Anna föreslår en ändring i
// Linsgryta"). The l10n string stays one sentence for translators; the names
// are found in the finished text.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_text_styles.dart';

class BoldInText extends StatelessWidget {
  const BoldInText(this.text, {required this.bold, super.key});

  final String text;

  /// Every occurrence of each non-empty string here is drawn stronger.
  final List<String> bold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plain = AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant);
    final strong = AppTextStyles.labelLargeBold.copyWith(color: cs.onSurface);
    final names = bold.where((b) => b.isNotEmpty).toList();
    if (names.isEmpty) return Text(text, style: plain);
    final pattern = RegExp(names.map(RegExp.escape).join('|'));
    final spans = <TextSpan>[];
    text.splitMapJoin(
      pattern,
      onMatch: (m) {
        spans.add(TextSpan(text: m[0], style: strong));
        return '';
      },
      onNonMatch: (s) {
        if (s.isNotEmpty) spans.add(TextSpan(text: s));
        return '';
      },
    );
    return Text.rich(TextSpan(style: plain, children: spans));
  }
}
