import 'package:flutter/material.dart';

/// A grid whose rows are as tall as the tallest card in them.
///
/// The alternative, and what this replaced, is a `GridView` — which needs each
/// tile's height BEFORE it lays anything out, and can only be told that height
/// as a ratio of the tile's own width or as a fixed number. Neither can be
/// right for a card carrying text. What has to fit grows with the OS text
/// scale and SHRINKS with width, so a ratio is wrong at one end whatever it is
/// set to; and a fixed number has to predict every `Wrap` inside the card,
/// which steps with the width. Measured on the recipe card at 2x: the block
/// below the image needs 244 logical pixels on a 360dp phone and 272 on a
/// 320dp one, and it keeps growing as the tile gets narrower — the badge row
/// wraps onto another run, and where that run lands is a step, not a curve.
///
/// A prediction that comes out short does not fail loudly. A release build
/// draws no overflow stripes — it clips, and the content is simply gone. So
/// nothing here predicts: each row is an [IntrinsicHeight] over [Expanded]
/// cells, and the cards size to their own content (BUT-1911).
///
/// Laziness is kept. [ListView.builder] builds a row when it scrolls near,
/// exactly as `GridView.builder` built a tile.
///
/// Cards are stretched to their row's height, so a card that draws less than
/// its neighbour keeps the same box rather than ending short of it.
class ContentSizedGrid extends StatelessWidget {
  const ContentSizedGrid({
    super.key,
    required this.itemCount,
    required this.columns,
    required this.spacing,
    required this.itemBuilder,
    this.padding,
    this.primary,
  });

  final int itemCount;

  /// How many cards sit side by side. The caller decides, because the answer
  /// is a breakpoint question about the screen, not about this widget.
  final int columns;

  /// Used between columns AND between rows, so a caller cannot set the two to
  /// different values by accident the way two separate delegate fields invite.
  final double spacing;

  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    assert(columns > 0, 'a grid needs at least one column');
    final rowCount = (itemCount + columns - 1) ~/ columns;

    return ListView.builder(
      primary: primary,
      padding: padding,
      itemCount: rowCount,
      itemBuilder: (context, rowIndex) {
        final firstIndex = rowIndex * columns;
        return Padding(
          padding: EdgeInsets.only(
            bottom: rowIndex == rowCount - 1 ? 0 : spacing,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) SizedBox(width: spacing),
                  Expanded(
                    // The last row can be short. Its empty cells are still
                    // laid out, so the cards in it keep the width they have in
                    // every other row — without them a lone final card would
                    // stretch across the screen.
                    child: firstIndex + column < itemCount
                        ? itemBuilder(context, firstIndex + column)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
