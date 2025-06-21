// lib/widgets/portion_scaler.dart
// Smart portionsskalning med ingrediens-uppdatering

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/text_utils.dart';

/// Widget för att skala portioner och visa uppdaterade ingrediensmängder
/// Med +/- knappar och realtidsuppdatering av ingredienser
class PortionScaler extends StatefulWidget {
  final int originalPortions;
  final List<String> originalIngredients;
  final Function(int newPortions, List<String> scaledIngredients)
  onPortionChanged;
  final int minPortions;
  final int maxPortions;

  const PortionScaler({
    super.key,
    required this.originalPortions,
    required this.originalIngredients,
    required this.onPortionChanged,
    this.minPortions = 1,
    this.maxPortions = 20,
  });

  @override
  State<PortionScaler> createState() => _PortionScalerState();
}

class _PortionScalerState extends State<PortionScaler>
    with SingleTickerProviderStateMixin {
  late int _currentPortions;
  late List<String> _scaledIngredients;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _convertToSwedish = false; // NY! Toggle för enhetskonvertering
  bool _hasAmericanUnits =
      false; // NY! Detekterar om receptet har amerikanska enheter

  @override
  void initState() {
    super.initState();
    _currentPortions = widget.originalPortions;
    _scaledIngredients = List.from(widget.originalIngredients);
    _hasAmericanUnits = _detectAmericanUnits(); // Detektera amerikanska enheter

    // Animation för visuell feedback
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updatePortions(int newPortions) {
    if (newPortions < widget.minPortions || newPortions > widget.maxPortions) {
      return;
    }

    setState(() {
      _currentPortions = newPortions;
      _scaledIngredients = _scaleIngredients(newPortions);
    });

    // Visuell feedback
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Callback till parent
    widget.onPortionChanged(_currentPortions, _scaledIngredients);
  }

  // NY METOD för att detektera amerikanska enheter
  bool _detectAmericanUnits() {
    const americanUnits = {
      'cup',
      'cups',
      'oz',
      'fl oz',
      'floz',
      'tbsp',
      'tsp',
      'lb',
      'lbs',
      'pound',
      'pounds',
      'ounce',
      'ounces',
      'pint',
      'pints',
      'quart',
      'quarts',
      'gallon',
      'gallons',
      'tablespoon',
      'tablespoons',
      'teaspoon',
      'teaspoons',
    };

    for (final ingredient in widget.originalIngredients) {
      // Först: försök med parser
      final parsed = IngredientParser.parseIngredient(ingredient);

      if (americanUnits.contains(parsed.unit.toLowerCase())) {
        return true;
      }

      // Fallback: enkel strängkontroll
      final lowerIngredient = ingredient.toLowerCase();
      for (final unit in americanUnits) {
        if (lowerIngredient.contains(' $unit ') ||
            lowerIngredient.startsWith('$unit ') ||
            lowerIngredient.endsWith(' $unit')) {
          return true;
        }
      }
    }
    return false;
  }

  // NY METOD för enhetskonvertering toggle
  void _toggleUnitConversion() {
    setState(() {
      _convertToSwedish = !_convertToSwedish;
      _scaledIngredients = _scaleIngredients(_currentPortions);
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Callback till parent
    widget.onPortionChanged(_currentPortions, _scaledIngredients);
  }

  List<String> _scaleIngredients(int newPortions) {
    if (widget.originalPortions == 0 ||
        newPortions == widget.originalPortions) {
      // ÄVEN om portionerna är samma, kör konvertering om _convertToSwedish är true
      if (_convertToSwedish) {
        final scaledList = <String>[];
        for (final ingredient in widget.originalIngredients) {
          final converted = _scaleIndividualIngredient(
            ingredient,
            1.0,
          ); // Scalefactor 1.0
          scaledList.add(converted);
        }
        return scaledList;
      }

      return List.from(widget.originalIngredients);
    }

    final scaleFactor = newPortions / widget.originalPortions;
    final scaledList = <String>[];

    for (final ingredient in widget.originalIngredients) {
      final scaled = _scaleIndividualIngredient(ingredient, scaleFactor);
      scaledList.add(scaled);
    }

    return scaledList;
  }

  String _scaleIndividualIngredient(String ingredient, double scaleFactor) {
    if (ingredient.trim().isEmpty) return ingredient;

    final parsed = IngredientParser.parseIngredient(ingredient);

    // Om ingen kvantitet hittades, returnera oförändrad
    if (parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == ingredient) {
      return ingredient;
    }

    // Skala kvantiteten
    final scaledQuantity = parsed.quantity * scaleFactor;

    // Enhetskonvertering
    String finalUnit = parsed.unit;
    double finalQuantity = scaledQuantity;

    // Amerikanska → Svenska konvertering (om aktiverad)
    if (_convertToSwedish && parsed.unit.isNotEmpty) {
      final americanUnits = {
        'cup',
        'cups',
        'oz',
        'fl oz',
        'floz',
        'tbsp',
        'tsp',
        'lb',
        'lbs',
        'pound',
        'pounds',
        'ounce',
        'ounces',
        'pint',
        'pints',
        'quart',
        'quarts',
        'gallon',
        'gallons',
        'tablespoon',
        'tablespoons',
        'teaspoon',
        'teaspoons',
      };

      if (americanUnits.contains(parsed.unit.toLowerCase())) {
        final converted = SmartUnitConverter.convertToReadableUnit(
          scaledQuantity,
          parsed.unit,
        );
        finalQuantity = converted.quantity;
        finalUnit = converted.unit;
      }
    }

    // Normal svensk enhetskonvertering (alltid aktiv)
    if (parsed.unit.isNotEmpty &&
        SmartUnitConverter.shouldConvert(finalQuantity, finalUnit)) {
      final converted = SmartUnitConverter.convertToReadableUnit(
        finalQuantity,
        finalUnit,
      );
      finalQuantity = converted.quantity;
      finalUnit = converted.unit;
    }

    // Formatera med svenska bråk och enheter
    final formattedQuantity = toSwedishHalfFraction(finalQuantity);

    // Bygg ihop igen
    if (finalUnit.isNotEmpty) {
      return '$formattedQuantity $finalUnit ${parsed.name}';
    } else {
      // Använd pluralisering för ingredienser utan enhet
      return SwedishPluralization.formatIngredient(parsed.name, scaledQuantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header med portionskontroller
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Theme.of(context).colorScheme.primary,
                size: AppTheme.iconSizeSmall,
              ),
              const SizedBox(width: AppTheme.spacingXs),
              Text(
                'Portioner',
                style: AppTheme.getTextStyle(
                  context,
                  AppTheme.subtitleStyle,
                  color: Theme.of(context).colorScheme.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _buildPortionControls(context),
            ],
          ),

          AppTheme.smallGap,

          // Info om skalning och enhetskonvertering
          if (_currentPortions != widget.originalPortions ||
              _convertToSwedish) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _convertToSwedish ? Icons.language : Icons.calculate,
                    size: AppTheme.iconSizeSmall,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  Flexible(
                    child: Text(
                      _buildStatusText(),
                      style: AppTheme.captionStyle.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppTheme.smallGap,
          ],

          // Enhetskonvertering toggle (bara om receptet har amerikanska enheter)
          if (_hasAmericanUnits) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleUnitConversion,
                      icon: Icon(
                        _convertToSwedish ? Icons.check_circle : Icons.language,
                        size: AppTheme.iconSizeSmall,
                      ),
                      label: Text(
                        _convertToSwedish
                            ? 'Använder svenska enheter'
                            : 'Konvertera amerikanska enheter',
                        style: AppTheme.captionStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _convertToSwedish
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(
                          color:
                              _convertToSwedish
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                        ),
                        backgroundColor:
                            _convertToSwedish
                                ? Theme.of(context).colorScheme.primaryContainer
                                    .withValues(alpha: 0.3)
                                : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXs,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Skalade ingredienser
          _buildScaledIngredients(context),
        ],
      ),
    );
  }

  Widget _buildPortionControls(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minus knapp
                _buildControlButton(
                  context,
                  icon: Icons.remove,
                  onPressed:
                      _currentPortions > widget.minPortions
                          ? () => _updatePortions(_currentPortions - 1)
                          : null,
                ),

                // Nuvarande portioner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  child: Text(
                    '$_currentPortions',
                    style: AppTheme.getTextStyle(
                      context,
                      AppTheme.cardTitleStyle,
                      color: Theme.of(context).colorScheme.primary,
                    ).copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Plus knapp
                _buildControlButton(
                  context,
                  icon: Icons.add,
                  onPressed:
                      _currentPortions < widget.maxPortions
                          ? () => _updatePortions(_currentPortions + 1)
                          : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingSm),
          child: Icon(
            icon,
            size: AppTheme.iconSizeSmall,
            color:
                onPressed != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  String _buildStatusText() {
    final List<String> status = [];

    if (_currentPortions != widget.originalPortions) {
      status.add(
        'Skalat från ${widget.originalPortions} till $_currentPortions portioner',
      );
    }

    if (_convertToSwedish) {
      status.add('Amerikanska enheter konverterade till svenska');
    }

    return status.join(' • ');
  }

  Widget _buildScaledIngredients(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredienser för $_currentPortions ${_currentPortions == 1 ? 'portion' : 'portioner'}:',
          style: AppTheme.getTextStyle(
            context,
            AppTheme.bodyStyle,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w500),
        ),

        AppTheme.smallGap,

        Container(
          width: double.infinity,
          padding: AppTheme.cardPadding,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppTheme.cardBorderRadius,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                _scaledIngredients.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ingredient = entry.value;
                  final originalIngredient =
                      index < widget.originalIngredients.length
                          ? widget.originalIngredients[index]
                          : '';
                  final isChanged =
                      _currentPortions != widget.originalPortions ||
                      _convertToSwedish ||
                      ingredient != originalIngredient;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppTheme.spacingXxs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bullet point
                        Container(
                          width: 6,
                          height: 6,
                          margin: EdgeInsets.only(
                            top: 8,
                            right: AppTheme.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isChanged
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),

                        // Ingrediens text
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: AppTheme.getTextStyle(
                              context,
                              AppTheme.bodyStyle,
                              color:
                                  isChanged
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                            ).copyWith(
                              fontWeight:
                                  isChanged
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                            child: Text(ingredient),
                          ),
                        ),

                        // Ändrad indikator
                        if (isChanged)
                          Icon(
                            Icons.refresh,
                            size: AppTheme.iconSizeSmall,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }
}
