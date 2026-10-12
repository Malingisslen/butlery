// lib/widgets/common/navigation/underline_tabs.dart
//
// A row of text tabs over a hairline, the chosen one in ink with a bar under
// it (Skarmar v12 #inkop: "Alla / Min del / Efter zon"). For choosing how one
// list is shown; the page-level tabs are the TabBar the theme draws.
library;

import 'package:butlery/widgets/common/press_fill.dart';
import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          for (final value in values)
            Flexible(
              child: Semantics(
                label: labelOf(value),
                button: true,
                selected: value == selected,
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
                              color: value == selected
                                  ? cs.onSurface
                                  : Colors.transparent,
                              width: _bar,
                            ),
                          ),
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            labelOf(value),
                            style:
                                (value == selected
                                        ? AppTextStyles.labelLarge
                                        : AppTextStyles.labelMedium)
                                    .copyWith(
                                      color: value == selected
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
            ),
        ],
      ),
    );
  }
}
