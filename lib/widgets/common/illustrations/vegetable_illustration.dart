/// Vegetable illustration widget for empty states and decorative use.
///
/// Uses the hand-drawn vegetable illustrations from assets/illustrations/
/// with consistent sizing and styling for empty states.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Types of vegetable illustrations available.
enum VegetableType {
  /// Broccoli - used for "no recipes" state
  broccoli,

  /// Mushroom/champinjon - used for "no search results" state
  mushroom,

  /// Pea pod/ärtskida - used for "no menu" state (static)
  peaPod,

  /// Carrot/morot - used for "no shopping items" state
  carrot,

  /// Red onion/rödlök - used for error states
  redOnion,
}

/// Displays a vegetable illustration from the assets.
///
/// Used primarily in empty states to add visual interest and
/// match the Butlery brand aesthetic.
///
/// Example:
/// ```dart
/// VegetableIllustration(
///   type: VegetableType.broccoli,
///   size: 120,
/// )
/// ```
class VegetableIllustration extends StatelessWidget {
  /// Creates a vegetable illustration.
  const VegetableIllustration({
    required this.type,
    this.size = 100,
    this.opacity = 1.0,
    super.key,
  });

  /// The type of vegetable to display.
  final VegetableType type;

  /// The size (width and height) of the illustration.
  final double size;

  /// Opacity of the illustration (0.0 to 1.0).
  final double opacity;

  /// Returns the asset path for a vegetable type.
  static String getAssetPath(VegetableType type) {
    switch (type) {
      case VegetableType.broccoli:
        return 'assets/illustrations/broccoli.png';
      case VegetableType.mushroom:
        return 'assets/illustrations/champinjon.PNG';
      case VegetableType.peaPod:
        return 'assets/illustrations/artskida.PNG';
      case VegetableType.carrot:
        return 'assets/illustrations/morot.png';
      case VegetableType.redOnion:
        return 'assets/illustrations/rodlok.PNG';
    }
  }

  /// Returns a random vegetable type for placeholder use.
  static VegetableType randomForRecipe(String recipeId) {
    final hash = recipeId.hashCode.abs();
    const values = VegetableType.values;
    return values[hash % values.length];
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        getAssetPath(type),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to a simple icon if image fails to load
          return Icon(
            _getFallbackIcon(type),
            size: size * 0.6,
            color: _getFallbackColor(type),
          );
        },
      ),
    );
  }

  IconData _getFallbackIcon(VegetableType type) {
    switch (type) {
      case VegetableType.broccoli:
        return Icons.eco;
      case VegetableType.mushroom:
        return Icons.search_off;
      case VegetableType.peaPod:
        return Icons.calendar_today;
      case VegetableType.carrot:
        return Icons.shopping_cart;
      case VegetableType.redOnion:
        return Icons.error_outline;
    }
  }

  static const _fallbackColors = {
    VegetableType.broccoli: AppColors.forestGreen,
    VegetableType.mushroom: Color(0xFFA08060), // Brown
    VegetableType.peaPod: AppColors.forestGreen,
    VegetableType.carrot: Color(0xFFE07020), // Orange
    VegetableType.redOnion: Color(0xFF8B2252), // Purple-red
  };

  Color _getFallbackColor(VegetableType type) {
    return _fallbackColors[type] ?? AppColors.forestGreen;
  }
}

/// A container widget that displays an illustration with optional label.
///
/// Useful for empty state compositions.
class IllustrationContainer extends StatelessWidget {
  /// Creates an illustration container.
  const IllustrationContainer({
    required this.type,
    this.label,
    this.sublabel,
    this.size = 120,
    this.spacing = AppDimensions.spacingMd,
    super.key,
  });

  /// The type of vegetable illustration.
  final VegetableType type;

  /// Optional label below the illustration.
  final String? label;

  /// Optional sublabel below the label.
  final String? sublabel;

  /// Size of the illustration.
  final double size;

  /// Spacing between elements.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VegetableIllustration(
          type: type,
          size: size,
        ),
        if (label != null) ...[
          SizedBox(height: spacing),
          Text(
            label!,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (sublabel != null) ...[
          SizedBox(height: spacing / 2),
          Text(
            sublabel!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
