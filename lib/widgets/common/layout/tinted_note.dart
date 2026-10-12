// lib/widgets/common/layout/tinted_note.dart
//
// The quiet green panel the sketches use for a note under a list (Notiser,
// Min samling) and, full width, for an action band above one ("Markera alla
// lästa"). One surface, so the notes cannot drift apart.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class TintedNote extends StatelessWidget {
  /// A note: rounded panel with body text.
  const TintedNote({required this.child, super.key}) : _band = false;

  /// An action band: full width, square, for a row that acts on the list.
  const TintedNote.band({required this.child, super.key}) : _band = true;

  final Widget child;
  final bool _band;

  /// The text style a note's plain text uses; callers add emphasis with
  /// [TextSpan]s on top of it.
  static TextStyle textStyle(BuildContext context) =>
      AppTextStyles.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: _band
            ? null
            : BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        child: child,
      ),
    );
  }
}
