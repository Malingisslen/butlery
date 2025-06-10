// lib/views/edit_recipe_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_form_viewmodel.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';
import '../widgets/cached_recipe_image.dart';
import '../core/validators/form_validators.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD REDIGERA RECEPT VY MED RECIPEFORMVIEWMODEL
class EditRecipeView extends StatelessWidget {
  final Recipe recipe;

  const EditRecipeView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) =>
              RecipeFormViewModel(recipeService: sl(), initialRecipe: recipe),
      child: const _EditRecipeViewContent(),
    );
  }
}

class _EditRecipeViewContent extends StatefulWidget {
  const _EditRecipeViewContent();

  @override
  State<_EditRecipeViewContent> createState() => _EditRecipeViewContentState();
}

class _EditRecipeViewContentState extends State<_EditRecipeViewContent> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<RecipeFormViewModel>();
    final success = await viewModel.saveRecipe();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ändringar sparade!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error ?? 'Kunde inte spara ändringar'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Redigera recept')),
      bottomNavigationBar: Padding(
        padding: AppTheme.screenPadding,
        child: ActionButton.primary(
          label: 'Spara ändringar',
          icon: Icons.save,
          onPressed:
              viewModel.isSaving || !viewModel.isValid ? null : _saveRecipe,
          isLoading: viewModel.isSaving,
          loadingText: 'Sparar...',
          isExpanded: true,
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: AppTheme.screenPadding,
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Måltidstyp
                  DropdownButtonFormField<String>(
                    value: viewModel.mealType,
                    decoration: const InputDecoration(labelText: 'Måltidstyp'),
                    items:
                        RecipeFormViewModel.mealTypes
                            .map(
                              (mt) =>
                                  DropdownMenuItem(value: mt, child: Text(mt)),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) viewModel.setMealType(value);
                    },
                  ),
                  AppTheme.mediumGap,

                  // Bildförhandsvisning
                  if (viewModel.imageUrl != null &&
                      viewModel.imageUrl!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spacingMd),
                      child: ClipRRect(
                        borderRadius: AppTheme.largeRadius,
                        child: CachedRecipeHeroImage(
                          imageUrl: viewModel.imageUrl,
                          height: AppTheme.imageHeightMedium,
                        ),
                      ),
                    ),

                  // Titel
                  TextFormField(
                    initialValue: viewModel.title,
                    decoration: const InputDecoration(labelText: 'Titel'),
                    onChanged: viewModel.setTitle,
                    validator: FormValidators.combine([
                      FormValidators.required('Titel'),
                      FormValidators.maxLength(100, 'Titel'),
                    ]),
                  ),
                  AppTheme.mediumGap,

                  // Beskrivning
                  TextFormField(
                    initialValue: viewModel.description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Beskrivning'),
                    onChanged: viewModel.setDescription,
                    validator: FormValidators.maxLength(500, 'Beskrivning'),
                  ),
                  AppTheme.mediumGap,

                  // Portioner
                  TextFormField(
                    initialValue: viewModel.portions?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Antal portioner',
                    ),
                    onChanged: viewModel.setPortions,
                    validator: FormValidators.portions(),
                  ),
                  AppTheme.mediumGap,

                  // Tid
                  TextFormField(
                    initialValue: viewModel.timeMinutes?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tid (minuter)',
                    ),
                    onChanged: viewModel.setTimeMinutes,
                    validator: FormValidators.cookingTime(),
                  ),
                  AppTheme.mediumGap,

                  // Ingredienser
                  _buildDynamicList(
                    'Ingrediens',
                    viewModel.ingredients,
                    viewModel.updateIngredient,
                    viewModel.addIngredient,
                    viewModel.removeIngredient,
                  ),
                  AppTheme.mediumGap,

                  // Instruktioner
                  _buildDynamicList(
                    'Instruktion',
                    viewModel.instructions,
                    viewModel.updateInstruction,
                    viewModel.addInstruction,
                    viewModel.removeInstruction,
                  ),
                  AppTheme.mediumGap,

                  // Taggar
                  _buildDynamicList(
                    'Tagg',
                    viewModel.tags,
                    viewModel.updateTag,
                    viewModel.addTag,
                    viewModel.removeTag,
                  ),
                  AppTheme.mediumGap,

                  // Betyg
                  TextFormField(
                    initialValue: viewModel.rating?.toString() ?? '',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
                    onChanged: viewModel.setRating,
                    validator: FormValidators.rating(),
                  ),
                  AppTheme.mediumGap,

                  // Bild-URL
                  TextFormField(
                    initialValue: viewModel.imageUrl ?? '',
                    decoration: const InputDecoration(labelText: 'Bild-URL'),
                    onChanged: viewModel.setImageUrl,
                    validator: FormValidators.url(),
                    onFieldSubmitted: (_) {
                      // Trigger rebuild för att uppdatera bildförhandsvisning
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (viewModel.isSaving)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: AppTheme.cardPadding,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: AppTheme.largeRadius,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppTheme.mediumLoadingIndicator(),
                      AppTheme.smallGap,
                      Text(
                        'Uppdaterar recept...',
                        style: AppTheme.subtitleStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicList(
    String label,
    List<String> items,
    Function(int, String) onUpdate,
    VoidCallback onAdd,
    Function(int) onRemove,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.formLabelStyle),
        AppTheme.smallGap,
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${label}_$index'),
                    initialValue: value,
                    decoration: InputDecoration(
                      hintText: '$label ${index + 1}',
                    ),
                    onChanged: (newValue) => onUpdate(index, newValue),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                if (value.trim().isNotEmpty || index < items.length - 1)
                  IconButton(
                    icon: AppTheme.actionIcon(context, Icons.delete),
                    onPressed: () => onRemove(index),
                  ),
              ],
            ),
          );
        }),
        if (items.isEmpty || items.last.isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Lägg till $label'),
            onPressed: onAdd,
          ),
      ],
    );
  }
}
