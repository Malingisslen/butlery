import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_shadows.dart';

/// Predefined colors for personal tags.
class PersonalTagColors {
  PersonalTagColors._();

  static const List<String> colors = [
    '#E57373', // Red
    '#F06292', // Pink
    '#BA68C8', // Purple
    '#9575CD', // Deep Purple
    '#7986CB', // Indigo
    '#64B5F6', // Blue
    '#4FC3F7', // Light Blue
    '#4DD0E1', // Cyan
    '#4DB6AC', // Teal
    '#81C784', // Green
    '#AED581', // Light Green
    '#DCE775', // Lime
    '#FFF176', // Yellow
    '#FFD54F', // Amber
    '#FFB74D', // Orange
    '#FF8A65', // Deep Orange
    '#A1887F', // Brown
    '#90A4AE', // Blue Grey
  ];

  /// Converts hex string to Color.
  ///
  /// When [hex] is null/empty, returns [fallback] if provided, otherwise
  /// a default green matching the brand primary in light mode.
  static Color fromHex(String? hex, {Color? fallback}) {
    if (hex == null || hex.isEmpty) return fallback ?? const Color(0xFF4A7C59);

    String colorStr = hex.replaceAll('#', '');
    if (colorStr.length == 6) {
      colorStr = 'FF$colorStr';
    }
    return Color(int.parse(colorStr, radix: 16));
  }
}

/// A simple grid of predefined colors for tag color selection.
class PersonalTagColorPicker extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String> onColorSelected;
  final String? title;

  const PersonalTagColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(title!, style: AppTextStyles.labelMedium),
          const SizedBox(height: AppDimensions.spacingS),
        ],
        Wrap(
          spacing: AppDimensions.spacingS,
          runSpacing: AppDimensions.spacingS,
          children: PersonalTagColors.colors.map((color) {
            final isSelected =
                selectedColor?.toUpperCase() == color.toUpperCase();
            return _ColorCircle(
              color: color,
              isSelected: isSelected,
              onTap: () => onColorSelected(color),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final String color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colorValue = PersonalTagColors.fromHex(color, fallback: cs.primary);

    return Semantics(
      label: context.l10n.personalTagSelectColor,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDimensions.animationDurationFast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorValue,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? cs.onSurface : Colors.transparent,
              width: isSelected ? 3 : 0,
            ),
            boxShadow: isSelected ? AppShadows.card : null,
          ),
          child: isSelected
              ? Icon(
                  Icons.check,
                  color: cs.surfaceContainerHighest,
                  size: AppDimensions.iconSizeM,
                )
              : null,
        ),
      ),
    );
  }
}

/// A small colored dot to display a tag's color.
class PersonalTagColorDot extends StatelessWidget {
  final String? color;
  final double size;

  const PersonalTagColorDot({
    super.key,
    this.color,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PersonalTagColors.fromHex(color,
            fallback: Theme.of(context).colorScheme.primary),
        shape: BoxShape.circle,
      ),
    );
  }
}
