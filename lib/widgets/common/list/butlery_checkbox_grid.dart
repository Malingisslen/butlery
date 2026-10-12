// lib/widgets/common/list/butlery_checkbox_grid.dart
//
// A pick-many list as the sketch draws Allergener & kost (D2#17): a grid of
// two columns, a bordered box before each word, a tick in an ink box when
// chosen and never a colour alone, and a hairline under every cell.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class ButleryCheckboxGrid extends StatelessWidget {
  const ButleryCheckboxGrid({
    required this.options,
    required this.isSelected,
    required this.onToggle,
    super.key,
  });

  /// Stored key to the word shown.
  final Map<String, String> options;
  final bool Function(String key) isSelected;
  final ValueChanged<String> onToggle;

  static const int columns = 2;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();
    return Column(
      children: [
        for (var i = 0; i < entries.length; i += columns)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: AppDimensions.space24),
                  Expanded(
                    child: i + c < entries.length
                        ? _Cell(
                            label: entries[i + c].value,
                            selected: isSelected(entries[i + c].key),
                            onTap: () => onToggle(entries[i + c].key),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      checked: selected,
      label: label,
      child: ExcludeSemantics(
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.minTouchTarget,
                ),
                child: Row(
                  children: [
                    ButleryCheckboxMark(checked: selected),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.space8,
                        ),
                        child: Text(
                          label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
