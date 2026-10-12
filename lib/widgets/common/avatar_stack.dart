// lib/widgets/common/avatar_stack.dart
//
// The overlapping initials a shared surface draws for the people on it
// (Skarmar v12 del 2 #inkop, the shared list's header). The first name sits on ink;
// the others take the tones the assignee badge
// takes. A surplus past [maxShown] becomes one "+N".
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/theme/app_text_styles.dart';

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    required this.names,
    this.extra = 0,
    this.maxShown = 3,
    super.key,
  });

  /// Display names, the first on ink. Identical-looking initials are
  /// told apart by [distinctInitials].
  final List<String> names;

  /// People on the surface the names do not cover.
  final int extra;

  final int maxShown;

  static const double _size = 28;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = distinctInitials(names);
    final shown = initials.length > maxShown ? maxShown : initials.length;
    final hidden = extra + (initials.length - shown);
    final tones = [
      (cs.primary, cs.onPrimary),
      (cs.secondary, cs.onSecondary),
      (cs.tertiary, cs.onTertiary),
    ];

    Widget disc(String text, Color bg, Color fg) => Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        // The paper ring keeps neighbours apart where they overlap.
        border: Border.all(color: cs.surface, width: 2),
      ),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: fg)),
    );

    final discs = <Widget>[
      for (var i = 0; i < shown; i++)
        disc(
          initials[i],
          tones[i % tones.length].$1,
          tones[i % tones.length].$2,
        ),
      if (hidden > 0)
        disc('+$hidden', cs.surfaceContainerHighest, cs.onSurface),
    ];
    if (discs.isEmpty) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: SizedBox(
        width: _size + (discs.length - 1) * (_size - _overlap),
        height: _size,
        child: Stack(
          children: [
            for (var i = 0; i < discs.length; i++)
              PositionedDirectional(
                start: i * (_size - _overlap),
                child: discs[i],
              ),
          ],
        ),
      ),
    );
  }
}
