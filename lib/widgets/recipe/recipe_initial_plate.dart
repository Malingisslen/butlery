import 'package:flutter/material.dart';

import 'package:butlery/theme/app_text_styles.dart';

/// What a recipe without a photo shows where the photo would be: the first
/// letter of its title on surface.raised, in text.secondary (Komponentark v1,
/// "Bild saknas, bild misslyckas — fyra ytor, fyra svar"). Illustrations are
/// for empty states only (Grafisk manual v6), so a recipe never borrows a
/// vegetable that has nothing to do with it.
///
/// Fills the box it is given; the caller keeps the box, so a card keeps its
/// height.
class RecipeInitialPlate extends StatelessWidget {
  const RecipeInitialPlate({
    required this.title,
    this.letterSize = 20,
    super.key,
  });

  final String title;
  final double letterSize;

  /// The title's first character, upper-cased; empty for an empty title.
  static String initialOf(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty ? '' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Decorative: the title next to it is what a screen reader reads.
    return ExcludeSemantics(
      child: ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Text(
            initialOf(title),
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: letterSize,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
