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
  /// Also used for chanterelle season (September–October).
  mushroom,

  /// Pea pod/ärtskida - used for "no menu" state (static)
  peaPod,

  /// Carrot/morot - used for "no shopping items" state
  carrot,

  /// Red onion/rödlök - used for error states
  redOnion,

  // BUT-409: seasonal variants. Asset paths currently map to the closest
  // visual placeholder from the existing 5 — swap to dedicated illustrations
  // when they ship.
  /// Asparagus/sparris - April season.
  asparagus,

  /// Rhubarb/rabarber - May season.
  rhubarb,

  /// Berry (strawberry/blueberry) - June–August season.
  berry,

  /// Pumpkin/pumpa - September season.
  pumpkin,

  /// Cabbage/kål - January, March, November season.
  cabbage,

  /// Citrus - February, December season (greenhouse/imported staple).
  citrus,

  /// Beetroot/rödbeta - November season.
  beetroot,
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
  ///
  /// Seasonal variants (asparagus, rhubarb, etc.) currently reuse the closest
  /// visual placeholder from the original five. When dedicated illustrations
  /// ship, update only this switch — no call-site changes needed.
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
      // Seasonal placeholders — map to nearest existing illustration.
      case VegetableType.asparagus:
        return 'assets/illustrations/artskida.PNG';
      case VegetableType.rhubarb:
        return 'assets/illustrations/morot.png';
      case VegetableType.berry:
        return 'assets/illustrations/rodlok.PNG';
      case VegetableType.pumpkin:
        return 'assets/illustrations/morot.png';
      case VegetableType.cabbage:
        return 'assets/illustrations/broccoli.png';
      case VegetableType.citrus:
        return 'assets/illustrations/morot.png';
      case VegetableType.beetroot:
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
      case VegetableType.asparagus:
      case VegetableType.rhubarb:
      case VegetableType.cabbage:
        return Icons.grass;
      case VegetableType.berry:
      case VegetableType.citrus:
        return Icons.circle;
      case VegetableType.pumpkin:
      case VegetableType.beetroot:
        return Icons.eco;
    }
  }

  static const _fallbackColors = {
    VegetableType.broccoli: AppColors.forestGreen,
    VegetableType.mushroom: AppColors.illustrationBrown,
    VegetableType.peaPod: AppColors.forestGreen,
    VegetableType.carrot: AppColors.illustrationOrange,
    VegetableType.redOnion: AppColors.illustrationPurpleRed,
    VegetableType.asparagus: AppColors.forestGreen,
    VegetableType.rhubarb: AppColors.illustrationPurpleRed,
    VegetableType.berry: AppColors.illustrationPurpleRed,
    VegetableType.pumpkin: AppColors.illustrationOrange,
    VegetableType.cabbage: AppColors.forestGreen,
    VegetableType.citrus: AppColors.illustrationOrange,
    VegetableType.beetroot: AppColors.illustrationPurpleRed,
  };

  Color _getFallbackColor(VegetableType type) {
    return _fallbackColors[type] ?? AppColors.forestGreen;
  }
}

/// Ghost illustration for page headers — large, very transparent, brightened.
///
/// Positioned absolutely behind the header title text.
/// Each main view maps to a specific vegetable.
class HeaderGhostIllustration extends StatelessWidget {
  const HeaderGhostIllustration({
    required this.type,
    this.size = 130,
    super.key,
  });

  final VegetableType type;
  final double size;

  /// Maps main view routes to their illustration type.
  static const viewMapping = {
    'recipes': VegetableType.broccoli,
    'menu': VegetableType.peaPod,
    'shopping': VegetableType.carrot,
    'add': VegetableType.redOnion,
    'profile': VegetableType.mushroom,
  };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -10,
      bottom: -15,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.12,
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.modulate,
            ),
            child: Image.asset(
              VegetableIllustration.getAssetPath(type),
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small illustration for section headers (36px, semi-transparent).
class SectionIllustration extends StatelessWidget {
  const SectionIllustration({
    required this.type,
    this.size = 36,
    super.key,
  });

  final VegetableType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: Image.asset(
        VegetableIllustration.getAssetPath(type),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Faint watermark illustration in recipe card corners (6% opacity).
class CardWatermarkIllustration extends StatelessWidget {
  const CardWatermarkIllustration({
    required this.type,
    this.size = 50,
    super.key,
  });

  final VegetableType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -5,
      bottom: -5,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.06,
          child: Image.asset(
            VegetableIllustration.getAssetPath(type),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
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
