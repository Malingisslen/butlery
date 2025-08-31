// lib/views/edit_recipe/edit_recipe_form_fields.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
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
      // Meal type dropdown - Custom layout to fix text cutoff
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Måltidstyp',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4.0), // Minimal gap between label and dropdown
          DropdownButtonFormField<String>(
            initialValue: viewModel.mealType,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL,
                vertical: AppDimensions.paddingM,
              ),
              border: OutlineInputBorder(),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            items: RecipeFormViewModel.mealTypes
                .map((mt) => DropdownMenuItem(value: mt, child: Text(mt)))
                .toList(),
            onChanged: (value) {
              if (value != null) viewModel.setMealType(value);
            },
          ),
        ],
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Image management
      UniversalImageManager.recipeEdit(
        imageUrls: viewModel.imageUrls,
        onRemoveImage: viewModel.removeImageAt,
        onSetPrimary: (index) {
          if (index < viewModel.imageUrls.length) {
            final imageUrl = viewModel.imageUrls[index];
            viewModel.setPrimaryImage(imageUrl);
          }
        },
        userId: ServiceLocator.get<PermissionService>().currentUserId ?? '',
        onPickImage: () => EditRecipeImagePicker.pickImage(context, viewModel),
        maxImages: 5,
        isLoading: viewModel.isUploadingImage,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Title field
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
      const SizedBox(height: AppDimensions.spacingXl),

      // Description field
      TextFormField(
        initialValue: viewModel.description,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Beskrivning'),
        style: Theme.of(context).textTheme.bodyMedium,
        textInputAction: TextInputAction.next,
        onChanged: viewModel.setDescription,
        validator: FormValidators.maxLength(500, 'Beskrivning'),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Portions field
      TextFormField(
        initialValue: viewModel.portions?.toString() ?? '',
        decoration: const InputDecoration(labelText: 'Portioner'),
        style: Theme.of(context).textTheme.bodyMedium,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        onChanged: (value) => viewModel.setPortions(int.tryParse(value)),
        validator: FormValidators.portions(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Time field
      TextFormField(
        initialValue: viewModel.timeMinutes?.toString() ?? '',
        decoration: const InputDecoration(labelText: 'Tid (min)'),
        style: Theme.of(context).textTheme.bodyMedium,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
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
        context: context,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Instructions dynamic list
      EditRecipeDynamicList.build(
        label: 'Instruktion',
        controllers: viewModel.instructionControllers,
        onUpdate: viewModel.updateInstruction,
        onAdd: viewModel.addInstruction,
        onRemove: viewModel.removeInstruction,
        context: context,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Tags dynamic list
      EditRecipeDynamicList.build(
        label: 'Tagg',
        controllers: viewModel.tagControllers,
        onUpdate: viewModel.updateTag,
        onAdd: viewModel.addTag,
        onRemove: viewModel.removeTag,
        context: context,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Rating field
      TextFormField(
        initialValue: viewModel.rating?.toString() ?? '',
        decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
        style: Theme.of(context).textTheme.bodyMedium,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        onChanged: (value) => viewModel.setRating(double.tryParse(value)),
        validator: FormValidators.rating(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Source URL field
      TextFormField(
        initialValue: viewModel.sourceUrl ?? '',
        decoration: InputDecoration(
          labelText: 'Källa (URL)',
          hintText: 'Valfritt: länk till originalreceptet',
          helperText: viewModel.sourceUrl == 'Delad från annan app'
              ? 'Importerat från delning'
              : 'Länk till originalreceptet',
          prefixIcon: const Icon(
            Icons.link,
            size: AppDimensions.iconSizeAction,
          ),
        ),
        style: Theme.of(context).textTheme.bodyMedium,
        keyboardType: TextInputType.url,
        onChanged: viewModel.setSourceUrl,
        validator: FormValidators.recipeSourceUrl(),
      ),
    ];
  }
}
