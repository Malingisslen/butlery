// lib/views/edit_recipe/edit_recipe_form_fields.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/views/edit_recipe/edit_recipe_image_picker.dart';
import 'package:butlery/views/edit_recipe/edit_recipe_dynamic_list.dart';

/// Form fields for edit recipe view
class EditRecipeFormFields {
  
  /// Build all form fields for recipe editing
  static List<Widget> buildFormFields(
    BuildContext context,
    RecipeFormViewModel viewModel,
  ) {
    return [
      // Meal type dropdown
      DropdownButtonFormField<String>(
        value: viewModel.mealType,
        decoration: const InputDecoration(labelText: 'Måltidstyp'),
        items: RecipeFormViewModel.mealTypes
            .map((mt) => DropdownMenuItem(value: mt, child: Text(mt)))
            .toList(),
        onChanged: (value) {
          if (value != null) viewModel.setMealType(value);
        },
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Image management
      UniversalImageManager.recipeEdit(
        imageUrls: viewModel.imageUrls,
        userId: sl<PermissionService>().currentUserId ?? '',
        onAddImage: viewModel.addImageUrl,
        onRemoveImage: viewModel.removeImageAt,
        onSetPrimary: (index) {
          if (index < viewModel.imageUrls.length) {
            viewModel.setPrimaryImage(viewModel.imageUrls[index]);
          }
        },
        onPickImage: () => EditRecipeImagePicker.pickImage(context, viewModel),
        maxImages: 5,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Title field
      TextFormField(
        initialValue: viewModel.title,
        decoration: const InputDecoration(labelText: 'Titel'),
        onChanged: viewModel.setTitle,
        validator: FormValidators.combine([
          FormValidators.required('Titel'),
          FormValidators.maxLength(100, 'Titel'),
        ]),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Description field
      TextFormField(
        initialValue: viewModel.description,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Beskrivning'),
        onChanged: viewModel.setDescription,
        validator: FormValidators.maxLength(500, 'Beskrivning'),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Portions field
      TextFormField(
        initialValue: viewModel.portions?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Antal portioner'),
        onChanged: (value) => viewModel.setPortions(int.tryParse(value)),
        validator: FormValidators.portions(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Time field
      TextFormField(
        initialValue: viewModel.timeMinutes?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Tid (minuter)'),
        onChanged: (value) => viewModel.setTimeMinutes(int.tryParse(value)),
        validator: FormValidators.cookingTime(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Ingredients dynamic list
      EditRecipeDynamicList.build(
        label: 'Ingrediens',
        controllers: viewModel.ingredientControllers,
        onUpdate: viewModel.updateIngredient,
        onAdd: viewModel.addIngredient,
        onRemove: viewModel.removeIngredient,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Instructions dynamic list
      EditRecipeDynamicList.build(
        label: 'Instruktion',
        controllers: viewModel.instructionControllers,
        onUpdate: viewModel.updateInstruction,
        onAdd: viewModel.addInstruction,
        onRemove: viewModel.removeInstruction,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Tags dynamic list
      EditRecipeDynamicList.build(
        label: 'Tagg',
        controllers: viewModel.tagControllers,
        onUpdate: viewModel.updateTag,
        onAdd: viewModel.addTag,
        onRemove: viewModel.removeTag,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Rating field
      TextFormField(
        initialValue: viewModel.rating?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
        onChanged: (value) => viewModel.setRating(double.tryParse(value)),
        validator: FormValidators.rating(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Source URL field
      TextFormField(
        initialValue: viewModel.sourceUrl ?? '',
        decoration: const InputDecoration(
          labelText: 'Källa (URL)',
          hintText: 'https://exempel.com/recept',
          helperText: 'Länk till originalreceptet',
          prefixIcon: Icon(Icons.link, size: AppDimensions.iconSizeAction),
        ),
        keyboardType: TextInputType.url,
        onChanged: viewModel.setSourceUrl,
        validator: FormValidators.url(),
      ),
    ];
  }
}