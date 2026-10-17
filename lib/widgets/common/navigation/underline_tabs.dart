// lib/widgets/common/navigation/underline_tabs.dart
//
// A row of text tabs over a hairline, the chosen one in ink with a bar under
// it (Skarmar v12 #inkop: "Alla / Min del / Efter zon"). For choosing how one
// list is shown; the page-level tabs are the TabBar the theme draws.
library;

import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

class UnderlineTabs<T> extends StatelessWidget {
  const UnderlineTabs({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  static const double _bar = 2.5;
  static const double _tabPadding = AppDimensions.space12 * 2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final labels = [for (final value in values) labelOf(value)];
        final share = constraints.maxWidth / values.length;
        // Under large text a two-word tab that wraps beside one-word tabs
        // reads as a mistake, so every label must fit its share on one line.
        final wordsFit = isLargeText(context)
            ? _widestLabel(context, labels) + _tabPadding <= share
            : widestWord(context, labels, AppTextStyles.labelLarge) +
                      _tabPadding <=
                  share;
        // The hairline sits under the chosen tab's bar rather than beside
        // it, so the two never read as a pair of stacked lines.
        Widget withHairline(Widget tabs) => Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: cs.outlineVariant),
              ),
            ),
            tabs,
          ],
        );
        // A tab list, so a screen reader announces the tabs as a group
        // rather than as loose buttons.
        Widget tabBar(Widget child) => Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          explicitChildNodes: true,
          child: child,
        );
        // Large text: tabs that cannot give each word its share keep their
        // words whole on one line and scroll sideways, rather than breaking
        // a word in two. The scroll view adds a semantics node of its own,
        // so the tab list sits inside it, directly over the tabs.
        if (wordsFit) {
          return tabBar(
            withHairline(
              Row(
                children: [
                  for (final value in values)
                    Flexible(child: _tab(context, cs, value)),
                ],
              ),
            ),
          );
        }
        return withHairline(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: tabBar(
              Row(
                children: [
                  for (final value in values)
                    _tab(context, cs, value, wrap: false),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static double _widestLabel(BuildContext context, List<String> labels) =>
      labels
          .map(
            (label) =>
                singleLineWidth(context, label, AppTextStyles.labelLarge),
          )
          .fold(0.0, (widest, width) => width > widest ? width : widest);

  Widget _tab(
    BuildContext context,
    ColorScheme cs,
    T value, {
    bool wrap = true,
  }) {
    final isSelected = value == selected;
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      button: true,
      label: labelOf(value),
      selected: isSelected,
      child: ButleryControlFocus(
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: () => onChanged(value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? cs.onSurface : Colors.transparent,
                      width: _bar,
                    ),
                  ),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    labelOf(value),
                    softWrap: wrap,
                    style:
                        (isSelected
                                ? AppTextStyles.labelLarge
                                : AppTextStyles.labelMedium)
                            .copyWith(
                              color: isSelected
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
