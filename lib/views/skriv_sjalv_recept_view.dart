// lib/views/skriv_sjalv_recept_view.dart
// REFAKTORERAD: Nu följer strikt MVVM - alla controllers hanteras av ViewModel

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_form_viewmodel.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';
import '../core/validators/form_validators.dart';
import '../core/injection.dart';

/// Skapa nytt recept view - nu med ren MVVM implementation
class SkrivSjalvReceptView extends StatelessWidget {
  final Recipe? initialRecipe;
  final bool isTemplate;

  const SkrivSjalvReceptView({
    super.key,
    this.initialRecipe,
    this.isTemplate = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) => RecipeFormViewModel(
            recipeService: sl(),
            initialRecipe: initialRecipe,
            isTemplate: isTemplate,
          ),
      child: const _SkrivSjalvReceptViewContent(),
    );
  }
}

class _SkrivSjalvReceptViewContent extends StatefulWidget {
  const _SkrivSjalvReceptViewContent();

  @override
  State<_SkrivSjalvReceptViewContent> createState() =>
      _SkrivSjalvReceptViewContentState();
}

class _SkrivSjalvReceptViewContentState
    extends State<_SkrivSjalvReceptViewContent> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<RecipeFormViewModel>();
    final success = await viewModel.saveRecipe();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recept sparat!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error ?? 'Kunde inte spara recept'),
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
      appBar: AppBar(
        title: Text(
          viewModel.isEditMode ? 'Redigera recept' : 'Skriv nytt recept',
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: AppTheme.screenPadding,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: AppTheme.spacingXxl + AppTheme.spacingMd,
                ),
                children: [
                  // Måltidstyp
                  DropdownButtonFormField<String>(
                    value: viewModel.mealType,
                    decoration: const InputDecoration(labelText: 'Måltidstyp'),
                    style: Theme.of(context).textTheme.bodyMedium,
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

                  // Titel
                  TextFormField(
                    initialValue: viewModel.title,
                    decoration: const InputDecoration(labelText: 'Titel'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
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
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setDescription,
                    validator: FormValidators.maxLength(500, 'Beskrivning'),
                  ),
                  AppTheme.mediumGap,

                  // Portioner
                  TextFormField(
                    initialValue: viewModel.portions?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Portioner'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setPortions,
                    validator: FormValidators.portions(),
                  ),
                  AppTheme.mediumGap,

                  // Tid
                  TextFormField(
                    initialValue: viewModel.timeMinutes?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Tid (min)'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setTimeMinutes,
                    validator: FormValidators.cookingTime(),
                  ),
                  AppTheme.mediumGap,

                  // Ingredienser - FIXAD!
                  _buildDynamicList(
                    label: 'Ingrediens',
                    controllers: viewModel.ingredientControllers,
                    onUpdate: viewModel.updateIngredient,
                    onAdd: viewModel.addIngredient,
                    onRemove: viewModel.removeIngredient,
                    viewModel: viewModel,
                  ),
                  AppTheme.mediumGap,

                  // Instruktioner - FIXAD!
                  _buildDynamicList(
                    label: 'Instruktion',
                    controllers: viewModel.instructionControllers,
                    onUpdate: viewModel.updateInstruction,
                    onAdd: viewModel.addInstruction,
                    onRemove: viewModel.removeInstruction,
                    viewModel: viewModel,
                  ),
                  AppTheme.mediumGap,

                  // Taggar
                  _buildDynamicList(
                    label: 'Tagg',
                    controllers: viewModel.tagControllers,
                    onUpdate: viewModel.updateTag,
                    onAdd: viewModel.addTag,
                    onRemove: viewModel.removeTag,
                    viewModel: viewModel,
                  ),
                  AppTheme.mediumGap,

                  // Betyg
                  TextFormField(
                    initialValue: viewModel.rating?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setRating,
                    validator: FormValidators.rating(),
                  ),
                  AppTheme.mediumGap,

                  // Bild-URL
                  TextFormField(
                    initialValue: viewModel.imageUrl ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Bild-URL',
                      hintText: 'Valfritt: länk till bild',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: TextInputType.url,
                    onChanged: viewModel.setImageUrl,
                    validator: (value) {
                      // Gör URL-validering valfri - bara validera om fältet har innehåll
                      if (value == null || value.isEmpty) return null;
                      return FormValidators.url()(value);
                    },
                  ),
                  AppTheme.mediumGap,

                  // Source URL-fält
                  TextFormField(
                    initialValue: viewModel.sourceUrl ?? '',
                    decoration: InputDecoration(
                      labelText: 'Källa (URL)',
                      hintText: 'Valfritt: länk till originalreceptet',
                      helperText:
                          viewModel.sourceUrl == 'Delad från annan app'
                              ? 'Importerat från delning'
                              : 'Länk till originalreceptet',
                      prefixIcon: Icon(
                        Icons.link,
                        size: AppTheme.iconSizeAction,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: TextInputType.url,
                    onChanged: viewModel.setSourceUrl,
                    validator: (value) {
                      // Gör URL-validering valfri - bara validera om fältet har innehåll
                      if (value == null || value.isEmpty) return null;
                      // Tillåt även "Delad från annan app" och liknande texter
                      if (value.startsWith('Delad från') ||
                          value.startsWith('Importerad från')) {
                        return null;
                      }
                      return FormValidators.url()(value);
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
                  decoration: AppTheme.cardDecoration,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppTheme.mediumLoadingIndicator(),
                      AppTheme.smallGap,
                      Text('Sparar recept...', style: AppTheme.subtitleStyle),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Spara-knappen
      bottomNavigationBar: Padding(
        padding: AppTheme.screenPadding,
        child: ActionButton.primary(
          label: 'Spara recept',
          icon: Icons.save,
          onPressed:
              viewModel.isSaving || !viewModel.isValid ? null : _saveRecipe,
          isLoading: viewModel.isSaving,
          loadingText: 'Sparar...',
          isExpanded: true,
        ),
      ),
    );
  }

  // FIXAD METOD - Nu lägger till ny ruta automatiskt!
  Widget _buildDynamicList({
    required String label,
    required List<TextEditingController> controllers,
    required Function(int, String) onUpdate,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required RecipeFormViewModel viewModel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.formLabelStyle),
        AppTheme.smallGap,

        // Bygg fält från controllers som ViewModel tillhandahåller
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: '$label ${index + 1}',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    // KRITISK FIX: onChanged som både uppdaterar OCH lägger till ny ruta
                    onChanged: (value) {
                      onUpdate(index, value);

                      // Om detta är sista fältet och det har text, lägg till nytt fält
                      if (index == controllers.length - 1 && value.isNotEmpty) {
                        // Kör efter frame för att undvika setState under build
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onAdd();
                        });
                      }
                    },
                  ),
                ),
                // Visa delete-knapp om det finns mer än ett fält
                if (controllers.length > 1)
                  IconButton(
                    icon: AppTheme.actionIcon(context, Icons.delete),
                    onPressed: () => onRemove(index),
                  ),
              ],
            ),
          );
        }),

        // Lägg till-knapp endast om listan är tom
        if (controllers.isEmpty)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Lägg till $label'),
            onPressed: onAdd,
          ),
      ],
    );
  }
}
