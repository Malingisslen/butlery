/// Autocomplete text input with removable ingredient chips.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/input/ingredient_suggestion_list.dart';

class IngredientChipInput extends StatefulWidget {
  const IngredientChipInput({
    required this.selectedIngredients,
    required this.autocompleteResults,
    required this.onSearchChanged,
    required this.onIngredientSelected,
    required this.onIngredientRemoved,
    super.key,
  });

  final List<IngredientData> selectedIngredients;
  final List<IngredientData> autocompleteResults;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<IngredientData> onIngredientSelected;
  final ValueChanged<String> onIngredientRemoved;

  @override
  State<IngredientChipInput> createState() => _IngredientChipInputState();
}

class _IngredientChipInputState extends State<IngredientChipInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    widget.onSearchChanged(query);
    setState(() => _showSuggestions = query.trim().isNotEmpty);
  }

  void _onSuggestionTap(IngredientData ingredient) {
    widget.onIngredientSelected(ingredient);
    _controller.clear();
    setState(() => _showSuggestions = false);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text input
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: l10n.ingredientSearchHint,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),

        // Autocomplete suggestions
        if (_showSuggestions && widget.autocompleteResults.isNotEmpty)
          IngredientSuggestionList(
            results: widget.autocompleteResults,
            onTap: _onSuggestionTap,
          ),

        // Selected ingredient chips
        if (widget.selectedIngredients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
            child: Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              children: widget.selectedIngredients.map((ingredient) {
                return _IngredientChip(
                  key: ValueKey(ingredient.id),
                  label: ingredient.swedish,
                  onRemove: () => widget.onIngredientRemoved(ingredient.id),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({
    required this.label,
    required this.onRemove,
    super.key,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppDimensions.paddingSymmetric6x2,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
        border: Border.all(
          color: cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(color: cs.primary),
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Semantics(
            label: context.l10n.a11yRemoveIngredientChip(label),
            button: true,
            child: InkWell(
              onTap: onRemove,
              child: SizedBox(
                width: AppDimensions.minTouchTarget,
                height: AppDimensions.minTouchTarget,
                child: Icon(
                  Icons.close,
                  size: AppDimensions.iconSizeS,
                  color: cs.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
