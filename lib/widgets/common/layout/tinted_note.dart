// lib/widgets/common/layout/tinted_note.dart
//
// The quiet green panel the sketches use for a note under a list (Notiser,
// Min samling) and, full width, for an action band above one ("Markera alla
// lästa"). One surface, so the notes cannot drift apart.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

class TintedNote extends StatelessWidget {
  /// A note: rounded panel with body text.
  const TintedNote({required this.child, super.key}) : _band = false;

  /// An action band: full width, square, for a row that acts on the list.
  const TintedNote.band({required this.child, super.key}) : _band = true;

  /// A panel with a bold title, optional leading glyph and body text:
  /// Samtycken' terms box, the deletion notice, the two-step status.
  factory TintedNote.titled({
    required String title,
    String? body,
    IconData? icon,
    Color? iconColor,
    Key? key,
  }) => TintedNote(
    key: key,
    child: TintedNoteEntry(
      title: title,
      body: body,
      icon: icon,
      iconColor: iconColor,
    ),
  );

  /// A panel that opens with a bold label, as the outcome of a decision
  /// ("Utfall: receptet togs bort.").
  factory TintedNote.labelled({
    required String label,
    required String text,
    Key? key,
  }) => TintedNote(
    key: key,
    child: _LabelledNoteBody(label: label, text: text),
  );

  final Widget child;
  final bool _band;

  /// The text style a note's plain text uses; callers add emphasis with
  /// [TextSpan]s on top of it.
  static TextStyle textStyle(BuildContext context) =>
      AppTextStyles.captionBase.copyWith(
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

/// One titled entry inside a [TintedNote], with an optional leading glyph.
class TintedNoteEntry extends StatelessWidget {
  const TintedNoteEntry({
    required this.title,
    this.body,
    this.icon,
    this.iconColor,
    super.key,
  });

  final String title;
  final String? body;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
        ),
        if (body != null) ...[
          const SizedBox(height: AppDimensions.space4),
          Text(body!, style: TintedNote.textStyle(context)),
        ],
      ],
    );
    if (icon == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space4),
          child: ExcludeSemantics(
            child: ButleryIcon(
              icon,
              size: AppDimensions.iconSizeM,
              color: iconColor ?? cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.space12),
        Expanded(child: text),
      ],
    );
  }
}

class _LabelledNoteBody extends StatelessWidget {
  const _LabelledNoteBody({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final base = TintedNote.textStyle(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: AppTextStyles.captionBold.copyWith(color: base.color),
          ),
          TextSpan(text: text),
        ],
      ),
      style: base,
    );
  }
}
