/// Autocomplete text input with removable ingredient chips.
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
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
        // The chosen ingredients stand as chips inside the box, before the
        // text (Komponentark v1 §07 "Tokeniserad").
        ButlerySearchBox(
          controller: _controller,
          focusNode: _focusNode,
          hintText: l10n.ingredientSearchHint,
          onChanged: _onSearchChanged,
          tokens: [
            for (final ingredient in widget.selectedIngredients)
              SearchToken(
                id: ingredient.id,
                label: ingredient.swedish,
                onRemove: () => widget.onIngredientRemoved(ingredient.id),
              ),
          ],
        ),

        if (_showSuggestions && widget.autocompleteResults.isNotEmpty)
          IngredientSuggestionList(
            results: widget.autocompleteResults,
            onTap: _onSuggestionTap,
          ),
      ],
    );
  }
}
