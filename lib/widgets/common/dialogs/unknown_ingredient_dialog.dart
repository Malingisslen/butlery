import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Dialog for handling unknown ingredients found during recipe tagging.
///
/// Shows a list of unknown ingredients and allows the user to:
/// - Skip individual ingredients (leave as unknown)
/// - Define properties for each ingredient
/// - Save defined ingredients for future recipes
class UnknownIngredientDialog extends StatefulWidget {
  final List<String> unknownIngredients;
  final String? userId;
  final VoidCallback? onComplete;

  const UnknownIngredientDialog({
    super.key,
    required this.unknownIngredients,
    this.userId,
    this.onComplete,
  });

  /// Shows the dialog and returns true if any ingredients were defined.
  static Future<bool> show(
    BuildContext context, {
    required List<String> unknownIngredients,
    String? userId,
    VoidCallback? onComplete,
  }) async {
    if (unknownIngredients.isEmpty) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnknownIngredientDialog(
        unknownIngredients: unknownIngredients,
        userId: userId,
        onComplete: onComplete,
      ),
    );

    return result ?? false;
  }

  @override
  State<UnknownIngredientDialog> createState() =>
      _UnknownIngredientDialogState();
}

class _UnknownIngredientDialogState extends State<UnknownIngredientDialog> {
  late List<_IngredientDefinition> _definitions;
  int _currentIndex = 0;
  bool _isSaving = false;

  TaggingService? get _taggingService {
    try {
      return ServiceLocator.get<TaggingService>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _definitions = widget.unknownIngredients
        .map((name) => _IngredientDefinition(name: name))
        .toList();
  }

  _IngredientDefinition get _current => _definitions[_currentIndex];
  bool get _isLast => _currentIndex == _definitions.length - 1;
  bool get _isFirst => _currentIndex == 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        context.l10n.dialogUnknownIngredientProgress(
            _currentIndex + 1, _definitions.length),
        style: theme.textTheme.titleLarge,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ingredient name
              Text(
                _current.name,
                style: AppTextStyles.headlineBold,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                context.l10n.dialogUnknownIngredientDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),

              // Common allergen toggles
              Text(
                context.l10n.dialogContainsAllergens,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              _buildAllergenSection(),

              const SizedBox(height: AppDimensions.spacingMd),

              // Dietary properties
              Text(
                context.l10n.dialogDietaryProperties,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              _buildDietarySection(),
            ],
          ),
        ),
      ),
      actions: [
        // Skip button
        TextButton(
          onPressed: _isSaving ? null : _skipCurrent,
          child: Text(
              _isLast ? context.l10n.commonSkipAll : context.l10n.commonSkip),
        ),
        // Navigation/Save buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isFirst)
              TextButton(
                onPressed: _isSaving ? null : _previous,
                child: Text(context.l10n.commonPrevious),
              ),
            const SizedBox(width: AppDimensions.spacingSm),
            FilledButton(
              onPressed: _isSaving ? null : _saveAndNext,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isLast
                      ? context.l10n.commonSaveAndClose
                      : context.l10n.commonSaveAndNext),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAllergenSection() {
    final commonAllergens = [
      ('contains-gluten', context.l10n.allergenGluten),
      ('dairy', context.l10n.allergenDairy),
      ('egg', context.l10n.allergenEgg),
      ('fish', context.l10n.allergenFish),
      ('crustacean', context.l10n.allergenCrustacean),
      ('tree-nut', context.l10n.allergenTreeNut),
      ('peanut', context.l10n.allergenPeanut),
      ('soy', context.l10n.allergenSoy),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: commonAllergens.map((allergen) {
        final isSelected = _current.properties.contains(allergen.$1);
        return FilterChip(
          label: Text(allergen.$2),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _current.properties.add(allergen.$1);
              } else {
                _current.properties.remove(allergen.$1);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildDietarySection() {
    final dietaryOptions = [
      ('meat', context.l10n.dietaryMeat),
      ('pork', context.l10n.dietaryPork),
      ('beef', context.l10n.dietaryBeef),
      ('poultry', context.l10n.dietaryPoultry),
      ('seafood', context.l10n.dietarySeafood),
      ('animal-product', context.l10n.dietaryAnimalProduct),
      ('contains-alcohol', context.l10n.dietaryAlcohol),
      ('is-spicy', context.l10n.dietarySpicy),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: dietaryOptions.map((option) {
        final isSelected = _current.properties.contains(option.$1);
        return FilterChip(
          label: Text(option.$2),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _current.properties.add(option.$1);
              } else {
                _current.properties.remove(option.$1);
              }
            });
          },
        );
      }).toList(),
    );
  }

  void _skipCurrent() {
    if (_isLast) {
      // Skip all remaining and close
      _close(anyDefined: _definitions.any((d) => d.isDefined));
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _previous() {
    if (!_isFirst) {
      setState(() => _currentIndex--);
    }
  }

  Future<void> _saveAndNext() async {
    if (_current.properties.isEmpty) {
      // Nothing to save, just skip
      _skipCurrent();
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save the ingredient definition
      if (_taggingService != null && widget.userId != null) {
        await _taggingService!.saveUserIngredient(
          userId: widget.userId!,
          ingredientName: _current.name,
          properties: _current.properties,
        );
        _current.isDefined = true;
      }

      if (_isLast) {
        _close(anyDefined: true);
      } else {
        if (!mounted) return;
        setState(() {
          _currentIndex++;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.dialogCouldNotSave(e.toString()))),
        );
      }
    }
  }

  void _close({required bool anyDefined}) {
    widget.onComplete?.call();
    Navigator.of(context).pop(anyDefined);
  }
}

/// Internal class to track ingredient definition state.
class _IngredientDefinition {
  final String name;
  final Set<String> properties = {};
  bool isDefined = false;

  _IngredientDefinition({required this.name});
}
