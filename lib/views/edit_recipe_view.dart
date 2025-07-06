// lib/views/edit_recipe_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_form_viewmodel.dart';
import '../widgets/common/utility_components.dart';
import '../widgets/image/universal_image_manager.dart';
import '../theme/app_theme.dart';
import '../core/validators/form_validators.dart';
import '../core/injection.dart';

/// ✨ MIGRERAD REDIGERA RECEPT VY - Nu med UtilityComponents
class EditRecipeView extends StatelessWidget {
  final Recipe recipe;

  const EditRecipeView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeFormViewModel(
        recipeService: sl(),
        analyticsService: sl(),
        storageService: sl(),
        imagePickerService: sl(),
        authService: sl(),
        initialRecipe: recipe,
      ),
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
        // ✅ MIGRERAD: Använd UtilityComponents.showSuccessSnackbar
        UtilityComponents.showSuccessSnackbar(context, 'Ändringar sparade!');
        Navigator.pop(context, true);
      } else {
        // ✅ MIGRERAD: Använd UtilityComponents.showErrorSnackbar
        UtilityComponents.showErrorSnackbar(
            context, viewModel.error ?? 'Kunde inte spara ändringar');
      }
    }
  }

  // FÖRENKLAD SMART BILDVÄLJARE
  Future<void> _pickImage(RecipeFormViewModel viewModel) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              child: Text(
                'Lägg till bild',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Ta foto'),
              subtitle: const Text('Använd kameran'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Från galleriet'),
              subtitle: Text(
                viewModel.canAddMoreImages
                    ? 'Välj upp till ${RecipeFormViewModel.maxImages - viewModel.imageUrls.length} bilder'
                    : 'Välj en bild från galleriet',
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.link,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: const Text('Lägg till från URL'),
              subtitle: const Text('För bilder från webben'),
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Avbryt'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    switch (choice) {
      case 'camera':
        await viewModel.pickAndUploadImage(context, source: ImageSource.camera);
        break;
      case 'gallery':
        if (viewModel.canAddMoreImages && viewModel.imageUrls.length < 4) {
          await viewModel.pickMultipleImages(context);
        } else {
          await viewModel.pickAndUploadImage(
            context,
            source: ImageSource.gallery,
          );
        }
        break;
      case 'url':
        final controller = TextEditingController();
        final url = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lägg till bild från URL'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Bild-URL',
                hintText: 'https://exempel.com/bild.jpg',
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Lägg till'),
              ),
            ],
          ),
        );

        if (url != null && url.isNotEmpty) {
          if (Uri.tryParse(url) != null &&
              (url.startsWith('http://') || url.startsWith('https://'))) {
            viewModel.addImageUrl(url);
          } else {
            if (mounted) {
              UtilityComponents.showErrorSnackbar(context, 'Ogiltig URL');
            }
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();
    final authService = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Redigera recept')),
      bottomNavigationBar: Padding(
        padding: AppTheme.screenPadding,
        // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
        child: UtilityComponents.primaryButton(
          context,
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
                    items: RecipeFormViewModel.mealTypes
                        .map(
                          (mt) => DropdownMenuItem(value: mt, child: Text(mt)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) viewModel.setMealType(value);
                    },
                  ),
                  AppTheme.mediumGap,

                  // Bildhantering med UniversalImageManager
                  UniversalImageManager.recipeEdit(
                    imageUrls: viewModel.imageUrls,
                    userId: authService.currentUser?.uid ?? '',
                    onAddImage: viewModel.addImageUrl,
                    onRemoveImage: viewModel.removeImageAt,
                    onSetPrimary: viewModel.setPrimaryImage,
                    onPickImage: () => _pickImage(viewModel),
                    maxImages: 5,
                  ),
                  AppTheme.largeGap,

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
                    label: 'Ingrediens',
                    controllers: viewModel.ingredientControllers,
                    onUpdate: viewModel.updateIngredient,
                    onAdd: viewModel.addIngredient,
                    onRemove: viewModel.removeIngredient,
                  ),
                  AppTheme.mediumGap,

                  // Instruktioner
                  _buildDynamicList(
                    label: 'Instruktion',
                    controllers: viewModel.instructionControllers,
                    onUpdate: viewModel.updateInstruction,
                    onAdd: viewModel.addInstruction,
                    onRemove: viewModel.removeInstruction,
                  ),
                  AppTheme.mediumGap,

                  // Taggar
                  _buildDynamicList(
                    label: 'Tagg',
                    controllers: viewModel.tagControllers,
                    onUpdate: viewModel.updateTag,
                    onAdd: viewModel.addTag,
                    onRemove: viewModel.removeTag,
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

                  // Source URL-fält
                  TextFormField(
                    initialValue: viewModel.sourceUrl ?? '',
                    decoration: InputDecoration(
                      labelText: 'Källa (URL)',
                      hintText: 'https://exempel.com/recept',
                      helperText: 'Länk till originalreceptet',
                      prefixIcon: Icon(
                        Icons.link,
                        size: AppTheme.iconSizeAction,
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: viewModel.setSourceUrl,
                    validator: FormValidators.url(),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay med UtilityComponents
          if (viewModel.isSaving)
            UtilityComponents.loadingOverlay(
              isLoading: true,
              loadingMessage: 'Uppdaterar recept...',
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicList({
    required String label,
    required List<TextEditingController> controllers,
    required Function(int, String) onUpdate,
    required VoidCallback onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.formLabelStyle),
        AppTheme.smallGap,
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
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onChanged: (value) => onUpdate(index, value),
                  ),
                ),
                if (controllers.length > 1)
                  IconButton(
                    icon: AppTheme.actionIcon(context, Icons.delete),
                    onPressed: () => onRemove(index),
                  ),
              ],
            ),
          );
        }),
        if (controllers.isEmpty ||
            (controllers.isNotEmpty && controllers.last.text.isNotEmpty))
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Lägg till $label'),
            onPressed: onAdd,
          ),
      ],
    );
  }
}
