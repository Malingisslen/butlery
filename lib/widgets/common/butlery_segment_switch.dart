/// The one two-way switch: the component sheet's segment (1.5 px ink border,
/// 8 dp radius, the chosen half filled), used for "Alla recept | Kokböcker" and
/// "Lista | Kalender". Every switch of this kind is this widget, so the shape
/// is decided in one place.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class ButlerySegmentSwitch<T> extends StatelessWidget {
  const ButlerySegmentSwitch({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  /// The halves, in order, as value and visible label.
  final List<(T, String)> choices;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Room a label needs beside it for the segment's padding and border.
  static const double segmentPadding = 2 * AppDimensions.space24;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Large text: chips that wrap, rather than a segment breaking a word
        // in half.
        if (!_fitsSideBySide(context, constraints.maxWidth)) {
          return SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: AppDimensions.space8,
              runSpacing: AppDimensions.space4,
              children: [
                for (final (value, label) in choices)
                  PressFill(
                    surface: value == selected
                        ? PressSurface.ink
                        : PressSurface.base,
                    child: ChoiceChip(
                      label: Text(label),
                      selected: value == selected,
                      onSelected: (_) {
                        if (value != selected) onChanged(value);
                      },
                    ),
                  ),
              ],
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            style: _segmentStyle(Theme.of(context).colorScheme),
            segments: [
              for (final (value, label) in choices)
                ButtonSegment(value: value, label: Text(label)),
            ],
            selected: {selected},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        );
      },
    );
  }

  /// Ink border, 8 dp radius, the chosen half filled with ink. `onSurface`
  /// is ink on light and paper on dark, so the switch reads in both modes.
  ButtonStyle _segmentStyle(ColorScheme cs) {
    return SegmentedButton.styleFrom(
      foregroundColor: cs.onSurface,
      selectedForegroundColor: cs.surface,
      selectedBackgroundColor: cs.onSurface,
      side: BorderSide(color: cs.onSurface, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      minimumSize: const Size(0, AppDimensions.minTouchTarget),
    );
  }

  bool _fitsSideBySide(BuildContext context, double width) {
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

    final widest = choices
        .map((c) => labelWidth(c.$2))
        .reduce((a, b) => a > b ? a : b);
    return widest + segmentPadding <= width / 2;
  }
}
