/// The partial outcome: the third outcome, beside success and failure (I-29).
///
/// produktregler.md:905-909 (§ 17.6): "Delvis utfall är ett tredje utfall,
/// inte ett lyckat och inte ett fel. Formen är `surface.raised` med
/// varningskant." It names what went, what did not and why, and the failed
/// ones stay where the user can try again. produktregler.md:588 adds that
/// "sju av nio" must never be reported as nine.
///
/// The drawing is Skarmar v12 etapp 9 globala tillstand och flerval.dc.html
/// :390-393 (#flergrupp, "En av två togs bort") and :317-319 (#flermeny):
/// - surface `surface.raised` (tokens.json: #E6EAD9 light, #2F4437 dark),
///   read as `ColorScheme.surfaceContainerHighest`, which carries that token
///   in both schemes;
/// - a 3 px edge on the leading side only, #CE7C1E in both themes of the
///   drawing, read as `ColorScheme.secondary` (action.primary, #CE7C1E light
///   and dark);
/// - the square leading edge and 8 px trailing corners
///   (`border-radius:0 8px 8px 0`), 14 px padding;
/// - an info glyph in text.accent.onRaised (#8A5212 light, #DCA968 dark,
///   `ColorScheme.onSecondaryContainer`). The drawing strokes #A15A0A, which
///   tokens.json forbids on surface.raised (4,30:1), so the token's own
///   on-raised value is used;
/// - a 14/700 title and a 12.5/600 body.
///
/// Interpretations, recorded here so the reader of the code sees them:
/// - The title uses the `label` role (14/600). The delivery has no 14/700
///   role yet; package 2 made the same fallback for the subpage title (D2).
/// - The body text is `text.primary` (onSurface). The drawing uses
///   text.bodyMuted (#37453A / #C9D3C4), which the delivered theme does not
///   expose to widgets. text.primary passes on surface.raised in both modes
///   (#24382C on #E6EAD9, #F5F4ED on #2F4437), so nothing gets less legible.
///
/// ## Public API (stable; P5-T4 reads it in phase B)
///
/// ```dart
/// PartialOutcome(
///   title: 'Vi hämtade 7 av 9 länkar',
///   message: 'De som inte gick att hämta ligger kvar här.',
///   items: [
///     PartialOutcomeItem(
///       id: result.id,            // stable data id, never the row number
///       label: result.url,
///       reason: result.error,
///       action: TextButton(onPressed: retry, child: Text('Försök igen')),
///     ),
///   ],
///   actions: [...],               // the way on, below the items
///   child: ...,                   // optional extra content, e.g. chips
/// )
/// ```
///
/// Each item is keyed `PartialOutcome.itemKey(id)`. The title is a live
/// region, so the outcome is announced without moving focus (Grafisk manual
/// v6:586, "Status som annonseras").
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// One thing that did not go through, with its reason and its way on.
@immutable
class PartialOutcomeItem {
  const PartialOutcomeItem({
    required this.id,
    required this.label,
    this.reason,
    this.action,
  });

  /// The item's own identity (a data id). Keys the row, so a row never
  /// takes its identity from its position or its text.
  final String id;

  /// What it is, as the user wrote or named it (never re-cased).
  final String label;

  /// Why it did not go through. Null when the cause is unknown.
  final String? reason;

  /// Its own way on, for example "Försök igen".
  final Widget? action;
}

/// The shared partial-outcome surface (I-29). See the library comment.
class PartialOutcome extends StatelessWidget {
  const PartialOutcome({
    super.key,
    required this.title,
    this.message,
    this.items = const [],
    this.actions = const [],
    this.child,
  });

  /// What went: "Vi hämtade 7 av 9 länkar". Counted, never rounded up.
  final String title;

  /// Why the rest did not go, and what happens to it.
  final String? message;

  /// What did not go, one row each.
  final List<PartialOutcomeItem> items;

  /// The way on for the whole outcome, below the items.
  final List<Widget> actions;

  /// Optional content below the message (for example draggable chips).
  final Widget? child;

  /// Width of the warning edge (Skarmar v12 etapp 9:390, 3 px).
  static const double edgeWidth = 3;

  /// Trailing corner radius (Skarmar v12 etapp 9:390, 8 px).
  static const double cornerRadius = AppDimensions.radiusControl;

  /// Key on the surface that carries the colour and the edge.
  static const Key surfaceKey = ValueKey('partial-outcome-surface');

  /// Key of the row for the item with [id].
  static Key itemKey(String id) => ValueKey('partial-outcome-item-$id');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = cs.onSurface;
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(
        right: Radius.circular(cornerRadius),
      ),
      child: DecoratedBox(
        key: surfaceKey,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(
            left: BorderSide(color: cs.secondary, width: edgeWidth),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingModerate),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingMs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      container: true,
                      liveRegion: true,
                      header: true,
                      child: Text(
                        title,
                        style: AppTextStyles.labelLarge.copyWith(color: text),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        message!,
                        style: AppTextStyles.labelMedium.copyWith(color: text),
                      ),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: AppDimensions.paddingMs),
                      child!,
                    ],
                    for (final item in items)
                      _PartialOutcomeRow(
                        key: itemKey(item.id),
                        item: item,
                        color: text,
                      ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingL),
                      Wrap(
                        spacing: AppDimensions.spacingSm,
                        runSpacing: AppDimensions.spacingSm,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartialOutcomeRow extends StatelessWidget {
  const _PartialOutcomeRow({
    super.key,
    required this.item,
    required this.color,
  });

  final PartialOutcomeItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reason = item.reason;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(color: color),
                  ),
                  if (reason != null && reason.isNotEmpty)
                    Text(
                      reason,
                      style: AppTextStyles.labelMedium.copyWith(color: color),
                    ),
                ],
              ),
            ),
          ),
          if (item.action != null) ...[
            const SizedBox(width: AppDimensions.spacingSm),
            item.action!,
          ],
        ],
      ),
    );
  }
}
