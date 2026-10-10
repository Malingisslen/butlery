import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// "Alla recept | Kokböcker" at the top of Hem's library (BUT-1325). The
/// cookbooks are their own tab in Malin's decision; the library is the
/// lower half of Hem, so the tab is this switch rather than a navigation
/// item.
class LibrarySwitch extends StatelessWidget {
  const LibrarySwitch({
    required this.showCookbooks,
    required this.onChanged,
    super.key,
  });

  final bool showCookbooks;
  final ValueChanged<bool> onChanged;

  static const switchKey = ValueKey('library-switch');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final side = ButleryTopBar.sideMargin(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        side,
        AppDimensions.spacingSm,
        side,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final choices = [
            (false, l10n.libraryTabAllRecipes),
            (true, l10n.libraryTabCookbooks),
          ];
          // Large text: chips that wrap, rather than a segment breaking a
          // word in half.
          if (!_fitsSideBySide(context, constraints.maxWidth)) {
            return SizedBox(
              width: double.infinity,
              child: Wrap(
                key: switchKey,
                spacing: AppDimensions.spacingSm,
                runSpacing: AppDimensions.spacingXs,
                children: [
                  for (final (value, label) in choices)
                    PressFill(
                      surface: value == showCookbooks
                          ? PressSurface.ink
                          : PressSurface.base,
                      child: ChoiceChip(
                        label: Text(label),
                        selected: value == showCookbooks,
                        onSelected: (_) {
                          if (value != showCookbooks) onChanged(value);
                        },
                      ),
                    ),
                ],
              ),
            );
          }
          return SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              key: switchKey,
              showSelectedIcon: false,
              segments: [
                for (final (value, label) in choices)
                  ButtonSegment(value: value, label: Text(label)),
              ],
              selected: {showCookbooks},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          );
        },
      ),
    );
  }

  bool _fitsSideBySide(BuildContext context, double width) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    double labelWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final widest = [
      labelWidth(l10n.libraryTabAllRecipes),
      labelWidth(l10n.libraryTabCookbooks),
    ].reduce((a, b) => a > b ? a : b);
    return widest + segmentPadding <= width / 2;
  }

  /// Room a label needs beside it for the segment's padding and border.
  static const double segmentPadding = 2 * AppDimensions.spacingLg;
}
